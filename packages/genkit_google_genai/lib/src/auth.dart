import 'dart:async';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

Future<http.Client> getVertexAuthClient([http.Client? customClient]) async {
  if (customClient != null) return customClient;
  return clientViaApplicationDefaultCredentials(
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  );
}
