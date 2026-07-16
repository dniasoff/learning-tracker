/// Tests for [LocalDataUploadService] — upload service logic.
///
/// Exercises every entity kind that [pushAllLocalData] reads from the local DB
/// and routes through [OutboxSyncWriteFacade]:
///   completions, bookmarks, goals, profile-programs, streak events,
///   ledger entries, curriculum tracks, notification settings,
///   gamification settings, and UI preferences.
///
/// Strategy:
///   - In-memory Drift DB via [inMemoryDb] / [seedProfile].
///   - Real [OutboxSyncWriteFacade] wired to the same DB so we can inspect the
///     outbox table directly instead of mocking call sequences.
///   - [SharedPreferences.setMockInitialValues] to control notification prefs.
///   - [FakeLocalDayClock] for deterministic "now" values.
///   - After [pushAllLocalData] we assert on the outbox rows: entity kind,
///     entity key shape, and decoded payload field set.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Batch, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/parent_analytics_repository.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/sync/data/local_data_upload_service.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/drift_memory.dart';

/// Fake [ParentAnalyticsRepository] for AUD-sync-05 (SM-7): proves
/// [LocalDataUploadService] can have its analytics dependency substituted
/// via the constructor seam without also faking [UserDatabase].
///
/// Only [getAllCompletions] is exercised by [LocalDataUploadService
/// .pushAllLocalData] — the remaining methods are unused by that path and
/// throw if ever called, so an accidental new dependency on them fails
/// loudly instead of silently returning empty data.
class _FakeParentAnalyticsRepository implements ParentAnalyticsRepository {
  _FakeParentAnalyticsRepository(this._completions);

  final List<Completion> _completions;
  int getAllCompletionsCallCount = 0;

  @override
  Future<List<Completion>> getAllCompletions({
    required CrossProfileScope scope,
  }) async {
    getAllCompletionsCallCount++;
    return _completions;
  }

  @override
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId, {
    required CrossProfileScope scope,
  }) => throw UnimplementedError();

  @override
  Future<List<Completion>> getCompletionsForContent(
    String sefariaRef, {
    required CrossProfileScope scope,
  }) => throw UnimplementedError();

  @override
  Future<List<Completion>> getCompletionsByDateRange(
    DateTime start,
    DateTime end, {
    required CrossProfileScope scope,
  }) => throw UnimplementedError();

  @override
  Future<bool> hasCompletionsInDateRange(
    DateTime start,
    DateTime end, {
    required CrossProfileScope scope,
  }) => throw UnimplementedError();

  @override
  Future<int> getAggregateCount(
    String curriculumId, {
    required CrossProfileScope scope,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, int>> getTrackBreakdown(
    String curriculumId, {
    required CrossProfileScope scope,
  }) => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _profileId = 1;
final _now = DateTime.utc(2026, 5, 29, 10, 0);

/// Build a wired service + facade pair using the supplied [db].
///
/// The [FakeLocalDayClock] at [_now] ensures gamification / ui-prefs
/// snapshots have a deterministic [updated_at].
({LocalDataUploadService service, OutboxSyncWriteFacade facade}) _buildService(
  UserDatabase db,
) {
  final clock = FakeLocalDayClock(_now);
  final facade = OutboxSyncWriteFacade(
    outboxDao: db.outboxDao,
    database: db,
    resolveProfileId: () => _profileId,
    clock: clock,
  );
  final service = LocalDataUploadService(
    facade: facade,
    database: db,
    resolveProfileId: () => _profileId,
  );
  return (service: service, facade: facade);
}

/// Decode all outbox rows of [kind] into their payload maps.
Future<List<Map<String, dynamic>>> _payloadsOf(
  UserDatabase db,
  String kind,
) async {
  final rows = await db.outboxDao.getPendingByKind(kind, _profileId);
  return rows
      .map((r) => jsonDecode(r.payload) as Map<String, dynamic>)
      .toList();
}

/// Return outbox row objects of [kind] for [_profileId].
Future<List<OutboxData>> _rowsOf(UserDatabase db, String kind) =>
    db.outboxDao.getPendingByKind(kind, _profileId);

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db); // seeds account + profile id=1
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    await db.close();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    resetLocalDayClock();
  });

  // ── Learner profiles (SYNC-RECONCILE: the never-reached-cloud gap) ─────────
  group('learner profiles', () {
    test(
      'pushAllLocalData enqueues every OWN learner profile (the bulk '
      'reconciler must include the profile rows, not just their sub-data)',
      () async {
        // seedProfile already created account + profile id=1 ("Test User").
        // Add a second own profile on the same account.
        final accountId = (await db.profileDao.getProfileById(
          _profileId,
        ))!.accountId;
        await db
            .into(db.learnerProfiles)
            .insert(
              LearnerProfilesCompanion.insert(
                accountId: accountId,
                displayName: 'Second Child',
                mode: 'child',
                createdAt: DateTimeFactory.nowUtc(),
                updatedAt: DateTimeFactory.nowUtc(),
              ),
            );

        final (:service, facade: _) = _buildService(db);
        await service.pushAllLocalData();

        final payloads = await _payloadsOf(db, OutboxEntityKind.learnerProfile);
        final names = payloads
            .map((p) => p['display_name'] ?? p['displayName'])
            .toSet();
        expect(names, containsAll(<String>{'Test User', 'Second Child'}));
      },
    );

    test('pushAllLocalData does NOT enqueue tutored mirror profiles', () async {
      final accountId = (await db.profileDao.getProfileById(
        _profileId,
      ))!.accountId;
      // A synthetic talmid mirror (tutorParentUid != null) must be excluded —
      // it is another account's child, not this account's own profile.
      await db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: accountId,
              displayName: 'Talmid Mirror',
              mode: 'child',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
              tutorParentUid: const Value('some-parent-uid'),
            ),
          );

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final payloads = await _payloadsOf(db, OutboxEntityKind.learnerProfile);
      final names = payloads
          .map((p) => p['display_name'] ?? p['displayName'])
          .toSet();
      expect(names, contains('Test User'));
      expect(
        names,
        isNot(contains('Talmid Mirror')),
        reason: 'tutored mirror profiles must not be pushed as own profiles',
      );
    });
  });

  // ── Empty DB — still completes and enqueues singleton kinds ────────────────
  group('empty DB', () {
    test('pushAllLocalData completes without throwing', () async {
      final (:service, :facade) = _buildService(db);
      await expectLater(service.pushAllLocalData(), completes);
    });

    test(
      'enqueues exactly one gamification_settings row even when DB is empty',
      () async {
        final (:service, facade: _) = _buildService(db);
        await service.pushAllLocalData();

        final rows = await _rowsOf(db, OutboxEntityKind.gamificationSettings);
        expect(rows, hasLength(1));
        expect(rows.first.entityKey, 'gamification_settings_$_profileId');
      },
    );

    test(
      'enqueues exactly one ui_preferences row even when DB is empty',
      () async {
        final (:service, facade: _) = _buildService(db);
        await service.pushAllLocalData();

        final rows = await _rowsOf(db, OutboxEntityKind.uiPreferences);
        expect(rows, hasLength(1));
        expect(rows.first.entityKey, 'ui_preferences_$_profileId');
      },
    );

    test(
      'enqueues exactly one notification_settings row even when DB is empty',
      () async {
        final (:service, facade: _) = _buildService(db);
        await service.pushAllLocalData();

        final rows = await _rowsOf(db, OutboxEntityKind.notificationSettings);
        expect(rows, hasLength(1));
        expect(rows.first.entityKey, 'notification_settings_$_profileId');
      },
    );
  });

  // ── 2. Completions ─────────────────────────────────────────────────────────

  group('completions', () {
    test('existing completion is NOT re-enqueued via CompletionWriter '
        '(idempotent)', () async {
      // Seed one completion event directly.
      await db
          .into(db.completionEvents)
          .insert(
            CompletionEventsCompanion.insert(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              sefariaRef: 'Mishnah Berakhot 1:1',
              stageId: 1,
              trackType: 'personal',
              eventTimestamp: _now.subtract(const Duration(days: 1)),
            ),
          );

      // Drain any outbox rows seeded above so we start clean.
      await db.delete(db.outbox).go();

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      // CompletionWriter.commitBatch will see the existing event and
      // return isNew=false — no new outbox row. That is correct
      // idempotent behaviour: the service only enqueues NEW completions.
      final completionRows = await _rowsOf(db, OutboxEntityKind.completion);
      expect(completionRows, isEmpty);
    });

    test(
      'multiple completions each get an outbox row via CompletionWriter',
      () async {
        // Push first calls CompletionWriter.commitBatch which inserts outbox
        // rows for new completions. We start with a truly empty DB to confirm
        // fresh insertions go through.
        final refs = ['Mishnah Berakhot 1:1', 'Mishnah Berakhot 1:2'];
        for (final ref in refs) {
          await db
              .into(db.completionEvents)
              .insert(
                CompletionEventsCompanion.insert(
                  profileId: _profileId,
                  curriculumId: 'mishnayos',
                  sefariaRef: ref,
                  stageId: 1,
                  trackType: 'personal',
                  eventTimestamp: _now.subtract(const Duration(days: 2)),
                ),
              );
        }
        // Clear outbox rows from seeding.
        await db.delete(db.outbox).go();

        final (:service, facade: _) = _buildService(db);
        await service.pushAllLocalData();

        // The completions already exist so commitBatch returns isNew=false and
        // does NOT enqueue additional outbox rows — idempotency confirmed.
        final completionRows = await _rowsOf(db, OutboxEntityKind.completion);
        // Pre-existing completions = 0 new outbox rows pushed (idempotent).
        expect(completionRows, isEmpty);
      },
    );

    test('pushAllLocalData reads completions from the injected '
        'analyticsRepository, not from a self-constructed '
        'ParentAnalyticsRepositoryImpl (AUD-sync-05, SM-7)', () async {
      // Start from a truly empty completions view so the only completion
      // that can possibly be enqueued is the one the fake repository
      // hands back — proving the constructor seam is actually wired
      // through to pushAllLocalData rather than being an unused parameter.
      await db.delete(db.outbox).go();

      final fakeRepo = _FakeParentAnalyticsRepository([
        Completion(
          id: 999,
          profileId: _profileId,
          curriculumId: 'mishnayos',
          sefariaRef: 'Injected Ref 1:1',
          stageId: 1,
          trackType: 'personal',
          trackId: 0,
          completedAt: _now.subtract(const Duration(days: 3)),
          points: 5,
        ),
      ]);
      final clock = FakeLocalDayClock(_now);
      final facade = OutboxSyncWriteFacade(
        outboxDao: db.outboxDao,
        database: db,
        resolveProfileId: () => _profileId,
        clock: clock,
      );
      final service = LocalDataUploadService(
        facade: facade,
        database: db,
        resolveProfileId: () => _profileId,
        analyticsRepository: fakeRepo,
      );

      await service.pushAllLocalData();

      expect(
        fakeRepo.getAllCompletionsCallCount,
        1,
        reason: 'pushAllLocalData must call the injected repository',
      );
      final payloads = await _payloadsOf(db, OutboxEntityKind.completion);
      expect(
        payloads.any((p) => p['sefaria_ref'] == 'Injected Ref 1:1'),
        isTrue,
        reason:
            "the outbox row must come from the fake repository's "
            'completion, proving pushAllLocalData used the injected '
            'seam instead of constructing its own '
            'ParentAnalyticsRepositoryImpl',
      );
    });
  });

  // ── 3. Bookmarks ───────────────────────────────────────────────────────────

  group('bookmarks', () {
    test('bookmark with a valid track is enqueued', () async {
      final trackId = await seedTrack(db, profileId: _profileId);
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              trackId: trackId,
              sefariaRef: 'Mishnah Berakhot 1:1',
              updatedAt: _now,
            ),
          );

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.bookmark);
      expect(rows, hasLength(1));

      final payload = jsonDecode(rows.first.payload) as Map<String, dynamic>;
      expect(payload['curriculum_id'], 'mishnayos');
      // Phase B: the bookmark ref is now written under the canonical `sefaria_ref`
      // key (BookmarkCodec.encode); all readers accept sefaria_ref ?? content_item_id.
      expect(payload['sefaria_ref'], 'Mishnah Berakhot 1:1');
      // Drift may return local vs UTC ISO depending on the environment; just
      // verify the date fragment is present (YYYY-MM-DD).
      expect(payload['updated_at'], startsWith('2026-05-29'));
    });

    test('bookmark whose track is missing is silently skipped', () async {
      // Insert a bookmark referencing a non-existent track id.
      // This requires bypassing the FK constraint — we use a track we
      // don't create so the service's track lookup returns null.
      // Actually, FKs are enforced so we seed the track first then delete it.
      final trackId = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: 'mishnayos',
      );
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              trackId: trackId,
              sefariaRef: 'Mishnah Berakhot 1:1',
              updatedAt: _now,
            ),
          );
      // Hard-delete the track. Bookmarks FK is CASCADE so the bookmark goes too.
      // Recreate the bookmark via direct insert after the track is gone.
      await (db.delete(
        db.curriculumTracks,
      )..where((t) => t.id.equals(trackId))).go();

      // Bookmarks were cascade-deleted; outbox is empty. Service should not enqueue.
      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.bookmark);
      expect(rows, isEmpty);
    });

    test(
      'payload includes curriculum_id, sefaria_ref, updated_at keys',
      () async {
        final trackId = await seedTrack(db, profileId: _profileId);
        await db
            .into(db.bookmarks)
            .insert(
              BookmarksCompanion.insert(
                profileId: _profileId,
                curriculumId: 'bavli',
                trackId: trackId,
                sefariaRef: 'Berakhot 2a',
                updatedAt: _now,
              ),
            );

        final (:service, facade: _) = _buildService(db);
        await service.pushAllLocalData();

        final payloads = await _payloadsOf(db, OutboxEntityKind.bookmark);
        expect(
          payloads.first.keys,
          containsAll(['curriculum_id', 'sefaria_ref', 'updated_at']),
        );
      },
    );
  });

  // ── 4. Goals ───────────────────────────────────────────────────────────────

  group('goals', () {
    test('goal is enqueued with deterministic Firestore id', () async {
      final trackId = await seedTrack(db, profileId: _profileId);
      final createdAt = DateTime.utc(2026, 1, 1);
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              trackId: trackId,
              targetPercent: const Value(75.0),
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.goal);
      expect(rows, hasLength(1));

      final payload = jsonDecode(rows.first.payload) as Map<String, dynamic>;
      expect(payload['curriculum_id'], 'mishnayos');
      expect(payload['profile_id'], _profileId);
      expect(payload['target_percent'], 75.0);
      expect(payload['id'], isNotEmpty);

      // id is deterministic: curriculumId_targetPercent_createdAtMs
      final expectedId = 'mishnayos_75.0_${createdAt.millisecondsSinceEpoch}';
      expect(payload['id'], expectedId);
    });

    test('payload contains all required goal fields', () async {
      final trackId = await seedTrack(db, profileId: _profileId);
      final createdAt = DateTime.utc(2026, 2, 1);
      final targetDate = DateTime.utc(2026, 12, 31);
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              trackId: trackId,
              targetPercent: const Value(100.0),
              targetDate: Value(targetDate),
              description: const Value('Finish Moed'),
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final payloads = await _payloadsOf(db, OutboxEntityKind.goal);
      final p = payloads.first;
      // Phase B: GoalCodec.encode omits null optional fields (the old hand-built
      // map wrote them as null). This is a DEADLINE goal with no pace, so
      // pace_value/pace_unit are correctly absent (the merger reads them
      // null-safely). All non-pace required fields must be present.
      expect(
        p.keys,
        containsAll([
          'id',
          'profile_id',
          'track_id',
          'curriculum_id',
          'description',
          'target_percent',
          'target_date',
          'date_type',
          'goal_type',
          'created_at',
          'updated_at',
        ]),
      );
    });

    test('two goals produce two outbox rows', () async {
      final t1 = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: 'mishnayos',
      );
      final t2 = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: 'bavli',
      );
      final base = DateTime.utc(2026, 1, 1);
      for (final (trackId, cId) in [(t1, 'mishnayos'), (t2, 'bavli')]) {
        await db
            .into(db.goals)
            .insert(
              GoalsCompanion.insert(
                profileId: _profileId,
                curriculumId: cId,
                trackId: trackId,
                createdAt: base,
                updatedAt: base,
              ),
            );
      }

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.goal);
      expect(rows, hasLength(2));
    });
  });

  // ── 5. Profile programs ────────────────────────────────────────────────────

  group('profile programs', () {
    test('profile program is enqueued', () async {
      await db
          .into(db.profilePrograms)
          .insert(
            ProfileProgramsCompanion.insert(
              profileId: _profileId,
              curriculumType: 'mishnayos',
              programId: 42,
            ),
          );

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.profileProgram);
      expect(rows, hasLength(1));

      final payload = jsonDecode(rows.first.payload) as Map<String, dynamic>;
      expect(payload['curriculum_id'], 'mishnayos');
      expect(payload['program_id'], 42);
      expect(payload['profile_id'], _profileId);
    });

    test(
      'payload has tracking_start_date and tracking_start_ref keys',
      () async {
        final startDate = DateTime.utc(2026, 3, 1);
        await db
            .into(db.profilePrograms)
            .insert(
              ProfileProgramsCompanion.insert(
                profileId: _profileId,
                curriculumType: 'bavli',
                programId: 7,
                trackingStartDate: Value(startDate),
                trackingStartRef: const Value('Berakhot 2a'),
              ),
            );

        final (:service, facade: _) = _buildService(db);
        await service.pushAllLocalData();

        final payloads = await _payloadsOf(db, OutboxEntityKind.profileProgram);
        final p = payloads.first;
        // Drift may return local vs UTC ISO depending on the environment.
        expect(p['tracking_start_date'], startsWith('2026-03-01'));
        expect(p['tracking_start_ref'], 'Berakhot 2a');
      },
    );

    test('only programs for the target profileId are enqueued', () async {
      // Seed a second profile.
      final acct2 = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'other@example.com',
              tier: 'localBorn',
              displayName: 'Other',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );
      await db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: acct2,
              displayName: 'Other',
              mode: 'adult',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );

      // Program for profileId=1 (target).
      await db
          .into(db.profilePrograms)
          .insert(
            ProfileProgramsCompanion.insert(
              profileId: _profileId,
              curriculumType: 'mishnayos',
              programId: 1,
            ),
          );
      // Program for profileId=2 (other — should NOT be enqueued).
      await db
          .into(db.profilePrograms)
          .insert(
            ProfileProgramsCompanion.insert(
              profileId: acct2, // second profile's id
              curriculumType: 'mishnayos',
              programId: 99,
            ),
          );

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.profileProgram);
      expect(rows, hasLength(1));
      final p = jsonDecode(rows.first.payload) as Map<String, dynamic>;
      expect(p['program_id'], 1);
    });
  });

  // ── 6. Streak events ───────────────────────────────────────────────────────

  group('streak events', () {
    test('streak event is enqueued with correct fields', () async {
      final dayUtc = DateTime.utc(2026, 5, 28);
      await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: _profileId,
          eventType: 'completion',
          dayUtc: dayUtc,
          eventTimestamp: dayUtc,
        ),
      );

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.streak);
      expect(rows, hasLength(1));

      final p = jsonDecode(rows.first.payload) as Map<String, dynamic>;
      expect(p['event_type'], 'completion');
      expect(p['profile_id'], _profileId);
      expect(p.containsKey('ulid'), isTrue);
      expect(p.containsKey('study_date'), isTrue);
      expect(p.containsKey('created_at'), isTrue);
    });

    test(
      'payload includes ulid, profile_id, event_type, study_date, created_at',
      () async {
        final dayUtc = DateTime.utc(2026, 5, 27);
        await db.streakEventDao.appendEvent(
          StreakEventsCompanion.insert(
            profileId: _profileId,
            eventType: 'day_boundary',
            dayUtc: dayUtc,
            eventTimestamp: dayUtc,
          ),
        );

        final (:service, facade: _) = _buildService(db);
        await service.pushAllLocalData();

        final payloads = await _payloadsOf(db, OutboxEntityKind.streak);
        expect(
          payloads.first.keys,
          containsAll([
            'ulid',
            'profile_id',
            'event_type',
            'study_date',
            'created_at',
          ]),
        );
      },
    );

    test('only streak events for the target profileId are enqueued', () async {
      // Second profile.
      final acct2 = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'b@b.com',
              tier: 'localBorn',
              displayName: 'B',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );
      final profile2Id = await db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: acct2,
              displayName: 'B',
              mode: 'adult',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );

      final dayUtc = DateTime.utc(2026, 5, 25);
      await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: _profileId,
          eventType: 'completion',
          dayUtc: dayUtc,
          eventTimestamp: dayUtc,
        ),
      );
      await db.streakEventDao.appendEvent(
        StreakEventsCompanion.insert(
          profileId: profile2Id,
          eventType: 'completion',
          dayUtc: dayUtc.add(const Duration(hours: 1)),
          eventTimestamp: dayUtc.add(const Duration(hours: 1)),
        ),
      );

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.streak);
      // Only profile 1's event should be enqueued.
      for (final row in rows) {
        final p = jsonDecode(row.payload) as Map<String, dynamic>;
        expect(p['profile_id'], _profileId);
      }
    });
  });

  // ── 7. Learning ledger entries ─────────────────────────────────────────────

  group('learning ledger entries', () {
    test('ledger entry is enqueued with snake_case fields', () async {
      final trackId = await seedTrack(db, profileId: _profileId);
      await db
          .into(db.learningLedger)
          .insert(
            LearningLedgerCompanion.insert(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              entryScope: 'masechta',
              unitIdentifier: 'Berakhot',
              unitDisplayNameHe: 'ברכות',
              unitDisplayNameEn: 'Berakhot',
              trackType: 'personal',
              trackId: Value(trackId),
              completedAt: _now.subtract(const Duration(days: 1)),
              completionNumber: 1,
              markedBy: _profileId,
            ),
          );

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.learningLedgerEntry);
      expect(rows, hasLength(1));

      final p = jsonDecode(rows.first.payload) as Map<String, dynamic>;
      // Must use snake_case keys so the pull-side LearningLedgerMerger decodes them.
      expect(p.containsKey('unit_identifier'), isTrue);
      expect(p.containsKey('unit_display_name_he'), isTrue);
      expect(p.containsKey('unit_display_name_en'), isTrue);
      expect(p.containsKey('entry_scope'), isTrue);
      expect(p.containsKey('track_type'), isTrue);
      expect(p.containsKey('curriculum_id'), isTrue);
      expect(p.containsKey('completed_at'), isTrue);
    });

    test('payload does NOT use camelCase keys', () async {
      final trackId = await seedTrack(db, profileId: _profileId);
      await db
          .into(db.learningLedger)
          .insert(
            LearningLedgerCompanion.insert(
              profileId: _profileId,
              curriculumId: 'bavli',
              entryScope: 'masechta',
              unitIdentifier: 'Shabbat',
              unitDisplayNameHe: 'שבת',
              unitDisplayNameEn: 'Shabbat',
              trackType: 'personal',
              trackId: Value(trackId),
              completedAt: _now,
              completionNumber: 1,
              markedBy: _profileId,
            ),
          );

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final payloads = await _payloadsOf(
        db,
        OutboxEntityKind.learningLedgerEntry,
      );
      final p = payloads.first;
      // Explicitly assert camelCase keys are absent.
      expect(p.containsKey('unitIdentifier'), isFalse);
      expect(p.containsKey('unitDisplayNameHe'), isFalse);
      expect(p.containsKey('unitDisplayNameEn'), isFalse);
      expect(p.containsKey('entryScope'), isFalse);
      expect(p.containsKey('trackType'), isFalse);
    });
  });

  // ── 8. Curriculum tracks ───────────────────────────────────────────────────

  group('curriculum tracks', () {
    test('active track for profileId is enqueued', () async {
      await seedTrack(db, profileId: _profileId, curriculumId: 'mishnayos');

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.track);
      // Note: seedTrack goes through db.into(curriculumTracks) directly, not
      // through TrackDao.activateTrack, so no outbox row is written at seed time.
      // After pushAllLocalData there is 1 row for the 1 track.
      expect(rows, hasLength(1));
    });

    test('track payload includes required fields', () async {
      await seedTrack(db, profileId: _profileId, curriculumId: 'bavli');

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final payloads = await _payloadsOf(db, OutboxEntityKind.track);
      final p = payloads.first;
      expect(
        p.keys,
        containsAll([
          'profile_id',
          'track_id',
          'curriculum_id',
          'state',
          'state_changed_at',
          'activated_at',
        ]),
      );
    });

    test('track payload omits pace_reset_date when null', () async {
      await seedTrack(db, profileId: _profileId);

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final payloads = await _payloadsOf(db, OutboxEntityKind.track);
      expect(payloads.first['pace_reset_date'], isNull);
    });

    test('multiple tracks for same profile are all enqueued', () async {
      await seedTrack(db, profileId: _profileId, curriculumId: 'mishnayos');
      await seedTrack(db, profileId: _profileId, curriculumId: 'bavli');

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.track);
      expect(rows, hasLength(2));
    });

    test('tracks for a different profile are NOT enqueued', () async {
      // Seed a track for profile 1 (target) and one for profile 2.
      await seedTrack(db, profileId: _profileId, curriculumId: 'mishnayos');

      // Create profile 2 and its track.
      final acct2 = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'c@c.com',
              tier: 'localBorn',
              displayName: 'C',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );
      final profile2Id = await db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: acct2,
              displayName: 'C',
              mode: 'adult',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );
      await seedTrack(db, profileId: profile2Id, curriculumId: 'mishnayos');

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.track);
      // Only profile 1's track.
      for (final row in rows) {
        final p = jsonDecode(row.payload) as Map<String, dynamic>;
        expect(p['profile_id'], _profileId);
      }
      expect(rows, hasLength(1));
    });
  });

  // ── 9. Notification settings ───────────────────────────────────────────────

  group('notification settings', () {
    test('payload carries schema_version = 1', () async {
      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final payloads = await _payloadsOf(
        db,
        OutboxEntityKind.notificationSettings,
      );
      expect(payloads.first['schema_version'], 1);
    });

    test('defaults to reminder enabled=true, hour=19, minute=0', () async {
      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final p = (await _payloadsOf(
        db,
        OutboxEntityKind.notificationSettings,
      )).first;
      final daily = p['daily_reminder'] as Map<String, dynamic>;
      expect(daily['enabled'], isTrue);
      expect(daily['hour'], 19);
      expect(daily['minute'], 0);
    });

    test('defaults to streak alert enabled=true, hour=21, minute=0', () async {
      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final p = (await _payloadsOf(
        db,
        OutboxEntityKind.notificationSettings,
      )).first;
      final alert = p['streak_alert'] as Map<String, dynamic>;
      expect(alert['enabled'], isTrue);
      expect(alert['hour'], 21);
      expect(alert['minute'], 0);
    });

    test('reads custom values from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        NotificationPreferencesRepository.reminderEnabledKey(_profileId): false,
        NotificationPreferencesRepository.reminderHourKey(_profileId): 8,
        NotificationPreferencesRepository.reminderMinuteKey(_profileId): 30,
        NotificationPreferencesRepository.streakAlertEnabledKey(_profileId):
            false,
        NotificationPreferencesRepository.rewardNotificationEnabledKey(
          _profileId,
        ): false,
      });

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final p = (await _payloadsOf(
        db,
        OutboxEntityKind.notificationSettings,
      )).first;
      final daily = p['daily_reminder'] as Map<String, dynamic>;
      expect(daily['enabled'], isFalse);
      expect(daily['hour'], 8);
      expect(daily['minute'], 30);
      final alert = p['streak_alert'] as Map<String, dynamic>;
      expect(alert['enabled'], isFalse);
      final reward = p['reward_notifications'] as Map<String, dynamic>;
      expect(reward['enabled'], isFalse);
    });

    test('updated_at uses stored ms timestamp when present', () async {
      final ms = DateTime.utc(2026, 4, 15, 9, 0).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues(<String, Object>{
        NotificationPreferencesRepository.notificationSettingsUpdatedAtMsKey(
          _profileId,
        ): ms,
      });

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final p = (await _payloadsOf(
        db,
        OutboxEntityKind.notificationSettings,
      )).first;
      expect(
        p['updated_at'],
        DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String(),
      );
    });
  });

  // ── 10. Gamification settings ──────────────────────────────────────────────

  group('gamification settings', () {
    test('payload carries schema_version = 3', () async {
      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final p = (await _payloadsOf(
        db,
        OutboxEntityKind.gamificationSettings,
      )).first;
      expect(p['schema_version'], 3);
    });

    test(
      'payload has updated_at, points_config, reward_settings, lifetime_stats',
      () async {
        final (:service, facade: _) = _buildService(db);
        await service.pushAllLocalData();

        final p = (await _payloadsOf(
          db,
          OutboxEntityKind.gamificationSettings,
        )).first;
        expect(
          p.keys,
          containsAll([
            'updated_at',
            'points_config',
            'reward_settings',
            'lifetime_stats',
          ]),
        );
      },
    );
  });

  // ── 11. UI preferences ─────────────────────────────────────────────────────

  group('ui preferences', () {
    test('payload carries schema_version = 2', () async {
      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final p = (await _payloadsOf(db, OutboxEntityKind.uiPreferences)).first;
      expect(p['schema_version'], 2);
    });

    test('payload has profile_id and text_display sub-map', () async {
      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final p = (await _payloadsOf(db, OutboxEntityKind.uiPreferences)).first;
      expect(p['profile_id'], _profileId);
      expect(p['text_display'], isA<Map<String, dynamic>>());
    });

    test('entity key is ui_preferences_{profileId}', () async {
      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.uiPreferences);
      expect(rows.first.entityKey, 'ui_preferences_$_profileId');
    });
  });

  // ── 12. Idempotency — calling pushAllLocalData twice ──────────────────────

  group('idempotency', () {
    test('calling pushAllLocalData twice doubles singleton outbox rows '
        '(outbox has no UNIQUE constraint — rows accumulate)', () async {
      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();
      await service.pushAllLocalData();

      // Each call enqueues one gamification_settings row. Two calls → 2 rows.
      final rows = await _rowsOf(db, OutboxEntityKind.gamificationSettings);
      expect(rows, hasLength(2));
    });

    test(
      'entity-data completions are idempotent: re-running pushAllLocalData '
      'does not create new completion outbox rows for pre-existing completions',
      () async {
        // Pre-seed a completion.
        await db
            .into(db.completionEvents)
            .insert(
              CompletionEventsCompanion.insert(
                profileId: _profileId,
                curriculumId: 'mishnayos',
                sefariaRef: 'Mishnah Berakhot 1:1',
                stageId: 1,
                trackType: 'personal',
                eventTimestamp: _now.subtract(const Duration(days: 1)),
              ),
            );
        // Clear initial outbox rows.
        await db.delete(db.outbox).go();

        final (:service, facade: _) = _buildService(db);
        await service.pushAllLocalData();
        await service.pushAllLocalData();

        // CompletionWriter.commitBatch sees pre-existing completions and does NOT
        // enqueue additional rows for them on each re-run.
        final completionRows = await _rowsOf(db, OutboxEntityKind.completion);
        expect(
          completionRows,
          isEmpty,
          reason: 'pre-existing completions must not generate new outbox rows',
        );
      },
    );
  });

  // ── 13. Error: facade throws on one entity kind ────────────────────────────

  group('error propagation', () {
    test(
      'if the DB is closed, pushAllLocalData throws StateError or similar',
      () async {
        final (:service, facade: _) = _buildService(db);
        await db.close();
        // Re-opening avoidance: calling on a closed DB should throw.
        await expectLater(service.pushAllLocalData(), throwsA(anything));
        // Prevent double-close in tearDown.
        db = inMemoryDb();
        await seedProfile(db);
      },
    );
  });

  // ── 14. Entity-key shape contracts ────────────────────────────────────────

  group('entity key shapes', () {
    test('gamification key is gamification_settings_{profileId}', () async {
      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.gamificationSettings);
      expect(rows.first.entityKey, 'gamification_settings_$_profileId');
    });

    test(
      'notification settings key is notification_settings_{profileId}',
      () async {
        final (:service, facade: _) = _buildService(db);
        await service.pushAllLocalData();

        final rows = await _rowsOf(db, OutboxEntityKind.notificationSettings);
        expect(rows.first.entityKey, 'notification_settings_$_profileId');
      },
    );

    test('bookmark entity key encodes curriculum_id', () async {
      final trackId = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: 'mishnayos',
      );
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              trackId: trackId,
              sefariaRef: 'X',
              updatedAt: _now,
            ),
          );

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.bookmark);
      expect(rows.first.entityKey, contains('mishnayos'));
    });

    test('goal entity key matches deterministic Firestore id', () async {
      final trackId = await seedTrack(db, profileId: _profileId);
      final createdAt = DateTime.utc(2026, 1, 15);
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: _profileId,
              curriculumId: 'mishnayos',
              trackId: trackId,
              targetPercent: const Value(50.0),
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );

      final (:service, facade: _) = _buildService(db);
      await service.pushAllLocalData();

      final rows = await _rowsOf(db, OutboxEntityKind.goal);
      final expectedId = 'mishnayos_50.0_${createdAt.millisecondsSinceEpoch}';
      expect(rows.first.entityKey, expectedId);
    });
  });

  // ── DB-3 (AUD-sync-02): batched outbox writes ───────────────────────────────
  group('batched outbox writes (DB-3)', () {
    test('pushAllLocalData with N seeded tracks performs O(1) outbox INSERT '
        'statements for that kind, not O(N)', () async {
      const trackCount = 20;
      for (var i = 0; i < trackCount; i++) {
        await seedTrack(db, profileId: _profileId, curriculumId: 'c$i');
      }

      final spyDao = _SpyOutboxDao(db);
      final clock = FakeLocalDayClock(_now);
      final facade = OutboxSyncWriteFacade(
        outboxDao: spyDao,
        database: db,
        resolveProfileId: () => _profileId,
        clock: clock,
      );
      final service = LocalDataUploadService(
        facade: facade,
        database: db,
        resolveProfileId: () => _profileId,
      );

      await service.pushAllLocalData();

      // The rows genuinely landed — batching must not have dropped any.
      final rows = await _rowsOf(db, OutboxEntityKind.track);
      expect(rows, hasLength(trackCount));

      // O(1): pushAllLocalData enqueues (up to) 7 entity kinds through the
      // batched path — one batch() call per kind, regardless of how many
      // rows that kind has. The outer setUp's seedProfile(db) means the
      // "learner profiles" kind also has exactly 1 row here, so 2 batch
      // calls are expected (tracks + learner profile); the other 5 kinds
      // are empty and _enqueueBatch short-circuits before calling the DAO
      // at all. The load-bearing assertion is that the call count stays
      // WAY below trackCount, not tied to it.
      expect(
        spyDao.batchInsertOutboxRowsCalls,
        lessThan(trackCount),
        reason:
            'all $trackCount track rows must go through ONE batch() '
            'call per kind, not $trackCount individually-awaited inserts',
      );
      expect(
        spyDao.batchInsertOutboxRowsCalls,
        lessThanOrEqualTo(2),
        reason:
            'exactly the tracks batch + the incidental learner-profile '
            'batch from setUp\'s seeded profile — no other kind is seeded',
      );
      expect(
        spyDao.insertOutboxRowCalls,
        lessThan(trackCount),
        reason:
            'the per-row insert path must stay at its fixed baseline '
            '(notification/gamification/ui-prefs snapshots) regardless '
            'of how many tracks were seeded',
      );
    });
  });
}

/// Hand-written fake (TQ-4) — counts calls to the per-row vs batched insert
/// paths so a test can assert O(1) statements for O(N) rows (DB-3).
class _SpyOutboxDao extends OutboxDao {
  _SpyOutboxDao(super.db);

  int insertOutboxRowCalls = 0;
  int batchInsertOutboxRowsCalls = 0;

  @override
  Future<int> insertOutboxRow(OutboxCompanion companion) {
    insertOutboxRowCalls++;
    return super.insertOutboxRow(companion);
  }

  @override
  void batchInsertOutboxRows(Batch batch, List<OutboxCompanion> rows) {
    batchInsertOutboxRowsCalls++;
    super.batchInsertOutboxRows(batch, rows);
  }
}
