// Copyright 2025 Google LLC
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

import 'dart:async';
import 'package:genkit/plugin.dart';
import 'package:schemantic/schemantic.dart';

part 'tool_approval_middleware.g.dart';

@Schema()
abstract class $ToolApprovalOptions {
  List<String> get approved;
}

/// Registers the `toolApproval` middleware.
///
/// [approvedTools] is the default allow-list, used when [toolApproval] is
/// called without `approved:`.
class ToolApprovalPlugin extends GenkitPlugin {
  final List<String>? approvedTools;

  ToolApprovalPlugin({this.approvedTools});

  @override
  String get name => 'toolApproval';

  @override
  List<GenerateMiddlewareDef> middleware() => [
    generateMiddleware<ToolApprovalOptions>(
      name: 'toolApproval',
      configSchema: ToolApprovalOptions.$schema,
      create: (config, ctx) {
        final options =
            config ?? ToolApprovalOptions(approved: approvedTools ?? []);
        return ToolApprovalMiddleware(options);
      },
    ),
  ];
}

/// Interrupts any tool call whose name is not in the allow-list, so a human
/// can approve it (by restarting with `{'tool-approved': true}`).
///
/// [approved] replaces the plugin's `approvedTools` for this call (the two are
/// not merged). When omitted, the plugin's list applies.
GenerateMiddlewareRef<ToolApprovalOptions> toolApproval({
  List<String>? approved,
}) {
  return middlewareRef(
    name: 'toolApproval',
    // A null config lets the plugin fall back to its `approvedTools`.
    config: approved == null ? null : ToolApprovalOptions(approved: approved),
  );
}

class ToolApprovalMiddleware extends GenerateMiddleware {
  final List<String> approvedTools;

  ToolApprovalMiddleware(ToolApprovalOptions options)
    : approvedTools = options.approved;

  @override
  Future<ToolResult> tool(
    ToolRequestPart request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResult> Function(
      ToolRequestPart request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) async {
    // Access approval via the tool request's `resumed` payload (populated by
    // `restart(...)`, matching the JS convention).
    final resumed = request.metadata?['resumed'];
    final approvedByMetadata =
        resumed is Map && resumed['tool-approved'] == true;

    // Check if the tool is implicitly approved or explicitly approved via metadata
    if (!approvedTools.contains(request.toolRequest.name) &&
        !approvedByMetadata) {
      return .interrupt('Tool not in approved list');
    }

    return next(request, ctx);
  }
}
