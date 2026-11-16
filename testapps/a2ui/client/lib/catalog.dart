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

import 'package:a2ui_core/a2ui_core.dart' show BasicCatalog;
import 'package:a2ui_flutter/a2ui_flutter.dart';
// The agent sends A2UI v0.9, so the v0.9 edition of the basic components.
import 'package:a2ui_flutter/v0_9/basic_catalog.dart';
import 'package:url_launcher/url_launcher.dart';

import 'gauge.dart';
import 'shared.dart';

/// The client catalog, matching the server's custom `weatherCatalog`.
///
/// The server's catalog is the bundled basic components plus a custom `Gauge`
/// (see `../server/lib/agent.dart`), advertised under [weatherCatalogId]. Here
/// we mirror that: the basic widgets and functions plus the matching [gauge],
/// under the same [weatherCatalogId], so a surface the agent creates with that
/// `catalogId` resolves to these widgets. (The renderer rejects a surface
/// whose catalog id it does not hold, so the ids MUST match on both sides.)
final CatalogImplementation weatherCatalog = CatalogImplementation(
  id: weatherCatalogId,
  components: [...BasicComponents.all, gauge],
  functions: BasicCatalog.v0_9(
    openUrl: (uri) => launchUrl(uri),
  ).functions.values.toList(),
  themeSchema: BasicComponents.api.themeSchema,
  definitions: BasicComponents.api.definitions,
);
