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

final class McpTaskState {
  final String id;
  final DateTime createdAt;
  DateTime lastUpdatedAt;
  final int? ttl;
  final int pollInterval;
  String status;
  String? statusMessage;
  Map<String, dynamic>? result;
  Map<String, dynamic>? error;

  McpTaskState({required this.id, this.ttl})
    : createdAt = DateTime.now(),
      lastUpdatedAt = DateTime.now(),
      pollInterval = 1000,
      status = 'working';

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  bool isExpired(DateTime now) {
    final ttl = this.ttl;
    return ttl != null && now.difference(createdAt).inMilliseconds > ttl;
  }

  void complete(Map<String, dynamic> value) {
    status = 'completed';
    result = value;
    _touch();
  }

  void fail(Map<String, dynamic> value) {
    status = 'failed';
    error = value;
    _touch();
  }

  void cancel(String message) {
    status = 'cancelled';
    statusMessage = message;
    _touch();
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': id,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'pollInterval': pollInterval,
      'ttl': ttl,
      if (statusMessage != null) 'statusMessage': statusMessage,
    };
  }

  void _touch() {
    lastUpdatedAt = DateTime.now();
  }
}
