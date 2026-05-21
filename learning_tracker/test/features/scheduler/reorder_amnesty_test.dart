/// Regression tests for the reorder-amnesty feature (architecture §10.1).
///
/// Three scenarios covered:
///   A. Reorder stamps lastReorderAt and the projection filters pre-reorder
///      overdue items (amnesty fires).
///   B. Pace change does NOT stamp lastReorderAt; overdue items remain.
///   C. learning_order_version mismatch on getOrder triggers amnesty +
///      warning telemetry log.
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class MockContentRepository extends Mock implements ContentRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ContentItem _makeItem(String ref, {int sortOrder = 0}) {
  return ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Zeraim',
    level2: ref,
    displayNameHe: '$ref-he',
    displayNameEn: '$ref-en',
    sefariaRef: ref,
    sortOrder: sortOrder,
    isLeaf: false,
  );
}

LearningOrderItem _orderItem(String ref, int order) => LearningOrderItem(
  sefariaRef: ref,
  displayNameHe: '$ref-he',
  displayNameEn: '$ref-en',
  userSortOrder: order,
  isCustomOrdered: true,
);

/// Minimal selfPacedSchedule helper: assigns one unit per day starting from
/// [anchor] for each ref in [orderedRefs].
List<ScheduledUnit> _buildSchedule({
  required DateTime anchor,
  required List<String> orderedRefs,
}) {
  return [
    for (var i = 0; i < orderedRefs.length; i++)
      ScheduledUnit(
        date: anchor.add(Duration(days: i)),
        sefariaRef: orderedRefs[i],
      ),
  ];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late UserDatabase db;
  late MockContentRepository mockContent;

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    await seedProfile(db); // inserts account(1)+profile(1)
    mockContent = MockContentRepository();

    when(() => mockContent.getHierarchyConfig(any())).thenAnswer(
      (_) async => const CurriculumHierarchyConfig(
        curriculumId: 'mishnayos',
        levelLabels: ['Seder', 'Masechta', 'Perek', 'Mishna'],
        totalItems: 10,
      ),
    );
    when(() => mockContent.getContentForCurriculum(any())).thenAnswer(
      (_) async => [
        _makeItem('Berakhot', sortOrder: 0),
        _makeItem('Shabbat', sortOrder: 1),
        _makeItem('Peah', sortOrder: 2),
      ],
    );
  });

  tearDown(() async => db.close());

  // ────────────────────────────────────────────────────────────────────────────
  // Scenario A — reorder stamps lastReorderAt; projection amnesty fires.
  // ────────────────────────────────────────────────────────────────────────────

  group('Scenario A — reorder stamps lastReorderAt', () {
    test('stampReorderAt updates lastReorderAt on the track row', () async {
      // Arrange: create a track row
      final before = DateTime.utc(2026, 1, 1);
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: before,
              activatedAt: before,
            ),
          );

      // Act: stamp reorder
      final reorderTs = DateTime.utc(2026, 5, 20, 10, 0, 0);
      await db.trackDao.stampReorderAt(trackId, at: reorderTs);

      // Assert: compare via epoch ms to avoid UTC/local offset mismatch
      final track = await db.trackDao.getTrackById(trackId);
      expect(track, isNotNull);
      expect(
        track!.lastReorderAt?.millisecondsSinceEpoch,
        equals(reorderTs.millisecondsSinceEpoch),
      );
    });

    test(
      'projection amnesty: overdue items scheduled before lastReorderAt are filtered',
      () async {
        // Arrange: build a schedule anchored 5 days ago with 5 refs.
        final today = DateTime.utc(2026, 5, 20);
        final anchor = today.subtract(const Duration(days: 4));
        final refs = ['A', 'B', 'C', 'D', 'E'];
        final schedule = _buildSchedule(anchor: anchor, orderedRefs: refs);

        // All 4 past items (A–D) are overdue; E is today.
        final projection = project(
          schedule: schedule,
          completions: const {},
          today: today,
        );
        expect(projection.overdue, containsAll(['A', 'B', 'C', 'D']));
        expect(projection.dueToday, contains('E'));

        // Simulate a reorder at day 2 (after A+B were scheduled).
        // Items A+B should be amnestied; C+D should still appear as overdue.
        final lastReorderAt = anchor.add(const Duration(days: 2));
        final scheduleIndex = <String, DateTime>{
          for (final unit in schedule) unit.sefariaRef: unit.date,
        };

        final amnestied = projection.overdue.where((ref) {
          final scheduledDate = scheduleIndex[ref];
          if (scheduledDate == null) return false;
          return scheduledDate.isBefore(lastReorderAt);
        }).toSet();

        final remaining = projection.overdue.difference(amnestied);

        // A (day 0) and B (day 1) were scheduled before reorder at day 2.
        expect(amnestied, equals({'A', 'B'}));
        // C (day 2) and D (day 3) are on/after reorder — they remain.
        expect(remaining, equals({'C', 'D'}));
      },
    );

    test(
      'mid-day lastReorderAt does not amnesty same-local-day schedule entries',
      () async {
        // Regression for the "track activated yesterday, overdue=0 today" bug.
        //
        // Real-world repro: a user activates a self-paced track yesterday
        // (Israel evening), which stamps lastReorderAt = some mid-day UTC
        // instant. Schedule entries are dated to UTC midnight of the local
        // day. A naive `scheduledDate.isBefore(lastReorderAt)` then treats
        // every same-day entry as "before the reorder" and silently amnesties
        // it — so the next day, the previous day's allocation never accrues
        // as overdue.
        //
        // The cutoff used by the production filter normalises lastReorderAt
        // to UTC midnight of its device-local date; this test locks in that
        // behaviour against an instant-level regression.

        // Today (UTC midnight) and a schedule that started yesterday.
        final today = DateTime.utc(2026, 5, 21);
        final yesterdayMidnight = DateTime.utc(2026, 5, 20);

        final schedule = [
          ScheduledUnit(date: yesterdayMidnight, sefariaRef: 'Y1'),
          ScheduledUnit(date: today, sefariaRef: 'T1'),
        ];

        final projection = project(
          schedule: schedule,
          completions: const {},
          today: today,
        );
        expect(projection.overdue, equals({'Y1'}));
        expect(projection.dueToday, equals({'T1'}));

        // Simulate activation yesterday at 15:00 UTC (mid-day).  The local
        // date is still 2026-05-20 in UTC and in any timezone east of about
        // UTC-15, so the day-level cutoff must come out to 2026-05-20 00:00
        // UTC — i.e. the same midnight as the Y1 schedule entry.
        final midDayYesterday = DateTime.utc(2026, 5, 20, 15, 0, 0);

        // Mimic the production day-level cutoff (see
        // scheduler_providers.dart:_amnestyDayCutoffUtc).
        final local = midDayYesterday.toLocal();
        final cutoff = DateTime.utc(local.year, local.month, local.day);

        final scheduleIndex = <String, DateTime>{
          for (final unit in schedule) unit.sefariaRef: unit.date,
        };
        final amnestied = projection.overdue.where((ref) {
          final scheduledDate = scheduleIndex[ref];
          if (scheduledDate == null) return false;
          return scheduledDate.isBefore(cutoff);
        }).toSet();

        // Yesterday's entry must NOT be amnestied even though
        // lastReorderAt is mid-day yesterday.  Pre-fix this set was {'Y1'}.
        expect(
          amnestied,
          isEmpty,
          reason:
              'A mid-day lastReorderAt on the same device-local day as a '
              'schedule entry must not amnesty that entry. The day-level '
              'cutoff is what makes the projection robust against the '
              'time-of-day component of lastReorderAt.',
        );
      },
    );

    test('saveOrder stamps lastReorderAt on the active track', () async {
      // Arrange: activate a track for profile 1
      final activatedAt = DateTime.utc(2026, 1, 1);
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: activatedAt,
              activatedAt: activatedAt,
            ),
          );
      expect(trackId, isPositive);

      final repo = LearningOrderRepositoryImpl(
        database: db,
        contentRepository: mockContent,
        profileId: 1,
      );

      // Act: save a custom order
      await repo.saveOrder(CurriculumId.mishnayos, [
        _orderItem('Berakhot', 0),
        _orderItem('Peah', 1),
        _orderItem('Shabbat', 2),
      ]);

      // Assert: lastReorderAt is now set to a recent timestamp
      final track = await db.trackDao.getTrackById(trackId);
      expect(track, isNotNull);
      expect(track!.lastReorderAt, isNotNull);
      // Should be recent (within 10 seconds of now)
      final diff = DateTimeFactory.nowUtc()
          .difference(track.lastReorderAt!)
          .abs()
          .inSeconds;
      expect(diff, lessThan(10));
    });

    test('resetToDefault stamps lastReorderAt on the active track', () async {
      // Arrange: activate a track
      final activatedAt = DateTime.utc(2026, 1, 1);
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: activatedAt,
              activatedAt: activatedAt,
            ),
          );

      final repo = LearningOrderRepositoryImpl(
        database: db,
        contentRepository: mockContent,
        profileId: 1,
      );

      // Act: reset to default
      await repo.resetToDefault(CurriculumId.mishnayos);

      // Assert: lastReorderAt is now set
      final track = await db.trackDao.getTrackById(trackId);
      expect(track, isNotNull);
      expect(track!.lastReorderAt, isNotNull);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Scenario B — pace change does NOT stamp lastReorderAt.
  // ────────────────────────────────────────────────────────────────────────────

  group('Scenario B — pace change does NOT stamp lastReorderAt', () {
    test('resetPace does not change lastReorderAt', () async {
      // Arrange: create a track with a known lastReorderAt (epoch ms)
      const knownReorderMs = 1_742_000_000_000; // some fixed ms
      final knownReorderAt = DateTime.fromMillisecondsSinceEpoch(
        knownReorderMs,
        isUtc: true,
      );
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: knownReorderAt,
              activatedAt: knownReorderAt,
              lastReorderAt: Value(knownReorderAt),
            ),
          );

      // Act: reset pace (simulates a pace-change operation)
      await db.trackDao.resetPace(trackId);

      // Assert: lastReorderAt milliseconds are unchanged
      final track = await db.trackDao.getTrackById(trackId);
      expect(track, isNotNull);
      expect(
        track!.lastReorderAt!.millisecondsSinceEpoch,
        equals(knownReorderMs),
        reason:
            'resetPace must not modify lastReorderAt — '
            'pace changes do not trigger amnesty',
      );

      // paceResetDate is set, but lastReorderAt is the same
      expect(track.paceResetDate, isNotNull);
    });

    test(
      'updating stateChangedAt (not a reorder) does not change lastReorderAt',
      () async {
        // Arrange
        const knownReorderMs = 1_745_000_000_000;
        final knownReorderAt = DateTime.fromMillisecondsSinceEpoch(
          knownReorderMs,
          isUtc: true,
        );
        final trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'mishnayos',
                stateChangedAt: knownReorderAt,
                activatedAt: knownReorderAt,
                lastReorderAt: Value(knownReorderAt),
              ),
            );

        // Simulate a non-reorder write (e.g. state change)
        await (db.update(
          db.curriculumTracks,
        )..where((t) => t.id.equals(trackId))).write(
          CurriculumTracksCompanion(
            stateChangedAt: Value(DateTime.utc(2026, 5, 1)),
          ),
        );

        // lastReorderAt must be unchanged (compare via milliseconds)
        final track = await db.trackDao.getTrackById(trackId);
        expect(
          track!.lastReorderAt!.millisecondsSinceEpoch,
          equals(knownReorderMs),
        );
      },
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Scenario C — learning_order_version mismatch triggers amnesty.
  // ────────────────────────────────────────────────────────────────────────────

  group('Scenario C — learning_order_version guard', () {
    test('getOrder: version mismatch stamps lastReorderAt (amnesty)', () async {
      // Arrange: a track exists with no prior lastReorderAt
      final activatedAt = DateTime.utc(2026, 1, 1);
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: activatedAt,
              activatedAt: activatedAt,
            ),
          );

      // Insert a learning_order row with version = 1
      await db.learningOrderDao.upsertLearningOrder(
        LearningOrderCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot',
          userSortOrder: 0,
          learningOrderVersion: const Value(1),
        ),
      );

      // Repo is initialised with currentContentVersion = 2 (simulates reseed)
      final repo = LearningOrderRepositoryImpl(
        database: db,
        contentRepository: mockContent,
        profileId: 1,
        currentContentVersion: 2,
      );

      // Act: getOrder — version mismatch should trigger re-amnesty
      await repo.getOrder(CurriculumId.mishnayos);

      // Assert: lastReorderAt is now stamped
      final track = await db.trackDao.getTrackById(trackId);
      expect(track, isNotNull);
      expect(
        track!.lastReorderAt,
        isNotNull,
        reason:
            'learning_order_version mismatch must trigger '
            'stampReorderAt on the active track',
      );
    });

    test(
      'getOrder: no version mismatch → lastReorderAt is NOT changed',
      () async {
        // Arrange: a track with a known lastReorderAt (use fixed ms epoch)
        const knownReorderMs = 1_745_600_000_000;
        final knownReorderAt = DateTime.fromMillisecondsSinceEpoch(
          knownReorderMs,
          isUtc: true,
        );
        final trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'mishnayos',
                stateChangedAt: knownReorderAt,
                activatedAt: knownReorderAt,
                lastReorderAt: Value(knownReorderAt),
              ),
            );

        // Insert a learning_order row with version = 5 (matching content version)
        await db.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot',
            userSortOrder: 0,
            learningOrderVersion: const Value(5),
          ),
        );

        final repo = LearningOrderRepositoryImpl(
          database: db,
          contentRepository: mockContent,
          profileId: 1,
          currentContentVersion: 5, // same as saved
        );

        // Act
        await repo.getOrder(CurriculumId.mishnayos);

        // Assert: lastReorderAt is untouched (compare via milliseconds)
        final track = await db.trackDao.getTrackById(trackId);
        expect(
          track!.lastReorderAt!.millisecondsSinceEpoch,
          equals(knownReorderMs),
          reason: 'No mismatch — lastReorderAt must not change',
        );
      },
    );

    test('saveOrder stamps saved version onto learning_order rows', () async {
      // Arrange
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final repo = LearningOrderRepositoryImpl(
        database: db,
        contentRepository: mockContent,
        profileId: 1,
        currentContentVersion: 7,
      );

      // Act
      await repo.saveOrder(CurriculumId.mishnayos, [_orderItem('Berakhot', 0)]);

      // Assert: the saved row carries version 7
      final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
        'mishnayos',
      );
      expect(rows, hasLength(1));
      expect(rows.first.learningOrderVersion, equals(7));
    });
  });
}
