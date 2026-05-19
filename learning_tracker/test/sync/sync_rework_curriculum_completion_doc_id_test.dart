/// Per-curriculum completion doc-ID and tombstone-propagation tests.
///
/// Finding 1 (sync half): two completions for the same (profileId, sefariaRef,
///   stageId, trackType) but DIFFERENT curriculumIds must land in DISTINCT
///   Firestore documents. This test suite verifies that `_completionDocId`
///   includes `curriculum_id` as its fifth component.
///
/// Finding 2: after [BulkPriorCompletionService.expungePriorCompletions],
///   the tombstoned rows must have `purgedAt` set AND an outbox row must be
///   enqueued so the tombstone propagates to Firestore.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/learning/completion_command.dart';
import 'package:learning_tracker/core/learning/completion_writer.dart';
import 'package:learning_tracker/core/sync/firestore_gateway_impl.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/push_pipeline_impl.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/auth/domain/models/app_user.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/drift_memory.dart';
import '../helpers/firestore_fake.dart';

// ---------------------------------------------------------------------------
// Stub AuthRepository
// ---------------------------------------------------------------------------

const _uid = 'uid_curriculum_docid_test';
const _profileId = 1;

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
// Mock repositories for BulkPriorCompletionService
// ---------------------------------------------------------------------------

class _MockContentRepository extends Mock implements ContentRepository {}

class _MockCompletionRepository extends Mock implements CompletionRepository {}

class _MockBookmarkRepository extends Mock implements BookmarkRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Count documents in the completions subcollection.
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

/// Returns all doc IDs in the completions subcollection.
Future<List<String>> _completionDocIds(FirebaseFirestore fs) async {
  final snap = await fs
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId.toString())
      .collection('completions')
      .get();
  return snap.docs.map((d) => d.id).toList();
}

/// snake_case completion payload.
Map<String, dynamic> _payload({
  required String sefariaRef,
  required String curriculumId,
  int stageId = 1,
  String trackType = 'personal',
}) => {
  'profile_id': _profileId,
  'curriculum_id': curriculumId,
  'sefaria_ref': sefariaRef,
  'stage_id': stageId,
  'track_type': trackType,
  'completed_at': '2026-05-01T00:00:00.000Z',
  'points': 5,
};

Future<int> _seedTrack(
  UserDatabase db, {
  String curriculumId = 'mishnayos',
}) => db.into(db.curriculumTracks).insert(
  CurriculumTracksCompanion.insert(
    profileId: _profileId,
    curriculumId: curriculumId,
    trackType: 'personal',
    activatedAt: DateTime.utc(2026, 1, 1),
    isActive: const Value(true),
  ),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Finding 1 (sync half): per-curriculum doc IDs ───────────────────────
  group(
    'Finding 1 — two curricula for the same section get distinct Firestore docs',
    () {
      test(
        'pushCompletion: same (ref, stage, trackType) but different '
        'curriculumIds → two distinct documents',
        () async {
          final fs = createFakeFirestore(authenticatedUid: _uid);
          final gateway = FirestoreGatewayImpl(
            firestore: fs,
            authRepository: const _StubAuthRepository(_uid),
          );

          await gateway.pushCompletion(
            profileId: _profileId,
            data: _payload(
              sefariaRef: 'Berakhot 1:1',
              curriculumId: 'mishnayos',
            ),
          );
          await gateway.pushCompletion(
            profileId: _profileId,
            data: _payload(
              sefariaRef: 'Berakhot 1:1',
              curriculumId: 'daf_yomi',
            ),
          );

          expect(
            await _completionDocCount(fs),
            equals(2),
            reason:
                'Finding 1: two completions with different curriculumIds for '
                'the same section MUST produce two distinct Firestore docs',
          );

          final ids = await _completionDocIds(fs);
          expect(
            ids[0],
            isNot(equals(ids[1])),
            reason: 'The two doc IDs must differ',
          );
        },
      );

      test(
        'pushCompletionsBatch: same (ref, stage, trackType) but different '
        'curriculumIds in one batch → two distinct documents',
        () async {
          final fs = createFakeFirestore(authenticatedUid: _uid);
          final gateway = FirestoreGatewayImpl(
            firestore: fs,
            authRepository: const _StubAuthRepository(_uid),
          );

          await gateway.pushCompletionsBatch(
            profileId: _profileId,
            items: [
              (
                entityKey:
                    '$_profileId:Berakhot 1:1:1:personal:mishnayos',
                payload: _payload(
                  sefariaRef: 'Berakhot 1:1',
                  curriculumId: 'mishnayos',
                ),
              ),
              (
                entityKey:
                    '$_profileId:Berakhot 1:1:1:personal:daf_yomi',
                payload: _payload(
                  sefariaRef: 'Berakhot 1:1',
                  curriculumId: 'daf_yomi',
                ),
              ),
            ],
          );

          expect(
            await _completionDocCount(fs),
            equals(2),
            reason:
                'Finding 1: batch path must also produce distinct docs per curriculum',
          );
        },
      );

      test(
        'same completion pushed twice (same curriculumId) is idempotent — '
        'still exactly one document',
        () async {
          final fs = createFakeFirestore(authenticatedUid: _uid);
          final gateway = FirestoreGatewayImpl(
            firestore: fs,
            authRepository: const _StubAuthRepository(_uid),
          );

          final payload = _payload(
            sefariaRef: 'Berakhot 2:1',
            curriculumId: 'mishnayos',
          );
          await gateway.pushCompletion(profileId: _profileId, data: payload);
          await gateway.pushCompletion(profileId: _profileId, data: payload);

          expect(
            await _completionDocCount(fs),
            equals(1),
            reason:
                'Idempotency must hold: re-pushing the same completion with '
                'the same curriculumId produces exactly one document',
          );
        },
      );

      test(
        'single-push and batch-push paths derive the same doc ID for the '
        'same completion (consistency across push paths)',
        () async {
          final fs = createFakeFirestore(authenticatedUid: _uid);
          final gateway = FirestoreGatewayImpl(
            firestore: fs,
            authRepository: const _StubAuthRepository(_uid),
          );

          final payload = _payload(
            sefariaRef: 'Berakhot 3:1',
            curriculumId: 'mishnayos',
          );
          await gateway.pushCompletion(profileId: _profileId, data: payload);
          await gateway.pushCompletionsBatch(
            profileId: _profileId,
            items: [
              (
                entityKey:
                    '$_profileId:Berakhot 3:1:1:personal:mishnayos',
                payload: payload,
              ),
            ],
          );

          // The two paths must derive the same doc ID → still 1 document.
          expect(
            await _completionDocCount(fs),
            equals(1),
            reason:
                'pushCompletion and pushCompletionsBatch MUST derive the '
                'same doc ID for the same payload',
          );
        },
      );

      test(
        'via full outbox drain: two curricula for same ref reach two '
        'distinct Firestore documents',
        () async {
          final db = inMemoryDb();
          await seedProfile(db);
          await _seedTrack(db, curriculumId: 'mishnayos');
          await _seedTrack(db, curriculumId: 'daf_yomi');

          final fs = createFakeFirestore(authenticatedUid: _uid);
          const authRepo = _StubAuthRepository(_uid);
          final gateway = FirestoreGatewayImpl(
            firestore: fs,
            authRepository: authRepo,
          );
          final processor = OutboxProcessor(
            outboxDao: db.outboxDao,
            pipeline: OutboxPushPipeline(gateway: gateway),
            clock: FakeLocalDayClock(DateTime.utc(2026, 5, 19)),
          );

          final writer = CompletionWriter(db);
          final ts = DateTime.utc(2026, 5, 1);

          // Write the SAME sefariaRef + stageId + trackType but two different
          // curricula — these must be distinct completions end-to-end.
          await writer.commit(
            CompletionCommand(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              sefariaRef: 'Berakhot 4:1',
              stageId: 1,
              trackType: 'personal',
              trackId: 1,
              completedAt: ts,
              points: 5,
            ),
          );
          await writer.commit(
            CompletionCommand(
              profileId: _profileId,
              curriculumId: 'daf_yomi',
              sefariaRef: 'Berakhot 4:1',
              stageId: 1,
              trackType: 'personal',
              trackId: 2,
              completedAt: ts,
              points: 5,
            ),
          );

          await processor.drain(_profileId);

          expect(
            await _completionDocCount(fs),
            equals(2),
            reason:
                'End-to-end: two curricula for the same ref must produce '
                'two distinct Firestore documents after outbox drain',
          );

          await db.close();
        },
      );
    },
  );

  // ── Finding 2: tombstone propagation via outbox ─────────────────────────
  group(
    'Finding 2 — expungePriorCompletions enqueues outbox rows for tombstones',
    () {
      late UserDatabase db;
      late _MockContentRepository contentRepo;
      late _MockCompletionRepository completionRepo;
      late _MockBookmarkRepository bookmarkRepo;

      setUp(() async {
        db = inMemoryDb();
        await seedProfile(db);
        await _seedTrack(db);

        contentRepo = _MockContentRepository();
        completionRepo = _MockCompletionRepository();
        bookmarkRepo = _MockBookmarkRepository();
      });

      tearDown(() async {
        await db.close();
      });

      test(
        'purgedAt is set on tombstoned rows after expungePriorCompletions',
        () async {
          // Seed two completion_events rows with the sentinel timestamp,
          // mimicking a bulk-mark-prior run (one per stage).
          final sentinelTs = kBulkPriorSentinelDate;
          await db.completionEventDao.appendEvent(
            CompletionEventsCompanion.insert(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              sefariaRef: 'Berakhot 5:1',
              stageId: 1,
              trackType: 'personal',
              eventTimestamp: sentinelTs,
            ),
          );
          await db.completionEventDao.appendEvent(
            CompletionEventsCompanion.insert(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              sefariaRef: 'Berakhot 5:1',
              stageId: 2,
              trackType: 'personal',
              eventTimestamp: sentinelTs,
            ),
          );

          final service = BulkPriorCompletionService(
            contentRepository: contentRepo,
            completionRepository: completionRepo,
            bookmarkRepository: bookmarkRepo,
            database: db,
            outboxDao: db.outboxDao,
          );

          await service.expungePriorCompletions(
            profileId: _profileId,
            sefariaRef: 'Berakhot 5:1',
            curriculumId: CurriculumId.mishnayos,
          );

          // All sentinel rows for this item+curriculum must now be tombstoned.
          final rows = await (db.select(db.completionEvents)
                ..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.sefariaRef.equals('Berakhot 5:1'),
                ))
              .get();

          expect(rows, hasLength(2));
          for (final row in rows) {
            expect(
              row.purgedAt,
              isNotNull,
              reason: 'Every prior-mark row must be tombstoned (purgedAt set)',
            );
          }
        },
      );

      test(
        'expungePriorCompletions enqueues one outbox row per tombstoned '
        'completion_event row',
        () async {
          final sentinelTs = kBulkPriorSentinelDate;

          // Seed three completion_events for different stageIds.
          for (var stage = 1; stage <= 3; stage++) {
            await db.completionEventDao.appendEvent(
              CompletionEventsCompanion.insert(
                profileId: _profileId,
                curriculumId: 'mishnayos',
                sefariaRef: 'Berakhot 6:1',
                stageId: stage,
                trackType: 'personal',
                eventTimestamp: sentinelTs,
              ),
            );
          }

          final service = BulkPriorCompletionService(
            contentRepository: contentRepo,
            completionRepository: completionRepo,
            bookmarkRepository: bookmarkRepo,
            database: db,
            outboxDao: db.outboxDao,
          );

          await service.expungePriorCompletions(
            profileId: _profileId,
            sefariaRef: 'Berakhot 6:1',
            curriculumId: CurriculumId.mishnayos,
          );

          // One outbox row per tombstoned event.
          final outboxRows = await db.outboxDao.getPendingByKind(
            OutboxEntityKind.completion,
            _profileId,
            limit: 100,
          );
          expect(
            outboxRows,
            hasLength(3),
            reason:
                'Finding 2: one outbox row must be enqueued per tombstoned '
                'completion_events row',
          );

          // Every outbox row must carry purged_at in its payload.
          for (final row in outboxRows) {
            final payload = jsonDecode(row.payload) as Map<String, dynamic>;
            expect(
              payload.containsKey('purged_at'),
              isTrue,
              reason: 'Tombstone outbox payload must include purged_at',
            );
            expect(payload['purged_at'], isNotNull);
            expect(payload['sefaria_ref'], equals('Berakhot 6:1'));
            expect(payload['curriculum_id'], equals('mishnayos'));
          }
        },
      );

      test(
        'outbox row entityKey for tombstones includes curriculumId '
        '(per-curriculum key format)',
        () async {
          final sentinelTs = kBulkPriorSentinelDate;
          await db.completionEventDao.appendEvent(
            CompletionEventsCompanion.insert(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              sefariaRef: 'Berakhot 7:1',
              stageId: 1,
              trackType: 'personal',
              eventTimestamp: sentinelTs,
            ),
          );

          final service = BulkPriorCompletionService(
            contentRepository: contentRepo,
            completionRepository: completionRepo,
            bookmarkRepository: bookmarkRepo,
            database: db,
            outboxDao: db.outboxDao,
          );

          await service.expungePriorCompletions(
            profileId: _profileId,
            sefariaRef: 'Berakhot 7:1',
            curriculumId: CurriculumId.mishnayos,
          );

          final outboxRows = await db.outboxDao.getPendingByKind(
            OutboxEntityKind.completion,
            _profileId,
            limit: 10,
          );
          expect(outboxRows, hasLength(1));

          // The entityKey must end with the curriculumId component.
          final key = outboxRows.first.entityKey;
          expect(
            key,
            contains('mishnayos'),
            reason:
                'Tombstone outbox entityKey must include curriculumId so the '
                'gateway derives the correct per-curriculum Firestore doc ID',
          );
          // Format: profileId:sefariaRef:stageId:trackType:curriculumId
          expect(
            key,
            equals('$_profileId:Berakhot 7:1:1:personal:mishnayos'),
          );
        },
      );

      test(
        'when outboxDao is null, expungePriorCompletions still tombstones '
        'rows locally but skips outbox enqueue (graceful no-op)',
        () async {
          final sentinelTs = kBulkPriorSentinelDate;
          await db.completionEventDao.appendEvent(
            CompletionEventsCompanion.insert(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              sefariaRef: 'Berakhot 8:1',
              stageId: 1,
              trackType: 'personal',
              eventTimestamp: sentinelTs,
            ),
          );

          // No outboxDao injected — local-only tombstone.
          final service = BulkPriorCompletionService(
            contentRepository: contentRepo,
            completionRepository: completionRepo,
            bookmarkRepository: bookmarkRepo,
            database: db,
          );

          // Must not throw.
          await service.expungePriorCompletions(
            profileId: _profileId,
            sefariaRef: 'Berakhot 8:1',
            curriculumId: CurriculumId.mishnayos,
          );

          // Row is tombstoned locally.
          final rows = await (db.select(db.completionEvents)
                ..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.sefariaRef.equals('Berakhot 8:1'),
                ))
              .get();
          expect(rows.first.purgedAt, isNotNull);

          // No outbox row was enqueued.
          final outboxRows = await db.outboxDao.getPendingByKind(
            OutboxEntityKind.completion,
            _profileId,
            limit: 10,
          );
          expect(outboxRows, isEmpty);
        },
      );
    },
  );
}
