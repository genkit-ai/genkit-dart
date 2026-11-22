// Copyright 2026 Google LLC
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

/// System One decision models for Genkit Dart.
///
/// A decision model does not generate text. It evaluates a state against
/// typed questions and returns one typed answer per question, with calibrated
/// probabilities. That makes it a fit for the
/// decisions inside an application: routing, classification, scoring,
/// guardrails, and verification.
///
/// The plugin serves such a model as one that speaks only constrained JSON,
/// which is the subset of the generate API it fits exactly. The output schema
/// is the question set: `Choice`, `ScoreOf`, `Noul`, and `NoulOf` are the
/// questions, `decisionSchema` puts them together, and the answers land in
/// typed fields. `questionsSchema` asks questions built at run time.
///
/// `SystemOne` serves the models from any server that speaks the protocol;
/// `SystemOne.typeSafe`, `SystemOne.openRouter`, `SystemOne.ollama`, and
/// `SystemOne.workersAI` set it up for the known ones.
///
/// Preview: this API may change in any minor release.
library;

export 'src/info.dart' show SystemOneInfo;
export 'src/options.dart' show SystemOneOptions;
export 'src/plugin.dart'
    show MediaSupport, ModelSpec, SystemOne, SystemOneRoute, SystemOneUnwrap;
export 'src/questions.dart'
    show
        Answer,
        Choice,
        ChoiceOption,
        ChoiceQuestion,
        Noul,
        NoulOf,
        NoulQuestion,
        Option,
        Question,
        Rubric,
        ScoreOf,
        ScoreQuestion,
        YesNo,
        decisionSchema,
        questionsSchema;
