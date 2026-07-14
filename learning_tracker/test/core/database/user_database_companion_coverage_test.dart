/// Companion-class coverage tests for user_database.g.dart.
///
/// Exercises the following generated patterns that the earlier DataClass and
/// manager tests leave uncovered:
///   • Companion.toString()  — StringBuffer body, 5-14 lines per class
///   • Companion.custom()    — RawValuesInsertable body, 5-15 lines per class
///   • Companion.toColumns() — optional-field branches when fields are present
///   • validateIntegrity missing paths — triggered by empty inserts
///
/// No Firebase or Riverpod — plain Drift in-memory DB.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  final now = DateTime.utc(2026, 3, 1, 12);

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ─── Helper inserts ───────────────────────────────────────────────────────

  Future<int> makeAccount({String email = 'a@test.local'}) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: email,
          tier: 'localBorn',
          displayName: 'User',
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> makeProfile(int accountId) => db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Learner',
          mode: 'adult',
          createdAt: now,
          updatedAt: now,
        ),
      );

  // ─── AccountsCompanion ────────────────────────────────────────────────────

  group('AccountsCompanion', () {
    test('toString covers StringBuffer body', () {
      // Empty companion exercises all field writes
      const c = AccountsCompanion();
      final s = c.toString();
      expect(s, contains('AccountsCompanion'));
      expect(s, contains('email'));
      expect(s, contains('tier'));
      expect(s, contains('firebaseUid'));
      expect(s, contains('passwordHash'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = AccountsCompanion.custom(
        email: const Variable('raw@example.com'),
        tier: const Variable('cloudBorn'),
        displayName: const Variable('Raw User'),
        createdAt: Variable(now),
        updatedAt: Variable(now),
        firebaseUid: const Variable('fb-raw'),
        passwordHash: const Variable('hash'),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('email'), isTrue);
      expect(cols.containsKey('firebase_uid'), isTrue);
      expect(cols.containsKey('password_hash'), isTrue);
    });

    test('toColumns with optional fields (firebaseUid, passwordHash)', () {
      final c = AccountsCompanion(
        email: const Value('opt@test.local'),
        firebaseUid: const Value('fb123'),
        passwordHash: const Value('hash'),
        tier: const Value('localBorn'),
        displayName: const Value('Opt'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('firebase_uid'), isTrue);
      expect(cols.containsKey('password_hash'), isTrue);
    });
  });

  // ─── LearnerProfilesCompanion ─────────────────────────────────────────────

  group('LearnerProfilesCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = LearnerProfilesCompanion();
      final s = c.toString();
      expect(s, contains('LearnerProfilesCompanion'));
      expect(s, contains('displayName'));
      expect(s, contains('avatarIndex'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = LearnerProfilesCompanion.custom(
        accountId: const Variable(1),
        displayName: const Variable('Custom'),
        mode: const Variable('adult'),
        avatarIndex: const Variable(3),
        createdAt: Variable(now),
        updatedAt: Variable(now),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('account_id'), isTrue);
      expect(cols.containsKey('avatar_index'), isTrue);
    });

    test('toColumns with avatarIndex present', () {
      final c = LearnerProfilesCompanion(
        accountId: const Value(1),
        displayName: const Value('Learner'),
        mode: const Value('adult'),
        avatarIndex: const Value(3),
        createdAt: Value(now),
        updatedAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('avatar_index'), isTrue);
    });
  });

  // ─── CurriculumTracksCompanion ────────────────────────────────────────────

  group('CurriculumTracksCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = CurriculumTracksCompanion();
      final s = c.toString();
      expect(s, contains('CurriculumTracksCompanion'));
      expect(s, contains('state'));
      expect(s, contains('stateChangedAt'));
      expect(s, contains('paceResetDate'));
      expect(s, contains('activatedAt'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = CurriculumTracksCompanion.custom(
        profileId: const Variable(1),
        curriculumId: const Variable('mishnah'),
        state: const Variable('active'),
        stateChangedAt: Variable(now),
        activatedAt: Variable(now),
        paceResetDate: Variable(now),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('state'), isTrue);
      expect(cols.containsKey('state_changed_at'), isTrue);
      expect(cols.containsKey('pace_reset_date'), isTrue);
      expect(cols.containsKey('activated_at'), isTrue);
    });

    test('toColumns with optional fields', () {
      final c = CurriculumTracksCompanion(
        profileId: const Value(1),
        curriculumId: const Value('bavli'),
        state: const Value('retired'),
        stateChangedAt: Value(now),
        activatedAt: Value(now),
        paceResetDate: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('state'), isTrue);
      expect(cols.containsKey('state_changed_at'), isTrue);
      expect(cols.containsKey('pace_reset_date'), isTrue);
      expect(cols.containsKey('activated_at'), isTrue);
    });
  });

  // ─── CurriculumScopesCompanion ────────────────────────────────────────────

  group('CurriculumScopesCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = CurriculumScopesCompanion();
      final s = c.toString();
      expect(s, contains('CurriculumScopesCompanion'));
      expect(s, contains('scopeLevel'));
      expect(s, contains('scopeValue'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = CurriculumScopesCompanion.custom(
        profileId: const Variable(1),
        curriculumId: const Variable('bavli'),
        trackId: const Variable(1),
        scopeLevel: const Variable(1),
        scopeValue: const Variable('Berakhot'),
        createdAt: Variable(now),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('scope_level'), isTrue);
      expect(cols.containsKey('scope_value'), isTrue);
    });

    test('toColumns present branches', () {
      final c = CurriculumScopesCompanion(
        profileId: const Value(1),
        curriculumId: const Value('bavli'),
        trackId: const Value(1),
        scopeLevel: const Value(1),
        scopeValue: const Value('Berakhot'),
        createdAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('scope_level'), isTrue);
    });
  });

  // ─── ProfileProgramsCompanion ─────────────────────────────────────────────

  group('ProfileProgramsCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = ProfileProgramsCompanion();
      final s = c.toString();
      expect(s, contains('ProfileProgramsCompanion'));
      expect(s, contains('trackingStartDate'));
      expect(s, contains('trackingStartRef'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = ProfileProgramsCompanion.custom(
        profileId: const Variable(1),
        curriculumType: const Variable('bavli'),
        programId: const Variable(1),
        trackingStartDate: Variable(now),
        trackingStartRef: const Variable('Berakhot 2a'),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('program_id'), isTrue);
      expect(cols.containsKey('tracking_start_date'), isTrue);
      expect(cols.containsKey('tracking_start_ref'), isTrue);
    });

    test('toColumns with optional fields present', () {
      final c = ProfileProgramsCompanion(
        profileId: const Value(1),
        curriculumType: const Value('bavli'),
        programId: const Value(1),
        trackingStartDate: Value(now),
        trackingStartRef: const Value('Berakhot 2a'),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('tracking_start_date'), isTrue);
      expect(cols.containsKey('tracking_start_ref'), isTrue);
    });
  });

  // ─── StageDefinitionsCompanion ────────────────────────────────────────────

  group('StageDefinitionsCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = StageDefinitionsCompanion();
      final s = c.toString();
      expect(s, contains('StageDefinitionsCompanion'));
      expect(s, contains('stageName'));
      expect(s, contains('schedule'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = StageDefinitionsCompanion.custom(
        profileId: const Variable(1),
        trackId: const Variable(1),
        curriculumId: const Variable('bavli'),
        stageName: const Variable('review'),
        stageOrder: const Variable(2),
        schedule: const Variable('{"type":"delay","delay_days":7}'),
        isDefault: const Variable(false),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('stage_name'), isTrue);
      expect(cols.containsKey('schedule'), isTrue);
      expect(cols.containsKey('is_default'), isTrue);
    });
  });

  // ─── PointConfigsCompanion ────────────────────────────────────────────────

  group('PointConfigsCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = PointConfigsCompanion();
      final s = c.toString();
      expect(s, contains('PointConfigsCompanion'));
      expect(s, contains('points'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = PointConfigsCompanion.custom(
        profileId: const Variable(1),
        trackId: const Variable(1),
        curriculumId: const Variable('bavli'),
        stageOrder: const Variable(1),
        points: const Variable(10),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('points'), isTrue);
      expect(cols.containsKey('stage_order'), isTrue);
    });
  });

  // ─── StudyDayConfigsCompanion ─────────────────────────────────────────────

  group('StudyDayConfigsCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = StudyDayConfigsCompanion();
      final s = c.toString();
      expect(s, contains('StudyDayConfigsCompanion'));
      expect(s, contains('dayType'));
      expect(s, contains('dayOfWeek'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = StudyDayConfigsCompanion.custom(
        profileId: const Variable(1),
        curriculumId: const Variable('bavli'),
        trackId: const Variable(1),
        dayOfWeek: const Variable(1),
        dayType: const Variable('study'),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('day_of_week'), isTrue);
      expect(cols.containsKey('day_type'), isTrue);
    });
  });

  // ─── CompletionEventsCompanion ─────────────────────────────────────────────────

  group('CompletionEventsCompanion', () {
    // AUD-t-cross-13: this group used to be pasted twice under the same
    // name — one copy exercising the `points` field, the other exercising
    // `createdAt`. Merged into one group; every original assertion is
    // preserved, just with disambiguated test names.
    test('toString covers StringBuffer body (points field)', () {
      const c = CompletionEventsCompanion();
      final s = c.toString();
      expect(s, contains('CompletionEventsCompanion'));
      expect(s, contains('sefariaRef'));
      expect(s, contains('points'));
    });

    test('custom() covers RawValuesInsertable body (points field)', () {
      final insertable = CompletionEventsCompanion.custom(
        profileId: const Variable(1),
        trackId: const Variable(1),
        curriculumId: const Variable('bavli'),
        stageId: const Variable(1),
        trackType: const Variable('personal'),
        sefariaRef: const Variable('Berakhot 2a'),
        eventTimestamp: Variable(now),
        points: const Variable(5),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('sefaria_ref'), isTrue);
      expect(cols.containsKey('points'), isTrue);
    });

    test('toColumns with points present', () {
      final c = CompletionEventsCompanion(
        profileId: const Value(1),
        trackId: const Value(1),
        curriculumId: const Value('bavli'),
        stageId: const Value(1),
        trackType: const Value('personal'),
        sefariaRef: const Value('Berakhot 2a'),
        eventTimestamp: Value(now),
        points: const Value(5),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('points'), isTrue);
    });

    test('toString covers StringBuffer body (createdAt field)', () {
      const c = CompletionEventsCompanion();
      final s = c.toString();
      expect(s, contains('CompletionEventsCompanion'));
      expect(s, contains('eventTimestamp'));
    });

    test('custom() covers RawValuesInsertable body (createdAt field)', () {
      final insertable = CompletionEventsCompanion.custom(
        profileId: const Variable(1),
        curriculumId: const Variable('bavli'),
        stageId: const Variable(1),
        sefariaRef: const Variable('Berakhot 2a'),
        eventTimestamp: Variable(now),
        trackType: const Variable('personal'),
        createdAt: Variable(now),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('event_timestamp'), isTrue);
      expect(cols.containsKey('created_at'), isTrue);
    });

    test('toColumns with createdAt present', () {
      final c = CompletionEventsCompanion(
        profileId: const Value(1),
        curriculumId: const Value('bavli'),
        stageId: const Value(1),
        sefariaRef: const Value('Berakhot 2a'),
        eventTimestamp: Value(now),
        trackType: const Value('personal'),
        createdAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('created_at'), isTrue);
    });
  });

  // ─── DailyPlansCompanion ──────────────────────────────────────────────────

  group('DailyPlansCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = DailyPlansCompanion();
      final s = c.toString();
      expect(s, contains('DailyPlansCompanion'));
      expect(s, contains('planDate'));
      expect(s, contains('priority'));
      expect(s, contains('trackLabel'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = DailyPlansCompanion.custom(
        profileId: const Variable(1),
        curriculumId: const Variable('bavli'),
        planDate: Variable(now),
        sefariaRef: const Variable('Berakhot 2a'),
        stageOrder: const Variable(1),
        stageDefinitionId: const Variable(1),
        trackId: const Variable(1),
        trackLabel: const Variable('Daily Study'),
        priority: const Variable('normal'),
        isOverdue: const Variable(false),
        reason: const Variable('scheduled'),
        stageName: const Variable('limud'),
        estimatedEffortMinutes: const Variable(30),
        sortOrder: const Variable(1),
        createdAt: Variable(now),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('plan_date'), isTrue);
      expect(cols.containsKey('track_label'), isTrue);
      expect(cols.containsKey('is_overdue'), isTrue);
      expect(cols.containsKey('reason'), isTrue);
      expect(cols.containsKey('stage_name'), isTrue);
    });

    test('toColumns with optional fields present', () {
      final c = DailyPlansCompanion(
        profileId: const Value(1),
        curriculumId: const Value('bavli'),
        planDate: Value(now),
        sefariaRef: const Value('Berakhot 2a'),
        stageOrder: const Value(1),
        stageDefinitionId: const Value(1),
        trackId: const Value(1),
        trackLabel: const Value('Daily Study'),
        priority: const Value('normal'),
        isOverdue: const Value(false),
        reason: const Value('scheduled'),
        stageName: const Value('limud'),
        estimatedEffortMinutes: const Value(30),
        sortOrder: const Value(1),
        createdAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('track_label'), isTrue);
      expect(cols.containsKey('is_overdue'), isTrue);
      expect(cols.containsKey('reason'), isTrue);
      expect(cols.containsKey('stage_name'), isTrue);
      expect(cols.containsKey('estimated_effort_minutes'), isTrue);
      expect(cols.containsKey('sort_order'), isTrue);
    });
  });

  // ─── LearningLedgerCompanion ──────────────────────────────────────────────

  group('LearningLedgerCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = LearningLedgerCompanion();
      final s = c.toString();
      expect(s, contains('LearningLedgerCompanion'));
      expect(s, contains('profileId'));
      expect(s, contains('completedAt'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = LearningLedgerCompanion.custom(
        profileId: const Variable(1),
        ulid: const Variable('01ARZ3NDEKTSV4RRFFQ69G5FAV'),
        curriculumId: const Variable('bavli'),
        entryScope: const Variable('unit'),
        unitIdentifier: const Variable('Berakhot 2a'),
        unitDisplayNameHe: const Variable('ברכות ב׳'),
        unitDisplayNameEn: const Variable('Berakhot 2a'),
        trackType: const Variable('personal'),
        trackId: const Variable(1),
        completedAt: Variable(now),
        completionNumber: const Variable(1),
        markedBy: const Variable(1),
        isManual: const Variable(false),
        createdAt: Variable(now),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('profile_id'), isTrue);
      expect(cols.containsKey('ulid'), isTrue);
      expect(cols.containsKey('is_manual'), isTrue);
      expect(cols.containsKey('created_at'), isTrue);
    });

    test('toColumns with optional fields (trackId, ulid)', () {
      final c = LearningLedgerCompanion(
        profileId: const Value(1),
        ulid: const Value('01ARZ3NDEKTSV4RRFFQ69G5FAV'),
        curriculumId: const Value('bavli'),
        entryScope: const Value('unit'),
        unitIdentifier: const Value('Berakhot 2a'),
        unitDisplayNameHe: const Value('ברכות'),
        unitDisplayNameEn: const Value('Berakhot'),
        trackType: const Value('personal'),
        trackId: const Value(1),
        completedAt: Value(now),
        completionNumber: const Value(1),
        markedBy: const Value(1),
        isManual: const Value(false),
        createdAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('ulid'), isTrue);
      expect(cols.containsKey('track_id'), isTrue);
      expect(cols.containsKey('is_manual'), isTrue);
    });
  });

  // ─── BookmarksCompanion ───────────────────────────────────────────────────

  group('BookmarksCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = BookmarksCompanion();
      final s = c.toString();
      expect(s, contains('BookmarksCompanion'));
      expect(s, contains('sefariaRef'));
      expect(s, contains('updatedAt'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = BookmarksCompanion.custom(
        profileId: const Variable(1),
        curriculumId: const Variable('bavli'),
        trackId: const Variable(1),
        sefariaRef: const Variable('Berakhot 2a'),
        updatedAt: Variable(now),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('sefaria_ref'), isTrue);
      expect(cols.containsKey('updated_at'), isTrue);
    });
  });

  // ─── LearningOrderCompanion ───────────────────────────────────────────────

  group('LearningOrderCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = LearningOrderCompanion();
      final s = c.toString();
      expect(s, contains('LearningOrderCompanion'));
      expect(s, contains('userSortOrder'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = LearningOrderCompanion.custom(
        profileId: const Variable(1),
        curriculumId: const Variable('bavli'),
        sefariaRef: const Variable('Berakhot 2a'),
        userSortOrder: const Variable(1),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('user_sort_order'), isTrue);
    });
  });

  // ─── GoalsCompanion ───────────────────────────────────────────────────────

  group('GoalsCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = GoalsCompanion();
      final s = c.toString();
      expect(s, contains('GoalsCompanion'));
      expect(s, contains('targetPercent'));
      expect(s, contains('paceValue'));
      expect(s, contains('pacePeriod'));
      expect(s, contains('paceGranularity'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = GoalsCompanion.custom(
        profileId: const Variable(1),
        curriculumId: const Variable('bavli'),
        trackId: const Variable(1),
        targetPercent: const Variable(80.0),
        targetDate: Variable(now),
        description: const Variable('My goal'),
        dateType: const Variable('gregorian'),
        goalType: const Variable('completion'),
        paceValue: const Variable(1),
        pacePeriod: const Variable('week'),
        paceGranularity: const Variable('daf'),
        createdAt: Variable(now),
        updatedAt: Variable(now),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('target_percent'), isTrue);
      expect(cols.containsKey('pace_value'), isTrue);
      // W3: renamed pace_unit → pace_period, learning_unit → pace_granularity
      expect(cols.containsKey('pace_period'), isTrue);
      expect(cols.containsKey('pace_granularity'), isTrue);
    });

    test('toColumns with all optional fields present', () {
      final c = GoalsCompanion(
        profileId: const Value(1),
        curriculumId: const Value('bavli'),
        trackId: const Value(1),
        targetPercent: const Value(80.0),
        targetDate: Value(now),
        description: const Value('My goal'),
        dateType: const Value('gregorian'),
        goalType: const Value('completion'),
        paceValue: const Value(1),
        pacePeriod: const Value('week'),
        paceGranularity: const Value('daf'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('target_percent'), isTrue);
      expect(cols.containsKey('target_date'), isTrue);
      expect(cols.containsKey('pace_value'), isTrue);
      // W3: renamed pace_unit → pace_period, learning_unit → pace_granularity
      expect(cols.containsKey('pace_period'), isTrue);
      expect(cols.containsKey('pace_granularity'), isTrue);
    });
  });

  // ─── StreakEventsCompanion ─────────────────────────────────────────────────────

  group('StreakEventsCompanion (snapshot fields removed in W3)', () {
    test('toString covers StringBuffer body', () {
      const c = StreakEventsCompanion();
      final s = c.toString();
      expect(s, contains('StreakEventsCompanion'));
      expect(s, contains('eventType'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = StreakEventsCompanion.custom(
        profileId: const Variable(1),
        eventType: const Variable('study'),
        dayUtc: Variable(now),
        eventTimestamp: Variable(now),
        clientDeviceId: const Variable('device-x'),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('event_type'), isTrue);
      expect(cols.containsKey('day_utc'), isTrue);
      expect(cols.containsKey('event_timestamp'), isTrue);
      expect(cols.containsKey('client_device_id'), isTrue);
    });

    test('toColumns with optional fields (clientDeviceId)', () {
      final c = StreakEventsCompanion(
        profileId: const Value(1),
        eventType: const Value('study'),
        dayUtc: Value(now),
        eventTimestamp: Value(now),
        clientDeviceId: const Value('device-x'),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('client_device_id'), isTrue);
      expect(cols.containsKey('event_type'), isTrue);
    });
  });

  // ─── StreakEventsCompanion ────────────────────────────────────────────────

  group('StreakEventsCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = StreakEventsCompanion();
      final s = c.toString();
      expect(s, contains('StreakEventsCompanion'));
      expect(s, contains('eventType'));
      expect(s, contains('clientDeviceId'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = StreakEventsCompanion.custom(
        profileId: const Variable(1),
        eventType: const Variable('study'),
        dayUtc: Variable(now),
        eventTimestamp: Variable(now),
        clientDeviceId: const Variable('device-123'),
        createdAt: Variable(now),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('event_type'), isTrue);
      expect(cols.containsKey('client_device_id'), isTrue);
      expect(cols.containsKey('created_at'), isTrue);
    });

    test('toColumns with clientDeviceId and createdAt present', () {
      final c = StreakEventsCompanion(
        profileId: const Value(1),
        eventType: const Value('study'),
        dayUtc: Value(now),
        eventTimestamp: Value(now),
        clientDeviceId: const Value('device-123'),
        createdAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('client_device_id'), isTrue);
      expect(cols.containsKey('created_at'), isTrue);
    });
  });

  // ─── TextDownloadStatusesCompanion ────────────────────────────────────────

  group('TextDownloadStatusesCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = TextDownloadStatusesCompanion();
      final s = c.toString();
      expect(s, contains('TextDownloadStatusesCompanion'));
      expect(s, contains('itemCount'));
      expect(s, contains('storedItemCount'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = TextDownloadStatusesCompanion.custom(
        curriculumId: const Variable('mishnah'),
        itemCount: const Variable(200),
        textVersion: const Variable('2.0.0'),
        downloadedAt: Variable(now),
        storedItemCount: const Variable(150),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('item_count'), isTrue);
      expect(cols.containsKey('stored_item_count'), isTrue);
    });

    test('toColumns with storedItemCount present', () {
      final c = TextDownloadStatusesCompanion(
        curriculumId: const Value('bavli'),
        itemCount: const Value(100),
        textVersion: const Value('1.0'),
        downloadedAt: Value(now),
        storedItemCount: const Value(50),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('stored_item_count'), isTrue);
    });
  });

  // ─── OutboxCompanion ──────────────────────────────────────────────────────

  group('OutboxCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = OutboxCompanion();
      final s = c.toString();
      expect(s, contains('OutboxCompanion'));
      expect(s, contains('entityKind'));
      expect(s, contains('attempts'));
      expect(s, contains('lastError'));
      expect(s, contains('lastAttemptAt'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = OutboxCompanion.custom(
        profileId: const Variable(1),
        entityKind: const Variable('streak'),
        entityKey: const Variable('key-2'),
        payload: const Variable('{"k":"v"}'),
        createdAt: Variable(now),
        attempts: const Variable(1),
        lastError: const Variable('Timeout'),
        lastAttemptAt: Variable(now),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('entity_kind'), isTrue);
      expect(cols.containsKey('attempts'), isTrue);
      expect(cols.containsKey('last_error'), isTrue);
      expect(cols.containsKey('last_attempt_at'), isTrue);
    });

    test('toColumns with all optional fields present', () {
      final c = OutboxCompanion(
        profileId: const Value(1),
        entityKind: const Value('completion'),
        entityKey: const Value('key-3'),
        payload: const Value('{}'),
        createdAt: Value(now),
        attempts: const Value(2),
        lastError: const Value('error'),
        lastAttemptAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('attempts'), isTrue);
      expect(cols.containsKey('last_error'), isTrue);
      expect(cols.containsKey('last_attempt_at'), isTrue);
    });
  });

  // ─── SacredWindowEntriesCompanion ─────────────────────────────────────────

  group('SacredWindowEntriesCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = SacredWindowEntriesCompanion();
      final s = c.toString();
      expect(s, contains('SacredWindowEntriesCompanion'));
      expect(s, contains('kind'));
      expect(s, contains('lat'));
      expect(s, contains('lng'));
      expect(s, contains('inIsrael'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = SacredWindowEntriesCompanion.custom(
        startUtc: Variable(now),
        endUtc: Variable(now.add(const Duration(hours: 2))),
        kind: const Variable('yom_tov'),
        lat: const Variable(31.7683),
        lng: const Variable(35.2137),
        inIsrael: const Variable(true),
        createdAt: Variable(now),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('kind'), isTrue);
      expect(cols.containsKey('lat'), isTrue);
      expect(cols.containsKey('lng'), isTrue);
      expect(cols.containsKey('in_israel'), isTrue);
    });

    test('toColumns with lat/lng/createdAt present', () {
      final c = SacredWindowEntriesCompanion(
        startUtc: Value(now),
        endUtc: Value(now.add(const Duration(hours: 1))),
        kind: const Value('shabbat'),
        lat: const Value(31.7),
        lng: const Value(35.2),
        inIsrael: const Value(true),
        createdAt: Value(now),
      );
      final cols = c.toColumns(false);
      expect(cols.containsKey('lat'), isTrue);
      expect(cols.containsKey('lng'), isTrue);
      expect(cols.containsKey('in_israel'), isTrue);
      expect(cols.containsKey('created_at'), isTrue);
    });
  });

  // ─── TrackLearningOrderCompanion ──────────────────────────────────────────

  group('TrackLearningOrderCompanion', () {
    test('toString covers StringBuffer body', () {
      const c = TrackLearningOrderCompanion();
      final s = c.toString();
      expect(s, contains('TrackLearningOrderCompanion'));
      expect(s, contains('sefariaRef'));
      expect(s, contains('sortOrder'));
    });

    test('custom() covers RawValuesInsertable body', () {
      final insertable = TrackLearningOrderCompanion.custom(
        trackId: const Variable(1),
        sefariaRef: const Variable('Berakhot 2a'),
        sortOrder: const Variable(1),
      );
      final cols = insertable.toColumns(false);
      expect(cols.containsKey('sefaria_ref'), isTrue);
      expect(cols.containsKey('sort_order'), isTrue);
    });
  });

  // ─── Managers for remaining tables ────────────────────────────────────────

  group('managers — textDownloadStatuses', () {
    test('insert, filter, and DataClass round-trip', () async {
      await db
          .into(db.textDownloadStatuses)
          .insert(
            TextDownloadStatusesCompanion.insert(
              curriculumId: 'bavli',
              itemCount: 2711,
              textVersion: '1.2.3',
              downloadedAt: now,
            ),
          );
      await db
          .into(db.textDownloadStatuses)
          .insert(
            TextDownloadStatusesCompanion.insert(
              curriculumId: 'mishnah',
              itemCount: 4192,
              textVersion: '2.0.0',
              downloadedAt: now,
            ),
          );

      final bavli = await db.managers.textDownloadStatuses
          .filter((f) => f.curriculumId('bavli'))
          .get();
      expect(bavli, hasLength(1));
      expect(bavli.first.itemCount, 2711);

      final sorted = await db.managers.textDownloadStatuses
          .orderBy((o) => o.itemCount.desc())
          .get();
      expect(sorted.first.curriculumId, 'mishnah');
    });

    test('with storedItemCount (nullable column)', () async {
      await db
          .into(db.textDownloadStatuses)
          .insert(
            TextDownloadStatusesCompanion.insert(
              curriculumId: 'yerushalmi',
              itemCount: 100,
              textVersion: '0.5',
              downloadedAt: now,
              storedItemCount: const Value(42),
            ),
          );

      final rows = await db.managers.textDownloadStatuses
          .filter((f) => f.curriculumId('yerushalmi'))
          .get();
      expect(rows.first.storedItemCount, 42);
    });
  });

  group('managers — outbox', () {
    test('insert, filter, orderBy', () async {
      final accId = await makeAccount(email: 'ob@test.local');
      final profileId = await makeProfile(accId);

      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              profileId: profileId,
              entityKind: 'completion',
              entityKey: 'Berakhot_2a_limud',
              payload: '{"sefariaRef":"Berakhot 2a"}',
              createdAt: now,
            ),
          );
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              profileId: profileId,
              entityKind: 'bookmark',
              entityKey: 'bk-bavli',
              payload: '{"ref":"Berakhot 5a"}',
              createdAt: now.add(const Duration(minutes: 5)),
            ),
          );

      final completions = await db.managers.outbox
          .filter((f) => f.entityKind('completion'))
          .get();
      expect(completions, hasLength(1));
      expect(completions.first.entityKey, 'Berakhot_2a_limud');

      final byProfile = await db.managers.outbox
          .filter((f) => f.profileId(profileId))
          .orderBy((o) => o.createdAt.asc())
          .get();
      expect(byProfile, hasLength(2));
      expect(byProfile.first.entityKind, 'completion');
    });

    test('update with lastError and lastAttemptAt', () async {
      final accId = await makeAccount(email: 'ob2@test.local');
      final profileId = await makeProfile(accId);

      final id = await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              profileId: profileId,
              entityKind: 'streak',
              entityKey: 'streak-1',
              payload: '{}',
              createdAt: now,
            ),
          );

      await (db.update(db.outbox)..where((t) => t.id.equals(id))).write(
        OutboxCompanion(
          attempts: const Value(1),
          lastError: const Value('Network timeout'),
          lastAttemptAt: Value(now),
        ),
      );

      final updated = await (db.select(
        db.outbox,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      expect(updated!.attempts, 1);
      expect(updated.lastError, 'Network timeout');
      expect(updated.lastAttemptAt, isNotNull);
    });
  });

  group('managers — sacredWindowEntries', () {
    test('insert, filter, orderBy', () async {
      final start1 = now;
      final end1 = now.add(const Duration(hours: 25));
      final start2 = now.add(const Duration(days: 7));
      final end2 = now.add(const Duration(days: 7, hours: 25));

      await db
          .into(db.sacredWindowEntries)
          .insert(
            SacredWindowEntriesCompanion.insert(
              startUtc: start1,
              endUtc: end1,
              kind: 'shabbat',
              inIsrael: false,
            ),
          );
      await db
          .into(db.sacredWindowEntries)
          .insert(
            SacredWindowEntriesCompanion.insert(
              startUtc: start2,
              endUtc: end2,
              kind: 'yom_tov',
              inIsrael: true,
              lat: const Value(31.7683),
              lng: const Value(35.2137),
            ),
          );

      final shabbatRows = await db.managers.sacredWindowEntries
          .filter((f) => f.kind('shabbat'))
          .get();
      expect(shabbatRows, hasLength(1));
      expect(shabbatRows.first.inIsrael, false);

      final inIsrael = await db.managers.sacredWindowEntries
          .filter((f) => f.inIsrael(true))
          .get();
      expect(inIsrael, hasLength(1));
      expect(inIsrael.first.lat, closeTo(31.7683, 0.001));
      expect(inIsrael.first.lng, closeTo(35.2137, 0.001));

      final sorted = await db.managers.sacredWindowEntries
          .orderBy((o) => o.startUtc.asc())
          .get();
      expect(sorted.first.kind, 'shabbat');
    });
  });

  // ─── validateIntegrity missing paths ─────────────────────────────────────
  //
  // AUD-t-cross-92: these previously used the untyped "any thrown object"
  // matcher, not specifically Drift's own required-field validation.
  // Replaced with the concrete type Drift's generated insert() actually
  // throws for a missing-required-field Companion
  // (drift.InvalidDataException).
  //
  // AC2 (red-first, all 3 sites in this file): verified the same way as the
  // 15 sites in user_database_dataclass_test.dart — the required-field
  // check was temporarily removed from each table's generated
  // validateIntegrity() body (user_database.g.dart only; no source .dart
  // table file touched), the test re-run to confirm it goes red (insert
  // reaches sqlite3, which throws `SqliteException` for the NOT NULL
  // column, not `InvalidDataException`), then the generated file was
  // reverted and the test re-run to confirm green again. Full per-site
  // red/green log is in the AUD-t-cross-92 AC2 commit body (the
  // test(database) commit following 9b79454d).

  group('validateIntegrity — missing required fields', () {
    test('outbox missing entityKind triggers insert error', () async {
      expect(
        () => db.into(db.outbox).insert(const OutboxCompanion()),
        throwsA(isA<InvalidDataException>()),
      );
    });

    test('sacredWindowEntries missing startUtc triggers insert error', () {
      expect(
        () => db
            .into(db.sacredWindowEntries)
            .insert(const SacredWindowEntriesCompanion()),
        throwsA(isA<InvalidDataException>()),
      );
    });

    test('textDownloadStatuses missing curriculumId triggers insert error', () {
      expect(
        () => db
            .into(db.textDownloadStatuses)
            .insert(const TextDownloadStatusesCompanion()),
        throwsA(isA<InvalidDataException>()),
      );
    });
  });
}
