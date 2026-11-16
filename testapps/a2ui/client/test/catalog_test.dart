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

import 'package:a2ui_client/a2ui_helpers.dart';
import 'package:a2ui_client/catalog.dart';
import 'package:a2ui_client/shared.dart';
import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _surfaceId = 'tokyo-weather';

/// What the agent sends for a weather card, in A2UI v0.9.
const _messages = <Map<String, dynamic>>[
  {
    'version': 'v0.9',
    'deleteSurface': {'surfaceId': _surfaceId},
  },
  {
    'version': 'v0.9',
    'createSurface': {'surfaceId': _surfaceId, 'catalogId': weatherCatalogId},
  },
  {
    'version': 'v0.9',
    'updateComponents': {
      'surfaceId': _surfaceId,
      'components': [
        {'id': 'root', 'component': 'Card', 'child': 'body'},
        {
          'id': 'body',
          'component': 'Column',
          'children': ['title', 'gauges', 'refresh'],
        },
        {
          'id': 'title',
          'component': 'Text',
          'text': 'Weather in Tokyo',
          'variant': 'h3',
        },
        // A stretch Row inside a Column: surfaces sit in a scrolling list, so
        // this must lay out without a bounded height.
        {
          'id': 'gauges',
          'component': 'Row',
          'children': ['temp', 'humidity'],
          'align': 'stretch',
        },
        {
          'id': 'temp',
          'component': 'Gauge',
          'value': {'path': '/temp'},
          'min': -10,
          'max': 40,
          'label': 'Temperature',
          'unit': '°C',
        },
        {
          'id': 'humidity',
          'component': 'Gauge',
          'value': 74,
          'label': 'Humidity',
          'unit': '%',
        },
        {
          'id': 'refresh',
          'component': 'Button',
          'child': 'refresh_label',
          'variant': 'primary',
          'action': {
            'event': {
              'name': 'refresh',
              'context': {
                'city': 'Tokyo',
                'temp': {'path': '/temp'},
              },
            },
          },
        },
        {'id': 'refresh_label', 'component': 'Text', 'text': 'Refresh'},
      ],
    },
  },
  {
    'version': 'v0.9',
    'updateDataModel': {'surfaceId': _surfaceId, 'path': '/temp', 'value': 18},
  },
];

void main() {
  late MessageProcessor<ComponentImplementation> processor;
  late List<RendererToAgentMessage> sent;

  setUp(() {
    sent = [];
    processor = MessageProcessor(
      catalogs: [weatherCatalog],
      unifiedOutbound: true,
      outboundListener: sent.add,
    );
  });

  tearDown(() => processor.dispose());

  Future<void> pumpSurface(WidgetTester tester) async {
    for (final message in _messages) {
      processor.processMessages([message]);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              A2uiSurface(surface: processor.model.getSurface(_surfaceId)!),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the basic components and the custom Gauge', (
    tester,
  ) async {
    await pumpSurface(tester);

    expect(find.text('Weather in Tokyo'), findsOneWidget);
    expect(find.text('18°C'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('74%'), findsOneWidget);
  });

  testWidgets('a data model update reaches a bound Gauge', (tester) async {
    await pumpSurface(tester);

    processor.processMessages([
      {
        'version': 'v0.9',
        'updateDataModel': {
          'surfaceId': _surfaceId,
          'path': '/temp',
          'value': 21,
        },
      },
    ]);
    await tester.pumpAndSettle();

    expect(find.text('21°C'), findsOneWidget);
    expect(find.text('18°C'), findsNothing);
  });

  testWidgets('a button press becomes the a2ui part the agent reads', (
    tester,
  ) async {
    await pumpSurface(tester);

    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();

    final message = a2uiActionToMessage(sent.whereType<ActionMessage>().single);
    expect(message.toJson(), {
      'role': 'user',
      'content': [
        {
          'data': {
            'messages': [
              {
                'version': 'v0.9',
                'action': {
                  'name': 'refresh',
                  'surfaceId': _surfaceId,
                  'sourceComponentId': 'refresh',
                  'timestamp': isA<String>(),
                  // The binding is resolved against the data model.
                  'context': {'city': 'Tokyo', 'temp': 18},
                },
              },
            ],
          },
          'metadata': {'mimeType': a2uiMimeType},
        },
      ],
    });
  });
}
