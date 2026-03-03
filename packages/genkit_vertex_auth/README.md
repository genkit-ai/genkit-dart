[![Pub](https://img.shields.io/pub/v/genkit_vertex_auth.svg)](https://pub.dev/packages/genkit_vertex_auth)

# Genkit Vertex Auth

Shared Vertex AI authentication and project-resolution helpers for Genkit Dart
provider plugins.

## Features

- ADC and service-account access token providers for Vertex AI.
- Cached token refresh with a safety skew.
- Common project ID resolution for `GOOGLE_CLOUD_PROJECT` and `GCLOUD_PROJECT`.
- Shared `x-goog-api-client` header builder for Genkit providers.

## Usage

```dart
import 'package:genkit_vertex_auth/genkit_vertex_auth.dart';

void main() {
  final provider = createAdcAccessTokenProvider();
  final projectId = resolveEnvironmentProjectId();
  final header = googleApiClientHeaderValue();

  print('projectId: $projectId');
  print('header: $header');
  print('provider: ${provider.runtimeType}');
}
```
