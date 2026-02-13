import 'dart:async';
import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

part 'tool_approval_middleware.g.dart';

@Schematic()
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

  // We use an internal map to track approved restarts for the current execution
  // because contexts might be null. We key by the request context or just hold it
  // globally per instance since middleware instances are usually per-plugin.
  // Actually, since this is Dart and concurrency is single-threaded async, and
  // genkit doesn't run multiple generates concurrently on the same options object natively,
  // we can use an Expando keyed by the options object!
  ToolApprovalMiddleware(ToolApprovalOptions options)
    : approvedTools = options.approved;

  static final _approvedRestartsKey = Object();

  @override
  Future<GenerateResponseHelper> generate(
    GenerateActionOptions options,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResponseHelper> Function(
      GenerateActionOptions options,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  ) async {
    final restartRequests = options.resume?.restart
        ?.where((r) => r.metadata?['tool-approved'] == true)
        .map((r) => r.toolRequest.name)
        .toSet();

    return await runZoned(
      () => next(options, ctx),
      zoneValues: {
        if (restartRequests != null && restartRequests.isNotEmpty)
          _approvedRestartsKey: restartRequests,
      },
    );
  }

  @override
  Future<ToolResponse> tool(
    ToolRequest request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResponse> Function(
      ToolRequest request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) async {
    final approvedRestarts =
        (Zone.current[_approvedRestartsKey] as Set<String>?) ?? {};

    // Check if the tool is implicitly approved or explicitly approved via restart
    if (!approvedTools.contains(request.name) &&
        !approvedRestarts.contains(request.name)) {
      throw ToolInterruptException('Tool not in approved list');
    }

    return next(request, ctx);
  }
}
