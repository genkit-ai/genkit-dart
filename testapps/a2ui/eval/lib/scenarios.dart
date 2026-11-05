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

/// The scenarios. Every turn also gets three implicit checks: the turn did
/// not fail, the renderer accepted every message, and no markup leaked into
/// the prose.
library;

import 'src/scenario.dart';

const first = SurfaceRef.nth(0);
const second = SurfaceRef.nth(1);
const third = SurfaceRef.nth(2);

/// In the chatty scenario other turns may render UI too, so the weather
/// comparison is found by the turn that asked for it.
const weather = SurfaceRef.fromTurn(1);

final scenarios = <Scenario>[
  Scenario('new render', [
    const Say("What's the weather in Tokyo?"),
    Expect.newSurfaces(1),
    Expect.shows('Tokyo'),
    Expect.uses('Gauge'),
    Expect.proseUnder(400),
  ]),

  Scenario('small talk renders nothing', [
    const Say('Hi! How are you today?'),
    Expect.noUi(),
    const Say('Can you tell me a fun fact about octopuses?'),
    Expect.noUi(),
  ], description: 'Plain conversation should stay prose.'),

  Scenario('second request adds a surface', [
    const Say("What's the weather in Tokyo?"),
    Expect.newSurfaces(1),
    const Say('And in Paris?'),
    Expect.newSurfaces(1),
    Expect.untouched(first),
    Expect.liveSurfaces(2),
    Expect.shows('Paris', on: second),
  ], description: 'A new question gets a new surface, the old one stays.'),

  Scenario('action targets its own surface (2 surfaces)', [
    const Say("Show the weather in Tokyo, with a Refresh button."),
    const Say("Now show Paris as a separate card, also with a Refresh button."),
    Expect.liveSurfaces(2),
    const Press('Refresh', on: first),
    Expect.touched(first),
    Expect.untouched(second),
    Expect.newSurfaces(0),
    Expect.shows('Tokyo', on: first),
  ]),

  Scenario('action targets its own surface (3 surfaces, middle)', [
    const Say('Show the weather in Tokyo, with a Refresh button.'),
    const Say('Now Paris, as a separate card with a Refresh button.'),
    const Say('Now Rome, as a separate card with a Refresh button.'),
    Expect.liveSurfaces(3),
    const Press('Refresh', on: second),
    Expect.touched(second),
    Expect.untouched(first),
    Expect.untouched(third),
    Expect.newSurfaces(0),
    Expect.shows('Paris', on: second),
  ]),

  Scenario('follow-up edits the existing surface', [
    const Say("What's the weather in Tokyo?"),
    Expect.newSurfaces(1),
    const Say('Add the wind conditions to that card.'),
    Expect.touched(first),
    Expect.newSurfaces(0),
    Expect.liveSurfaces(1),
  ]),

  Scenario('comparison grows in place', [
    const Say('Compare the weather in London, Paris and Rome.'),
    Expect.newSurfaces(1),
    Expect.shows('Rome'),
    const Say('Add Berlin to the comparison.'),
    Expect.touched(first),
    Expect.newSurfaces(0),
    Expect.shows('Berlin', on: first),
    Expect.shows('London', on: first),
  ]),

  Scenario('delete a surface', [
    const Say("What's the weather in Tokyo?"),
    const Say('And in Paris, as a separate card?'),
    Expect.liveSurfaces(2),
    const Say('Remove the Paris card, I do not need it any more.'),
    Expect.deleted(second),
    Expect.untouched(first),
    Expect.liveSurfaces(1),
  ]),

  Scenario('form round-trip', [
    const Say(
      'Give me a short signup form with name and email fields and a Submit '
      'button.',
    ),
    Expect.newSurfaces(1),
    Expect.uses('TextField'),
    const Fill('name', 'Ada Lovelace', on: first),
    const Fill('email', 'ada@example.com', on: first),
    const Press('Submit', or: ['Sign up', 'Register'], on: first),
    Expect.acknowledges('Ada'),
  ], description: 'Values typed into the form reach the agent.'),

  Scenario('long chatty conversation', [
    const Say("Hi! I'm planning a trip to Europe next month."),
    Expect.noUi(),
    const Say(
      'Compare the weather in London, Paris and Rome, with a Refresh '
      'button.',
    ),
    Expect.newSurfaces(1),
    const Say('Thanks! Which of those is usually the rainiest?'),
    const Say('Good to know. Any packing tips for a rainy city?'),
    Expect.noUi(),
    const Say('What about museums in Paris, any must-sees?'),
    const Say('Great. One more: is the metro easy to use in Rome?'),
    const Press('Refresh', on: weather),
    Expect.touched(weather),
    Expect.newSurfaces(0),
    const Say('Add Berlin to the weather comparison.'),
    Expect.touched(weather),
    Expect.shows('Berlin', on: weather),
  ], description: 'Surfaces stay addressable after many prose turns.'),
];
