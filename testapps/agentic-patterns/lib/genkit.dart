import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

export 'package:genkit/genkit.dart';

// Shared Genkit instance for all samples
final ai = Genkit(
  plugins: [
    googleAI(),
  ],
);

final geminiFlash = googleAI.gemini('gemini-2.5-flash');
