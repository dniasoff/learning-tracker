/// Regression tests for the Recent Activity engagement-tier additions to
/// [ChartDataService] (W3-A / Task #9):
///   - [ChartDataService.getDailyLimudimAndChazaros] — stacked
///     limud/chazara two-colour split, live-only.
///   - [ChartDataService.getCumulativeProgressLive] — cumulative line,
///     live-only.
///   - [ChartDataService.getStreakCalendarLive] — weekly dot calendar,
///     live-only.
///
/// All three drop bulkInTrack and lifetimeOnly rows (which surface under
/// Lifetime Knowledge instead), and the stacked feed splits the live rows
/// into stage-1 (limud) and stage ≥ 2 (chazara) segments.
@Tags(['progress', 'recent_activity'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

import '../../../../helpers/drift_memory.dart';

const _profileId = 1;
const _curriculumId = 'mishnayos';

final _startDate = DateTime(2026, 5, 1);
final _endDate = DateTime(2026, 5, 31);
final _liveDay = DateTime(2026, 5, 10);

Future<void> _seedLive(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required int stageId,
  DateTime? at,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at ?? DateTime(2026, 5, 10, 10),
    ),
  );
}

Future<void> _seedBulkInTrack(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required int stageId,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: DateTime(2026, 5, 10, 11),
    ),
  );
  await db.priorCompletionImportDao.batchInsertImports([
    PriorCompletionImportsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      source: 'bulkInTrack',
    ),
  ]);
}

Future<void> _seedLifetimeOnly(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required int stageId,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: DateTime(2026, 5, 10, 12),
    ),
  );
  await db.priorCompletionImportDao.batchInsertImports([
    PriorCompletionImportsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      source: 'lifetimeOnly',
    ),
  ]);
}

void main() {
  late UserDatabase db;
  late ChartDataService service;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await seedTrack(
      db,
      profileId: _profileId,
      curriculumId: _curriculumId,
    );
    service = ChartDataService(db, profileId: _profileId);
  });

  tearDown(() => db.close());

  group('getDailyLimudimAndChazaros', () {
    test('zero-fills empty window with zero limud + zero chazara', () async {
      final start = DateTime(2026, 3, 1);
      final end = DateTime(2026, 3, 3);
      final result = await service.getDailyLimudimAndChazaros(
        startDate: start,
        endDate: end,
      );
      expect(result, hasLength(3));
      expect(
        result.every((d) => d.limudCount == 0 && d.chazaraCount == 0),
        isTrue,
      );
    });

    test('mixed stages on one day produce a stacked bar with both '
        'segments', () async {
      // 2 limudim (stage 1) and 3 chazaros (stages 2 & 3) on May 10.
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'limud_a',
        stageId: 1,
      );
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'limud_b',
        stageId: 1,
      );
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'chaz_a',
        stageId: 2,
      );
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'chaz_b',
        stageId: 2,
      );
      await _seedLive(
        db,
        trackId: trackId,
        ref: 'chaz_c',
        stageId: 3,
      );

      final result = await service.getDailyLimudimAndChazaros(
        startDate: _startDate,
        endDate: _endDate,
      );

      final day10 = result.firstWhere((d) => d.date == _liveDay);
      expect(day10.limudCount, 2, reason: 'two stage-1 live marks on May 10');
      expect(
        day10.chazaraCount,
        3,
        reason: 'three stage>=2 live marks on May 10',
      );
      expect(day10.total, 5);

      // Other days are empty.
      final others = result.where((d) => d.date != _liveDay);
      expect(
        others.every((d) => d.limudCount == 0 && d.chazaraCount == 0),
        isTrue,
      );
    });

    test('bulkInTrack rows are EXCLUDED from the live-only stacked feed', () async {
      await _seedLive(db, trackId: trackId, ref: 'live', stageId: 1);
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk', stageId: 1);

      final result = await service.getDailyLimudimAndChazaros(
        startDate: _startDate,
        endDate: _endDate,
      );

      final day10 = result.firstWhere((d) => d.date == _liveDay);
      expect(day10.limudCount, 1, reason: 'only the live mark counts');
      expect(day10.chazaraCount, 0);
    });

    test('lifetimeOnly rows are EXCLUDED from the live-only stacked feed',
        () async {
      await _seedLive(db, trackId: trackId, ref: 'live', stageId: 2);
      await _seedLifetimeOnly(
        db,
        trackId: trackId,
        ref: 'lifetime',
        stageId: 2,
      );

      final result = await service.getDailyLimudimAndChazaros(
        startDate: _startDate,
        endDate: _endDate,
      );

      final day10 = result.firstWhere((d) => d.date == _liveDay);
      expect(day10.limudCount, 0);
      expect(day10.chazaraCount, 1, reason: 'only the live mark counts');
    });

    test('curriculum filter applies', () async {
      // Add a bavli track + completion on the same day; the mishnayos
      // filter must drop it.
      final bavliTrack = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: 'bavli',
      );
      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: _profileId,
          curriculumId: 'bavli',
          sefariaRef: 'bavli_ref',
          stageId: 1,
          trackType: 'personal',
          trackId: Value(bavliTrack),
          eventTimestamp: DateTime(2026, 5, 10, 13),
        ),
      );
      await _seedLive(db, trackId: trackId, ref: 'mish_ref', stageId: 1);

      final result = await service.getDailyLimudimAndChazaros(
        startDate: _startDate,
        endDate: _endDate,
        curriculumId: 'mishnayos',
      );

      final day10 = result.firstWhere((d) => d.date == _liveDay);
      expect(day10.limudCount, 1);
      expect(day10.chazaraCount, 0);
    });
  });

  group('getCumulativeProgressLive', () {
    test('only live rows contribute to the running total', () async {
      await _seedLive(db, trackId: trackId, ref: 'live_1', stageId: 1);
      await _seedBulkInTrack(db, trackId: trackId, ref: 'bulk_1', stageId: 1);
      await _seedLifetimeOnly(
        db,
        trackId: trackId,
        ref: 'lifetime_1',
        stageId: 1,
      );

      final result = await service.getCumulativeProgressLive(
        startDate: _startDate,
        endDate: _endDate,
      );

      // Day-9 has zero; day-10 has one; day-11..end stays at one. The
      // total ever climbs to 1, not 3.
      expect(
        result.map((p) => p.total).reduce((a, b) => a > b ? a : b),
        1,
        reason: 'bulkInTrack and lifetimeOnly must not bump the live total',
      );
    });
  });

  group('getStreakCalendarLive', () {
    test('only live marks light up the streak calendar', () async {
      // Bulk row on May 5; live row on May 10.
      await _seedBulkInTrack(
        db,
        trackId: trackId,
        ref: 'bulk',
        stageId: 1,
      );
      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: _profileId,
          curriculumId: _curriculumId,
          sefariaRef: 'live_may5',
          stageId: 1,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: DateTime(2026, 5, 5, 9),
        ),
      );

      final dates = await service.getStreakCalendarLive(
        startDate: _startDate,
        endDate: _endDate,
      );

      // The live mark on May 5 is present; the bulk mark on May 10 is not.
      expect(dates.contains(DateTime(2026, 5, 5)), isTrue);
      expect(dates.contains(DateTime(2026, 5, 10)), isFalse);
    });

    // F11 (W7-D fix wave): the curriculum filter pill must scope the
    // calendar dot pattern — previously the method ignored curriculumId
    // and the dots stayed unchanged when the chip changed.
    test(
      'curriculum filter scopes the streak calendar to the selected curriculum',
      () async {
        // Live mark on May 5 in mishnayos; live mark on May 10 in bavli.
        // Each curriculum needs its own track (the schema FK).
        final bavliTrack = await seedTrack(
          db,
          profileId: _profileId,
          curriculumId: 'bavli',
        );
        await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: _profileId,
            curriculumId: _curriculumId,
            sefariaRef: 'mish_may5',
            stageId: 1,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: DateTime(2026, 5, 5, 9),
          ),
        );
        await db.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: _profileId,
            curriculumId: 'bavli',
            sefariaRef: 'bav_may10',
            stageId: 1,
            trackType: 'personal',
            trackId: Value(bavliTrack),
            eventTimestamp: DateTime(2026, 5, 10, 10),
          ),
        );

        // No filter → both dates light up.
        final allDates = await service.getStreakCalendarLive(
          startDate: _startDate,
          endDate: _endDate,
        );
        expect(allDates.contains(DateTime(2026, 5, 5)), isTrue);
        expect(allDates.contains(DateTime(2026, 5, 10)), isTrue);

        // Mishnayos filter → only the May 5 dot remains.
        final mishOnly = await service.getStreakCalendarLive(
          startDate: _startDate,
          endDate: _endDate,
          curriculumId: 'mishnayos',
        );
        expect(mishOnly.contains(DateTime(2026, 5, 5)), isTrue);
        expect(
          mishOnly.contains(DateTime(2026, 5, 10)),
          isFalse,
          reason: 'May 10 bavli mark must be dropped under the mishnayos chip',
        );

        // Bavli filter → only the May 10 dot remains.
        final bavOnly = await service.getStreakCalendarLive(
          startDate: _startDate,
          endDate: _endDate,
          curriculumId: 'bavli',
        );
        expect(bavOnly.contains(DateTime(2026, 5, 10)), isTrue);
        expect(
          bavOnly.contains(DateTime(2026, 5, 5)),
          isFalse,
          reason: 'May 5 mishnayos mark must be dropped under the bavli chip',
        );
      },
    );
  });
}
