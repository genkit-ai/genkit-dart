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

import 'dart:io';

const licenseHeader = '''
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

''';

void main(List<String> args) async {
  final checkMode = args.contains('--check');
  final currentDir = Directory.current;
  
  print('Running in ${checkMode ? "check" : "apply"} mode...');

  final stats = await processDirectory(currentDir, checkMode);
  
  print('\nSummary:');
  print('Files checked: ${stats.checked}');
  print('Files skipped (already has header): ${stats.skipped}');
  print('Files needing header: ${stats.modified}');
  
  if (checkMode && stats.modified > 0) {
    print('\nFAILURE: ${stats.modified} files are missing license headers.');
    exit(1);
  }
  
  if (!checkMode && stats.modified > 0) {
    print('\nSUCCESS: Applied license headers to ${stats.modified} files.');
  } else if (!checkMode) {
    print('\nSUCCESS: All files already have license headers.');
  }
}

class Stats {
  int checked = 0;
  int skipped = 0;
  int modified = 0;
}

Future<Stats> processDirectory(Directory dir, bool checkMode) async {
  final stats = Stats();
  
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      if (!_shouldProcess(entity.path)) continue;
      
      stats.checked++;
      final needsHeader = await _processFile(entity, checkMode);
      if (needsHeader) {
        stats.modified++;
      } else {
        stats.skipped++;
      }
    }
  }
  
  return stats;
}

bool _shouldProcess(String path) {
  if (!path.endsWith('.dart')) return false;
  // Exclude hidden files and directories
  if (path.contains('/.')) return false;
  // Exclude generated files (optional, but usually good practice to exclude .g.dart or .freezed.dart if the header shouldn't be there, 
  // but often licenses are applied there too. Let's include them for now unless they are typically excluded. 
  // Actually, generated files often have "Do not edit" comments. Let's apply to all .dart files as requested "all files (.dart mainly)".)
  
  // Exclude build directories or package cache if any (unlikely in recursive list from root unless ignored)
  // .gitignore is respected by developer but Directory.list lists everything.
  // We should probably check if it's in a hidden directory like .dart_tool
  if (path.contains('.dart_tool/')) return false;
  
  return true;
}

Future<bool> _processFile(File file, bool checkMode) async {
  try {
    final content = await file.readAsString();
    
    // Check for shebang
    bool hasShebang = content.startsWith('#!');
    String contentToCheck = content;
    String? shebangLine;
    
    if (hasShebang) {
      final newlineIndex = content.indexOf('\n');
      if (newlineIndex != -1) {
        shebangLine = content.substring(0, newlineIndex + 1);
        contentToCheck = content.substring(newlineIndex + 1);
      } else {
        // File is only shebang
        shebangLine = content;
        contentToCheck = '';
      }
    }

    if (contentToCheck.trimLeft().startsWith('// Copyright')) {
      return false; // Already has header
    }
    
    // Check for Apache license mention if copyright format is different
    // We only check the first 1000 characters to avoid matching string constants later in the file
    final checkLimit = contentToCheck.length > 1000 ? 1000 : contentToCheck.length;
    if (contentToCheck.substring(0, checkLimit).contains('Licensed under the Apache License')) {
       return false;
    }

    if (checkMode) {
      print('Missing header: ${file.path}');
      return true;
    }

    // Apply header
    final sb = StringBuffer();
    if (hasShebang && shebangLine != null) {
      sb.write(shebangLine);
    }
    sb.write(licenseHeader);
    sb.write(contentToCheck);
    
    await file.writeAsString(sb.toString());
    print('Applied header: ${file.path}');
    return true;
    
  } catch (e) {
    print('Error processing ${file.path}: $e');
    return false;
  }
}
