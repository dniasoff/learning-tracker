/// Story acceptance coverage for Epic 14 — settings.
@Tags(['epic_14'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Story 14.1 — settings profile contract', tags: ['story_14_1'], () {
    test('settings screen reads through the active profile identity seam', () {
      final source = File(
        'lib/features/settings/presentation/screens/settings_screen.dart',
      ).readAsStringSync();
      expect(source, contains('activeProfileIdProvider'));
    });

  });

  group('Story 14.2 — data export/import', tags: ['story_14_2'], skip:
      'Blocked: the existing acceptance flow exercises the Drift DataExportImportService and its schemaV1 format. Firestore export/import format remains an unresolved product decision.',
      () {
    test('placeholder for the pending Firestore export format', () {});
  });

  group('Story 14.3 — account management', tags: ['story_14_3'], skip:
      'Blocked: account deletion in the original flow cascades through Drift user tables; no Firestore-native deletion contract is exposed to this suite.',
      () {
    test('placeholder for the pending Firestore account-management seam', () {});
  });
}
