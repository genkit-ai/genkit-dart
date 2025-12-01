import 'dart:io' as io;
import 'package:flutter/foundation.dart';

String? getEnvVar(String name) {
  print('getEnvVar $name $kIsWeb');
  if (kIsWeb) {
    print('qpam $name = ${Uri.base.queryParameters[name]}');
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