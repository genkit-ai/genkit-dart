import 'dart:io' as io;

const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');

String? getEnvVar(String name) {
  if (kIsWeb) {
     if (Uri.base.queryParameters.containsKey(name)) {
      return Uri.base.queryParameters[name];
     }

    return null;
  } else {
    return io.Platform.environment[name];
  }
}

String getPid() {
  return kIsWeb ? 'web' : '${io.pid}';
}
