#!/bin/bash

# Make sure this options file exists so CI can analyze the code

FILE=lib/firebase_options.dart
if [ ! -f "$FILE" ]; then
  echo "Creating $FILE"
  cat <<'EOF' > $FILE
import 'package:firebase_core/firebase_core.dart';

abstract final class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'place-holder',
    appId: 'place-holder',
    messagingSenderId: 'place-holder',
    projectId: 'place-holder',
  );
}
EOF
else
  echo "$FILE already exists"
fi
