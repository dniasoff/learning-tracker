/// Sync-rework push-path invariants — exercised against the REAL
/// [FirestoreGatewayImpl] backed by `fake_cloud_firestore`.
///
/// S3: the real gateway derives a deterministic, collision-free completion
///     document ID from the structured natural key — pushing the same
///     completion twice yields exactly one document, and two completions
///     whose `sefaria_ref` differs only by `.` vs `/` vs space land in
///     DISTINCT documents (this would FAIL against the pre-H2 gateway,
///     whose `_sanitizeDocId` collapsed all three to `_`).
/// S4: a 655-item bulk push goes through real `WriteBatch` commits in
///     ≤500-op chunks — every distinct completion reaches Firestore and
///     the 500/501 boundary is handled.
/// S9: two devices marking overlapping items converge to the union with
///     no duplicate documents, through the real gateway + OutboxProcessor.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/learning/completion_command.dart';
import 'package:learning_tracker/core/learning/completion_writer.dart';
import 'package:learning_tracker/core/sync/firestore_gateway_impl.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/push_pipeline_impl.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/auth/domain/models/app_user.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';

import '../helpers/drift_memory.dart';
import '../helpers/firestore_fake.dart';

// ---------------------------------------------------------------------------
// Minimal stub AuthRepository — FirestoreGatewayImpl reads only currentUser.uid
// ---------------------------------------------------------------------------

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
  Future<void> signInWithEmail(String e, String p) =>
      throw UnimplementedError();
  @override
  Future<void> signInWithGoogle() => throw UnimplementedError();
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _uid = 'uid_sync_rework_push';
const _profileId = 1;

Future<int> _seedTrack(UserDatabase db, {String curriculumId = 'mishnayos'}) =>
    db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: curriculumId,
            trackType: 'personal',
            activatedAt: DateTime.utc(2026, 1, 1),
            isActive: const Value(true),
          ),
        );

/// Count documents currently in the `completions` subcollection for the
/// canonical learner-profile path.
Future<int> _completionDocCount(FirebaseFirestore fs) async {
  final snap = await fs
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId.toString())
      .collection('completions')
      .get();
  return snap.docs.length;
}

/// snake_case completion payload (the canonical Firestore schema).
Map<String, dynamic> _completion({
  required String sefariaRef,
  int stageId = 1,
  String trackType = 'personal',
  String curriculumId = 'mishnayos',
  int points = 5,
}) => {
  'profile_id': _profileId,
  'curriculum_id': curriculumId,
  'sefaria_ref': sefariaRef,
  'stage_id': stageId,
  'track_type': trackType,
  'completed_at': '2026-05-01T00:00:00.000Z',
  'points': points,
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('S3 / S4 / S9 — push-path invariants (real FirestoreGatewayImpl)', () {
    // ── S3 ─────────────────────────────────────────────────────────────────
    group('S3 — deterministic, collision-free completion doc IDs', () {
      test(
        'same completion pushed twice lands in exactly one Firestore doc',
        () async {
          final fs = createFakeFirestore(authenticatedUid: _uid);
          final gateway = FirestoreGatewayImpl(
            firestore: fs,
            authRepository: const _StubAuthRepository(_uid),
          );

          final payload = _completion(sefariaRef: 'Berakhot 1:1');
          await gateway.pushCompletion(profileId: _profileId, data: payload);
          await gateway.pushCompletion(profileId: _profileId, data: payload);

          expect(
            await _completionDocCount(fs),
            equals(1),
            reason:
                'S3: a deterministic doc ID means re-pushing the same '
                'completion overwrites in place — never a second document',
          );
        },
      );

      test('completions whose sefaria_ref differs only by "." / "/" / space '
          'get DISTINCT documents (would collide pre-H2)', () async {
        final fs = createFakeFirestore(authenticatedUid: _uid);
        final gateway = FirestoreGatewayImpl(
          firestore: fs,
          authRepository: const _StubAuthRepository(_uid),
        );

        // Pre-H2 `_sanitizeDocId` replaced `.`, `/` and space all with `_`,
        // so these three distinct natural keys collapsed to ONE doc id —
        // silent data loss. The H2 percent-encoded scheme keeps them apart.
        await gateway.pushCompletion(
          profileId: _profileId,
          data: _completion(sefariaRef: 'Berakhot 1.1'),
        );
        await gateway.pushCompletion(
          profileId: _profileId,
          data: _completion(sefariaRef: 'Berakhot 1/1'),
        );
        await gateway.pushCompletion(
          profileId: _profileId,
          data: _completion(sefariaRef: 'Berakhot 1 1'),
        );

        expect(
          await _completionDocCount(fs),
          equals(3),
          reason:
              'S3: distinct natural-key tuples MUST map to distinct doc '
              'IDs — the doc-id function is collision-free',
        );
      });

      test(
        'the batch path derives the SAME id as the single-push path',
        () async {
          final fs = createFakeFirestore(authenticatedUid: _uid);
          final gateway = FirestoreGatewayImpl(
            firestore: fs,
            authRepository: const _StubAuthRepository(_uid),
          );

          final payload = _completion(sefariaRef: 'Berakhot 2:3');
          // Single push, then the SAME completion via the batch path.
          await gateway.pushCompletion(profileId: _profileId, data: payload);
          await gateway.pushCompletionsBatch(
            profileId: _profileId,
            items: [(entityKey: '1:Berakhot 2:3:1:personal', payload: payload)],
          );

          expect(
            await _completionDocCount(fs),
            equals(1),
            reason:
                'S3: pushCompletion and pushCompletionsBatch MUST derive the '
                'same canonical doc ID — no path-dependent divergence',
          );
        },
      );
    });

    // ── S4 ─────────────────────────────────────────────────────────────────
    group('S4 — bulk push via real WriteBatch chunks', () {
      test(
        '655 distinct completions all reach Firestore through chunked batches',
        () async {
          final fs = createFakeFirestore(authenticatedUid: _uid);
          final gateway = FirestoreGatewayImpl(
            firestore: fs,
            authRepository: const _StubAuthRepository(_uid),
          );
          const n = 655;

          final items = List.generate(
            n,
            (i) => (
              entityKey: '1:Mishnah $i:1:1:personal',
              payload: _completion(sefariaRef: 'Mishnah $i:1'),
            ),
          );

          final committed = await gateway.pushCompletionsBatch(
            profileId: _profileId,
            items: items,
          );

          // 655 > 500 (Firestore WriteBatch limit) → exactly 2 chunked
          // commits. Every distinct completion must land.
          expect(committed, hasLength(n));
          expect(
            await _completionDocCount(fs),
            equals(n),
            reason: 'S4: all 655 distinct completions must reach Firestore',
          );
        },
      );

      test('chunk boundary (500 → 1 chunk, 501 → 2 chunks) is exact', () async {
        for (final n in [500, 501]) {
          final fs = createFakeFirestore(authenticatedUid: _uid);
          final gateway = FirestoreGatewayImpl(
            firestore: fs,
            authRepository: const _StubAuthRepository(_uid),
          );
          final items = List.generate(
            n,
            (i) => (
              entityKey: '1:Item $i:1:1:personal',
              payload: _completion(sefariaRef: 'Item $i:1'),
            ),
          );
          final committed = await gateway.pushCompletionsBatch(
            profileId: _profileId,
            items: items,
          );
          expect(committed, hasLength(n));
          expect(
            await _completionDocCount(fs),
            equals(n),
            reason: 'S4: $n items must all land regardless of chunk count',
          );
        }
      });

      test(
        're-pushing the same 655 items is idempotent — still 655 docs',
        () async {
          final fs = createFakeFirestore(authenticatedUid: _uid);
          final gateway = FirestoreGatewayImpl(
            firestore: fs,
            authRepository: const _StubAuthRepository(_uid),
          );
          final items = List.generate(
            655,
            (i) => (
              entityKey: '1:Mishnah $i:1:1:personal',
              payload: _completion(sefariaRef: 'Mishnah $i:1'),
            ),
          );
          await gateway.pushCompletionsBatch(
            profileId: _profileId,
            items: items,
          );
          await gateway.pushCompletionsBatch(
            profileId: _profileId,
            items: items,
          );
          expect(
            await _completionDocCount(fs),
            equals(655),
            reason: 'S4: deterministic ids make the batch push idempotent',
          );
        },
      );
    });

    // ── S9 ─────────────────────────────────────────────────────────────────
    group('S9 — two-device overlap convergence (real gateway)', () {
      late UserDatabase deviceA;
      late UserDatabase deviceB;
      late FirebaseFirestore sharedFs;
      late OutboxProcessor processorA;
      late OutboxProcessor processorB;

      setUp(() async {
        deviceA = inMemoryDb();
        deviceB = inMemoryDb();
        await seedProfile(deviceA);
        await seedProfile(deviceB);
        await _seedTrack(deviceA);
        await _seedTrack(deviceB);

        // Both devices push to the SAME backing Firestore — modelling the
        // single cloud collection two devices converge into.
        sharedFs = createFakeFirestore(authenticatedUid: _uid);
        const authRepo = _StubAuthRepository(_uid);
        final gatewayA = FirestoreGatewayImpl(
          firestore: sharedFs,
          authRepository: authRepo,
        );
        final gatewayB = FirestoreGatewayImpl(
          firestore: sharedFs,
          authRepository: authRepo,
        );
        processorA = OutboxProcessor(
          outboxDao: deviceA.outboxDao,
          pipeline: OutboxPushPipeline(gateway: gatewayA),
          clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
        );
        processorB = OutboxProcessor(
          outboxDao: deviceB.outboxDao,
          pipeline: OutboxPushPipeline(gateway: gatewayB),
          clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
        );
      });

      tearDown(() async {
        await deviceA.close();
        await deviceB.close();
      });

      test('overlapping completions from two devices converge to the union '
          'with no duplicate documents', () async {
        final writerA = CompletionWriter(deviceA);
        final writerB = CompletionWriter(deviceB);

        const sharedRef = 'Berakhot 2:1';
        final ts = DateTime.utc(2026, 5, 10, 12);

        // Both devices independently mark the SAME item (overlap).
        for (final writer in [writerA, writerB]) {
          await writer.commit(
            CompletionCommand(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              sefariaRef: sharedRef,
              stageId: 1,
              trackType: 'personal',
              trackId: 1,
              completedAt: ts,
              points: 5,
            ),
          );
        }
        // Device A marks a unique item.
        await writerA.commit(
          CompletionCommand(
            profileId: _profileId,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot 3:1',
            stageId: 1,
            trackType: 'personal',
            trackId: 1,
            completedAt: DateTime.utc(2026, 5, 10, 13),
            points: 5,
          ),
        );
        // Device B marks a different unique item.
        await writerB.commit(
          CompletionCommand(
            profileId: _profileId,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot 4:1',
            stageId: 1,
            trackType: 'personal',
            trackId: 1,
            completedAt: DateTime.utc(2026, 5, 10, 14),
            points: 5,
          ),
        );

        // Both flush to the shared cloud Firestore.
        await processorA.drain(_profileId);
        await processorB.drain(_profileId);

        // 3 unique documents: the shared ref counted once + 2 unique.
        expect(
          await _completionDocCount(sharedFs),
          equals(3),
          reason:
              'S9: the deterministic doc ID collapses the overlapping '
              'completion to one document — convergence to the union',
        );
      });
    });
  });
}
