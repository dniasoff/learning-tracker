import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/last_active_curriculum_exception.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';

import '../../../../helpers/drift_memory.dart' as drift_helpers;

Future<void> _dummyPushCurriculumTrack(Map<String, dynamic> data) async {}

/// Recording [SyncWriteFacade] that captures [pushStudyDayConfig] calls.
///
/// All other methods are no-ops so the recording is focused on the push path
/// under test (R3-5 regression).
class _RecordingSyncFacade implements SyncWriteFacade {
  final List<Map<String, dynamic>> studyDayConfigPushes = [];

  @override
  Future<void> pushStudyDayConfig(Map<String, dynamic> payload) async {
    studyDayConfigPushes.add(Map<String, dynamic>.from(payload));
  }

  @override
  Future<void> pushGamificationSettingsSnapshot() async {}
  @override
  Future<void> pushUiPreferencesSnapshot() async {}
  @override
  Future<void> pushBookmark(Map<String, dynamic> bookmark) async {}
  @override
  Future<void> pushSettings(Map<String, dynamic> settings) async {}
  @override
  Future<void> pushGoal(Map<String, dynamic> goal) async {}
  @override
  Future<void> deleteGoal(Map<String, dynamic> payload) async {}
  @override
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async {}
  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async {}
  @override
  Future<void> deleteLearnerProfile(int profileId) async {}
  @override
  Future<void> pushStageDefinitions({
    required int trackId,
    required String curriculumId,
    required List<Map<String, dynamic>> stages,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> deleteCompletion(String completionId) async {}
  @override
  Future<void> pushProfileProgram(Map<String, dynamic> payload) async {}
}

void main() {
  late UserDatabase database;
  late CurriculumActivationService service;

  setUp(() async {
    database = UserDatabase(NativeDatabase.memory());
    service = CurriculumActivationService(
      database: database,
      pushCurriculumTrack: _dummyPushCurriculumTrack,
      trackRepository: TrackRepositoryImpl(database: database),
    );

    // Seed parent rows required by FK constraints.
    await drift_helpers.seedProfile(database);
    await drift_helpers.seedProfileZero(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> getTrackId(CurriculumId curriculum) async {
    final tracks = await database.trackDao.getAllTracks(curriculum);
    return tracks.first.id;
  }

  group('CurriculumActivationService', () {
    test('activate adds curriculum to database', () async {
      await service.activate(CurriculumId.bavli);

      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.bavli,
      );
      expect(isActive, isTrue);
    });

    test('deactivate removes curriculum from database', () async {
      // Activate two curricula
      await service.activate(CurriculumId.bavli);
      await service.activate(CurriculumId.yerushalmi);

      // Deactivate one
      await service.deactivate(CurriculumId.bavli);

      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.bavli,
      );
      expect(isActive, isFalse);
    });

    test('toggle activates an inactive curriculum', () async {
      await service.toggle(CurriculumId.bavli);

      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.bavli,
      );
      expect(isActive, isTrue);
    });

    test('toggle deactivates an active curriculum', () async {
      // Activate two curricula
      await service.activate(CurriculumId.bavli);
      await service.activate(CurriculumId.yerushalmi);

      // Toggle off Bavli
      await service.toggle(CurriculumId.bavli);

      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.bavli,
      );
      expect(isActive, isFalse);
    });

    test(
      'attempting to deactivate the last curriculum throws LastActiveCurriculumException',
      () async {
        await service.activate(CurriculumId.mishnayos);

        expect(
          () => service.deactivate(CurriculumId.mishnayos),
          throwsA(isA<LastActiveCurriculumException>()),
        );
      },
    );

    test(
      'initialize sets default active curriculum (Mishnayos) if none active',
      () async {
        await service.initialize();

        final activeCurricula = await database.activeCurriculumDao
            .getActiveCurricula();
        expect(activeCurricula, contains(CurriculumId.mishnayos.storageKey));
      },
    );

    test('initialize does not override existing active curricula', () async {
      // Pre-activate Bavli
      await database.activeCurriculumDao.activate(CurriculumId.bavli);

      await service.initialize();

      final activeCurricula = await database.activeCurriculumDao
          .getActiveCurricula();
      expect(activeCurricula, contains(CurriculumId.bavli.storageKey));
      expect(
        activeCurricula,
        isNot(contains(CurriculumId.mishnayos.storageKey)),
      );
    });

    test(
      'watchActiveCurricula emits stream of active curriculum IDs',
      () async {
        final stream = service.watchActiveCurricula();

        expect(
          stream,
          emitsInOrder([
            <String>[], // Initial empty state
            [CurriculumId.bavli.storageKey], // After activation
          ]),
        );

        await Future<void>.delayed(
          Duration.zero,
        ); // Let stream emit initial value
        await service.activate(CurriculumId.bavli);
      },
    );

    test('getActiveCurricula returns list of CurriculumId enums', () async {
      await service.activate(CurriculumId.bavli);
      await service.activate(CurriculumId.yerushalmi);

      final activeCurricula = await service.getActiveCurricula();
      expect(
        activeCurricula,
        containsAll([CurriculumId.bavli, CurriculumId.yerushalmi]),
      );
    });

    test('all curricula can be activated simultaneously', () async {
      for (final curriculum in CurriculumId.values) {
        await service.activate(curriculum);
      }

      final activeCurricula = await service.getActiveCurricula();
      expect(activeCurricula, hasLength(CurriculumId.values.length));
      expect(activeCurricula, containsAll(CurriculumId.values));
    });

    test(
      'deactivation soft-deletes the track and preserves completions (DNI-317)',
      () async {
        // Activate two curricula
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);

        // Insert a completion for Bavli
        final bavliTrackId = await getTrackId(CurriculumId.bavli);
        await drift_helpers.seedCompletion(
          database,
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.bavli.storageKey,
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: 'personal',
            trackId: Value(bavliTrackId),
            eventTimestamp: DateTime.now(),
            points: const Value(10),
          ),
        );

        // Deactivate Bavli
        await service.deactivate(CurriculumId.bavli);

        // The track row is soft-deleted (state == 'deleted'), not hard-deleted.
        // W3.28/W3.29: isActive/deletedAt replaced by unified `state` column.
        final allTracks = await database.trackDao.getAllTracks(
          CurriculumId.bavli,
        );
        expect(allTracks, hasLength(1));
        expect(allTracks.first.state, 'deleted');

        // Completion data is preserved — completions are append-only (FR5 / E24).
        final completions = await database.completionDao
            .internalGetCompletionsByCurriculumCrossProfile(
              CurriculumId.bavli.storageKey,
              scope: CrossProfileScope.dataExport,
            );
        expect(completions, hasLength(1));
      },
    );

    test(
      'deactivation preserves bookmarks (curriculum-scoped, not track-scoped)',
      () async {
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);

        final bavliTrackId = await getTrackId(CurriculumId.bavli);

        await database.bookmarkDao.upsertBookmark(
          curriculumId: CurriculumId.bavli.storageKey,
          trackId: bavliTrackId,
          profileId: 0,
          sefariaRef: 'Berakhot.2a',
          updatedAt: DateTime.now().toUtc(),
        );

        await service.deactivate(CurriculumId.bavli);

        final bookmark = await database.bookmarkDao
            .getBookmarkByCurriculumAndTrack(
              CurriculumId.bavli.storageKey,
              bavliTrackId,
            );
        expect(bookmark, isNotNull);
        expect(bookmark!.sefariaRef, equals('Berakhot.2a'));
      },
    );

    test(
      'cannot deactivate all curricula via toggle (last-one-standing)',
      () async {
        // Activate two, then deactivate down to one
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);

        await service.toggle(CurriculumId.bavli);

        // Mishnayos is the last one -- toggling should throw
        expect(
          () => service.toggle(CurriculumId.mishnayos),
          throwsA(isA<LastActiveCurriculumException>()),
        );

        // Verify mishnayos is still active
        final active = await service.getActiveCurricula();
        expect(active, contains(CurriculumId.mishnayos));
        expect(active, hasLength(1));
      },
    );
  });

  // R3-5 regression — study-day configs must be enqueued to the sync outbox
  // on every activation path so a fresh-device restore receives the schedule.
  group('R3-5 — study-day configs enqueued to outbox on activation', () {
    late UserDatabase db;
    late _RecordingSyncFacade facade;

    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      facade = _RecordingSyncFacade();
      await drift_helpers.seedProfile(db);
      await drift_helpers.seedProfileZero(db);
    });

    tearDown(() async => db.close());

    CurriculumActivationService makeService({int profileId = 1}) =>
        CurriculumActivationService(
          database: db,
          pushCurriculumTrack: _dummyPushCurriculumTrack,
          trackRepository: TrackRepositoryImpl(database: db),
          profileId: profileId,
          syncFacade: facade,
        );

    test(
      'activate() seeds 7 local rows AND enqueues 7 outbox pushes for profile+curriculum',
      () async {
        final svc = makeService();
        await svc.activate(CurriculumId.bavli);

        // Local rows: all 7 default study days.
        final localRows = await db.studyDayConfigDao
            .getConfigsByCurriculumAndProfile(CurriculumId.bavli.storageKey, 1);
        expect(
          localRows,
          hasLength(7),
          reason: 'seedDefaults must insert all 7 weekday rows',
        );
        expect(
          localRows.every((r) => r.dayType == 'study'),
          isTrue,
          reason: 'all seeded days must be study days',
        );

        // Outbox / facade: 7 pushStudyDayConfig calls, correct curriculum.
        expect(
          facade.studyDayConfigPushes,
          hasLength(7),
          reason: '_pushStudyDaysCloud must enqueue all 7 days',
        );
        expect(
          facade.studyDayConfigPushes.every(
            (p) =>
                p['curriculum_id'] == CurriculumId.bavli.storageKey &&
                p['profile_id'] == 1,
          ),
          isTrue,
          reason: 'every push must carry correct profile_id + curriculum_id',
        );
        final pushedDays = facade.studyDayConfigPushes
            .map((p) => p['day_of_week'] as int)
            .toSet();
        expect(pushedDays, equals({1, 2, 3, 4, 5, 6, 7}));
      },
    );

    test(
      'activateForProfile() enqueues 7 outbox pushes for the given profile',
      () async {
        // activateForProfile uses an explicit profileId, not _profileId.
        final svc = makeService(profileId: 1);
        await svc.activateForProfile(CurriculumId.mishnayos, 1);

        expect(
          facade.studyDayConfigPushes,
          hasLength(7),
          reason: 'activateForProfile must enqueue all 7 days',
        );
        expect(
          facade.studyDayConfigPushes.every(
            (p) =>
                p['profile_id'] == 1 &&
                p['curriculum_id'] == CurriculumId.mishnayos.storageKey,
          ),
          isTrue,
        );
      },
    );

    test(
      'initialize() enqueues 7 outbox pushes when no curricula are active',
      () async {
        final svc = makeService();
        await svc.initialize();

        expect(
          facade.studyDayConfigPushes,
          hasLength(7),
          reason: 'initialize must enqueue all 7 days for default Mishnayos',
        );
        expect(
          facade.studyDayConfigPushes.every(
            (p) =>
                p['profile_id'] == 1 &&
                p['curriculum_id'] == CurriculumId.mishnayos.storageKey,
          ),
          isTrue,
        );
      },
    );

    test(
      'activate() with null syncFacade is a no-op for outbox but still seeds locally',
      () async {
        // Null facade = local-born account — no outbox needed.
        final svc = CurriculumActivationService(
          database: db,
          pushCurriculumTrack: null,
          trackRepository: TrackRepositoryImpl(database: db),
          profileId: 1,
          syncFacade: null,
        );
        await svc.activate(CurriculumId.yerushalmi);

        final localRows = await db.studyDayConfigDao
            .getConfigsByCurriculumAndProfile(
              CurriculumId.yerushalmi.storageKey,
              1,
            );
        expect(
          localRows,
          hasLength(7),
          reason: 'seedDefaults still runs without a facade',
        );
        // Recording facade received nothing (different instance).
        expect(facade.studyDayConfigPushes, isEmpty);
      },
    );
  });
}
