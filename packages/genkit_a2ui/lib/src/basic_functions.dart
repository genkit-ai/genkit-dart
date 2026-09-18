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

/// The client functions of the A2UI basic catalog (v0.9.1), copied verbatim
/// from the specification's `catalog.json`.
///
/// Renderers of the basic catalog (genui among them) implement these, so the
/// bundled catalog declares them: without them the model cannot use `?required`
/// style checks or `formatString`, and the compiler rejects a block that does.
/// `test/catalog_core_test.dart` checks this list against the published file.
library;

import 'catalog_types.dart';

/// The basic catalog's client functions, keyed by name in spec order.
const List<A2uiCatalogFunction> basicFunctions = [
  A2uiCatalogFunction(
    name: 'required',
    schema: {
      'type': 'object',
      'description': 'Checks that the value is not null, undefined, or empty.',
      'properties': {
        'call': {'const': 'required'},
        'args': {
          'type': 'object',
          'properties': {
            'value': {'description': 'The value to check.'},
          },
          'required': ['value'],
          'additionalProperties': false,
        },
        'returnType': {'const': 'boolean'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
  A2uiCatalogFunction(
    name: 'regex',
    schema: {
      'type': 'object',
      'description':
          'Checks that the value matches a regular expression string.',
      'properties': {
        'call': {'const': 'regex'},
        'args': {
          'type': 'object',
          'properties': {
            'value': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicString',
            },
            'pattern': {
              'type': 'string',
              'description': 'The regex pattern to match against.',
            },
          },
          'required': ['value', 'pattern'],
          'unevaluatedProperties': false,
        },
        'returnType': {'const': 'boolean'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
  A2uiCatalogFunction(
    name: 'length',
    schema: {
      'type': 'object',
      'description': 'Checks string length constraints.',
      'properties': {
        'call': {'const': 'length'},
        'args': {
          'type': 'object',
          'properties': {
            'value': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicString',
            },
            'min': {
              'type': 'integer',
              'minimum': 0,
              'description': 'The minimum allowed length.',
            },
            'max': {
              'type': 'integer',
              'minimum': 0,
              'description': 'The maximum allowed length.',
            },
          },
          'required': ['value'],
          'anyOf': [
            {
              'required': ['min'],
            },
            {
              'required': ['max'],
            },
          ],
          'unevaluatedProperties': false,
        },
        'returnType': {'const': 'boolean'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
  A2uiCatalogFunction(
    name: 'numeric',
    schema: {
      'type': 'object',
      'description': 'Checks numeric range constraints.',
      'properties': {
        'call': {'const': 'numeric'},
        'args': {
          'type': 'object',
          'properties': {
            'value': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicNumber',
            },
            'min': {
              'type': 'number',
              'description': 'The minimum allowed value.',
            },
            'max': {
              'type': 'number',
              'description': 'The maximum allowed value.',
            },
          },
          'required': ['value'],
          'anyOf': [
            {
              'required': ['min'],
            },
            {
              'required': ['max'],
            },
          ],
          'unevaluatedProperties': false,
        },
        'returnType': {'const': 'boolean'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
  A2uiCatalogFunction(
    name: 'email',
    schema: {
      'type': 'object',
      'description': 'Checks that the value is a valid email address.',
      'properties': {
        'call': {'const': 'email'},
        'args': {
          'type': 'object',
          'properties': {
            'value': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicString',
            },
          },
          'required': ['value'],
          'unevaluatedProperties': false,
        },
        'returnType': {'const': 'boolean'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
  A2uiCatalogFunction(
    name: 'formatString',
    schema: {
      'type': 'object',
      'description':
          'Performs string interpolation of data model values and other functions in the catalog functions list and returns the resulting string. The value string can contain interpolated expressions in the `\${expression}` format. Supported expression types include: JSON Pointer paths to the data model (e.g., `\${/absolute/path}` or `\${relative/path}`), and client-side function calls (e.g., `\${now()}`). Function arguments must be named (e.g., `\${formatDate(value:\${/currentDate}, format:\'MM-dd\')}`). To include a literal `\${` sequence, escape it as `\\\${`.',
      'properties': {
        'call': {'const': 'formatString'},
        'args': {
          'type': 'object',
          'properties': {
            'value': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicString',
            },
          },
          'required': ['value'],
          'unevaluatedProperties': false,
        },
        'returnType': {'const': 'string'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
  A2uiCatalogFunction(
    name: 'formatNumber',
    schema: {
      'type': 'object',
      'description':
          'Formats a number with the specified grouping and decimal precision.',
      'properties': {
        'call': {'const': 'formatNumber'},
        'args': {
          'type': 'object',
          'properties': {
            'value': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicNumber',
              'description': 'The number to format.',
            },
            'decimals': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicNumber',
              'description':
                  'Optional. The number of decimal places to show. Defaults to 0 or 2 depending on locale.',
            },
            'grouping': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicBoolean',
              'description':
                  'Optional. If true, uses locale-specific grouping separators (e.g. \'1,000\'). If false, returns raw digits (e.g. \'1000\'). Defaults to true.',
            },
          },
          'required': ['value'],
          'unevaluatedProperties': false,
        },
        'returnType': {'const': 'string'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
  A2uiCatalogFunction(
    name: 'formatCurrency',
    schema: {
      'type': 'object',
      'description': 'Formats a number as a currency string.',
      'properties': {
        'call': {'const': 'formatCurrency'},
        'args': {
          'type': 'object',
          'properties': {
            'value': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicNumber',
              'description': 'The monetary amount.',
            },
            'currency': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicString',
              'description':
                  'The ISO 4217 currency code (e.g., \'USD\', \'EUR\').',
            },
            'decimals': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicNumber',
              'description':
                  'Optional. The number of decimal places to show. Defaults to 0 or 2 depending on locale.',
            },
            'grouping': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicBoolean',
              'description':
                  'Optional. If true, uses locale-specific grouping separators (e.g. \'1,000\'). If false, returns raw digits (e.g. \'1000\'). Defaults to true.',
            },
          },
          'required': ['currency', 'value'],
          'unevaluatedProperties': false,
        },
        'returnType': {'const': 'string'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
  A2uiCatalogFunction(
    name: 'formatDate',
    schema: {
      'type': 'object',
      'description': 'Formats a timestamp into a string using a pattern.',
      'properties': {
        'call': {'const': 'formatDate'},
        'args': {
          'type': 'object',
          'properties': {
            'value': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicValue',
              'description': 'The date to format.',
            },
            'format': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicString',
              'description':
                  'A Unicode TR35 date pattern string.\n\nToken Reference:\n- Year: \'yy\' (26), \'yyyy\' (2026)\n- Month: \'M\' (1), \'MM\' (01), \'MMM\' (Jan), \'MMMM\' (January)\n- Day: \'d\' (1), \'dd\' (01), \'E\' (Tue), \'EEEE\' (Tuesday)\n- Hour (12h): \'h\' (1-12), \'hh\' (01-12) - requires \'a\' for AM/PM\n- Hour (24h): \'H\' (0-23), \'HH\' (00-23) - Military Time\n- Minute: \'mm\' (00-59)\n- Second: \'ss\' (00-59)\n- Period: \'a\' (AM/PM)\n\nExamples:\n- \'MMM dd, yyyy\' -> \'Jan 16, 2026\'\n- \'HH:mm\' -> \'14:30\' (Military)\n- \'h:mm a\' -> \'2:30 PM\'\n- \'EEEE, d MMMM\' -> \'Friday, 16 January\'',
            },
          },
          'required': ['format', 'value'],
          'unevaluatedProperties': false,
        },
        'returnType': {'const': 'string'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
  A2uiCatalogFunction(
    name: 'pluralize',
    schema: {
      'type': 'object',
      'description':
          'Returns a localized string based on the Common Locale Data Repository (CLDR) plural category of the count (zero, one, two, few, many, other). Requires an \'other\' fallback. For English, just use \'one\' and \'other\'.',
      'properties': {
        'call': {'const': 'pluralize'},
        'args': {
          'type': 'object',
          'properties': {
            'value': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicNumber',
              'description':
                  'The numeric value used to determine the plural category.',
            },
            'zero': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicString',
              'description':
                  'String for the \'zero\' category (e.g., 0 items).',
            },
            'one': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicString',
              'description': 'String for the \'one\' category (e.g., 1 item).',
            },
            'two': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicString',
              'description':
                  'String for the \'two\' category (used in Arabic, Welsh, etc.).',
            },
            'few': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicString',
              'description':
                  'String for the \'few\' category (e.g., small groups in Slavic languages).',
            },
            'many': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicString',
              'description':
                  'String for the \'many\' category (e.g., large groups in various languages).',
            },
            'other': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicString',
              'description':
                  'The default/fallback string (used for general plural cases).',
            },
          },
          'required': ['value', 'other'],
          'unevaluatedProperties': false,
        },
        'returnType': {'const': 'string'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
  A2uiCatalogFunction(
    name: 'openUrl',
    schema: {
      'type': 'object',
      'description':
          'Opens the specified URL in a browser or handler. This function has no return value.',
      'properties': {
        'call': {'const': 'openUrl'},
        'args': {
          'type': 'object',
          'properties': {
            'url': {
              'type': 'string',
              'format': 'uri',
              'description': 'The URL to open.',
            },
          },
          'required': ['url'],
          'additionalProperties': false,
        },
        'returnType': {'const': 'void'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
  A2uiCatalogFunction(
    name: 'and',
    schema: {
      'type': 'object',
      'description':
          'Performs a logical AND operation on a list of boolean values.',
      'properties': {
        'call': {'const': 'and'},
        'args': {
          'type': 'object',
          'properties': {
            'values': {
              'type': 'array',
              'description': 'The list of boolean values to evaluate.',
              'items': {
                '\$ref':
                    'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicBoolean',
              },
              'minItems': 2,
            },
          },
          'required': ['values'],
          'unevaluatedProperties': false,
        },
        'returnType': {'const': 'boolean'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
  A2uiCatalogFunction(
    name: 'or',
    schema: {
      'type': 'object',
      'description':
          'Performs a logical OR operation on a list of boolean values.',
      'properties': {
        'call': {'const': 'or'},
        'args': {
          'type': 'object',
          'properties': {
            'values': {
              'type': 'array',
              'description': 'The list of boolean values to evaluate.',
              'items': {
                '\$ref':
                    'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicBoolean',
              },
              'minItems': 2,
            },
          },
          'required': ['values'],
          'unevaluatedProperties': false,
        },
        'returnType': {'const': 'boolean'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
  A2uiCatalogFunction(
    name: 'not',
    schema: {
      'type': 'object',
      'description': 'Performs a logical NOT operation on a boolean value.',
      'properties': {
        'call': {'const': 'not'},
        'args': {
          'type': 'object',
          'properties': {
            'value': {
              '\$ref':
                  'https://a2ui.org/specification/v0_9/common_types.json#/\$defs/DynamicBoolean',
              'description': 'The boolean value to negate.',
            },
          },
          'required': ['value'],
          'unevaluatedProperties': false,
        },
        'returnType': {'const': 'boolean'},
      },
      'required': ['call', 'args'],
      'unevaluatedProperties': false,
    },
  ),
];
