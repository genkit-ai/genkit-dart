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

import 'package:genkit/genkit.dart';

Map<String, dynamic> toJsonRpcError(Object error) {
  if (error is GenkitException) {
    return {
      'code': _httpStatusForStatus(error.status),
      'message': error.message,
    };
  }
  return {'code': -32603, 'message': error.toString()};
}

int _httpStatusForStatus(StatusCodes status) {
  switch (status) {
    case StatusCodes.OK:
      return 200;
    case StatusCodes.CANCELLED:
      return 499;
    case StatusCodes.UNKNOWN:
      return 500;
    case StatusCodes.INVALID_ARGUMENT:
      return 400;
    case StatusCodes.DEADLINE_EXCEEDED:
      return 504;
    case StatusCodes.NOT_FOUND:
      return 404;
    case StatusCodes.ALREADY_EXISTS:
      return 409;
    case StatusCodes.PERMISSION_DENIED:
      return 403;
    case StatusCodes.UNAUTHENTICATED:
      return 401;
    case StatusCodes.RESOURCE_EXHAUSTED:
      return 429;
    case StatusCodes.FAILED_PRECONDITION:
      return 400;
    case StatusCodes.ABORTED:
      return 409;
    case StatusCodes.OUT_OF_RANGE:
      return 400;
    case StatusCodes.UNIMPLEMENTED:
      return 501;
    case StatusCodes.INTERNAL:
      return 500;
    case StatusCodes.UNAVAILABLE:
      return 503;
    case StatusCodes.DATA_LOSS:
      return 500;
  }
}
