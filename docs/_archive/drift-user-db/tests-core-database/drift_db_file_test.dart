// Regression test for AUD-account-09: one shared .sqlite-suffix
// delete-with-fallback helper, used by both AccountLifecycleService and
// PendingLocalSignupStore instead of each defining its own copy.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/drift_db_file.dart';

void main() {
  group('resolveDriftDbFile / deleteDriftDbFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('drift_db_file_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('resolves the .sqlite-suffixed file when present', () async {
      const dbFileName = 'user_acc_a.db';
      final suffixed = File('${tempDir.path}/$dbFileName.sqlite');
      await suffixed.create();

      final resolved = resolveDriftDbFile(tempDir.path, dbFileName);
      expect(resolved?.path, suffixed.path);
    });

    test(
      'falls back to the bare filename when no .sqlite-suffixed file exists',
      () async {
        const dbFileName = 'user_acc_b.db';
        final bare = File('${tempDir.path}/$dbFileName');
        await bare.create();

        final resolved = resolveDriftDbFile(tempDir.path, dbFileName);
        expect(resolved?.path, bare.path);
      },
    );

    test('returns null when neither file exists', () {
      expect(resolveDriftDbFile(tempDir.path, 'nonexistent.db'), isNull);
    });

    test('deleteDriftDbFile removes the .sqlite-suffixed file', () async {
      const dbFileName = 'user_acc_c.db';
      final suffixed = File('${tempDir.path}/$dbFileName.sqlite');
      await suffixed.create();

      deleteDriftDbFile(tempDir.path, dbFileName);

      expect(suffixed.existsSync(), isFalse);
    });

    test(
      'deleteDriftDbFile is a no-op (does not throw) when nothing exists',
      () {
        expect(
          () => deleteDriftDbFile(tempDir.path, 'nonexistent.db'),
          returnsNormally,
        );
      },
    );
  });
}
