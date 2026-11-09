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

/// The client-side half of the sample's custom A2UI catalog: a `Gauge` widget.
///
/// The server advertises a `Gauge` component to the model (see
/// `weatherCatalog` in `lib/agent.dart`). Here we implement the matching
/// Flutter widget as a genui [CatalogItem]. genui builds a widget for a
/// component by looking up a [CatalogItem] whose [CatalogItem.name] equals the
/// component's `component` field, so the name here (`'Gauge'`) MUST match the
/// name the server catalog uses.
///
/// A [CatalogItem] is three things:
///  1. a `name` (the component type in the A2UI JSON),
///  2. a `dataSchema` describing its props (used for client-side validation),
///  3. a `widgetBuilder` that turns the parsed props into a Flutter widget.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// The prop schema for the `Gauge` component.
///
/// `value` uses [A2uiSchemas.numberReference] so it accepts either a literal
/// number or a `{ "path": "/..." }` data-model binding, exactly like the basic
/// catalog's Slider. The rest are simple literals.
final _gaugeSchema = S.object(
  description: 'A circular gauge visualizing a single numeric value.',
  properties: {
    'value': A2uiSchemas.numberReference(
      description:
          'The value to display. Literal number or a { path } binding.',
    ),
    'min': S.number(description: 'The minimum of the range. Defaults to 0.'),
    'max': S.number(description: 'The maximum of the range. Defaults to 100.'),
    'label': A2uiSchemas.stringReference(
      description: 'An optional caption shown under the value.',
    ),
    'unit': S.string(description: 'An optional unit suffix, e.g. "°C" or "%".'),
  },
  required: ['value'],
);

/// The `Gauge` catalog item.
///
/// Register it on the client by adding it to the catalog with
/// `catalog.copyWith(newItems: [gaugeCatalogItem])`.
final CatalogItem gaugeCatalogItem = CatalogItem(
  name: 'Gauge',
  dataSchema: _gaugeSchema,
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    final min = (data['min'] as num?)?.toDouble() ?? 0.0;
    final max = (data['max'] as num?)?.toDouble() ?? 100.0;
    final unit = data['unit'] as String?;

    // `value` and `label` may be literals or { path } bindings, so resolve
    // them through genui's Bound* widgets, which subscribe to the data model
    // and rebuild when it changes.
    return BoundNumber(
      dataContext: itemContext.dataContext,
      value: data['value'],
      builder: (context, value) {
        return BoundString(
          dataContext: itemContext.dataContext,
          value: data['label'],
          builder: (context, label) {
            return _GaugeView(
              value: (value ?? min).toDouble(),
              min: min,
              max: max,
              label: label,
              unit: unit,
            );
          },
        );
      },
    );
  },
  exampleData: [
    () => '''
      [
        {
          "id": "root",
          "component": "Gauge",
          "value": 18,
          "min": -10,
          "max": 40,
          "unit": "\u00b0C",
          "label": "Temperature"
        }
      ]
    ''',
  ],
);

/// A simple circular gauge painted with a [CustomPainter].
class _GaugeView extends StatelessWidget {
  const _GaugeView({
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.label,
  });

  final double value;
  final double min;
  final double max;
  final String? unit;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final span = (max - min);
    final fraction = span == 0
        ? 0.0
        : ((value - min) / span).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: 120,
        height: 120,
        child: CustomPaint(
          painter: _GaugePainter(
            fraction: fraction,
            trackColor: scheme.surfaceContainerHighest,
            valueColor: scheme.primary,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_formatValue(value)}${unit ?? ''}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (label != null && label!.isNotEmpty)
                  Text(
                    label!,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Drops a trailing ".0" so whole numbers read cleanly (e.g. "18" not "18.0").
  String _formatValue(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fraction,
    required this.trackColor,
    required this.valueColor,
  });

  final double fraction;
  final Color trackColor;
  final Color valueColor;

  // A 270-degree arc, starting at the bottom-left (135 degrees), leaving a gap
  // at the bottom so it reads as a gauge rather than a full ring.
  static const double _startAngle = math.pi * 0.75;
  static const double _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = valueColor;

    canvas.drawArc(arcRect, _startAngle, _sweep, false, track);
    canvas.drawArc(arcRect, _startAngle, _sweep * fraction, false, progress);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction ||
      old.trackColor != trackColor ||
      old.valueColor != valueColor;
}
