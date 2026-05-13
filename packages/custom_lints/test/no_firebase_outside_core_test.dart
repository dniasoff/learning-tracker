// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_firebase_outside_core.dart';

/// Writes [content] to a temporary file and returns the file.
File _tmpFile(String content) {
  final file = File(
    '${Directory.systemTemp.path}/test_firebase_${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

/// Writes [content] to a path that contains [pathSegment] so the rule's
/// whitelist check fires for the correct directory segment.
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
  const rule = NoFirebaseOutsideCore();

  group('NoFirebaseOutsideCore', () {
    group('violations', () {
      test('flags firebase_auth import in a non-core file', () async {
        final file = _tmpFile('''
import 'package:firebase_auth/firebase_auth.dart';
void main() {}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_firebase_outside_core'),
          isNotEmpty,
          reason: 'firebase_auth import outside core must be flagged',
        );
      });

      test('flags cloud_firestore import in a non-core file', () async {
        final file = _tmpFile('''
import 'package:cloud_firestore/cloud_firestore.dart';
void main() {}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_firebase_outside_core'),
          isNotEmpty,
          reason: 'cloud_firestore import outside core must be flagged',
        );
      });

      test('flags firebase_storage import in a non-core file', () async {
        final file = _tmpFile('''
import 'package:firebase_storage/firebase_storage.dart';
void main() {}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_firebase_outside_core'),
          isNotEmpty,
          reason: 'firebase_storage import outside core must be flagged',
        );
      });
    });

    group('allowed', () {
      test('allows non-firebase imports anywhere', () async {
        final file = _tmpFile('''
import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
void main() {}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_firebase_outside_core'),
          isEmpty,
          reason: 'Non-firebase imports must not be flagged',
        );
      });
    });

    group('whitelist — file path checks', () {
      test('isWhitelisted returns true for lib/core/auth/ path', () {
        expect(_invokeIsWhitelisted('lib/core/auth/firebase_auth_service.dart'),
            isTrue);
      });

      test('isWhitelisted returns true for lib/core/sync/ path', () {
        expect(
            _invokeIsWhitelisted('lib/core/sync/firestore_sync_service.dart'),
            isTrue);
      });

      test('isWhitelisted returns true for .g.dart', () {
        expect(_invokeIsWhitelisted('some.g.dart'), isTrue);
      });

      test('isWhitelisted returns true for .freezed.dart', () {
        expect(_invokeIsWhitelisted('model.freezed.dart'), isTrue);
      });

      test('isWhitelisted returns false for feature file', () {
        expect(
          _invokeIsWhitelisted(
              'lib/features/dashboard/presentation/screen.dart'),
          isFalse,
        );
      });

      test('isWhitelisted returns false for core/analytics file', () {
        expect(
          _invokeIsWhitelisted('lib/core/analytics/parent_analytics.dart'),
          isFalse,
        );
      });

      test('firebase_auth import allowed in lib/core/auth/', () async {
        final file = _tmpFileAt('''
import 'package:firebase_auth/firebase_auth.dart';
void main() {}
''', 'lib/core/auth');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_firebase_outside_core'),
          isEmpty,
          reason: 'firebase_auth is allowed inside lib/core/auth/',
        );
      });

      test('cloud_firestore import allowed in lib/core/sync/', () async {
        final file = _tmpFileAt('''
import 'package:cloud_firestore/cloud_firestore.dart';
void main() {}
''', 'lib/core/sync');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == 'no_firebase_outside_core'),
          isEmpty,
          reason: 'cloud_firestore is allowed inside lib/core/sync/',
        );
      });
    });
  });
}

/// Mirrors the private _isWhitelisted logic for unit-level path testing.
bool _invokeIsWhitelisted(String path) {
  final normalised = path.replaceAll(r'\', '/');
  if (normalised.contains('lib/core/auth/')) return true;
  if (normalised.contains('lib/core/sync/')) return true;
  if (normalised.endsWith('.g.dart')) return true;
  if (normalised.endsWith('.freezed.dart')) return true;
  return false;
}
