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

/// The client half of the sample's custom A2UI catalog.
library;

import 'package:a2ui_core/a2ui_core.dart'
    show A2uiProtocolVersion, BasicCatalog;
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:url_launcher/url_launcher.dart';

import 'gauge.dart';
import 'shared.dart';

/// The client catalog, matching the server's `weatherCatalog`.
///
/// The server's catalog extends the v1.0 basic catalog with a custom `Gauge`
/// (see `../server/lib/agent.dart`) under [weatherCatalogId]. Here we mirror
/// that: the v1.0 basic widgets and functions plus [gauge] under the same id.
/// (The renderer rejects a surface whose catalog id it does not hold, so the
/// ids MUST match on both sides.)
final CatalogImplementation weatherCatalog = CatalogImplementation(
  id: weatherCatalogId,
  protocolVersion: A2uiProtocolVersion.v1_0,
  components: [...BasicComponents.all, gauge],
  functions: BasicCatalog.v1_0(
    openUrl: (uri) => launchUrl(uri),
  ).functions.values.toList(),
  definitions: BasicComponents.api.definitions,
);
