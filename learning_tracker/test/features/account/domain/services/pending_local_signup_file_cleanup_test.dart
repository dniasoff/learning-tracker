// Regression test: deleteOrphanDbFile must delete the drift_flutter file
// which is named "$dbFileName.sqlite" on the filesystem, NOT "$dbFileName".
//
// drift_flutter 0.2.8 / src/native.dart line 51:
//   return File(p.join(directory, '$name.sqlite'));
// So driftDatabase(name:'user_acc_xxx.db') → "user_acc_xxx.db.sqlite" on disk.
//
// Previous behaviour: _deleteDbFile tried to delete "$databasesPath/$dbFileName"
// (i.e. "…/user_acc_xxx.db") which does not exist — the orphan DB file was
// silently left on disk after a failed local signup.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/services/pending_local_signup.dart';

void main() {
  group('PendingLocalSignupStore.deleteOrphanDbFile — drift_flutter suffix', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pending_signup_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test(
      'deletes the .sqlite-suffixed file that drift_flutter actually creates',
      () async {
        // drift_flutter stores "user_acc_xxx.db" as "user_acc_xxx.db.sqlite"
        const dbFileName = 'user_acc_test123.db';
        final driftFile = File('${tempDir.path}/$dbFileName.sqlite');
        await driftFile.create();
        expect(
          driftFile.existsSync(),
          isTrue,
          reason: 'precondition: drift file must exist before delete',
        );

        PendingLocalSignupStore.deleteOrphanDbFile(tempDir.path, dbFileName);

        expect(
          driftFile.existsSync(),
          isFalse,
          reason:
              'deleteOrphanDbFile must remove the .sqlite-suffixed drift file',
        );
      },
    );

    test(
      'does NOT leave the drift file behind when only the bare name is deleted',
      () async {
        // This test documents the BUG: if the bare name is deleted instead of
        // the .sqlite name, the drift file survives.
        const dbFileName = 'user_acc_test456.db';
        final driftFile = File('${tempDir.path}/$dbFileName.sqlite');
        await driftFile.create();

        // Simulate what the BUGGY code did: delete the bare path only
        final barePath = File('${tempDir.path}/$dbFileName');
        // barePath doesn't exist, so deleteSync would throw — the bug was
        // the guard "if existsSync" silently did nothing.
        expect(
          barePath.existsSync(),
          isFalse,
          reason: 'the bare path should NOT exist — only the .sqlite one',
        );

        // After calling the fixed deleteOrphanDbFile the .sqlite file MUST be gone
        PendingLocalSignupStore.deleteOrphanDbFile(tempDir.path, dbFileName);

        expect(
          driftFile.existsSync(),
          isFalse,
          reason:
              'the .sqlite drift file must be gone after deleteOrphanDbFile',
        );
      },
    );

    test('is a no-op when no file exists (both bare and .sqlite absent)', () {
      const dbFileName = 'user_acc_nonexistent.db';
      // Neither file exists — must not throw
      expect(
        () => PendingLocalSignupStore.deleteOrphanDbFile(
          tempDir.path,
          dbFileName,
        ),
        returnsNormally,
      );
    });
  });
}
