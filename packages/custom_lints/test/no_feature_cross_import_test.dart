// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_feature_cross_import.dart';

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

void main() {
  const rule = NoFeatureCrossImport();

  group('NoFeatureCrossImport', () {
    group('violations — cross-feature deep import', () {
      test('flags a feature importing another feature domain model', () async {
        // A file in lib/features/dashboard/ importing a deep path from lib/features/tracks/
        final file = _tmpFileAt(
          '''
import 'package:learning_tracker/features/tracks/domain/models/track.dart';
void main() {}
''',
          'lib/features/dashboard/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_feature_cross_import'),
          isNotEmpty,
          reason: 'Deep cross-feature import must be flagged',
        );
      });

      test('flags a feature importing another feature provider directly',
          () async {
        final file = _tmpFileAt(
          '''
import 'package:learning_tracker/features/tracks/presentation/providers/track_providers.dart';
void main() {}
''',
          'lib/features/gamification/streak',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_feature_cross_import'),
          isNotEmpty,
          reason: 'Cross-feature deep provider import must be flagged',
        );
      });

      test('flags nested sub-dir deep import', () async {
        final file = _tmpFileAt(
          '''
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
void main() {}
''',
          'lib/features/dashboard/domain',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_feature_cross_import'),
          isNotEmpty,
          reason: 'Sub-dir cross-feature deep import must be flagged',
        );
      });
    });

    group('allowed — same-feature deep imports are permitted', () {
      test('allows a feature importing its own domain model', () async {
        final file = _tmpFileAt(
          '''
import 'package:learning_tracker/features/tracks/domain/models/track.dart';
void main() {}
''',
          'lib/features/tracks/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_feature_cross_import'),
          isEmpty,
          reason: 'Same-feature imports must not be flagged',
        );
      });

      test('allows a feature importing its own nested sub-feature', () async {
        final file = _tmpFileAt(
          '''
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
void main() {}
''',
          'lib/features/tracks/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_feature_cross_import'),
          isEmpty,
          reason: 'Same top-level feature deep import must not be flagged',
        );
      });
    });

    group('allowed — barrel import is the correct cross-feature surface', () {
      test('allows import of the feature barrel (tracks.dart)', () async {
        final file = _tmpFileAt(
          '''
import 'package:learning_tracker/features/tracks/tracks.dart';
void main() {}
''',
          'lib/features/dashboard/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_feature_cross_import'),
          isEmpty,
          reason: 'Barrel import (features/tracks/tracks.dart) must be allowed',
        );
      });

      test('allows import of the account barrel (account.dart)', () async {
        final file = _tmpFileAt(
          '''
import 'package:learning_tracker/features/account/account.dart';
void main() {}
''',
          'lib/features/gamification/streak',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_feature_cross_import'),
          isEmpty,
          reason:
              'Barrel import (features/account/account.dart) must be allowed',
        );
      });
    });

    group('allowed — non-feature imports are never flagged', () {
      test('allows core/ package imports from a feature', () async {
        final file = _tmpFileAt(
          '''
import 'package:learning_tracker/core/logging/logger.dart';
void main() {}
''',
          'lib/features/dashboard/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_feature_cross_import'),
          isEmpty,
          reason: 'core/ imports from a feature must not be flagged',
        );
      });

      test('allows external package imports', () async {
        final file = _tmpFileAt(
          '''
import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
void main() {}
''',
          'lib/features/dashboard/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_feature_cross_import'),
          isEmpty,
          reason: 'External package imports must not be flagged',
        );
      });

      test('files outside features/ are not linted', () async {
        // A file in lib/core/ importing features/X/ deep path — this rule
        // does NOT flag it (that is checked by a separate audit grep #14).
        final file = _tmpFileAt(
          '''
import 'package:learning_tracker/features/tracks/domain/models/track.dart';
void main() {}
''',
          'lib/core/sync',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_feature_cross_import'),
          isEmpty,
          reason: 'Files outside lib/features/ are not subject to this rule',
        );
      });
    });

    group('feature classification — real analyzer path', () {
      test('does not lint host files outside lib/features/ (e.g. lib/app/)',
          () async {
        final file = _tmpFileAt(
          '''
import 'package:learning_tracker/features/tracks/domain/models/track.dart';
void main() {}
''',
          'lib/app/bootstrap',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_feature_cross_import'),
          isEmpty,
          reason: 'Host files outside lib/features/ (e.g. lib/app/) are not '
              'subject to this rule',
        );
      });

      test(
          'classifies a host file nested under a sub-feature by its '
          'top-level feature', () async {
        // The host file itself lives under features/tracks/stages/… (a
        // nested sub-feature); it must still be classified as feature
        // "tracks" so a deep import from a genuinely different feature is
        // flagged.
        final file = _tmpFileAt(
          '''
import 'package:learning_tracker/features/dashboard/domain/models/summary.dart';
void main() {}
''',
          'lib/features/tracks/stages/domain/models',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_feature_cross_import'),
          isNotEmpty,
          reason: 'A nested sub-feature host file is still classified under '
              'its top-level feature',
        );
      });

      test(
          'classifies host feature correctly with Windows-style backslash '
          'path segments', () async {
        // Simulates a Windows-reported path — a single directory literally
        // named "lib\features\tracks\presentation" (backslashes as
        // characters, not separators, since this test runs on Linux) so the
        // rule's path-separator-tolerant regex is exercised through the
        // real analyzer path.
        final file = _tmpFileAt(
          '''
import 'package:learning_tracker/features/dashboard/domain/models/summary.dart';
void main() {}
''',
          r'lib\features\tracks\presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_feature_cross_import'),
          isNotEmpty,
          reason: 'Windows-style backslash path segments must still '
              'classify the host feature as tracks and flag the '
              'cross-feature import',
        );
      });
    });
  });
}
