/// Story acceptance tests for Story 27.8 (DNI-384) — integration coverage
/// of Firestore security rules and the offline-completion flush path.
///
/// Two groups, both running against the in-process `fake_cloud_firestore`
/// helper landed in DNI-377:
///
///   Group A — Firestore rules (W3.30-W3.37 new layout):
///     The old top-level compat blocks (accounts, learner_profiles,
///     completion_events, etc.) were removed in W3.30. Tests now assert
///     the live nested layout under users/{uid}/learner_profiles/{profileId}.
///
///     1. `delete()` is rejected by the key nested-layout collections:
///        completions, streak_events, learning_ledger, import_metadata.
///     2. Field-validator clauses for completions (points range,
///        future `completed_at`) and the snapshot field whitelists are
///        present in the rules file.
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

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/outbox/push_pipeline.dart';
import 'package:learning_tracker/core/sync/push_pipeline_impl.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';
import '../helpers/firestore_fake.dart';

void main() {
  // ── Group A — Firestore rules ───────────────────────────────────────────

  group(
    'Story 27.8 — Firestore rules enforce per-collection semantics (new layout W3.30-W3.37)',
    tags: ['story_27_8_rules'],
    () {
      // Static rule-file assertions — these pin the field validators that
      // the dynamic fake cannot evaluate. After W3.30, the old top-level
      // compat blocks are gone; assertions now target the live nested layout.
      group('rules file pins per-AC field validators', () {
        late String rules;
        setUpAll(() {
          rules = _readProjectRules();
        });

        // W3.35 — completions in the nested layout enforce points + timestamp.
        test('completions/{completionId} enforces 0 <= points <= 100', () {
          final block = _extractRuleBlock(rules, 'completions/{completionId}');
          expect(block, contains('points >= 0'));
          expect(block, contains('points <= 100'));
        });

        test(
          'completions/{completionId} enforces completed_at <= request.time',
          () {
            final block = _extractRuleBlock(
              rules,
              'completions/{completionId}',
            );
            expect(block, contains('completed_at <= request.time'));
          },
        );

        test('completions/{completionId} denies update and delete', () {
          final block = _extractRuleBlock(rules, 'completions/{completionId}');
          expect(block, contains('allow update: if false'));
          expect(block, contains('allow delete: if false'));
        });

        // W3.37 — streak_events is now a per-event collection.
        // W3.36 — learning_ledger uses ULID doc-ids; still append-only.
        test('streak_events and learning_ledger deny update and delete', () {
          for (final c in [
            'streak_events/{streakEventId}',
            'learning_ledger/{entryId}',
          ]) {
            final block = _extractRuleBlock(rules, c);
            expect(block, contains('allow update: if false'), reason: c);
            expect(block, contains('allow delete: if false'), reason: c);
          }
        });

        // Snapshot collections in the nested layout gate writes through
        // a .hasOnly() whitelist.
        test(
          'snapshot collections gate writes through hasOnly() field whitelist',
          () {
            // Collections with write field whitelist + delete-denied.
            for (final c in [
              'bookmarks/{bookmarkId}',
              'stage_definitions/{stageId}',
              'import_metadata/{docId}', // W3.34: renamed
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
            // profile_programs: has hasOnly() whitelist, but allows owner-delete
            // (C4 fix — V3-W1: removeProfileProgramAssignment must hard-delete).
            final ppBlock = _extractRuleBlock(
              rules,
              'profile_programs/{curriculumId}',
            );
            expect(
              ppBlock,
              contains('.hasOnly('),
              reason:
                  'profile_programs must restrict writes to a fixed field list',
            );
          },
        );

        test(
          'global deny-all wildcard precedes per-collection allow rules',
          () {
            final denyIdx = rules.indexOf('match /{document=**}');
            // After W3.30 top-level compat blocks removed; first allow is
            // the tutor_grants block or the users/ block.
            final firstAllowIdx = rules.indexOf('match /tutor_grants');
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

        // W3.33 — preferences/{scope} replaces three separate collections.
        test('preferences/{scope} block allows owner reads/writes (W3.33)', () {
          final block = _extractRuleBlock(rules, 'preferences/{scope}');
          expect(
            block,
            contains('isOwner(uid)'),
            reason: 'preferences must be owner-gated',
          );
          expect(
            block,
            contains('allow delete: if false'),
            reason: 'preferences docs must not be deletable by clients',
          );
        });
      });
    },
  );

  // ── Group C — Tutor security boundary (W3.41) ──────────────────────────
  //
  // These are static structural assertions on the rules file (same approach
  // as Group A — the `fake_firebase_security_rules` package cannot evaluate
  // `request.auth.uid` comparisons dynamically, but string-scanning the rules
  // proves that the correct guards are present).
  //
  // The LOAD-BEARING security invariant tested here:
  //   • The `completions` rule gate is `isOwner(uid)` — which evaluates to
  //     `request.auth.uid == uid` where `uid` is the Firestore path segment
  //     for the profile owner. A tutor has a different uid and cannot satisfy
  //     this condition, making the create rule always false for non-owners.
  //   • The `tutor_grants` collection rules deny all client writes (create /
  //     update / delete: if false), preventing a malicious client from forging
  //     an active-state grant.
  //   • Audit log entries inside `tutor_grants/{grantId}/audit_log/{entryId}`
  //     also deny all client writes.

  group(
    'W3.41 — Tutor security boundary: completions write-block and grant rules',
    tags: ['story_w3_41_tutor_security'],
    () {
      late String rules;
      setUpAll(() {
        rules = _readProjectRules();
      });

      // ── 1. Completions write-block — non-owner cannot write ─────────────
      //
      // The completion create rule is `isOwner(uid)` which expands to
      // `request.auth.uid == uid`. A tutor (different uid) can never satisfy
      // this condition. We assert:
      //   (a) The completions block uses isOwner() — NOT a tutor helper.
      //   (b) No tutor-bypass path exists in the completions block.
      //   (c) The block still carries the mandatory `allow update: if false`
      //       and `allow delete: if false` guards.
      //   (d) The load-bearing comment keyword is present to aid future audit.

      test(
        'completions create is gated by isOwner(uid) — non-owner (tutor) is denied',
        () {
          final block = _extractRuleBlock(rules, 'completions/{completionId}');
          expect(
            block,
            contains('isOwner(uid)'),
            reason:
                'completions create MUST use isOwner(uid); a tutor whose '
                'request.auth.uid != uid always fails this check',
          );
        },
      );

      test('completions block contains no tutor-bypass allow clause', () {
        final block = _extractRuleBlock(rules, 'completions/{completionId}');
        expect(
          block,
          isNot(contains('isTutorOf')),
          reason:
              'isTutorOf MUST NOT appear in the completions block — '
              'tutors may never write live completions directly',
        );
        expect(
          block,
          isNot(contains('isActiveTutorGrant')),
          reason:
              'isActiveTutorGrant MUST NOT appear in the completions block '
              '— tutor completion writes go through Cloud Functions only',
        );
      });

      test('completions block denies update and delete', () {
        final block = _extractRuleBlock(rules, 'completions/{completionId}');
        expect(block, contains('allow update: if false'));
        expect(block, contains('allow delete: if false'));
      });

      test(
        'completions block documents the load-bearing security boundary',
        () {
          // The keyword comment is a searchable audit trail.
          expect(
            rules,
            contains('TUTOR WRITE BLOCK'),
            reason:
                'The rules file must contain the TUTOR WRITE BLOCK comment '
                'as a searchable security-boundary marker for auditors',
          );
        },
      );

      // ── 2. tutor_grants — client writes forbidden ────────────────────────
      //
      // If a client could write a grant doc with state='active', it could
      // bypass the entire permission model. All three write operations must
      // be denied.

      test(
        'tutor_grants denies all client writes (create, update, delete)',
        () {
          final block = _extractRuleBlock(rules, 'tutor_grants/{grantId}');
          expect(
            block,
            contains('allow create: if false'),
            reason: 'tutor_grants create must always be denied for clients',
          );
          expect(
            block,
            contains('allow update: if false'),
            reason: 'tutor_grants update must always be denied for clients',
          );
          expect(
            block,
            contains('allow delete: if false'),
            reason: 'tutor_grants delete must always be denied for clients',
          );
        },
      );

      test('tutor_grants audit_log denies all client writes', () {
        final block = _extractRuleBlock(rules, 'audit_log/{entryId}');
        expect(block, contains('allow create: if false'));
        expect(block, contains('allow update: if false'));
        expect(block, contains('allow delete: if false'));
      });

      // ── 3. Rule correctness — owner can create a completion ──────────────
      //
      // The positive direction: the owner's path through the rules must
      // succeed. We verify the rule allows the isOwner() path (structural).

      test(
        'completions allow create rule has an isOwner path (owner can write)',
        () {
          final block = _extractRuleBlock(rules, 'completions/{completionId}');
          // The rule body must contain `allow create: if isOwner(uid)` — this
          // is the ONLY branch that permits a completion create. If it is absent
          // no completion can ever be created, breaking the whole feature.
          expect(
            block,
            contains('allow create: if isOwner(uid)'),
            reason:
                'The owner MUST be able to create completions; '
                'isOwner(uid) is the positive branch',
          );
        },
      );

      // ── 4. tutor_grants read — only tutor or parent can read ────────────

      test('tutor_grants allows reads to tutor_uid or parent_uid', () {
        final block = _extractRuleBlock(rules, 'tutor_grants/{grantId}');
        expect(
          block,
          contains('tutor_uid'),
          reason:
              'tutor_grants read rule must reference tutor_uid for tutor self-read',
        );
        expect(
          block,
          contains('parent_uid'),
          reason:
              'tutor_grants read rule must reference parent_uid for parent read',
        );
        expect(
          block,
          contains('allow read: if isSignedIn()'),
          reason: 'tutor_grants must require authentication for all reads',
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
          clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
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

      test('drain() does not silently absorb failures — a batch error retains '
          'all rows for retry', () async {
        const profileId = 1;
        gateway.online = true;
        // Fail on the second individual push so pushCompletionsBatch throws.
        gateway.failOn = {1};

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
        // With batch semantics, a failure anywhere in the batch fails all rows.
        expect(
          flushed,
          equals(0),
          reason: 'batch failure means no rows counted as success',
        );

        final remaining = await db.select(db.outbox).get();
        expect(
          remaining,
          hasLength(3),
          reason: 'all rows must remain in outbox for retry when batch fails',
        );
        for (final row in remaining) {
          expect(row.attempts, equals(1));
          expect(row.lastError, isNotNull);
        }
      });
    },
  );
}

// ── Helpers ────────────────────────────────────────────────────────────────

/// Seed a curriculum_tracks row so completion FKs resolve.
///
/// Updated for W3.22/W3.28: trackType and isActive columns removed;
/// state + stateChangedAt are the new lifecycle columns.
Future<int> _seedTrack(UserDatabase db) => db
    .into(db.curriculumTracks)
    .insert(
      CurriculumTracksCompanion.insert(
        profileId: 1,
        curriculumId: 'mishnah_yomit',
        stateChangedAt: DateTime.utc(2026, 5, 1),
        activatedAt: DateTime.utc(2026, 5, 1),
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
    String? docId,
  }) async {
    final attempt = pushAttempts;
    pushAttempts++;
    if (!online) throw Exception('offline');
    if (failOn.contains(attempt)) {
      throw Exception('injected failure on attempt $attempt');
    }
    // The canonical completion payload is snake_case; the doc ID is derived
    // from the structured natural key (the [docId] parameter is no longer
    // threaded by the pipeline — H2). A `.`/`/`/space-safe encoding keeps
    // distinct natural keys in distinct documents.
    final ref = Uri.encodeComponent('${data['sefaria_ref']}');
    final stage = '${data['stage_id']}';
    final trackType = '${data['track_type']}';
    final id = '${uid}_${profileId}_${ref}_${stage}_$trackType';
    await _fs.collection('completion_events').doc(id).set({
      ...data,
      'uid': uid,
      'profile_id': profileId,
    });
  }

  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> items,
  }) async {
    // This fake models a NON-chunked gateway: an injected failure throws a
    // plain exception, which OutboxProcessor.drain treats as a total batch
    // failure (no committed entityKeys). On full success it reports every
    // entityKey as committed.
    for (final item in items) {
      await pushCompletion(profileId: profileId, data: item.payload);
    }
    return items.map((e) => e.entityKey).toList();
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
  Future<void> deleteGoal({
    required int profileId,
    required String firestoreId,
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
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int limit = 500}) =>
      const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int limit = 500}) =>
      const Stream.empty();

  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => null;

  @override
  Future<void> pushStageDefinition({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushStudyDayConfig({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushPointsLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushRewardRedemption({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  // W6.13: fetchAuditLogEntries added to FirestoreGateway interface.
  @override
  Future<List<Map<String, dynamic>>> fetchAuditLogEntries({
    required String grantId,
    String? startTimestamp,
    String? endTimestamp,
    String? actionFilter,
  }) async => const [];
}
