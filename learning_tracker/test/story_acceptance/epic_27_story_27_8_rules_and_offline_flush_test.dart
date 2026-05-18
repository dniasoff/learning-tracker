/// Story acceptance tests for Story 27.8 (DNI-384) — integration coverage
/// of Firestore security rules and the offline-completion flush path.
///
/// Two groups, both running against the in-process `fake_cloud_firestore`
/// helper landed in DNI-377:
///
///   Group A — Firestore rules (NFR13, FR4):
///     1. `delete()` is rejected by every event/snapshot collection rule
///        (strict-rules mode against the real `firestore.rules`).
///     2. Field-validator clauses for completion_events (points range,
///        future `completed_at`) and the snapshot field whitelists are
///        present in the rules file. These cannot be exercised dynamically
///        because `fake_firebase_security_rules` does not evaluate
///        `request.resource.data` clauses (documented limitation in
///        `test/helpers/firestore_fake.dart`). Structural assertions prove
///        the rules are authored correctly; the production emulator suite
///        under `test/firestore-rules/` enforces them dynamically.
///
///   Group B — Offline completion flush (FR24):
///     1. With the gateway "online" flag cleared, 50 successive
///        `CompletionWriter.commit()` calls land 50 rows in `outbox` and
///        zero documents on the gateway.
///     2. Flipping the flag and invoking `OutboxProcessor.drain()` flushes
///        all 50 rows — the outbox empties and the fake Firestore holds
///        50 `completion_events` documents.
@Tags(['epic_27'])
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/learning/completion_command.dart';
import 'package:learning_tracker/core/learning/completion_writer.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/outbox/push_pipeline.dart';
import 'package:learning_tracker/core/sync/push_pipeline_impl.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';
import '../helpers/firestore_fake.dart';

void main() {
  // ── Group A — Firestore rules ───────────────────────────────────────────

  group(
    'Story 27.8 — Firestore rules enforce per-collection semantics',
    tags: ['story_27_8_rules'],
    () {
      // Every collection's rule terminates with `allow delete: if false;`
      // (events use the combined `allow update, delete: if false`). That
      // is the one semantic the fake CAN exercise on every collection,
      // because `delete()` maps to `Method.delete` which the parser
      // recognises without needing `request.resource.data`.
      const denyCollections = [
        'accounts',
        'learner_profiles',
        'completion_events',
        'streak_events',
        'learning_ledger',
        'track_configs',
        'bookmarks',
        'settings',
      ];

      for (final coll in denyCollections) {
        test('delete on $coll/{docId} is rejected by the rules', () async {
          final fake = createFakeFirestore(
            authenticatedUid: 'uid_a',
            strictRules: true,
          );
          await expectLater(
            () => fake.collection(coll).doc('uid_a_1').delete(),
            throwsA(isA<Exception>()),
            reason: '`allow delete: if false;` must trip for $coll',
          );
        });
      }

      // Static rule-file assertions — these pin the field validators that
      // the dynamic fake cannot evaluate.
      group('rules file pins per-AC field validators', () {
        late String rules;
        setUpAll(() {
          rules = _readProjectRules();
        });

        test('completion_events enforces 0 <= points <= 100', () {
          final block = _extractRuleBlock(rules, 'completion_events/{docId}');
          expect(block, contains('points >= 0'));
          expect(block, contains('points <= 100'));
        });

        test('completion_events enforces completed_at <= request.time', () {
          final block = _extractRuleBlock(rules, 'completion_events/{docId}');
          expect(block, contains('completed_at <= request.time'));
        });

        test('completion_events denies update and delete', () {
          final block = _extractRuleBlock(rules, 'completion_events/{docId}');
          expect(block, contains('allow update: if false'));
          expect(block, contains('allow delete: if false'));
        });

        test('streak_events and learning_ledger deny update and delete', () {
          for (final c in [
            'streak_events/{docId}',
            'learning_ledger/{docId}',
          ]) {
            final block = _extractRuleBlock(rules, c);
            expect(block, contains('allow update: if false'), reason: c);
            expect(block, contains('allow delete: if false'), reason: c);
          }
        });

        test(
          'snapshot collections gate writes through hasOnly() field whitelist',
          () {
            for (final c in [
              'accounts/{docId}',
              'learner_profiles/{docId}',
              'track_configs/{docId}',
              'bookmarks/{docId}',
              'settings/{docId}',
            ]) {
              final block = _extractRuleBlock(rules, c);
              expect(
                block,
                contains('.hasOnly('),
                reason: '$c must restrict writes to a fixed field list',
              );
              expect(
                block,
                contains('allow delete: if false'),
                reason: '$c must deny deletes',
              );
            }
          },
        );

        test(
          'global deny-all wildcard precedes per-collection allow rules',
          () {
            final denyIdx = rules.indexOf('match /{document=**}');
            final firstAllowIdx = rules.indexOf('match /accounts');
            expect(denyIdx, greaterThan(-1));
            expect(firstAllowIdx, greaterThan(-1));
            expect(
              denyIdx,
              lessThan(firstAllowIdx),
              reason:
                  'Default deny rule must appear before any allow rule so '
                  'an undeclared collection inherits the deny default.',
            );
          },
        );
      });
    },
  );

  // ── Group B — Offline completion flush ──────────────────────────────────

  group(
    'Story 27.8 — Offline completions queue then drain to Firestore',
    tags: ['story_27_8_offline'],
    () {
      late UserDatabase db;
      late CompletionWriter writer;
      late _ToggleableFakeGateway gateway;
      late PushPipeline pipeline;
      late OutboxProcessor processor;
      late FakeFirebaseFirestore fakeFs;
      late int trackId;

      setUp(() async {
        db = inMemoryDb();
        await seedProfile(db);
        writer = CompletionWriter(db);
        fakeFs = createFakeFirestore(authenticatedUid: 'uid_offline');
        gateway = _ToggleableFakeGateway(firestore: fakeFs, uid: 'uid_offline');
        pipeline = OutboxPushPipeline(gateway: gateway);
        processor = OutboxProcessor(
          outboxDao: db.outboxDao,
          pipeline: pipeline,
        );
        trackId = await _seedTrack(db);
      });
      tearDown(() => db.close());

      test('offline: 50 commits land 50 outbox rows and zero Firestore docs; '
          'online: drain() flushes all 50', () async {
        const profileId = 1;
        // ── Phase 1: offline. CompletionWriter still commits locally
        // because it never touches the gateway directly; the outbox
        // row is its only sync hook. The processor is the only thing
        // that calls the gateway, and we do not run it here. ──
        gateway.online = false;

        for (var i = 0; i < 50; i++) {
          await writer.commit(
            CompletionCommand(
              profileId: profileId,
              curriculumId: 'mishnah_yomit',
              sefariaRef: 'Mishnah Berakhot $i',
              stageId: 1,
              trackType: 'personal',
              trackId: trackId,
              completedAt: DateTime.utc(
                2026,
                5,
                13,
                8,
              ).add(Duration(seconds: i)),
              points: 5,
            ),
          );
        }

        final queuedRows = await db.select(db.outbox).get();
        expect(
          queuedRows,
          hasLength(50),
          reason:
              'CompletionWriter must enqueue one outbox row per commit '
              'regardless of connectivity',
        );

        final docsWhileOffline = await fakeFs
            .collection('completion_events')
            .get();
        expect(
          docsWhileOffline.docs,
          isEmpty,
          reason: 'no push should reach Firestore while offline',
        );
        expect(
          gateway.pushAttempts,
          isZero,
          reason: 'OutboxProcessor was never invoked while offline',
        );

        // ── Phase 2: reconnect; drain. ──
        gateway.online = true;

        final flushed = await processor.drain(profileId);
        expect(flushed, equals(50));

        final docsAfter = await fakeFs.collection('completion_events').get();
        expect(
          docsAfter.docs,
          hasLength(50),
          reason: 'all 50 queued completions must reach Firestore',
        );

        final remaining = await db.select(db.outbox).get();
        expect(
          remaining,
          isEmpty,
          reason: 'drained rows must be deleted from outbox on success',
        );
      });

      test('drain() does not silently absorb failures — a single broken row '
          'is retained for retry while siblings still flush', () async {
        const profileId = 1;
        gateway.online = true;
        gateway.failOn = {1}; // fail on the second push (0-indexed)

        for (var i = 0; i < 3; i++) {
          await writer.commit(
            CompletionCommand(
              profileId: profileId,
              curriculumId: 'mishnah_yomit',
              sefariaRef: 'Mishnah Shabbat $i',
              stageId: 1,
              trackType: 'personal',
              trackId: trackId,
              completedAt: DateTime.utc(2026, 5, 13, 9, i),
              points: 5,
            ),
          );
        }

        final flushed = await processor.drain(profileId);
        expect(flushed, equals(2), reason: 'two pushes succeed, one fails');

        final remaining = await db.select(db.outbox).get();
        expect(
          remaining,
          hasLength(1),
          reason: 'failed row must remain in outbox for retry',
        );
        expect(remaining.single.attempts, equals(1));
        expect(remaining.single.lastError, isNotNull);
      });
    },
  );
}

// ── Helpers ────────────────────────────────────────────────────────────────

/// Seed a curriculum_tracks row so completion FKs resolve.
Future<int> _seedTrack(UserDatabase db) => db
    .into(db.curriculumTracks)
    .insert(
      CurriculumTracksCompanion.insert(
        profileId: 1,
        curriculumId: 'mishnah_yomit',
        trackType: 'personal',
        activatedAt: DateTime.utc(2026, 5, 1),
        isActive: const Value(true),
      ),
    );

/// Reads the project's `firestore.rules` file from the repo root, hopping
/// up one directory when the test launcher set cwd to `learning_tracker/`.
String _readProjectRules() {
  for (final path in const ['../firestore.rules', 'firestore.rules']) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError(
    'firestore.rules not found from cwd; run tests from learning_tracker/.',
  );
}

/// Extract the body (between `{` and matching `}`) of a `match /<pattern>`
/// rule. Brace counting starts at the first `{` AFTER the match
/// declaration, so path-parameter braces like `{docId}` do not skew it.
String _extractRuleBlock(String rules, String matchPattern) {
  final start = rules.indexOf('match /$matchPattern');
  if (start == -1) {
    throw StateError('rule block not found: $matchPattern');
  }
  var i = start + 'match /$matchPattern'.length;
  while (i < rules.length && rules[i] != '{') {
    i++;
  }
  if (i >= rules.length) return rules.substring(start);
  var depth = 0;
  while (i < rules.length) {
    final ch = rules[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return rules.substring(start, i + 1);
    }
    i++;
  }
  return rules.substring(start);
}

// ── Toggleable fake gateway ───────────────────────────────────────────────

/// `FirestoreGateway` backed by a [FakeFirebaseFirestore] that can be
/// switched offline (`online = false`) to simulate connectivity loss.
///
/// Push attempts count against [pushAttempts]; index-based failure
/// injection through [failOn] lets a single test verify the retry path.
class _ToggleableFakeGateway implements FirestoreGateway {
  _ToggleableFakeGateway({
    required FakeFirebaseFirestore firestore,
    required this.uid,
  }) : _fs = firestore;

  final FakeFirebaseFirestore _fs;
  final String uid;

  bool online = true;
  int pushAttempts = 0;
  Set<int> failOn = const {};

  @override
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final attempt = pushAttempts;
    pushAttempts++;
    if (!online) throw Exception('offline');
    if (failOn.contains(attempt)) {
      throw Exception('injected failure on attempt $attempt');
    }
    final ref = '${data['sefariaRef']}'.replaceAll(' ', '_');
    final docId =
        '${uid}_${profileId}_${ref}_${data['stageId']}_${data['trackType']}';
    await _fs.collection('completion_events').doc(docId).set({
      ...data,
      'uid': uid,
      'profile_id': profileId,
    });
  }

  @override
  Future<void> pushStreak({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    pushAttempts++;
    if (!online) throw Exception('offline');
    await _fs.collection('streak_events').add({...data, 'uid': uid});
  }

  @override
  Future<void> pushSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    pushAttempts++;
    if (!online) throw Exception('offline');
    await _fs.collection('settings').doc('${uid}_$profileId').set(data);
  }

  @override
  Future<void> pushTrack({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    pushAttempts++;
    if (!online) throw Exception('offline');
    await _fs.collection('track_configs').doc('${uid}_$profileId').set(data);
  }

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    pushAttempts++;
    if (!online) throw Exception('offline');
    await _fs.collection('learning_order').doc('${uid}_$profileId').set(data);
  }

  @override
  Future<void> pushBookmark({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    pushAttempts++;
    if (!online) throw Exception('offline');
    await _fs.collection('bookmarks').doc('${uid}_$profileId').set(data);
  }

  @override
  Future<void> pushNotificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    pushAttempts++;
    if (!online) throw Exception('offline');
    await _fs
        .collection('notification_settings')
        .doc('${uid}_$profileId')
        .set(data);
  }

  @override
  Future<void> pushGamificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    pushAttempts++;
    if (!online) throw Exception('offline');
    await _fs
        .collection('gamification_settings')
        .doc('${uid}_$profileId')
        .set(data);
  }

  @override
  Future<void> pushLearnerProfile({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    pushAttempts++;
    if (!online) throw Exception('offline');
    await _fs
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(profileId.toString())
        .set({...data});
  }

  @override
  Future<void> deleteLearnerProfile(int profileId) async {
    pushAttempts++;
    if (!online) throw Exception('offline');
    await _fs
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(profileId.toString())
        .delete();
  }

  @override
  Future<void> pushLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    pushAttempts++;
    if (!online) throw Exception('offline');
    await _fs.collection('learning_ledger').add({...data, 'uid': uid});
  }

  @override
  Future<void> pushLedgerEntriesBatch({
    required int profileId,
    required List<Map<String, dynamic>> entries,
  }) async {
    for (final entry in entries) {
      await pushLedgerEntry(profileId: profileId, data: entry);
    }
  }

  @override
  Future<void> pushProfileProgram({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    pushAttempts++;
    if (!online) throw Exception('offline');
    final curriculumId = data['curriculum_id']?.toString() ?? '';
    await _fs
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(profileId.toString())
        .collection('profile_programs')
        .doc(curriculumId)
        .set({...data});
  }

  @override
  Future<void> removeProfileProgramAssignment({
    required int profileId,
    required String curriculumStorageKey,
  }) async {
    pushAttempts++;
    if (!online) throw Exception('offline');
    await _fs
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(profileId.toString())
        .collection('profile_programs')
        .doc(curriculumStorageKey)
        .delete();
  }

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => const FirestorePage(rows: []);

  @override
  Future<List<Map<String, dynamic>>> fetchAll({
    required int profileId,
    required String collection,
  }) async => const <Map<String, dynamic>>[];

  // ── Step 1 additions (DNI-333 cutover) ─────────────────────────────────────

  @override
  Future<void> pushGoal({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushUiPreferences({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushAccountProfile({required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushCurriculumImportMetadata({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> deleteUserData(String uid) async {}

  @override
  Future<void> pushDiagnosticLog({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushAccountUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Stream<List<Map<String, dynamic>>> listenToCollection({
    required int profileId,
    required String collection,
  }) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => null;
}
