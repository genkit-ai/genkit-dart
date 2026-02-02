// Copyright 2024 Google LLC
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

/// Client-side utilities for interacting with Genkit.
///
/// Use this library when building clients (e.g., web or mobile apps) that
/// communicate with Genkit actions or flows, or when using Genkit in a
/// purely client-side context (e.g. with Chrome AI).
library;

export 'src/client/client.dart' show RemoteAction, defineRemoteAction;
export 'src/core/action.dart' show ActionStream;
export 'src/exception.dart' show GenkitException, StatusCodes;
export 'src/schema_extensions.dart';
export 'src/types.dart';
