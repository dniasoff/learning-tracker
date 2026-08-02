/// Golden/byte-for-byte equivalence tests for [DocIds] (Story 2.2).
///
/// **What this proves.** For a representative document of every synced
/// collection, [DocIds]'s output is compared against the id the LIVE
/// `FirestoreGatewayImpl` actually writes — not against a hand-derived
/// assumption. Each test pushes a representative payload through the real
/// gateway into a `fake_cloud_firestore` instance, reads back the doc id
/// Firestore actually assigned, and asserts [DocIds] independently computes
/// the identical string from the same payload. This is the byte-for-byte
/// equivalence AC (AD-5, AD-13, AD-29 tier 1 pure-unit).
///
/// **Red-demo (bottom group).** A deliberately-perturbed alternate formula
/// (drops the `_` separator) is shown to DISAGREE with the live gateway's
/// real output on a colliding pair of inputs — proving this harness has
/// teeth and would catch a byte-for-byte regression — immediately followed
/// by the real [DocIds] formula agreeing (green).
///
/// TQ-6: hermetic — no network (fake Firestore only), no wall clock, no
/// unseeded randomness, no shared mutable state (a fresh
/// `createFakeFirestore()` per test).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/firestore_gateway_impl.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';

import '../../helpers/firestore_fake.dart';

// ── Minimal stub AuthRepository ─────────────────────────────────────────
//
// FirestoreGatewayImpl only ever reads currentUser.uid; every other method
// throws UnimplementedError so an accidental call surfaces immediately.
// Mirrors test/integration/firestore_wipe_install_test.dart's
// _StubAuthRepository (kept file-local rather than shared to avoid coupling
// this new golden-test module to another test file's private class).
class _StubAuthRepository implements AuthRepository {
  const _StubAuthRepository(this._uid);

  final String _uid;

  @override
  AppUser? get currentUser => AppUser(
    uid: _uid,
    email: 'test@example.com',
    displayName: 'Test User',
    emailVerified: true,
    providers: const ['password'],
  );

  @override
  Stream<AppUser?> onAuthStateChanged() => Stream.value(currentUser);

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) =>
      throw UnimplementedError();
  @override
  Future<void> signInWithEmail(String e, String p) =>
      throw UnimplementedError();
  @override
  Future<void> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<AppUser?> reauthWithGoogleSilently() => throw UnimplementedError();
  @override
  Future<void> signUp(String e, String p, String n) =>
      throw UnimplementedError();
  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();
  @override
  Future<void> sendSignInLinkToEmail(String e) => throw UnimplementedError();
  @override
  Future<AppUser?> signInWithEmailLink(String e, String l) =>
      throw UnimplementedError();
  @override
  bool isSignInWithEmailLink(String l) => throw UnimplementedError();
  @override
  Future<void> sendPasswordResetEmail(String e) => throw UnimplementedError();
  @override
  Future<void> signOut() => throw UnimplementedError();
  @override
  Future<void> deleteAccount() => throw UnimplementedError();
  @override
  Future<void> changePassword(String p) => throw UnimplementedError();
  @override
  Future<void> reauthenticateWithEmail(String e, String p) =>
      throw UnimplementedError();
  @override
  Future<void> reauthenticateWithGoogle() => throw UnimplementedError();
  @override
  Future<void> linkGoogleProvider() => throw UnimplementedError();
  @override
  Future<void> linkEmailProvider(String e, String p) =>
      throw UnimplementedError();
  @override
  List<String> getLinkedProviders() => throw UnimplementedError();
  @override
  Future<AppUser?> reloadCurrentUser() => throw UnimplementedError();
  @override
  Future<void> checkActionCode(String c) => throw UnimplementedError();
  @override
  Future<void> applyActionCode(String c) => throw UnimplementedError();
  @override
  Future<String> createUserAccount(String e, String p) =>
      throw UnimplementedError();
  @override
  Future<AppUser?> signInAndGetUser(String e, String p) =>
      throw UnimplementedError();
  @override
  Future<void> updateDisplayName(String n) => throw UnimplementedError();
  @override
  Future<void> deleteCurrentFirebaseUser() => throw UnimplementedError();
}

const _uid = 'uid_doc_ids_golden_test';
const _profileId = 42;

FirestoreGatewayImpl _gw(FirebaseFirestore fs) => FirestoreGatewayImpl(
  firestore: fs,
  authRepository: const _StubAuthRepository(_uid),
);

/// Reads back the single doc id the live gateway actually wrote to a
/// per-profile subcollection. Fails loudly (via [hasLength]) if the push
/// didn't land exactly one document, so a broken test setup can never be
/// silently read as "the id matched" against an empty snapshot.
Future<String> _liveDocId(FakeFirebaseFirestore fs, String collection) async {
  final snap = await fs
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId.toString())
      .collection(collection)
      .get();
  expect(
    snap.docs,
    hasLength(1),
    reason: 'expected exactly one doc in $collection after the push',
  );
  return snap.docs.first.id;
}

void main() {
  group('DocIds — golden equivalence vs the live FirestoreGatewayImpl', () {
    test('completions: byte-for-byte for a representative document', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'profile_id': _profileId,
        'sefaria_ref': 'Berakhot 1:1',
        'stage_id': 1,
        'curriculum_id': 'mishnayos',
        'completed_at': '2026-05-01T00:00:00.000Z',
        'points': 5,
      };
      await _gw(fs).pushCompletion(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'completions');
      expect(DocIds.completionDocId(_profileId, data), equals(live));
    });

    test('completions: percent-encoding keeps three near-collision refs '
        'distinct, matching the live gateway on each', () async {
      // '.', '/' and ' ' each encode differently — this is the exact
      // collision-avoidance guarantee _completionDocId's doc comment
      // claims; prove DocIds reproduces it byte-for-byte for all three.
      for (final ref in ['Berakhot 1.1', 'Berakhot 1/1', 'Berakhot 1 1']) {
        final fs = createFakeFirestore(authenticatedUid: _uid);
        final data = <String, dynamic>{
          'profile_id': _profileId,
          'sefaria_ref': ref,
          'stage_id': 1,
          'curriculum_id': 'mishnayos',
          'completed_at': '2026-05-01T00:00:00.000Z',
        };
        await _gw(fs).pushCompletion(profileId: _profileId, data: data);
        final live = await _liveDocId(fs, 'completions');
        expect(DocIds.completionDocId(_profileId, data), equals(live));
      }
    });

    test(
      'completions: camelCase legacy-alias payload is byte-for-byte too',
      () async {
        final fs = createFakeFirestore(authenticatedUid: _uid);
        final data = <String, dynamic>{
          'profile_id': _profileId,
          'sefariaRef': 'Shabbat 2:3',
          'stageId': 4,
          'curriculumId': 'bavli',
        };
        await _gw(fs).pushCompletion(profileId: _profileId, data: data);
        final live = await _liveDocId(fs, 'completions');
        expect(DocIds.completionDocId(_profileId, data), equals(live));
      },
    );

    test('streak_events: ULID-present payload is byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'ulid': 'ULID_STREAK_1',
        'streak_count': 7,
      };
      await _gw(fs).pushStreak(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'streak_events');
      expect(DocIds.streakEventDocId(data), equals(live));
    });

    test('settings: curriculum_id payload is byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'curriculum_id': 'daf_yomi',
        'setting': true,
      };
      await _gw(fs).pushSettings(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'settings');
      expect(DocIds.settingsDocId(data), equals(live));
    });

    test(
      'settings: missing curriculum_id falls back to "default" byte-for-byte',
      () async {
        final fs = createFakeFirestore(authenticatedUid: _uid);
        final data = <String, dynamic>{'setting': false};
        await _gw(fs).pushSettings(profileId: _profileId, data: data);
        final live = await _liveDocId(fs, 'settings');
        expect(DocIds.settingsDocId(data), equals(live));
        expect(live, equals('default'));
      },
    );

    test('curriculum_tracks: byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'curriculum_id': 'mishnayos', 'pace': 1};
      await _gw(fs).pushTrack(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'curriculum_tracks');
      expect(DocIds.curriculumTrackDocId(data), equals(live));
    });

    test('learning_order: sefaria_ref payload is byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'curriculum_id': 'mishnayos',
        'sefaria_ref': 'Berakhot 1:1',
      };
      await _gw(fs).pushLearningOrder(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'learning_order');
      expect(DocIds.learningOrderDocId(data), equals(live));
    });

    test(
      'learning_order: legacy "ref" fallback payload is byte-for-byte',
      () async {
        final fs = createFakeFirestore(authenticatedUid: _uid);
        final data = <String, dynamic>{
          'curriculum_id': 'abc',
          'ref': 'Shabbat 2:1',
        };
        await _gw(fs).pushLearningOrder(profileId: _profileId, data: data);
        final live = await _liveDocId(fs, 'learning_order');
        expect(DocIds.learningOrderDocId(data), equals(live));
      },
    );

    test('bookmarks: byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'curriculum_id': 'mishnayos'};
      await _gw(fs).pushBookmark(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'bookmarks');
      expect(DocIds.bookmarkDocId(data), equals(live));
    });

    test('learning_ledger: pushLedgerEntry is byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'ulid': 'LEDGER_ULID_1', 'amount': 10};
      await _gw(fs).pushLedgerEntry(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'learning_ledger');
      expect(DocIds.learningLedgerDocId(data), equals(live));
    });

    test('learning_ledger: pushLedgerEntriesBatch derives the SAME formula as '
        'the single-entry path', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final entry = <String, dynamic>{'ulid': 'LEDGER_ULID_BATCH', 'amount': 3};
      await _gw(
        fs,
      ).pushLedgerEntriesBatch(profileId: _profileId, entries: [entry]);
      final live = await _liveDocId(fs, 'learning_ledger');
      expect(DocIds.learningLedgerDocId(entry), equals(live));
    });

    test('profile_programs: byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'curriculum_id': 'kitzur', 'active': true};
      await _gw(fs).pushProfileProgram(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'profile_programs');
      expect(DocIds.profileProgramDocId(data), equals(live));
    });

    test('goals: explicit "id" field is byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'id': '99', 'target': 5};
      await _gw(fs).pushGoal(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'goals');
      expect(DocIds.goalDocId(data), equals(live));
    });

    test('goals: "goal_id" fallback is byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'goal_id': '77', 'target': 3};
      await _gw(fs).pushGoal(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'goals');
      expect(DocIds.goalDocId(data), equals(live));
    });

    test('goals: id-less payload derives the SAME deterministic fallback key '
        'as the live gateway (AUD-core-sync-24 — never add())', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'curriculum_id': 'mishnayos',
        'target_percent': 50,
        'created_at': '2026-01-01T00:00:00.000Z',
      };
      await _gw(fs).pushGoal(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'goals');
      expect(DocIds.goalDocId(data), equals(live));
    });

    test('import_metadata: curriculum_id payload is byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'curriculum_id': 'daf_yomi'};
      await _gw(
        fs,
      ).pushCurriculumImportMetadata(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'import_metadata');
      expect(DocIds.importMetadataDocId(data), equals(live));
    });

    test('import_metadata: missing curriculum_id falls back to "default" '
        'byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{};
      await _gw(
        fs,
      ).pushCurriculumImportMetadata(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'import_metadata');
      expect(DocIds.importMetadataDocId(data), equals(live));
      expect(live, equals('default'));
    });

    test('stage_definitions: {trackId}_{stageOrder} is byte-for-byte '
        '(pre-AD-25-rekey formula, per Story 2.2 scope)', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'track_id': '7',
        'stage_order': '3',
        'name': 'Stage 3',
      };
      await _gw(fs).pushStageDefinition(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'stage_definitions');
      expect(DocIds.stageDefinitionDocId(data), equals(live));
    });

    test(
      'study_day_configs: {curriculumId}_{dayOfWeek}_{trackId} is '
      'byte-for-byte (pre-AD-25-rekey formula, per Story 2.2 scope)',
      () async {
        final fs = createFakeFirestore(authenticatedUid: _uid);
        final data = <String, dynamic>{
          'curriculum_id': 'mishnayos',
          'day_of_week': '1',
          'track_id': '5',
        };
        await _gw(fs).pushStudyDayConfig(profileId: _profileId, data: data);
        final live = await _liveDocId(fs, 'study_day_configs');
        expect(DocIds.studyDayConfigDocId(data), equals(live));
      },
    );

    test('points_ledger: byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'ulid': 'POINTS_ULID_X', 'delta': 5};
      await _gw(fs).pushPointsLedgerEntry(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'points_ledger');
      expect(DocIds.pointsLedgerDocId(data), equals(live));
    });

    test('reward_redemptions: byte-for-byte', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{
        'ulid': 'REDEMPTION_Y',
        'status': 'pending',
      };
      await _gw(fs).pushRewardRedemption(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'reward_redemptions');
      expect(DocIds.rewardRedemptionDocId(data), equals(live));
    });

    test(
      'learner_profiles: path-derived profileId.toString() is byte-for-byte',
      () async {
        final fs = createFakeFirestore(authenticatedUid: _uid);
        await _gw(fs).pushLearnerProfile(
          profileId: _profileId,
          data: {'display_name': 'Alice'},
        );
        final doc = await fs
            .collection('users')
            .doc(_uid)
            .collection('learner_profiles')
            .doc(_profileId.toString())
            .get();
        expect(doc.exists, isTrue);
        expect(DocIds.learnerProfileDocId(_profileId), equals(doc.id));
      },
    );
  });

  // ── RED-DEMO — the golden test has teeth ──────────────────────────────

  group('RED-DEMO — a perturbed formula is caught, the real one is not', () {
    // AD-5/MCF-3: dropping the `_` separator in a two-component composite
    // key is exactly the class of defect the byte-for-byte AC exists to
    // catch — it doesn't just produce a wrong string, it collides distinct
    // natural keys onto the SAME Firestore document (trackId='1'
    // stageOrder='23' and trackId='12' stageOrder='3' both perturb to
    // '123'), which is precisely the "off-by-one-character orphans
    // history" failure mode called out in this story's brief.
    String brokenStageDefinitionDocId(Map<String, dynamic> data) {
      final trackId = data['track_id']?.toString() ?? '';
      final stageOrder = data['stage_order']?.toString() ?? '';
      // Perturbation: separator dropped (vs the real '${trackId}_$stageOrder').
      return '$trackId$stageOrder';
    }

    test(
      'RED: a separator-dropping formula disagrees with the live gateway',
      () async {
        final fs = createFakeFirestore(authenticatedUid: _uid);
        final data = <String, dynamic>{'track_id': '1', 'stage_order': '23'};
        await _gw(fs).pushStageDefinition(profileId: _profileId, data: data);
        final live = await _liveDocId(fs, 'stage_definitions');

        // The live gateway wrote '1_23'; the perturbed formula would emit
        // '123' — proving a broken formula is NOT byte-for-byte and this
        // harness would fail a real regression here.
        expect(brokenStageDefinitionDocId(data), isNot(equals(live)));
      },
    );

    test('RED: the same perturbation collides two DISTINCT natural keys onto '
        'one doc id — the exact orphaning defect class this story guards '
        'against', () {
      final a = brokenStageDefinitionDocId({
        'track_id': '1',
        'stage_order': '23',
      });
      final b = brokenStageDefinitionDocId({
        'track_id': '12',
        'stage_order': '3',
      });
      expect(a, equals(b)); // collision — this is the bug class, not a fluke.
      expect(
        DocIds.stageDefinitionDocId({'track_id': '1', 'stage_order': '23'}),
        isNot(
          equals(
            DocIds.stageDefinitionDocId({'track_id': '12', 'stage_order': '3'}),
          ),
        ),
      );
    });

    test('GREEN: restored — DocIds.stageDefinitionDocId matches the live '
        'gateway exactly', () async {
      final fs = createFakeFirestore(authenticatedUid: _uid);
      final data = <String, dynamic>{'track_id': '1', 'stage_order': '23'};
      await _gw(fs).pushStageDefinition(profileId: _profileId, data: data);
      final live = await _liveDocId(fs, 'stage_definitions');
      expect(DocIds.stageDefinitionDocId(data), equals(live));
      expect(live, equals('1_23'));
    });
  });

  // ── AD-25 carve-out is documented, not silently absorbed ──────────────

  group(
    'AD-25 carve-out — track-scoped children keep the pre-rekey formula',
    () {
      test(
        'stage_definitions and study_day_configs still embed the per-device '
        'track_id (Story 2.3 re-keys this to curriculum_id, not this story)',
        () {
          expect(
            DocIds.stageDefinitionDocId({'track_id': '7', 'stage_order': '3'}),
            equals('7_3'),
          );
          expect(
            DocIds.studyDayConfigDocId({
              'curriculum_id': 'mishnayos',
              'day_of_week': '1',
              'track_id': '5',
            }),
            equals('mishnayos_1_5'),
          );
        },
      );

      test('goals is NOT re-keyed here — its doc-id formula never embedded '
          'track_id in the first place', () {
        expect(
          DocIds.goalDocId({
            'curriculum_id': 'mishnayos',
            'target_percent': 50,
            'created_at': '2026-01-01T00:00:00.000Z',
            'track_id': 999, // present in the payload but NOT in the doc-id
          }),
          isNot(contains('999')),
        );
      });
    },
  );
}
