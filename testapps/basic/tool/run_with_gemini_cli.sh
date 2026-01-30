#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/../node_server"

if [ ! -d "node_modules" ]; then
  echo "Warning: 'node_modules' not found. You may need to run 'npm install'." >&2
fi

set -x # just to echo the command
npx genkit start -- dart run ../bin/server_dart.dart
