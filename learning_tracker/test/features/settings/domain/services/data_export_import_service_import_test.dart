// Comprehensive importData coverage for DataExportImportService.
// Each test exercises the code path that inserts rows for one or more
// optional/required import sections.  A round-trip test (export → import)
// ensures the complete importData transaction runs end-to-end.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';

import '../../../../helpers/data_export_fixtures.dart';
import '../../../../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Row builders live in test/helpers/data_export_fixtures.dart
// (AUD-t-settings-08) — this file used to hand-roll its own copies
// (minimalPayload/userProfileMap/trackMap/stageMap/etc.); it is now the
// model the shared fixture is built from. `trackMap` → `curriculumTrackMap`,
// `stageMap` → `stageDefinitionMap`, `streakMap` → `legacyStreakMap` in the
// shared fixture; everything else kept its name.
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;
  late DataExportImportService service;

  setUp(() async {
    db = inMemoryDb();
    service = DataExportImportService(
      database: db,
      appVersionFetcher: () async => '1.0.0',
    );
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  // =========================================================================
  // importData — minimal payload (empty sections)
  // =========================================================================

  group('DataExportImportService.importData — minimal payload', () {
    test('completes without error on fully-empty payload', () async {
      final json = jsonEncode(exportPayloadMap());
      await expectLater(service.importData(json), completes);
    });

    test(
      'clears existing data for the imported profile before importing',
      () async {
        // Pre-populate a track for profile 1 (seedProfile in setUp created
        // account id=1 / learner profile id=1).
        await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'bavli',
                stateChangedAt: DateTime.utc(2026, 1, 1),
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );

        // AUD-settings-03: clears are scoped to the profiles/accounts present
        // in the payload — include profile 1 so it's in scope, then import
        // with an empty curriculumTracks section. The pre-existing row for
        // profile 1 should still be wiped.
        final payload = exportPayloadMap()
          ..['userProfiles'] = [userProfileMap(id: 1)]
          ..['learnerProfiles'] = [learnerProfileMap(id: 1, accountId: 1)];
        await service.importData(jsonEncode(payload));

        final tracks = await db.select(db.curriculumTracks).get();
        expect(tracks, isEmpty);
      },
    );
  });

  // =========================================================================
  // importData — userProfiles section
  // =========================================================================

  group('DataExportImportService.importData — userProfiles', () {
    test('inserts account rows', () async {
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1, displayName: 'Alice')];

      await service.importData(jsonEncode(payload));

      final accounts = await db.select(db.accounts).get();
      expect(accounts, hasLength(1));
      expect(accounts.first.displayName, 'Alice');
    });

    test('uses placeholder email with original id', () async {
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 42)];

      await service.importData(jsonEncode(payload));

      // AUD-settings-03: import is scoped to account id 42 only, so the
      // seedProfile-created account (id 1) also survives untouched —
      // look up the imported account explicitly rather than assuming it's
      // the only (or first) row.
      final imported = await (db.select(
        db.accounts,
      )..where((t) => t.id.equals(42))).getSingle();
      expect(imported.email, contains('42'));
    });

    test('imports multiple accounts', () async {
      final payload = exportPayloadMap()
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
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [
          {
            // T-41: required — importData's learnerProfiles insert now casts
            // this straight to String (mirrors the learningLedger section).
            'ulid': 'ulid-child-a',
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
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [curriculumTrackMap(id: 1, profileId: 1)];

      await service.importData(jsonEncode(payload));

      final tracks = await db.select(db.curriculumTracks).get();
      expect(tracks, hasLength(1));
      expect(tracks.first.curriculumId, 'bavli');
      expect(tracks.first.state, 'active');
    });

    test('handles optional deactivatedAt and paceResetDate fields', () async {
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [
          // Drop `stateChangedAt` (the current-schema field) so importData()
          // exercises its legacy back-compat fallback: it reads
          // `stateChangedAt` from `deactivatedAt` when the former is absent.
          {
            ...(curriculumTrackMap(id: 1)..remove('stateChangedAt')),
            'deactivatedAt': '2026-06-01T00:00:00.000Z',
            'paceResetDate': '2026-04-01T00:00:00.000Z',
          },
        ];

      await service.importData(jsonEncode(payload));

      final tracks = await db.select(db.curriculumTracks).get();
      expect(tracks.first.stateChangedAt, isNotNull);
      expect(tracks.first.paceResetDate, isNotNull);
    });
  });

  // =========================================================================
  // importData — curriculumScopes (optional)
  // =========================================================================

  group('DataExportImportService.importData — curriculumScopes', () {
    test('inserts curriculum scope rows', () async {
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [learnerProfileMap()]
        ..['curriculumTracks'] = [curriculumTrackMap(id: 1, profileId: 1)]
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
      final payload = exportPayloadMap()
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
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [learnerProfileMap()]
        ..['curriculumTracks'] = [curriculumTrackMap(id: 1)]
        ..['stageDefinitions'] = [stageDefinitionMap(trackId: 1)];

      await service.importData(jsonEncode(payload));

      final stages = await db.select(db.stageDefinitions).get();
      expect(stages, hasLength(1));
      expect(stages.first.stageName, 'Learn');
    });
  });

  // =========================================================================
  // importData — stageDefinitions.schedule back-compat (AUD-settings-05)
  //
  // _resolveScheduleJson() normalises two export shapes into the
  // `stage_definitions.schedule` JSON column: the pre-W3.27 quartet
  // (scheduleType/daysOfWeek/rollingWindowSize/delayDays) and the current
  // `schedule` field. Every stage-definition fixture elsewhere in this
  // suite hits only the `default: delay` fallback branch (no scheduleType
  // at all); these tests cover the other three branches so a legacy-backup
  // restore of a weekly/rolling schedule is provably correct.
  // =========================================================================

  group(
    'DataExportImportService.importData — stageDefinitions schedule back-compat',
    () {
      test('legacy scheduleType "weekly" with JSON-string daysOfWeek resolves '
          'to a weekly schedule column', () async {
        final payload = exportPayloadMap()
          ..['userProfiles'] = [userProfileMap(id: 1)]
          ..['learnerProfiles'] = [learnerProfileMap()]
          ..['curriculumTracks'] = [curriculumTrackMap(id: 1)]
          ..['stageDefinitions'] = [
            {
              ...stageDefinitionMap(trackId: 1),
              'scheduleType': 'weekly',
              'daysOfWeek': jsonEncode([1, 3, 5]),
            },
          ];

        await service.importData(jsonEncode(payload));

        final stages = await db.select(db.stageDefinitions).get();
        expect(stages, hasLength(1));
        final decoded =
            jsonDecode(stages.first.schedule) as Map<String, dynamic>;
        expect(decoded['type'], 'weekly');
        expect(decoded['days_of_week'], [1, 3, 5]);
      });

      test('legacy scheduleType "weekly" with a native-List daysOfWeek '
          'resolves to a weekly schedule column', () async {
        final payload = exportPayloadMap()
          ..['userProfiles'] = [userProfileMap(id: 1)]
          ..['learnerProfiles'] = [learnerProfileMap()]
          ..['curriculumTracks'] = [curriculumTrackMap(id: 1)]
          ..['stageDefinitions'] = [
            {
              ...stageDefinitionMap(trackId: 1),
              'scheduleType': 'weekly',
              'daysOfWeek': [0, 2, 4],
            },
          ];

        await service.importData(jsonEncode(payload));

        final stages = await db.select(db.stageDefinitions).get();
        expect(stages, hasLength(1));
        final decoded =
            jsonDecode(stages.first.schedule) as Map<String, dynamic>;
        expect(decoded['type'], 'weekly');
        expect(decoded['days_of_week'], [0, 2, 4]);
      });

      test('legacy scheduleType "rolling" resolves to a rolling schedule '
          'column carrying the window size', () async {
        final payload = exportPayloadMap()
          ..['userProfiles'] = [userProfileMap(id: 1)]
          ..['learnerProfiles'] = [learnerProfileMap()]
          ..['curriculumTracks'] = [curriculumTrackMap(id: 1)]
          ..['stageDefinitions'] = [
            {
              ...stageDefinitionMap(trackId: 1),
              'scheduleType': 'rolling',
              'rollingWindowSize': 14,
            },
          ];

        await service.importData(jsonEncode(payload));

        final stages = await db.select(db.stageDefinitions).get();
        expect(stages, hasLength(1));
        final decoded =
            jsonDecode(stages.first.schedule) as Map<String, dynamic>;
        expect(decoded['type'], 'rolling');
        expect(decoded['rolling_window_size'], 14);
      });

      test('a pre-populated new-schema "schedule" field is passed through '
          'verbatim, bypassing the legacy quartet', () async {
        const scheduleJson = '{"type":"delay","delay_days":9}';
        final payload = exportPayloadMap()
          ..['userProfiles'] = [userProfileMap(id: 1)]
          ..['learnerProfiles'] = [learnerProfileMap()]
          ..['curriculumTracks'] = [curriculumTrackMap(id: 1)]
          ..['stageDefinitions'] = [
            stageDefinitionMap(trackId: 1, schedule: scheduleJson),
          ];

        await service.importData(jsonEncode(payload));

        final stages = await db.select(db.stageDefinitions).get();
        expect(stages, hasLength(1));
        expect(stages.first.schedule, scheduleJson);
      });
    },
  );

  // =========================================================================
  // importData — pointConfigs
  // =========================================================================

  group('DataExportImportService.importData — pointConfigs', () {
    test('inserts point config rows', () async {
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [curriculumTrackMap(id: 1)]
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
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [curriculumTrackMap(id: 1)]
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
      // W3.20: the old `completions` section is skipped on import;
      // use `completionEvents` section instead.
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [learnerProfileMap()]
        ..['completionEvents'] = [
          {
            'profileId': 1,
            'curriculumId': 'bavli',
            'sefariaRef': 'Berakhot.2a',
            'stageId': 1,
            'trackType': 'personal',
            'trackId': 1,
            'eventTimestamp': '2026-03-01T00:00:00.000Z',
            'createdAt': '2026-03-01T00:00:00.000Z',
            'points': 5,
          },
        ];

      await service.importData(jsonEncode(payload));

      final completions = await db.select(db.completionEvents).get();
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
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [learnerProfileMap()]
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
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['curriculumTracks'] = [curriculumTrackMap(id: 1)]
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
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [learnerProfileMap()]
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
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [learnerProfileMap()]
        ..['curriculumTracks'] = [curriculumTrackMap(id: 1)]
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
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [learnerProfileMap()]
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
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [learnerProfileMap()]
        ..['curriculumTracks'] = [curriculumTrackMap(id: 1)]
        ..['trackLearningOrder'] = [
          {'trackId': 1, 'sefariaRef': 'Berakhot.2a', 'sortOrder': 1},
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
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [learnerProfileMap()]
        ..['curriculumTracks'] = [curriculumTrackMap(id: 1)]
        ..['goals'] = [goalMap(trackId: 1)];

      await service.importData(jsonEncode(payload));

      final goals = await db.select(db.goals).get();
      expect(goals, hasLength(1));
    });

    test('handles optional targetDate field', () async {
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [learnerProfileMap()]
        ..['curriculumTracks'] = [curriculumTrackMap(id: 1)]
        ..['goals'] = [
          {...goalMap(trackId: 1), 'targetDate': '2026-12-31T00:00:00.000Z'},
        ];

      await service.importData(jsonEncode(payload));

      final goals = await db.select(db.goals).get();
      expect(goals.first.targetDate, isNotNull);
    });
  });

  // =========================================================================
  // importData — streaks
  // =========================================================================

  // Legacy `streaks` key is ignored in Wave 3 — import service skips it.
  // Streak state is derived from streakEvents. Tests moved to streakEvents group.
  group('DataExportImportService.importData — streaks (legacy)', () {
    test('legacy streaks key is silently skipped', () async {
      final payload = exportPayloadMap()
        ..['streaks'] = [legacyStreakMap(profileId: 1)];

      await service.importData(jsonEncode(payload));

      // The import service ignores the legacy `streaks` key.
      final streakRows = await db.select(db.streakEvents).get();
      expect(streakRows, isEmpty);
    });
  });

  // =========================================================================
  // importData — streakEvents (optional)
  // =========================================================================

  group('DataExportImportService.importData — streakEvents', () {
    test('inserts streak event rows', () async {
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [learnerProfileMap()]
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
      // seedProfile (in setUp) already created account id=1 and learner
      // profile id=1. Use profileId=1 throughout so FK constraints are met.
      final now = DateTime.utc(2026, 1, 1);
      const profileId = 1;

      // Insert track.
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              stateChangedAt: now,
              activatedAt: now,
            ),
          );

      // Insert stage.
      await db
          .into(db.stageDefinitions)
          .insert(
            StageDefinitionsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              stageOrder: 1,
              stageName: 'Learn',
              schedule: const Value('{"type":"delay","delay_days":0}'),
            ),
          );

      // Insert point config.
      await db
          .into(db.pointConfigs)
          .insert(
            PointConfigsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              stageOrder: 1,
              points: 10,
            ),
          );

      // Insert completion.
      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: profileId,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot.2a',
          stageId: 1,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: now,
        ),
      );

      // Insert goal.
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: profileId,
          curriculumId: 'bavli',
          trackId: trackId,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Insert streak.
      await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profileId,
              eventType: 'completion',
              dayUtc: now,
              eventTimestamp: now,
            ),
          );

      // Insert streak event.
      await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profileId,
              eventType: 'study',
              dayUtc: now,
              eventTimestamp: now,
            ),
          );

      // Insert bookmark.
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              sefariaRef: 'Berakhot.2a',
              updatedAt: now,
            ),
          );

      // Insert learningOrder.
      await db
          .into(db.learningOrder)
          .insert(
            LearningOrderCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2a',
              userSortOrder: 1,
            ),
          );

      // Insert trackLearningOrder.
      await db
          .into(db.trackLearningOrder)
          .insert(
            TrackLearningOrderCompanion.insert(
              profileId: profileId,
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
      expect(await db.select(db.completionEvents).get(), hasLength(1));
      // Two streak events seeded above (completion + study).
      expect(await db.select(db.streakEvents).get(), hasLength(2));
      expect(await db.select(db.bookmarks).get(), hasLength(1));
      expect(await db.select(db.learningOrder).get(), hasLength(1));
      expect(await db.select(db.trackLearningOrder).get(), hasLength(1));
    });

    test('importData is idempotent when called twice', () async {
      // W3.37: old `streaks` section is skipped; use `streakEvents` instead.
      final payload = exportPayloadMap()
        ..['userProfiles'] = [userProfileMap(id: 1)]
        ..['learnerProfiles'] = [learnerProfileMap()]
        ..['curriculumTracks'] = [curriculumTrackMap(id: 1)]
        ..['streakEvents'] = [
          {
            'profileId': 1,
            'eventType': 'completion',
            'dayUtc': '2026-05-01T00:00:00.000Z',
            'eventTimestamp': '2026-05-01T00:00:00.000Z',
            'createdAt': '2026-05-01T00:00:00.000Z',
          },
        ];

      final json = jsonEncode(payload);
      await service.importData(json);
      await service.importData(json); // second import should replace first

      expect(await db.select(db.accounts).get(), hasLength(1));
      expect(await db.select(db.curriculumTracks).get(), hasLength(1));
      expect(await db.select(db.streakEvents).get(), hasLength(1));
    });
  });

  // =========================================================================
  // exportData — learningLedger serialization (covers lines 348-368)
  // =========================================================================

  group('DataExportImportService.exportData — learningLedger', () {
    test('serializes learning ledger rows', () async {
      final ts = DateTime.utc(2026, 3, 15);
      await db
          .into(db.learningLedger)
          .insert(
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
      final ledger = (decoded['learningLedger'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
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
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await db
          .into(db.trackLearningOrder)
          .insert(
            TrackLearningOrderCompanion.insert(
              profileId: 1,
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
      expect(orders.first['profileId'], 1);
    });
  });

  // =========================================================================
  // exportData — streakEvents serialization (covers lines 442-454)
  // =========================================================================

  group('DataExportImportService.exportData — streakEvents', () {
    test('serializes streak event rows', () async {
      final ts = DateTime.utc(2026, 5, 10);
      await db
          .into(db.streakEvents)
          .insert(
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

  // =========================================================================
  // importData — profile isolation (AUD-settings-03)
  //
  // The method's own doc comment promises a per-profile import that "does
  // not hard-delete accounts not present in the export". Before this fix,
  // every clear-step in importData() was a bare `delete(table).go()` with
  // no `.where()` — an unconditional wipe of every profile on the device,
  // not just the one(s) present in the import payload.
  // =========================================================================

  group('DataExportImportService.importData — profile isolation', () {
    test('importing a payload scoped to profile A leaves profile B rows in '
        'all 16 user-data tables byte-for-byte unchanged', () async {
      // ── Seed two independent profiles (siblings on one device) ──────
      final acctAId = await db
          .into(db.accounts)
          .insertReturning(
            AccountsCompanion.insert(
              email: 'alice@placeholder.local',
              tier: 'localBorn',
              displayName: 'Alice',
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          )
          .then((r) => r.id);
      final lpAId = await db
          .into(db.learnerProfiles)
          .insertReturning(
            LearnerProfilesCompanion.insert(
              accountId: acctAId,
              displayName: 'Alice (Learner)',
              mode: 'adult',
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
              // T-41: exportData/importData round-trip ulid now (mirrors
              // learningLedger); a real seeded profile always has one.
              ulid: const Value('ulid-alice'),
            ),
          )
          .then((r) => r.id);

      final acctBId = await db
          .into(db.accounts)
          .insertReturning(
            AccountsCompanion.insert(
              email: 'bob@placeholder.local',
              tier: 'localBorn',
              displayName: 'Bob',
              createdAt: DateTime.utc(2026, 2, 1),
              updatedAt: DateTime.utc(2026, 2, 1),
            ),
          )
          .then((r) => r.id);
      final lpBId = await db
          .into(db.learnerProfiles)
          .insertReturning(
            LearnerProfilesCompanion.insert(
              accountId: acctBId,
              displayName: 'Bob (Learner)',
              mode: 'child',
              createdAt: DateTime.utc(2026, 2, 1),
              updatedAt: DateTime.utc(2026, 2, 1),
              ulid: const Value('ulid-bob'),
            ),
          )
          .then((r) => r.id);

      Future<int> seedTrackFor(int profileId, String curriculumId) => db
          .into(db.curriculumTracks)
          .insertReturning(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: curriculumId,
              stateChangedAt: DateTime.utc(2026, 1, 5),
              activatedAt: DateTime.utc(2026, 1, 5),
            ),
          )
          .then((r) => r.id);

      final trackA = await seedTrackFor(lpAId, 'mishnayos');
      final trackB = await seedTrackFor(lpBId, 'bavli');

      // Seed one representative row per profile-scoped table for each
      // profile (14 of the 16 delete sites — accounts/learnerProfiles
      // already seeded above).
      Future<void> seedRowsFor(
        int profileId,
        int trackId,
        String curriculumId,
        String refPrefix,
      ) async {
        await db
            .into(db.curriculumScopes)
            .insert(
              CurriculumScopesCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                scopeLevel: 1,
                scopeValue: '$refPrefix-scope',
                createdAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await db
            .into(db.profilePrograms)
            .insert(
              ProfileProgramsCompanion.insert(
                profileId: profileId,
                curriculumType: curriculumId,
                programId: 1,
              ),
            );
        await db
            .into(db.stageDefinitions)
            .insert(
              StageDefinitionsCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                stageOrder: 1,
                stageName: '$refPrefix-stage',
              ),
            );
        await db
            .into(db.pointConfigs)
            .insert(
              PointConfigsCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                stageOrder: 1,
                points: 10,
              ),
            );
        await db
            .into(db.studyDayConfigs)
            .insert(
              StudyDayConfigsCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                dayOfWeek: 2,
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            sefariaRef: '$refPrefix.1.1',
            stageId: 1,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: DateTime.utc(2026, 1, 10),
          ),
        );
        await db
            .into(db.dailyPlans)
            .insert(
              DailyPlansCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                planDate: DateTime.utc(2026, 1, 11),
                sefariaRef: '$refPrefix.1.1',
                stageOrder: 1,
                stageDefinitionId: 1,
                trackId: trackId,
                priority: 'normal',
                createdAt: DateTime.utc(2026, 1, 11),
              ),
            );
        await db
            .into(db.learningLedger)
            .insert(
              LearningLedgerCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                entryScope: 'daf',
                unitIdentifier: '$refPrefix.1.1',
                unitDisplayNameHe: refPrefix,
                unitDisplayNameEn: refPrefix,
                trackType: 'personal',
                completedAt: DateTime.utc(2026, 1, 10),
                completionNumber: 1,
                markedBy: profileId,
              ),
            );
        await db
            .into(db.bookmarks)
            .insert(
              BookmarksCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                sefariaRef: '$refPrefix.1.1',
                updatedAt: DateTime.utc(2026, 1, 10),
              ),
            );
        await db
            .into(db.learningOrder)
            .insert(
              LearningOrderCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: '$refPrefix.1.1',
                userSortOrder: 1,
              ),
            );
        await db
            .into(db.trackLearningOrder)
            .insert(
              TrackLearningOrderCompanion.insert(
                profileId: profileId,
                trackId: trackId,
                sefariaRef: '$refPrefix.1.1',
                sortOrder: 1,
              ),
            );
        await db
            .into(db.goals)
            .insert(
              GoalsCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                trackId: trackId,
                createdAt: DateTime.utc(2026, 1, 1),
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await db
            .into(db.streakEvents)
            .insert(
              StreakEventsCompanion.insert(
                profileId: profileId,
                eventType: 'completion',
                dayUtc: DateTime.utc(2026, 1, 10),
                eventTimestamp: DateTime.utc(2026, 1, 10, 18),
              ),
            );
      }

      await seedRowsFor(lpAId, trackA, 'mishnayos', 'Alice');
      await seedRowsFor(lpBId, trackB, 'bavli', 'Bob');

      // ── Snapshot Bob's rows across all 16 tables before import ──────
      Future<Map<String, List<Object?>>> snapshotB() async => {
        'streakEvents': await (db.select(
          db.streakEvents,
        )..where((t) => t.profileId.equals(lpBId))).get(),
        'completionEvents': await (db.select(
          db.completionEvents,
        )..where((t) => t.profileId.equals(lpBId))).get(),
        'learningLedger': await (db.select(
          db.learningLedger,
        )..where((t) => t.profileId.equals(lpBId))).get(),
        'dailyPlans': await (db.select(
          db.dailyPlans,
        )..where((t) => t.profileId.equals(lpBId))).get(),
        'trackLearningOrder': await (db.select(
          db.trackLearningOrder,
        )..where((t) => t.trackId.equals(trackB))).get(),
        'learningOrder': await (db.select(
          db.learningOrder,
        )..where((t) => t.profileId.equals(lpBId))).get(),
        'bookmarks': await (db.select(
          db.bookmarks,
        )..where((t) => t.profileId.equals(lpBId))).get(),
        'goals': await (db.select(
          db.goals,
        )..where((t) => t.profileId.equals(lpBId))).get(),
        'studyDayConfigs': await (db.select(
          db.studyDayConfigs,
        )..where((t) => t.profileId.equals(lpBId))).get(),
        'pointConfigs': await (db.select(
          db.pointConfigs,
        )..where((t) => t.profileId.equals(lpBId))).get(),
        'stageDefinitions': await (db.select(
          db.stageDefinitions,
        )..where((t) => t.profileId.equals(lpBId))).get(),
        'profilePrograms': await (db.select(
          db.profilePrograms,
        )..where((t) => t.profileId.equals(lpBId))).get(),
        'curriculumScopes': await (db.select(
          db.curriculumScopes,
        )..where((t) => t.profileId.equals(lpBId))).get(),
        'curriculumTracks': await (db.select(
          db.curriculumTracks,
        )..where((t) => t.profileId.equals(lpBId))).get(),
        'learnerProfiles': await (db.select(
          db.learnerProfiles,
        )..where((t) => t.id.equals(lpBId))).get(),
        'accounts': await (db.select(
          db.accounts,
        )..where((t) => t.id.equals(acctBId))).get(),
      };

      final beforeB = await snapshotB();
      // Sanity: every section must actually hold a row for B, otherwise
      // the isolation assertion below would be vacuously true.
      for (final entry in beforeB.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: '${entry.key} fixture must seed a row for profile B',
        );
      }

      // ── Build a payload scoped to profile A only ─────────────────────
      // exportData() itself dumps the whole device (out of this fix's
      // scope — see AUD-settings-03); filtering its output down to A's
      // rows here simulates what a future per-profile export would
      // produce, and exercises importData()'s isolation contract.
      final fullExport =
          jsonDecode(await service.exportData()) as Map<String, dynamic>;
      final aOnly = Map<String, dynamic>.from(fullExport);
      bool matchesA(Map<String, dynamic> row, String key) {
        if (key == 'userProfiles') return row['id'] == acctAId;
        if (key == 'learnerProfiles') return row['id'] == lpAId;
        if (key == 'trackLearningOrder') return row['trackId'] == trackA;
        return row['profileId'] == lpAId;
      }

      for (final key in [
        'userProfiles',
        'learnerProfiles',
        'curriculumTracks',
        'curriculumScopes',
        'profilePrograms',
        'stageDefinitions',
        'pointConfigs',
        'studyDayConfigs',
        'completionEvents',
        'dailyPlans',
        'learningLedger',
        'bookmarks',
        'learningOrder',
        'trackLearningOrder',
        'goals',
        'streakEvents',
      ]) {
        final rows = (fullExport[key] as List).cast<Map<String, dynamic>>();
        aOnly[key] = rows.where((r) => matchesA(r, key)).toList();
      }

      await service.importData(jsonEncode(aOnly));

      // ── Profile B must be completely untouched ───────────────────────
      final afterB = await snapshotB();
      for (final key in beforeB.keys) {
        expect(
          afterB[key],
          equals(beforeB[key]),
          reason:
              'profile B rows in $key must survive importing profile '
              'A only',
        );
      }
    });
  });
}
