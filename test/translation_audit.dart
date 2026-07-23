/*
* Orion - An open-source user interface for the Odyssey 3d-printing engine.
* Copyright (C) 2025 Open Resin Alliance
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

class TranslationIssue {
  final String filePath;
  final int lineNumber;
  final String content;
  final String context;
  final bool isProbableFalsePositive;

  TranslationIssue(
    this.filePath,
    this.lineNumber,
    this.content,
    this.context, {
    this.isProbableFalsePositive = false,
  });
}

void main() async {
  final logFile = await createLogFile();
  print('🔍 Writing Translation Audit Report to: ${logFile.path}\n');
  
  final knownTranslations = await loadKnownTranslations();
  final issues = await findUntranslatedStrings(knownTranslations);
  writeReport(issues, logFile);
}

Future<File> createLogFile() async {
  final now = DateTime.now();
  final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
  final logDir = Directory('../logs');
  if (!await logDir.exists()) {
    await logDir.create();
  }
  return File('../logs/translation_audit_$timestamp.log');
}

Future<Set<String>> loadKnownTranslations() async {
  final baseFile = File('../lib/l10n/app_en.arb');
  if (!baseFile.existsSync()) {
    print('❌ Base translation file not found at ${baseFile.path}');
    exit(1);
  }

  final Map<String, dynamic> baseStrings = json.decode(baseFile.readAsStringSync());
  return baseStrings.keys
      .where((key) => !key.startsWith('@'))
      .toSet();
}

Future<List<TranslationIssue>> findUntranslatedStrings(Set<String> knownTranslations) async {
  final issues = <TranslationIssue>[];
  final sourcePath = Directory('../lib');
  
  // Patterns that indicate a string needs translation
  final translationPatterns = [
    RegExp(r'Text\("([^"]+)"\)'),              // Text("something")
    RegExp(r"Text\('([^']+)'\)"),              // Text('something')
    RegExp(r'title:\s*"([^"]+)"'),             // title: "something"
    RegExp(r"title:\s*'([^']+)'"),             // title: 'something'
    RegExp(r'label:\s*"([^"]+)"'),             // label: "something"
    RegExp(r"label:\s*'([^']+)'"),             // label: 'something'
    RegExp(r'hintText:\s*"([^"]+)"'),          // hintText: "something"
    RegExp(r"hintText:\s*'([^']+)'"),          // hintText: 'something'
    RegExp(r'tooltip:\s*"([^"]+)"'),           // tooltip: "something"
    RegExp(r"tooltip:\s*'([^']+)'"),           // tooltip: 'something'
    RegExp(r'message:\s*"([^"]+)"'),           // message: "something"
    RegExp(r"message:\s*'([^']+)'")            // message: 'something'
  ];

  // Patterns that should be ignored
  final ignorePatterns = [
    RegExp(r'^\s*//'),                         // Comments
    RegExp(r'"assets/[^"]+"'),                 // Asset paths with double quotes
    RegExp(r"'assets/[^']+'"),                 // Asset paths with single quotes
    RegExp(r'"https?://[^"]+"'),               // URLs with double quotes
    RegExp(r"\'https?://[^']+\'"),             // URLs with single quotes
    RegExp(r'@\w+'),                           // Annotations
    RegExp(r'^\s*import'),                     // Import statements
    RegExp(r'^\s*export'),                     // Export statements
    RegExp(r'context\.l10n\.\w+'),             // Already translated strings
  ];

  await for (final entity in sourcePath.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final lines = await entity.readAsLines();
      
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final contextLines = _getContextLines(lines, i, 2);
        
        // Skip if line matches any ignore pattern
        if (ignorePatterns.any((pattern) => pattern.hasMatch(line))) {
          continue;
        }

        for (final pattern in translationPatterns) {
          final match = pattern.firstMatch(line);
          if (match != null) {
            final content = match.group(1)!;
            
            // Skip if the string is already in translations
            if (knownTranslations.contains(content)) continue;
            
            // Check if it's likely a false positive
            final isProbableFalsePositive = _checkFalsePositive(content);

            issues.add(TranslationIssue(
              entity.path.replaceAll('${sourcePath.parent.path}/', ''),
              i + 1,
              content,
              contextLines,
              isProbableFalsePositive: isProbableFalsePositive,
            ));
          }
        }
      }
    }
  }

  return issues;
}

String _getContextLines(List<String> lines, int currentLine, int context) {
  final start = (currentLine - context).clamp(0, lines.length);
  final end = (currentLine + context + 1).clamp(0, lines.length);
  return lines.sublist(start, end).join('\n');
}

bool _checkFalsePositive(String content) {
  // Add patterns for common false positives
  final falsePositivePatterns = [
    RegExp(r'^[A-Z0-9_]+$'),              // All caps strings are likely constants
    RegExp(r'^\s*$'),                     // Empty or whitespace only
    RegExp(r'^[\d\s,.:-]+$'),             // Numbers and separators only
    RegExp(r'^[a-zA-Z0-9_]+$'),           // Single word identifiers
  ];

  return falsePositivePatterns.any((pattern) => pattern.hasMatch(content));
}

void writeReport(List<TranslationIssue> issues, File logFile) async {
  final buffer = StringBuffer();
  const int boxWidth = 70;
  
  String centerText(String text, int width) {
    final padding = (width - text.length) ~/ 2;
    return ' ' * padding + text + ' ' * (width - text.length - padding);
  }
  
  String createBox(String text) {
    return '║ ${centerText(text, boxWidth - 2)} ║';
  }

  buffer.writeln('╔${'═' * boxWidth}╗');
  buffer.writeln(createBox('Translation Audit Report'));
  buffer.writeln(createBox(DateTime.now().toString()));
  buffer.writeln('╚${'═' * boxWidth}╝\n');

  if (issues.isEmpty) {
    buffer.writeln('✅ No untranslated strings found!');
    await logFile.writeAsString(buffer.toString());
    return;
  }

  final realIssues = issues.where((i) => !i.isProbableFalsePositive).toList();
  final possibleFalsePositives = issues.where((i) => i.isProbableFalsePositive).toList();

  buffer.writeln('📊 Summary:');
  buffer.writeln('├─ ${realIssues.length} untranslated strings');
  buffer.writeln('└─ ${possibleFalsePositives.length} possible false positives\n');

  String currentFile = '';
  
  // Print real issues first
  if (realIssues.isNotEmpty) {
    buffer.writeln('╔${'═' * boxWidth}╗');
    buffer.writeln(createBox('Untranslated Strings'));
    buffer.writeln('╚${'═' * boxWidth}╝');
  }
  
  for (final issue in realIssues) {
    if (currentFile != issue.filePath) {
      currentFile = issue.filePath;
      buffer.writeln('\n📄 ${issue.filePath}');
      buffer.writeln('├${'─' * boxWidth}');
    }
    buffer.writeln('├─ Line ${issue.lineNumber}: "${issue.content}"');
    buffer.writeln('│  Context:');
    buffer.writeln('│    ${issue.context.replaceAll('\n', '\n│    ')}');
    buffer.writeln('│');
  }

  // Print possible false positives if any
  if (possibleFalsePositives.isNotEmpty) {
    buffer.writeln('\n╔${'═' * boxWidth}╗');
    buffer.writeln(createBox('Possible False Positives'));
    buffer.writeln('╚${'═' * boxWidth}╝');
    
    currentFile = '';
    for (final issue in possibleFalsePositives) {
      if (currentFile != issue.filePath) {
        currentFile = issue.filePath;
        buffer.writeln('\n📄 ${issue.filePath}');
        buffer.writeln('├${'─' * boxWidth}');
      }
      buffer.writeln('├─ Line ${issue.lineNumber}: "${issue.content}"');
    }
  }

  buffer.writeln('\n╔${'═' * boxWidth}╗');
  buffer.writeln(createBox('End Report'));
  buffer.writeln('╚${'═' * boxWidth}╝');

  await logFile.writeAsString(buffer.toString());
}