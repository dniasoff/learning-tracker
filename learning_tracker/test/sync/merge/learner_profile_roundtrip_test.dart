/// Round-trip test: the canonical write serializer (LearnerProfileCodec.encode)
/// must produce a payload that LearnerProfileMerger accepts and persists.
///
/// This test guards the Phase B invariant: if the codec's encode() ever drifts
/// from the key names the merger reads, the profile will be skipped on pull and
/// cross-device sync silently breaks. The test MUST fail before the fix when
/// there is a real mismatch, and pass after.
///
/// For learner_profiles the shapes were already consistent before Phase B, so
/// this test is simultaneously the regression gate and the proof of consistency.
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/learner_profile_codec.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/learner_profile_merger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _codec = LearnerProfileCodec();

/// The profile id the remote document claims.
const _remoteProfileId = 42;

final _updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _createdAt = DateTime.utc(2026, 1, 1, 0, 0, 0);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('learner_profile — codec.encode() → merger → DB round-trip', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late LearnerProfileMerger merger;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
      merger = LearnerProfileMerger(store: store);

      // Seed an account row so _resolveLocalAccountId has a FK target to bind.
      // Do NOT seed a learner profile — the merge must INSERT it.
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'test@example.com',
              tier: 'cloudBorn',
              displayName: 'Test Account',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'codec.encode() payload is accepted by the merger and the row lands in DB',
      () async {
        // Build the canonical write payload via the codec — exactly as
        // ProfileRepositoryImpl._toFirestorePayload now does.
        final row = LearnerProfileRow(
          profileId: _remoteProfileId,
          accountId: 1,
          displayName: 'Alice',
          mode: 'adult',
          avatarIndex: 3,
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        );
        final payload = _codec.encode(row);

        // The merger must accept the payload and write it to Drift.
        await merger.merge(profileId: _remoteProfileId, rows: [payload]);

        // Assert: the profile row materialised in the DB — not skipped.
        final profile = await db.profileDao.getProfileById(_remoteProfileId);
        expect(
          profile,
          isNotNull,
          reason:
              'LearnerProfileMerger must INSERT the profile when codec.encode() '
              'payload is fed in — if null, the merge read-keys diverge from the '
              'codec write-keys (the bookmarks-class push↔merge key-contract bug).',
        );
        expect(profile!.displayName, 'Alice');
        expect(profile.mode, 'adult');
        expect(profile.avatarIndex, 3);
        expect(
          profile.updatedAt.toUtc(),
          _updatedAt,
          reason:
              'updated_at must round-trip through the codec and be stored correctly',
        );
      },
    );

    test('currentUpdatedAt is persisted after a successful merge', () async {
      final row = LearnerProfileRow(
        profileId: _remoteProfileId,
        accountId: 1,
        displayName: 'Bob',
        mode: 'child',
        avatarIndex: 0,
        createdAt: _createdAt,
        updatedAt: _updatedAt,
      );
      await merger.merge(
        profileId: _remoteProfileId,
        rows: [_codec.encode(row)],
      );

      final persisted = await store.currentUpdatedAt(
        kind: EntityKind.learnerProfile,
        profileId: _remoteProfileId,
        naturalKey: _remoteProfileId.toString(),
      );
      expect(
        persisted,
        _updatedAt,
        reason:
            'persistUpdatedAt must record the remote updated_at so subsequent '
            'pulls use LWW symmetrically',
      );
    });

    test(
      'a second merge with an older updated_at is skipped (LWW wins local)',
      () async {
        final newer = LearnerProfileRow(
          profileId: _remoteProfileId,
          accountId: 1,
          displayName: 'Carol-new',
          mode: 'adult',
          avatarIndex: 1,
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        );
        await merger.merge(
          profileId: _remoteProfileId,
          rows: [_codec.encode(newer)],
        );

        // Now merge an older version — must not overwrite the newer local row.
        final older = LearnerProfileRow(
          profileId: _remoteProfileId,
          accountId: 1,
          displayName: 'Carol-old',
          mode: 'adult',
          avatarIndex: 2,
          createdAt: _createdAt,
          updatedAt: _updatedAt.subtract(const Duration(minutes: 1)),
        );
        await merger.merge(
          profileId: _remoteProfileId,
          rows: [_codec.encode(older)],
        );

        final profile = await db.profileDao.getProfileById(_remoteProfileId);
        expect(
          profile?.displayName,
          'Carol-new',
          reason: 'LWW: older remote must not overwrite a newer local row',
        );
        expect(profile?.avatarIndex, 1);
      },
    );
  });
}
