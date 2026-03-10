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

class ToolApprovalPlugin extends GenkitPlugin {
  final List<String>? approvedTools;

  ToolApprovalPlugin({this.approvedTools});

  @override
  String get name => 'toolApproval';

  @override
  List<GenerateMiddlewareDef> middleware() => [
    defineMiddleware<ToolApprovalOptions>(
      name: 'toolApproval',
      configSchema: ToolApprovalOptions.$schema,
      create: ([ToolApprovalOptions? config]) {
        final options =
            config ?? ToolApprovalOptions(approved: approvedTools ?? []);
        return ToolApprovalMiddleware(options);
      },
    ),
  ];
}

GenerateMiddlewareRef<ToolApprovalOptions> toolApproval({
  List<String>? approved,
}) {
  return middlewareRef(
    name: 'toolApproval',
    config: ToolApprovalOptions(approved: approved ?? []),
  );
}

class ToolApprovalMiddleware extends GenerateMiddleware {
  final List<String> approvedTools;

  ToolApprovalMiddleware(ToolApprovalOptions options)
    : approvedTools = options.approved;

  @override
  Future<ToolResponse> tool(
    ToolRequestPart request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResponse> Function(
      ToolRequestPart request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) async {
    final approvedByMetadata = request.metadata?['tool-approved'] == true;

    // Check if the tool is implicitly approved or explicitly approved via metadata
    if (!approvedTools.contains(request.toolRequest.name) &&
        !approvedByMetadata) {
      throw ToolInterruptException('Tool not in approved list');
    }

    return next(request, ctx);
  }
}
