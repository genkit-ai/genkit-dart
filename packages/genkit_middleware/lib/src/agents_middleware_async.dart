// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Background delegation for the agents middleware (the `async` option).
//
// A background delegation launches the sub-agent with `AgentInput.detach`: the
// runtime persists a pending snapshot, returns its ID at once, and keeps
// running the turn decoupled from this tool call. The pending snapshot is the
// durable record of the task: it is heartbeated while the worker lives,
// finalized in place with the cumulative session state when the work settles,
// and surfaced as `expired` by readers once the heartbeat goes stale.
//
// The middleware keeps no task registry. The task handle
// ("<agent>:<snapshotId>") is self-contained and rides in the tool result, so
// it is recorded in the orchestrator's conversation history; a re-instantiated
// orchestrator resumes tracking from the IDs in its history. Status goes
// through the sub-agent's snapshot/abort companion actions: check reads the
// row, abort flips a pending row to aborting, and wait polls the row until it
// settles.
//
// Unlike the Go port there is no blocking wait companion action, so
// `wait_for_background_tasks` polls the snapshot on an interval (the same
// strategy the runtime own DetachedTask.wait uses) rather than a single
// blocking dispatch.

part of 'agents_middleware.dart';

/// Polling interval used while a background
/// task is still in flight.
const _waitPollInterval = Duration(milliseconds: 200);

extension _AgentsMiddlewareAsync on AgentsMiddleware {
  // ── Launch ────────────────────────────────────────────────────────────────

  /// Starts a background delegation through the sub-agent's detach support and
  /// returns the task handle without waiting for the work. Launches count
  /// against maxDelegations like synchronous delegations, except a launch the
  /// sub-agent cannot support at all: that refusal returns its slot, so the
  /// synchronous fallback it hints at is not refused by a cap the refusal
  /// consumed. History is never forwarded: detach requires a server-managed
  /// sub-agent, and server-managed init rejects seeded state.
  Future<AgentDelegationResult> _launchDelegation(
    String name,
    String task,
    String? label,
  ) async {
    final begun = await _beginDelegation(name);
    if (begun.refusal != null) return begun.refusal!;
    final handle = begun.handle!;

    final words = _LaunchWords(
      errPrefix: "Error calling agent '$name'",
      withoutBackground: 'delegate to it without "background" instead',
      started: (taskId) => 'Background task $taskId started for agent "$name".',
      label: label,
    );

    final refusal = _refuseUndetachable(handle, words);
    if (refusal != null) return refusal;

    try {
      final out = await _runSubAgent(
        handle,
        message: Message(
          role: Role.user,
          content: [TextPart(text: task)],
        ),
        detach: true,
      );
      return _foldDetachOutcome(handle, begun.invocationNum, out, words);
    } catch (e) {
      return AgentDelegationResult(response: '${words.errPrefix}: $e');
    }
  }

  /// The pre-flight both background launches run. Abortable is derived at
  /// definition time from the store conditions the runtime's detach check
  /// enforces, so an agent that cannot detach is refused here deterministically,
  /// without a wasted invocation. The refusal names the synchronous retry, so it
  /// returns its slot.
  AgentDelegationResult? _refuseUndetachable(
    _AgentHandle handle,
    _LaunchWords words,
  ) {
    if (handle.abortable) return null;
    _releaseDelegation();
    return AgentDelegationResult(
      response:
          '${words.errPrefix}: this agent lacks a session store that supports '
          'background work, so it cannot run in the background; '
          '${words.withoutBackground}.',
    );
  }

  /// Turns the output of a detached run into the launch's tool result: the
  /// pending handle when the detach landed, or the ordinary fold when the run
  /// settled before detaching.
  AgentDelegationResult _foldDetachOutcome(
    _AgentHandle handle,
    int invocationNum,
    AgentOutput out,
    _LaunchWords words,
  ) {
    if (out.finishReason?.value == AgentFinishReason.detached.value &&
        out.snapshotId != null) {
      final taskId = _formatTaskId(handle.name, out.snapshotId!);
      final result = AgentDelegationResult(
        response:
            '${words.started(taskId)} Collect the result with $_checkToolName '
            'or $_waitToolName, or stop it with $_abortToolName.',
        taskId: taskId,
        status: SnapshotStatus.pending.value,
      );
      _labelTask(result, words.label);
      return result;
    }
    // The run settled before the detach landed, or failed on its own; fold it
    // like a synchronous delegation, handle and all.
    final result = _foldDelegationOutput(handle, out, invocationNum);
    _labelTask(result, words.label);
    return result;
  }

  // ── Background-task tools ──────────────────────────────────────────────────

  /// Builds the shared background-task tools added when the async option is set,
  /// one per control the orchestrator has over a launched task.
  List<Tool> _backgroundTaskTools() {
    return [
      Tool<BackgroundTasksInput, BackgroundTasksResult>(
        name: _checkToolName,
        description:
            'Returns the current status of background sub-agent tasks without '
            'waiting, including results for tasks that finished.',
        inputSchema: BackgroundTasksInput.$schema,
        toolOutputSchema: BackgroundTasksResult.$schema,
        fn: (input, _) async {
          final ids = input.taskIds ?? const [];
          if (ids.isEmpty) {
            return .response(BackgroundTasksResult(note: _noTaskIdsNote));
          }
          return .response(await _reportTasks(ids, _readSnapshotOnce));
        },
      ),
      Tool<WaitBackgroundTasksInput, BackgroundTasksResult>(
        name: _waitToolName,
        description:
            'Waits until the given background sub-agent tasks finish and returns '
            'their results. Set timeoutSeconds to bound the wait; on timeout the '
            'current statuses are returned. Set waitFor to "first" to return as '
            'soon as any one task settles.',
        inputSchema: WaitBackgroundTasksInput.$schema,
        toolOutputSchema: BackgroundTasksResult.$schema,
        fn: (input, _) async => .response(await _waitForBackgroundTasks(input)),
      ),
      Tool<BackgroundTasksInput, BackgroundTasksResult>(
        name: _abortToolName,
        description:
            'Stops background sub-agent tasks whose results are no longer '
            'needed, and returns where that left each one. A live task reports '
            '"aborting" while it winds down and settles as "aborted"; a task '
            'that had already finished is unaffected and reports its result.',
        inputSchema: BackgroundTasksInput.$schema,
        toolOutputSchema: BackgroundTasksResult.$schema,
        fn: (input, _) async {
          final ids = input.taskIds ?? const [];
          if (ids.isEmpty) {
            return .response(BackgroundTasksResult(note: _noTaskIdsNote));
          }
          return .response(await _reportTasks(ids, _abortSnapshot));
        },
      ),
    ];
  }

  static const _noTaskIdsNote =
      'No task IDs given. Pass the taskId values returned by background '
      'delegations.';

  /// The blocking status tool: it polls every task to its end, or returns the
  /// current statuses when the optional timeout elapses. "first" returns as soon
  /// as any one task settles, the rest reporting their current status.
  Future<BackgroundTasksResult> _waitForBackgroundTasks(
    WaitBackgroundTasksInput input,
  ) async {
    final ids = input.taskIds ?? const [];
    if (ids.isEmpty) return BackgroundTasksResult(note: _noTaskIdsNote);

    var first = false;
    switch (input.waitFor) {
      case null:
      case _waitForAll:
        break;
      case _waitForFirst:
        first = true;
      default:
        return BackgroundTasksResult(
          note:
              'Unknown waitFor value "${input.waitFor}". Use "$_waitForAll" '
              '(the default) to wait for every task, or "$_waitForFirst" to '
              'return when any one settles.',
        );
    }

    final timeoutSeconds = input.timeoutSeconds ?? 0;
    // A negative timeout means "don't wait": report the current statuses.
    if (timeoutSeconds < 0) {
      return _reportTasks(ids, _readSnapshotOnce);
    }

    final deadline = timeoutSeconds > 0
        ? DateTime.now().add(Duration(seconds: timeoutSeconds))
        : null;

    // Follow each task concurrently. The slowest task sets the wall clock; a
    // "first" wait returns as soon as any one settles.
    final reports = await _awaitAll(ids, deadline: deadline, first: first);

    final pending = reports.where((r) => !_reportSettled(r.status)).length;
    final res = BackgroundTasksResult(tasks: reports);
    if (pending > 0) {
      if (first && pending < reports.length) {
        res.note =
            'Returned on the first settled task; the remaining tasks report '
            'their current status and keep running.';
        return res;
      }
      res.timedOut = true;
      res.note =
          'Stopped waiting; the pending tasks are still running. Check them '
          'again later.';
    }
    return res;
  }

  /// Follows every task to its end (or the [deadline]), polling each one's
  /// snapshot. With [first] set the whole wait returns as soon as any one task
  /// settles; the remaining tasks are read once more for their current status.
  Future<List<BackgroundTaskReport>> _awaitAll(
    List<String> ids, {
    DateTime? deadline,
    bool first = false,
  }) async {
    // Distinct IDs share one poll; model-authored lists can repeat.
    final distinct = ids.toSet().toList();
    final settledFirst = Completer<void>();

    final futures = <String, Future<BackgroundTaskReport>>{};
    for (final id in distinct) {
      futures[id] = _awaitTask(
        id,
        deadline: deadline,
        stopSignal: first ? settledFirst.future : null,
        onSettled: first
            ? () {
                if (!settledFirst.isCompleted) settledFirst.complete();
              }
            : null,
      );
    }

    final resolved = <String, BackgroundTaskReport>{};
    await Future.wait(
      futures.entries.map((e) async => resolved[e.key] = await e.value),
    );

    return [for (final id in ids) resolved[id]!];
  }

  /// Follows one task by polling its snapshot until terminal or the [deadline].
  /// When [stopSignal] completes (the "first" race was won elsewhere), a still
  /// in-flight task is read once more and returned as it stands. [onSettled] is
  /// fired when this task itself reaches a terminal status, to win the race.
  Future<BackgroundTaskReport> _awaitTask(
    String taskId, {
    DateTime? deadline,
    Future<void>? stopSignal,
    void Function()? onSettled,
  }) async {
    var stopped = false;
    stopSignal?.then((_) => stopped = true);

    while (true) {
      final report = await _reportTask(taskId, _readSnapshotOnce);
      if (_reportSettled(report.status)) {
        onSettled?.call();
        return report;
      }
      if (stopped) return report;
      if (deadline != null && !DateTime.now().isBefore(deadline)) {
        return report;
      }
      await Future<void>.delayed(_waitPollInterval);
    }
  }

  /// Builds one report per task ID with a single fetch each, for the check and
  /// abort tools and the wait tool's don't-wait path.
  Future<BackgroundTasksResult> _reportTasks(
    List<String> taskIds,
    _SnapshotFetch fetch,
  ) async {
    // One fetch per distinct ID, shared across duplicates.
    final distinct = taskIds.toSet().toList();
    final fetched = <String, BackgroundTaskReport>{};
    await Future.wait(
      distinct.map((id) async => fetched[id] = await _reportTask(id, fetch)),
    );
    return BackgroundTasksResult(
      tasks: [for (final id in taskIds) fetched[id]!],
    );
  }

  /// Resolves one task handle, obtains its snapshot through [fetch], and shapes
  /// the result into a report. Completed tasks surface the sub-agent's final
  /// response and artifacts; terminal non-success statuses surface an
  /// explanatory error instead. Settled reports are cached for the rest of the
  /// call (except `expired`, which can still be re-read as a settled row).
  Future<BackgroundTaskReport> _reportTask(
    String taskId,
    _SnapshotFetch fetch,
  ) async {
    final cached = _settledReports[taskId];
    if (cached != null) return cached;

    final resolved = _resolveTaskId(taskId);
    if (resolved == null) {
      return BackgroundTaskReport(
        taskId: taskId,
        status: _taskStatusUnknown,
        error:
            'Task ID "$taskId" does not match any configured agent (expected '
            '"<agent>:<snapshotId>").',
      );
    }

    final handle = await _resolveHandle(resolved.name);
    final report = BackgroundTaskReport(
      taskId: taskId,
      agent: resolved.name,
      status: _taskStatusUnknown,
      name: _taskLabels[taskId],
    );
    if (handle == null || handle.snapshot == null) {
      report.error =
          "Agent '${resolved.name}' is not registered in this process. This "
          'task cannot be collected here; report it as unavailable rather than '
          'delegating it again.';
      return report;
    }

    SessionSnapshot? snap;
    try {
      snap = await fetch(handle, resolved.snapshotId);
    } catch (e) {
      report.status = _taskStatusUnknown;
      if (e is GenkitException && e.status == StatusCodes.NOT_FOUND) {
        report.error =
            'No record of this task exists ($e). Delegate the task again if '
            'the result is still needed.';
      } else if (_deadEndRead(e)) {
        report.error = e.toString();
      } else {
        report.error =
            "Could not read the task's status: $e. Check again later.";
      }
      return report;
    }

    if (snap == null) {
      report.status = _taskStatusUnknown;
      report.error =
          'No record of this task exists. Delegate the task again if the '
          'result is still needed.';
      return report;
    }

    final status = snap.status?.value ?? _taskStatusUnknown;
    report.status = status;

    switch (status) {
      case 'pending':
        // Still running; nothing to report yet.
        break;
      case 'completed':
        _foldCompletedReport(report, handle, resolved, snap);
      case 'aborting':
        report.error =
            'The stop signal reached the task and it is winding down; its '
            'progress is being saved and it will settle as "aborted". No '
            'further action is needed to stop it; collect the settled state '
            'with $_waitToolName if you need it.';
      case 'failed':
        report.error =
            '${_subAgentFailureMessage(snap.finishReason, snap.error, _lastModelMessage(snap))}'
            " The task's progress up to the failure is saved; continue it with "
            '$_continueToolName using this taskId.';
      case 'aborted':
        report.error =
            'The task was aborted before it finished. Continue it with '
            '$_continueToolName using this taskId to pick up from its last '
            'saved progress.';
      case 'expired':
        report.error =
            'The background worker stopped reporting progress and is presumed '
            'dead. Attempt $_continueToolName with this taskId to recover saved '
            'progress, or delegate the task again.';
    }

    // Expired can still change its mind (a slow-beating worker), so it is not
    // cached; everything else terminal is final and worth caching.
    if (_terminalStatuses.contains(status) && status != 'expired') {
      _settledReports[taskId] = report;
    }
    return report;
  }

  /// Folds a completed snapshot into [report], reusing the synchronous
  /// delegation fold so a background task reports the same answer and artifacts
  /// it would have synchronously.
  void _foldCompletedReport(
    BackgroundTaskReport report,
    _AgentHandle handle,
    ({String name, String snapshotId}) resolved,
    SessionSnapshot snap,
  ) {
    final tip = _lastModelMessage(snap);
    final arts = snap.state?.artifacts;
    final folded = _foldDelegationOutput(
      handle,
      AgentOutput(
        snapshotId: resolved.snapshotId,
        finishReason: snap.finishReason,
        message: tip,
        artifacts: arts,
      ),
      0,
    );
    if (_carriesResult(snap.finishReason)) {
      report.response = folded.response;
      report.artifacts = folded.artifacts;
    } else {
      // The row committed as completed, but the agent declared a reason that
      // carries no answer. Report the outcome the reader must act on, not the
      // row's bookkeeping.
      report.status = _settledStatus(snap.finishReason);
      report.error = folded.response;
    }
  }

  // ── Snapshot fetches ──────────────────────────────────────────────────────

  /// Reads a task's snapshot once (the check tool and the wait tool's poll).
  Future<SessionSnapshot?> _readSnapshotOnce(
    _AgentHandle handle,
    String snapshotId,
  ) => _getSnapshot(handle, snapshotId);

  /// The abort tool's fetch: reads first (an abort must not touch an expired or
  /// already-settled row, whose report the caller needs), then flips a genuinely
  /// live task and hands back the row it left.
  Future<SessionSnapshot?> _abortSnapshot(
    _AgentHandle handle,
    String snapshotId,
  ) async {
    final cur = await _getSnapshot(handle, snapshotId, metadataOnly: true);
    if (cur == null) return null;
    final status = cur.status?.value;
    if (status != null && _terminalStatuses.contains(status)) {
      // Nothing to stop; return the full row so the report explains itself.
      return _getSnapshot(handle, snapshotId);
    }
    final flipped = await _abort(handle, snapshotId);
    if (flipped?.value == SnapshotStatus.aborting.value) {
      cur.status = flipped;
      return cur;
    }
    // Settled between the read and the abort; fetch the answer it now carries.
    return _getSnapshot(handle, snapshotId);
  }

  /// Dispatches the sub-agent's getSnapshot companion action.
  Future<SessionSnapshot?> _getSnapshot(
    _AgentHandle handle,
    String snapshotId, {
    bool metadataOnly = false,
  }) async {
    final action = handle.snapshot;
    if (action == null) return null;
    final runResult = await action.runRaw(
      GetSnapshotDataInput(
        snapshotId: snapshotId,
        metadataOnly: metadataOnly ? true : null,
      ).toJson(),
    );
    return runResult.result as SessionSnapshot?;
  }

  /// Dispatches the sub-agent's abort companion action.
  Future<SnapshotStatus?> _abort(_AgentHandle handle, String snapshotId) async {
    final action = handle.abort;
    if (action == null) return null;
    final runResult = await action.runRaw(
      AgentAbortRequest(snapshotId: snapshotId).toJson(),
    );
    return (runResult.result as AgentAbortResponse).status;
  }
}

/// Whether a report's status can no longer change on its own, the rule the wait
/// loop counts by. Unknown is settled (it only arrives once a read failure was
/// classified unhelpable).
bool _reportSettled(String status) =>
    status == _taskStatusUnknown || _terminalStatuses.contains(status);

/// How a task's snapshot is obtained: read once for the check tool and the wait
/// poll, aborted first by the abort tool.
typedef _SnapshotFetch =
    Future<SessionSnapshot?> Function(_AgentHandle handle, String snapshotId);

/// Model-facing phrasings that differ between the two background launches (a
/// delegation and a continuation) of the one launch protocol.
class _LaunchWords {
  _LaunchWords({
    required this.errPrefix,
    required this.withoutBackground,
    required this.started,
    this.label,
  });

  /// Opens every refusal: "Error calling agent ..." for a delegation, "Error
  /// continuing task ..." for a continuation.
  final String errPrefix;

  /// Names the synchronous retry the refusals point at, as a clause.
  final String withoutBackground;

  /// Renders the sentence announcing the pending handle.
  final String Function(String taskId) started;

  /// The caller-chosen label to stamp on the result.
  final String? label;
}
