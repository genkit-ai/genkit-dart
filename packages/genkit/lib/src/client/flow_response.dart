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

import 'dart:async';

// Define the delimiter used by the flow stream protocol
const flowStreamDelimiter = '\n\n';
const sseDataPrefix = 'data: ';

/// Record type returned by [GenkitClient.streamFlow], containing the stream of chunks
/// and a future for the final response.
typedef FlowStreamResponse<O, S> = ({Future<O> response, Stream<S> stream});
