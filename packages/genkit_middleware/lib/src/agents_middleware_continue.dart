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

// Task continuation for the agents middleware.
//
// A delegation that settled leaves a handle behind ("<agent>:<snapshotId>",
// see AgentDelegationResult.taskId), and the sub-agent runtime makes the
// snapshot behind it a resume point: a failed or aborted run holds the state
// through its last committed turn, and a completed run holds the whole
// conversation. The shared continue tool spends that handle: it retries a
// failed or aborted task from its saved progress (an empty instructions field
// re-attempts the turn as committed; a non-empty one steers the retry), and
// follows up on a completed task inside the sub-agent's own session.
//
// Only server-managed sub-agents (those with a session store) are continuable.
// A client-managed delegation settles inline and leaves nothing durable a
// handle could name, so its result carries no taskId, and redoing its work
// means delegating again.

part of 'agents_middleware.dart';

extension _AgentsMiddlewareContinue on AgentsMiddleware {
  /// Builds the shared continue tool. Its input schema depends on whether
  /// background execution exists (the async variant carries the extra
  /// background flag).
  Tool _continueTool() {
    const description =
        'Continues a sub-agent task by its taskId: a failed or aborted task '
        'picks up from its last saved progress (omit instructions to retry it '
        'as it stood, or pass instructions to steer it), and a completed task '
        'accepts follow-up instructions inside its own session. A task that '
        'stopped on an interrupt cannot be continued.';
    if (_async) {
      return Tool<AsyncContinueInput, AgentDelegationResult>(
        name: _continueToolName,
        description: description,
        inputSchema: AsyncContinueInput.$schema,
        toolOutputSchema: AgentDelegationResult.$schema,
        fn: (input, _) async => .response(
          await _runContinue(
            input.taskId,
            input.instructions,
            input.background == true,
          ),
        ),
      );
    }
    return Tool<ContinueInput, AgentDelegationResult>(
      name: _continueToolName,
      description: description,
      inputSchema: ContinueInput.$schema,
      toolOutputSchema: AgentDelegationResult.$schema,
      fn: (input, _) async => .response(
        await _runContinue(input.taskId, input.instructions, false),
      ),
    );
  }

  /// The continue tool body. It spends a delegation slot like any delegation (a
  /// continuation is a real sub-agent run, and an always-failing task continued
  /// forever is exactly the runaway maxDelegations bounds), resolves the handle,
  /// and continues the snapshot behind it.
  ///
  /// Refusal slot policy follows the launch precedent: a refusal that ran no
  /// sub-agent work and names a corrected retry that can succeed (missing
  /// instructions, task still running, a transient read failure) returns its
  /// slot; a dead end (unknown handle, unresolvable or client-managed agent, no
  /// saved progress) keeps it, because its retry fails identically.
  Future<AgentDelegationResult> _runContinue(
    String taskId,
    String? instructions,
    bool background,
  ) async {
    final resolved = _resolveTaskId(taskId);
    if (resolved == null) {
      return AgentDelegationResult(
        response:
            'Error: task ID "$taskId" does not match any configured agent '
            '(expected "<agent>:<snapshotId>").',
      );
    }

    final begun = await _beginDelegation(resolved.name);
    if (begun.refusal != null) return begun.refusal!;
    final handle = begun.handle!;

    if (handle.isClientManaged) {
      // Nothing durable exists behind a client-managed delegation, so no handle
      // can name a resume point; a dead end keeps its slot.
      return AgentDelegationResult(
        response:
            "Error: agent '${resolved.name}' manages its state on the client "
            'and its delegations cannot be continued; delegate the task again. '
            'Only sub-agents with a session store leave continuable task '
            'handles.',
      );
    }

    return _continueFromStore(
      handle,
      begun.invocationNum,
      taskId,
      resolved.snapshotId,
      instructions,
      background,
    );
  }

  /// Continues a server-managed task from the snapshot behind its handle. The
  /// pre-read is metadata-only: the flow dispatches on status and finish reason
  /// alone, and the run itself loads the state it resumes.
  Future<AgentDelegationResult> _continueFromStore(
    _AgentHandle handle,
    int invocationNum,
    String taskId,
    String snapshotId,
    String? instructions,
    bool background,
  ) async {
    SessionSnapshot? snap;
    try {
      snap = await _getSnapshot(handle, snapshotId, metadataOnly: true);
    } catch (e) {
      if (e is GenkitException && e.status == StatusCodes.NOT_FOUND) {
        return AgentDelegationResult(
          response:
              'Error: no record of task "$taskId" exists ($e). Delegate the '
              'task again if the work is still needed.',
        );
      }
      if (_deadEndRead(e)) {
        return AgentDelegationResult(
          response: 'Error continuing task "$taskId": $e',
        );
      }
      _releaseDelegation();
      return AgentDelegationResult(
        response: 'Error: could not read task "$taskId" ($e). Try again later.',
      );
    }

    if (snap == null) {
      return AgentDelegationResult(
        response:
            'Error: no record of task "$taskId" exists. Delegate the task '
            'again if the work is still needed.',
      );
    }

    final status = snap.status?.value;
    if (status == SnapshotStatus.pending.value) {
      _releaseDelegation();
      var hint = '';
      if (_async) {
        hint =
            ' Collect it with $_checkToolName or $_waitToolName, or stop it '
            'with $_abortToolName first.';
      }
      return AgentDelegationResult(
        response:
            'Task "$taskId" is still running; only a settled task can be '
            'continued.$hint',
      );
    }
    if (status == SnapshotStatus.expired.value) {
      return _continueExpired(
        handle,
        invocationNum,
        taskId,
        snapshotId,
        instructions,
        background,
      );
    }
    if (status != null && _terminalStatuses.contains(status)) {
      return _continueSettled(
        handle,
        invocationNum,
        taskId,
        snapshotId,
        snap,
        instructions,
        background,
      );
    }
    // Aborting, the one other in-flight status.
    return _windingDownRefusal(taskId);
  }

  /// Continues a handle whose shaped row is settled (completed, failed, or
  /// aborted), applying the interrupt refusal and the completed-task
  /// instructions gate before the run.
  Future<AgentDelegationResult> _continueSettled(
    _AgentHandle handle,
    int invocationNum,
    String taskId,
    String snapshotId,
    SessionSnapshot snap,
    String? instructions,
    bool background,
  ) async {
    if (snap.finishReason?.value == AgentFinishReason.interrupted.value) {
      // Continuing past an interrupt means answering it, which the orchestrator
      // cannot do; a retry fails identically, so this dead end keeps its slot.
      return AgentDelegationResult(
        response:
            'Error: task "$taskId" stopped on an interrupt (a tool request '
            'that needs an answer from outside the sub-agent), and continuing '
            'interrupted tasks is not supported. Delegate a more self-contained '
            'task instead.',
      );
    }
    final refusal = _refuseEmptyFollowUp(
      snap,
      instructions,
      'Task "$taskId" already completed. To follow up in the sub-agent\'s '
      'session, call this tool again with instructions; re-running it without '
      'instructions would only repeat the finished work.',
    );
    if (refusal != null) return refusal;

    return _runContinueFrom(
      handle,
      invocationNum,
      taskId,
      snapshotId,
      instructions,
      background,
    );
  }

  /// Recovers a task whose worker is presumed dead. The row is aborted first as
  /// a fence (a live worker observes the flip and stops; a dead one is
  /// unaffected), and one shaped re-read then decides the recovery point: still
  /// expired falls back to the dead row's parent; a settled row continues like
  /// any settled handle; an aborting row means the fence reached a live worker,
  /// so the retry is named and the slot returned.
  Future<AgentDelegationResult> _continueExpired(
    _AgentHandle handle,
    int invocationNum,
    String taskId,
    String snapshotId,
    String? instructions,
    bool background,
  ) async {
    try {
      await _abort(handle, snapshotId);
    } catch (e) {
      return _refuseRead(
        e,
        'Error: could not fence task "$taskId" before recovering it ($e).',
      );
    }

    SessionSnapshot? cur;
    try {
      cur = await _getSnapshot(handle, snapshotId, metadataOnly: true);
    } catch (e) {
      return _refuseRead(
        e,
        'Error: could not read task "$taskId" after fencing it ($e).',
      );
    }
    if (cur == null) {
      return AgentDelegationResult(
        response:
            'Error: task "$taskId" vanished while being fenced for recovery. '
            'Delegate the task again if the work is still needed.',
      );
    }

    final status = cur.status?.value;
    if (status == SnapshotStatus.expired.value) {
      return _continueFromParent(
        handle,
        invocationNum,
        taskId,
        cur.parentId,
        instructions,
        background,
      );
    }
    if (status != null && _terminalStatuses.contains(status)) {
      return _continueSettled(
        handle,
        invocationNum,
        taskId,
        snapshotId,
        cur,
        instructions,
        background,
      );
    }
    // The fence reached a live worker: it beat after the flip, so its finalize
    // is coming and the parent must not be raced.
    return _windingDownRefusal(taskId);
  }

  /// Recovers a dead task from its pending row's parent: the last snapshot
  /// committed before the detach. A background delegation detaches at turn zero
  /// and has no parent, which is the honest nothing-was-saved case.
  Future<AgentDelegationResult> _continueFromParent(
    _AgentHandle handle,
    int invocationNum,
    String taskId,
    String? parentId,
    String? instructions,
    bool background,
  ) async {
    if (parentId == null || parentId.isEmpty) {
      return AgentDelegationResult(
        response:
            'Error: task "$taskId" saved no progress to continue from (it '
            'detached at the start of the run, and its worker died before '
            'finalizing). Delegate the task again if the work is still needed.',
      );
    }
    SessionSnapshot? parent;
    try {
      parent = await _getSnapshot(handle, parentId, metadataOnly: true);
    } catch (e) {
      return _refuseRead(
        e,
        'Error: task "$taskId" kept its progress in snapshot "$parentId", '
        'which could not be read ($e).',
      );
    }
    if (parent == null) {
      return AgentDelegationResult(
        response:
            'Error: task "$taskId" kept its progress in snapshot "$parentId", '
            'which no longer exists. Delegate the task again if the work is '
            'still needed.',
      );
    }
    final refusal = _refuseEmptyFollowUp(
      parent,
      instructions,
      'Task "$taskId" kept progress only up to its last finished turn (from '
      'before the background work started). Call this tool again with '
      'instructions to continue from there; an empty retry would only re-run '
      'that finished turn.',
    );
    if (refusal != null) return refusal;

    return _runContinueFrom(
      handle,
      invocationNum,
      taskId,
      parentId,
      instructions,
      background,
    );
  }

  /// The shared tail of every store-backed continuation: runs the sub-agent
  /// from the named snapshot with the instructions as the turn's user message
  /// and folds the outcome like a synchronous delegation, or launches it in the
  /// background through the same launch protocol as a background delegation.
  Future<AgentDelegationResult> _runContinueFrom(
    _AgentHandle handle,
    int invocationNum,
    String taskId,
    String snapshotId,
    String? instructions,
    bool background,
  ) async {
    final words = _LaunchWords(
      errPrefix: 'Error continuing task "$taskId"',
      withoutBackground: 'continue it without "background" instead',
      started: (newId) => 'Task $taskId continued in the background as $newId.',
      // The continuation is the same undertaking; its label follows the handle.
      label: _taskLabels[taskId],
    );

    if (background) {
      final refusal = _refuseUndetachable(handle, words);
      if (refusal != null) return refusal;
    }

    try {
      final out = await _runSubAgent(
        handle,
        message: _continueMessage(instructions, background),
        detach: background,
        init: AgentInit(snapshotId: snapshotId),
      );
      if (background) {
        return _foldDetachOutcome(handle, invocationNum, out, words);
      }
      final result = _foldDelegationOutput(handle, out, invocationNum);
      _labelTask(result, words.label);
      return result;
    } catch (e) {
      if (e is GenkitException && e.status == StatusCodes.FAILED_PRECONDITION) {
        // The runtime rejected the resume point itself (nothing behind it, or a
        // still-live worker); its message says which.
        return AgentDelegationResult(
          response:
              '${words.errPrefix}: $e. If no progress was saved, delegate the '
              'task again.',
        );
      }
      return AgentDelegationResult(response: '${words.errPrefix}: $e');
    }
  }

  /// Refuses to continue a task whose row is aborting: the stop landed and the
  /// worker is draining toward the finalize that makes the row a continuation
  /// point, so the same handle is the thing to retry.
  AgentDelegationResult _windingDownRefusal(String taskId) {
    _releaseDelegation();
    var hint = '';
    if (_async) {
      hint =
          ' Collect its settled state with $_waitToolName, then continue that.';
    }
    return AgentDelegationResult(
      response:
          'Task "$taskId" is winding down after a stop signal; its progress is '
          'being saved. Retry this taskId once it settles.$hint',
    );
  }

  /// Refuses an instructions-less continuation of a snapshot whose last
  /// committed turn finished (completed, with a result-carrying reason). The
  /// corrected call is a real run that can succeed, so the slot is returned.
  AgentDelegationResult? _refuseEmptyFollowUp(
    SessionSnapshot snap,
    String? instructions,
    String msg,
  ) {
    if (snap.status?.value != SnapshotStatus.completed.value ||
        !_carriesResult(snap.finishReason) ||
        (instructions != null && instructions.isNotEmpty)) {
      return null;
    }
    _releaseDelegation();
    return AgentDelegationResult(response: msg);
  }

  /// Turns a failed pre-read, fence, or parent read into the refusal [msg], with
  /// the slot following the failure's kind: a classified dead end keeps it (a
  /// retry fails identically), a transient failure returns it.
  AgentDelegationResult _refuseRead(Object err, String msg) {
    if (_deadEndRead(err)) {
      return AgentDelegationResult(response: msg);
    }
    _releaseDelegation();
    return AgentDelegationResult(response: '$msg Try again later.');
  }

  /// The user message a continuation delivers: the instructions when given,
  /// otherwise none so the runtime re-attempts the conversation as committed.
  /// The exception is a background retry: a detached input with no payload is a
  /// pure detach signal that runs no turn, so an empty background continuation
  /// gets the smallest honest payload instead.
  Message? _continueMessage(String? instructions, bool detach) {
    var text = instructions ?? '';
    if (text.isEmpty) {
      if (!detach) return null;
      text = 'Continue the task from where it stopped.';
    }
    return Message(
      role: Role.user,
      content: [TextPart(text: text)],
    );
  }
}
