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

/// Values the server and the Flutter client (`../client`) must agree on.
library;

/// The id of the app's custom A2UI catalog.
///
/// The server registers a catalog under this id (see `weatherCatalog` in
/// `lib/agent.dart`) and the client registers matching widgets under the same
/// id (`../client/lib/shared.dart`). The client and server are separate
/// packages so the client never depends on `genkit_a2ui`; the cost is that this
/// one string is duplicated, so keep both copies in sync. Reverse-domain
/// notation is recommended to avoid clashes with other catalogs.
const String weatherCatalogId = 'com.example.a2ui.weather';
