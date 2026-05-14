// Comprehensive importData coverage for DataExportImportService.
// Each test exercises the code path that inserts rows for one or more
// optional/required import sections.  A round-trip test (export → import)
// ensures the complete importData transaction runs end-to-end.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';

import '../../../../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal valid import payload (all required sections as empty lists,
/// optional sections absent).
Map<String, dynamic> minimalPayload() => {
      'formatVersion': 'schemaV1',
      'exportedAt': '2026-01-01T00:00:00.000Z',
      'appVersion': '1.0.0',
      'userProfiles': <dynamic>[],
      'learnerProfiles': <dynamic>[],
      'curriculumTracks': <dynamic>[],
      'stageDefinitions': <dynamic>[],
      'pointConfigs': <dynamic>[],
      'completions': <dynamic>[],
      'bookmarks': <dynamic>[],
      'learningOrder': <dynamic>[],
      'goals': <dynamic>[],
      'streaks': <dynamic>[],
    };

/// Returns a userProfile map (imported as an account row).
Map<String, dynamic> userProfileMap({
  int id = 1,
  String displayName = 'Test User',
  String tier = 'localBorn',
  String userMode = 'parent',
}) => {
      'id': id,
      'displayName': displayName,
      'tier': tier,
      'userMode': userMode,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    };

/// Returns a curriculumTrack map.
Map<String, dynamic> trackMap({
  int id = 1,
  int profileId = 1,
  String curriculumId = 'bavli',
  String trackType = 'personal',
  bool isActive = true,
}) => {
      'id': id,
      'profileId': profileId,
      'curriculumId': curriculumId,
      'trackType': trackType,
      'isActive': isActive,
      'activatedAt': '2026-01-01T00:00:00.000Z',
      'deactivatedAt': null,
      'paceResetDate': null,
      'deletedAt': null,
    };

/// Returns a stageDefinition map.
Map<String, dynamic> stageMap({
  int trackId = 1,
  int stageOrder = 1,
  String stageName = 'Learn',
  int delayDays = 0,
}) => {
      'profileId': 1,
      'curriculumId': 'bavli',
      'trackId': trackId,
      'stageOrder': stageOrder,
      'stageName': stageName,
      'delayDays': delayDays,
      'isDefault': true,
    };

/// Returns a pointConfig map.
Map<String, dynamic> pointConfigMap({int trackId = 1, int stageOrder = 1}) => {
      'profileId': 1,
      'curriculumId': 'bavli',
      'trackId': trackId,
      'stageOrder': stageOrder,
      'points': 10,
    };

/// Returns a completion map.
Map<String, dynamic> completionMap({int trackId = 1, int stageId = 1}) => {
      'profileId': 1,
      'curriculumId': 'bavli',
      'sefariaRef': 'Berakhot.2a',
      'stageId': stageId,
      'trackType': 'personal',
      'trackId': trackId,
      'completedAt': '2026-03-01T00:00:00.000Z',
      'points': 5,
    };

/// Returns a streak map.
Map<String, dynamic> streakMap({int profileId = 1}) => {
      'profileId': profileId,
      'currentStreak': 7,
      'maxStreak': 14,
      'lastCompletionDate': '2026-05-13T00:00:00.000Z',
      'graceUsedDate': null,
      'gracePeriodDays': 1,
    };

/// Returns a goal map.
Map<String, dynamic> goalMap({int trackId = 1}) => {
      'profileId': 1,
      'curriculumId': 'bavli',
      'trackId': trackId,
      'targetPercent': 90.0,
      'targetDate': null,
      'description': '',
      'dateType': 'gregorian',
      'goalType': 'deadline',
      'paceValue': null,
      'pacePeriod': null,
      'paceGranularity': null,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    };

/// Returns a bookmark map.
Map<String, dynamic> bookmarkMap({int trackId = 1}) => {
      'profileId': 1,
      'curriculumId': 'bavli',
      'trackId': trackId,
      'sefariaRef': 'Berakhot.2a',
      'updatedAt': '2026-05-01T00:00:00.000Z',
    };

/// Returns a learningOrder map.
Map<String, dynamic> learningOrderMap({
  String sefariaRef = 'Berakhot.2a',
  int userSortOrder = 1,
}) => {
      'profileId': 1,
      'curriculumId': 'bavli',
      'sefariaRef': sefariaRef,
      'userSortOrder': userSortOrder,
      'updatedAt': '2026-05-01T00:00:00.000Z',
    };

void main() {
  late UserDatabase db;
  late DataExportImportService service;

  setUp(() {
    db = inMemoryDb();
    service = DataExportImportService(
      database: db,
      appVersionFetcher: () async => '1.0.0',
    );
  });

  tearDown(() async {
    await db.close();
  });

  // =========================================================================
  // importData — minimal payload (empty sections)
  // =========================================================================

  group('DataExportImportService.importData — minimal payload', () {
    test('completes without error on fully-empty payload', () async {
      final json = jsonEncode(minimalPayload());
      await expectLater(service.importData(json), completes);
    });

    test('clears existing data before importing', () async {
      // Pre-populate a track.
      await db.into(db.curriculumTracks).insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              trackType: 'personal',
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      // Import with empty curriculumTracks — should wipe the existing row.
      await service.importData(jsonEncode(minimalPayload()));

      final tracks = await db.select(db.curriculumTracks).get();
      expect(tracks, isEmpty);
    });
  });

  // =========================================================================
  // importData — userProfiles section
  // =========================================================================

  group('DataExportImportService.importData — userProfiles', () {
    test('inserts account rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1, displayName: 'Alice')];

      await service.importData(jsonEncode(payload));

      final accounts = await db.select(db.accounts).get();
      expect(accounts, hasLength(1));
      expect(accounts.first.displayName, 'Alice');
    });

    test('uses placeholder email with original id', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 42)];

      await service.importData(jsonEncode(payload));

      final accounts = await db.select(db.accounts).get();
      expect(accounts.first.email, contains('42'));
    });

    test('imports multiple accounts', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [
          userProfileMap(id: 1, displayName: 'Alice'),
          userProfileMap(id: 2, displayName: 'Bob'),
        ];

      await service.importData(jsonEncode(payload));

      final accounts = await db.select(db.accounts).get();
      expect(accounts, hasLength(2));
    });
  });

  // =========================================================================
  // importData — learnerProfiles section (optional)
  // =========================================================================

  group('DataExportImportService.importData — learnerProfiles', () {
    test('inserts learner profile rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [
          {
            'accountId': 1,
            'displayName': 'Child A',
            'mode': 'child',
            'avatarIndex': 2,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ];

      await service.importData(jsonEncode(payload));

      final profiles = await db.select(db.learnerProfiles).get();
      expect(profiles, hasLength(1));
      expect(profiles.first.displayName, 'Child A');
    });
  });

  // =========================================================================
  // importData — curriculumTracks
  // =========================================================================

  group('DataExportImportService.importData — curriculumTracks', () {
    test('inserts track rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [trackMap(id: 1, profileId: 1)];

      await service.importData(jsonEncode(payload));

      final tracks = await db.select(db.curriculumTracks).get();
      expect(tracks, hasLength(1));
      expect(tracks.first.curriculumId, 'bavli');
      expect(tracks.first.isActive, isTrue);
    });

    test('handles optional deactivatedAt and paceResetDate fields', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [
          {
            ...trackMap(id: 1),
            'deactivatedAt': '2026-06-01T00:00:00.000Z',
            'paceResetDate': '2026-04-01T00:00:00.000Z',
          },
        ];

      await service.importData(jsonEncode(payload));

      final tracks = await db.select(db.curriculumTracks).get();
      expect(tracks.first.deactivatedAt, isNotNull);
      expect(tracks.first.paceResetDate, isNotNull);
    });
  });

  // =========================================================================
  // importData — curriculumScopes (optional)
  // =========================================================================

  group('DataExportImportService.importData — curriculumScopes', () {
    test('inserts curriculum scope rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [trackMap(id: 1, profileId: 1)]
        ..['curriculumScopes'] = [
          {
            'profileId': 1,
            'curriculumId': 'bavli',
            'trackId': 1,
            'scopeLevel': 1,
            'scopeValue': 'Berakhot',
            'createdAt': '2026-01-01T00:00:00.000Z',
          },
        ];

      await service.importData(jsonEncode(payload));

      final scopes = await db.select(db.curriculumScopes).get();
      expect(scopes, hasLength(1));
      expect(scopes.first.scopeValue, 'Berakhot');
    });
  });

  // =========================================================================
  // importData — profilePrograms (optional)
  // =========================================================================

  group('DataExportImportService.importData — profilePrograms', () {
    test('inserts profile program rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['profilePrograms'] = [
          {
            'profileId': 1,
            'curriculumType': 'bavli',
            'programId': 99,
            'trackingStartDate': null,
            'trackingStartRef': null,
          },
        ];

      await service.importData(jsonEncode(payload));

      final programs = await db.select(db.profilePrograms).get();
      expect(programs, hasLength(1));
      expect(programs.first.programId, 99);
    });
  });

  // =========================================================================
  // importData — stageDefinitions
  // =========================================================================

  group('DataExportImportService.importData — stageDefinitions', () {
    test('inserts stage definition rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [trackMap(id: 1)]
        ..['stageDefinitions'] = [stageMap(trackId: 1)];

      await service.importData(jsonEncode(payload));

      final stages = await db.select(db.stageDefinitions).get();
      expect(stages, hasLength(1));
      expect(stages.first.stageName, 'Learn');
    });
  });

  // =========================================================================
  // importData — pointConfigs
  // =========================================================================

  group('DataExportImportService.importData — pointConfigs', () {
    test('inserts point config rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [trackMap(id: 1)]
        ..['pointConfigs'] = [pointConfigMap(trackId: 1)];

      await service.importData(jsonEncode(payload));

      final configs = await db.select(db.pointConfigs).get();
      expect(configs, hasLength(1));
      expect(configs.first.points, 10);
    });
  });

  // =========================================================================
  // importData — studyDayConfigs (optional)
  // =========================================================================

  group('DataExportImportService.importData — studyDayConfigs', () {
    test('inserts study day config rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [trackMap(id: 1)]
        ..['studyDayConfigs'] = [
          {
            'profileId': 1,
            'curriculumId': 'bavli',
            'trackId': 1,
            'dayOfWeek': 2,
            'dayType': 'study',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ];

      await service.importData(jsonEncode(payload));

      final configs = await db.select(db.studyDayConfigs).get();
      expect(configs, hasLength(1));
      expect(configs.first.dayOfWeek, 2);
    });
  });

  // =========================================================================
  // importData — completions
  // =========================================================================

  group('DataExportImportService.importData — completions', () {
    test('inserts completion rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [trackMap(id: 1)]
        ..['completions'] = [completionMap(trackId: 1, stageId: 1)];

      await service.importData(jsonEncode(payload));

      final completions = await db.select(db.completions).get();
      expect(completions, hasLength(1));
      expect(completions.first.sefariaRef, 'Berakhot.2a');
      expect(completions.first.points, 5);
    });
  });

  // =========================================================================
  // importData — completionEvents (optional)
  // =========================================================================

  group('DataExportImportService.importData — completionEvents', () {
    test('inserts completion event rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['completionEvents'] = [
          {
            'profileId': 1,
            'curriculumId': 'bavli',
            'sefariaRef': 'Berakhot.2a',
            'stageId': 1,
            'trackType': 'personal',
            'eventTimestamp': '2026-03-01T00:00:00.000Z',
            'createdAt': '2026-03-01T00:00:00.000Z',
          },
        ];

      await service.importData(jsonEncode(payload));

      final events = await db.select(db.completionEvents).get();
      expect(events, hasLength(1));
      expect(events.first.sefariaRef, 'Berakhot.2a');
    });
  });

  // =========================================================================
  // importData — dailyPlans (optional)
  // =========================================================================

  group('DataExportImportService.importData — dailyPlans', () {
    test('inserts daily plan rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [trackMap(id: 1)]
        ..['dailyPlans'] = [
          {
            'profileId': 1,
            'curriculumId': 'bavli',
            'planDate': '2026-05-01T00:00:00.000Z',
            'sefariaRef': 'Berakhot.2a',
            'stageOrder': 1,
            'stageDefinitionId': 1,
            'trackId': 1,
            'trackLabel': '',
            'priority': 'normal',
            'isOverdue': false,
            'reason': '',
            'stageName': 'Learn',
            'estimatedEffortMinutes': 5,
            'sortOrder': 0,
            'createdAt': '2026-05-01T00:00:00.000Z',
          },
        ];

      await service.importData(jsonEncode(payload));

      final plans = await db.select(db.dailyPlans).get();
      expect(plans, hasLength(1));
      expect(plans.first.sefariaRef, 'Berakhot.2a');
      expect(plans.first.priority, 'normal');
    });
  });

  // =========================================================================
  // importData — learningLedger (optional)
  // =========================================================================

  group('DataExportImportService.importData — learningLedger', () {
    test('inserts learning ledger rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learningLedger'] = [
          {
            'profileId': 1,
            'ulid': '01HX0000000000000000000001',
            'curriculumId': 'bavli',
            'entryScope': 'daf',
            'unitIdentifier': 'Berakhot.2a',
            'unitDisplayNameHe': 'ברכות ב',
            'unitDisplayNameEn': 'Berakhot 2a',
            'trackType': 'personal',
            'trackId': null,
            'completedAt': '2026-03-01T00:00:00.000Z',
            'completionNumber': 1,
            'markedBy': 1,
            'isManual': false,
            'createdAt': '2026-03-01T00:00:00.000Z',
          },
        ];

      await service.importData(jsonEncode(payload));

      final ledger = await db.select(db.learningLedger).get();
      expect(ledger, hasLength(1));
      expect(ledger.first.unitIdentifier, 'Berakhot.2a');
    });
  });

  // =========================================================================
  // importData — bookmarks
  // =========================================================================

  group('DataExportImportService.importData — bookmarks', () {
    test('inserts bookmark rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [trackMap(id: 1)]
        ..['bookmarks'] = [bookmarkMap(trackId: 1)];

      await service.importData(jsonEncode(payload));

      final bms = await db.select(db.bookmarks).get();
      expect(bms, hasLength(1));
      expect(bms.first.sefariaRef, 'Berakhot.2a');
    });
  });

  // =========================================================================
  // importData — learningOrder
  // =========================================================================

  group('DataExportImportService.importData — learningOrder', () {
    test('inserts learning order rows', () async {
      final payload = minimalPayload()
        ..['learningOrder'] = [
          learningOrderMap(sefariaRef: 'Berakhot.2a', userSortOrder: 3),
        ];

      await service.importData(jsonEncode(payload));

      final orders = await db.select(db.learningOrder).get();
      expect(orders, hasLength(1));
      expect(orders.first.userSortOrder, 3);
    });
  });

  // =========================================================================
  // importData — trackLearningOrder (optional)
  // =========================================================================

  group('DataExportImportService.importData — trackLearningOrder', () {
    test('inserts track learning order rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [trackMap(id: 1)]
        ..['trackLearningOrder'] = [
          {
            'trackId': 1,
            'sefariaRef': 'Berakhot.2a',
            'sortOrder': 1,
          },
        ];

      await service.importData(jsonEncode(payload));

      final orders = await db.select(db.trackLearningOrder).get();
      expect(orders, hasLength(1));
      expect(orders.first.sefariaRef, 'Berakhot.2a');
    });
  });

  // =========================================================================
  // importData — goals
  // =========================================================================

  group('DataExportImportService.importData — goals', () {
    test('inserts goal rows', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [trackMap(id: 1)]
        ..['goals'] = [goalMap(trackId: 1)];

      await service.importData(jsonEncode(payload));

      final goals = await db.select(db.goals).get();
      expect(goals, hasLength(1));
    });

    test('handles optional targetDate field', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [trackMap(id: 1)]
        ..['goals'] = [
          {
            ...goalMap(trackId: 1),
            'targetDate': '2026-12-31T00:00:00.000Z',
          },
        ];

      await service.importData(jsonEncode(payload));

      final goals = await db.select(db.goals).get();
      expect(goals.first.targetDate, isNotNull);
    });
  });

  // =========================================================================
  // importData — streaks
  // =========================================================================

  group('DataExportImportService.importData — streaks', () {
    test('inserts streak rows', () async {
      final payload = minimalPayload()
        ..['streaks'] = [streakMap(profileId: 1)];

      await service.importData(jsonEncode(payload));

      final streaks = await db.select(db.streaks).get();
      expect(streaks, hasLength(1));
      expect(streaks.first.currentStreak, 7);
      expect(streaks.first.maxStreak, 14);
    });

    test('handles optional lastCompletionDate and graceUsedDate', () async {
      final payload = minimalPayload()
        ..['streaks'] = [
          {
            ...streakMap(),
            'graceUsedDate': '2026-05-12T00:00:00.000Z',
          },
        ];

      await service.importData(jsonEncode(payload));

      final streaks = await db.select(db.streaks).get();
      expect(streaks.first.graceUsedDate, isNotNull);
    });
  });

  // =========================================================================
  // importData — streakEvents (optional)
  // =========================================================================

  group('DataExportImportService.importData — streakEvents', () {
    test('inserts streak event rows', () async {
      final payload = minimalPayload()
        ..['streakEvents'] = [
          {
            'profileId': 1,
            'eventType': 'study',
            'dayUtc': '2026-05-13T00:00:00.000Z',
            'eventTimestamp': '2026-05-13T12:00:00.000Z',
            'clientDeviceId': 'device-abc',
            'createdAt': '2026-05-13T12:00:01.000Z',
          },
        ];

      await service.importData(jsonEncode(payload));

      final events = await db.select(db.streakEvents).get();
      expect(events, hasLength(1));
      expect(events.first.eventType, 'study');
      expect(events.first.clientDeviceId, 'device-abc');
    });
  });

  // =========================================================================
  // importData — full round-trip (export → import → verify)
  // =========================================================================

  group('DataExportImportService — full round-trip', () {
    test('round-trips all sections via export/import', () async {
      // 1. Populate source database.
      final now = DateTime.utc(2026, 1, 1);

      // Insert account.
      final accountId = await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              email: 'user@test.example',
              tier: 'localBorn',
              displayName: 'Round-trip User',
              userMode: 'parent',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Insert track.
      final trackId = await db.into(db.curriculumTracks).insert(
            CurriculumTracksCompanion.insert(
              profileId: accountId,
              curriculumId: 'bavli',
              trackType: 'personal',
              activatedAt: now,
            ),
          );

      // Insert stage.
      await db.into(db.stageDefinitions).insert(
            StageDefinitionsCompanion.insert(
              profileId: accountId,
              curriculumId: 'bavli',
              trackId: trackId,
              stageOrder: 1,
              stageName: 'Learn',
              delayDays: 0,
            ),
          );

      // Insert point config.
      await db.into(db.pointConfigs).insert(
            PointConfigsCompanion.insert(
              profileId: accountId,
              curriculumId: 'bavli',
              trackId: trackId,
              stageOrder: 1,
              points: 10,
            ),
          );

      // Insert completion.
      await db.into(db.completions).insert(
            CompletionsCompanion.insert(
              profileId: accountId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: 'personal',
              trackId: trackId,
              completedAt: now,
              points: const Value(5),
            ),
          );

      // Insert goal.
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: accountId,
          curriculumId: 'bavli',
          trackId: trackId,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Insert streak.
      await db.into(db.streaks).insert(
            StreaksCompanion.insert(profileId: accountId),
          );

      // Insert streak event.
      await db.into(db.streakEvents).insert(
            StreakEventsCompanion.insert(
              profileId: accountId,
              eventType: 'study',
              dayUtc: now,
              eventTimestamp: now,
            ),
          );

      // Insert bookmark.
      await db.into(db.bookmarks).insert(
            BookmarksCompanion.insert(
              profileId: accountId,
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot.2a',
              updatedAt: now,
            ),
          );

      // Insert learningOrder.
      await db.into(db.learningOrder).insert(
            LearningOrderCompanion.insert(
              profileId: accountId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2a',
              userSortOrder: 1,
            ),
          );

      // Insert trackLearningOrder.
      await db.into(db.trackLearningOrder).insert(
            TrackLearningOrderCompanion.insert(
              trackId: trackId,
              sefariaRef: 'Berakhot.2a',
              sortOrder: 1,
            ),
          );

      // 2. Export.
      final exported = await service.exportData();

      // 3. Import into the same DB (wipes then re-inserts).
      await service.importData(exported);

      // 4. Verify counts survive the round-trip.
      expect(await db.select(db.accounts).get(), hasLength(1));
      expect(await db.select(db.curriculumTracks).get(), hasLength(1));
      expect(await db.select(db.stageDefinitions).get(), hasLength(1));
      expect(await db.select(db.pointConfigs).get(), hasLength(1));
      expect(await db.select(db.completions).get(), hasLength(1));
      expect(await db.select(db.streaks).get(), hasLength(1));
      expect(await db.select(db.streakEvents).get(), hasLength(1));
      expect(await db.select(db.bookmarks).get(), hasLength(1));
      expect(await db.select(db.learningOrder).get(), hasLength(1));
      expect(await db.select(db.trackLearningOrder).get(), hasLength(1));
    });

    test('importData is idempotent when called twice', () async {
      final payload = minimalPayload()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [trackMap(id: 1)]
        ..['streaks'] = [streakMap()];

      final json = jsonEncode(payload);
      await service.importData(json);
      await service.importData(json); // second import should replace first

      expect(await db.select(db.accounts).get(), hasLength(1));
      expect(await db.select(db.curriculumTracks).get(), hasLength(1));
      expect(await db.select(db.streaks).get(), hasLength(1));
    });
  });

  // =========================================================================
  // exportData — learningLedger serialization (covers lines 348-368)
  // =========================================================================

  group('DataExportImportService.exportData — learningLedger', () {
    test('serializes learning ledger rows', () async {
      final ts = DateTime.utc(2026, 3, 15);
      await db.into(db.learningLedger).insert(
            LearningLedgerCompanion.insert(
              profileId: 1,
              ulid: const Value('01HX0000000000000000000001'),
              curriculumId: 'bavli',
              entryScope: 'daf',
              unitIdentifier: 'Berakhot.3a',
              unitDisplayNameHe: 'ברכות ג',
              unitDisplayNameEn: 'Berakhot 3a',
              trackType: 'personal',
              completedAt: ts,
              completionNumber: 2,
              markedBy: 1,
            ),
          );

      final raw = await service.exportData();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final ledger =
          (decoded['learningLedger'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(ledger, hasLength(1));
      expect(ledger.first['unitIdentifier'], 'Berakhot.3a');
      expect(ledger.first['completionNumber'], 2);
      expect(ledger.first['ulid'], '01HX0000000000000000000001');
    });
  });

  // =========================================================================
  // exportData — trackLearningOrder serialization (covers lines 396-405)
  // =========================================================================

  group('DataExportImportService.exportData — trackLearningOrder', () {
    test('serializes track learning order rows', () async {
      final trackId = await db.into(db.curriculumTracks).insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              trackType: 'personal',
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await db.into(db.trackLearningOrder).insert(
            TrackLearningOrderCompanion.insert(
              trackId: trackId,
              sefariaRef: 'Berakhot.4a',
              sortOrder: 5,
            ),
          );

      final raw = await service.exportData();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final orders = (decoded['trackLearningOrder'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(orders, hasLength(1));
      expect(orders.first['sefariaRef'], 'Berakhot.4a');
      expect(orders.first['sortOrder'], 5);
      expect(orders.first['trackId'], trackId);
    });
  });

  // =========================================================================
  // exportData — streakEvents serialization (covers lines 442-454)
  // =========================================================================

  group('DataExportImportService.exportData — streakEvents', () {
    test('serializes streak event rows', () async {
      final ts = DateTime.utc(2026, 5, 10);
      await db.into(db.streakEvents).insert(
            StreakEventsCompanion.insert(
              profileId: 1,
              eventType: 'grace',
              dayUtc: ts,
              eventTimestamp: ts,
              clientDeviceId: const Value('dev-xyz'),
            ),
          );

      final raw = await service.exportData();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final events = (decoded['streakEvents'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(events, hasLength(1));
      expect(events.first['eventType'], 'grace');
      expect(events.first['clientDeviceId'], 'dev-xyz');
    });
  });
}
