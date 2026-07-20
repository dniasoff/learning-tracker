// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_raw_talker.dart';

/// Writes [content] to a temporary file and returns it.
File _tmpFile(String content) {
  final file = File(
    '${Directory.systemTemp.path}/test_talker_${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

/// Writes [content] to a path that contains [pathSegment].
File _tmpFileAt(String content, String pathSegment) {
  final dir = Directory(
    '${Directory.systemTemp.path}/$pathSegment',
  );
  dir.createSync(recursive: true);
  final file = File(
    '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

/// Writes [content] to a temp file whose name ends with [suffix] (e.g.
/// `.g.dart`) so the rule's suffix-based whitelist checks are exercised
/// through the real analyzer path rather than a hand-copied helper.
File _tmpFileWithSuffix(String content, String suffix) {
  final file = File(
    '${Directory.systemTemp.path}/test_talker_gen_${DateTime.now().microsecondsSinceEpoch}$suffix',
  );
  file.writeAsStringSync(content);
  return file;
}

void main() {
  const rule = NoRawTalker();

  group('NoRawTalker', () {
    group('violations', () {
      test('flags package:talker/talker.dart import outside core/logging',
          () async {
        final file = _tmpFile('''
import 'package:talker/talker.dart';
void main() {}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_raw_talker'),
          isNotEmpty,
          reason: 'Raw talker import outside core/logging must be flagged',
        );
      });

      test('flags talker import in a feature file', () async {
        final file = _tmpFileAt('''
import 'package:talker/talker.dart';
void main() {}
''', 'lib/features/dashboard');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_raw_talker'),
          isNotEmpty,
          reason: 'Raw talker import in feature/ must be flagged',
        );
      });

      test('flags talker import in core/analytics', () async {
        final file = _tmpFileAt('''
import 'package:talker/talker.dart';
void main() {}
''', 'lib/core/analytics');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_raw_talker'),
          isNotEmpty,
          reason: 'Raw talker import in core/analytics must be flagged',
        );
      });
    });

    group('allowed', () {
      test('allows non-talker imports anywhere', () async {
        final file = _tmpFile('''
import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
void main() {}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_raw_talker'),
          isEmpty,
          reason: 'Non-talker imports must not be flagged',
        );
      });

      test('allows talker sub-package imports (not the banned URI)', () async {
        // e.g. package:talker_flutter/talker_flutter.dart is not banned
        final file = _tmpFile('''
import 'package:talker_flutter/talker_flutter.dart';
void main() {}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_raw_talker'),
          isEmpty,
          reason: 'Talker sub-packages are not restricted by this rule',
        );
      });
    });

    group('whitelist — file path checks', () {
      test('allows talker import in generated .g.dart file', () async {
        final file = _tmpFileWithSuffix('''
import 'package:talker/talker.dart';
void main() {}
''', '.g.dart');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_raw_talker'),
          isEmpty,
          reason: 'Generated .g.dart files are whitelisted',
        );
      });

      test('allows talker import in generated .freezed.dart file', () async {
        final file = _tmpFileWithSuffix('''
import 'package:talker/talker.dart';
void main() {}
''', '.freezed.dart');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_raw_talker'),
          isEmpty,
          reason: 'Generated .freezed.dart files are whitelisted',
        );
      });

      test('allows talker import in lib/core/logging/', () async {
        final file = _tmpFileAt('''
import 'package:talker/talker.dart';
void main() {}
''', 'lib/core/logging');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_raw_talker'),
          isEmpty,
          reason:
              'package:talker/talker.dart is allowed inside lib/core/logging/',
        );
      });
    });
  });
}
