/// Run-8 P2 (device-audit 5560 + 5562) — bulk-mark rollup into aggregates.
///
/// A bulk-mark ("Mark as Previously Learned") writes a completion_events row
/// stamped with the sentinel date [kBulkPriorSentinelDate] (2000-01-01 UTC)
/// plus a `prior_completion_imports` row (`source = 'bulkInTrack'`). The
/// finding was that such completions succeed and show in the per-row / detail
/// path, but do NOT roll up into aggregate surfaces.
///
/// Two aggregates are covered:
///
///  1. **Recent Activity — All-time limud/chazara feed** (the actual bug).
///     [ChartDataService.getDailyLimudimAndChazaros] uses the
///     `trackAchievement` tier (live + bulkInTrack) and its subtitle promises
///     "Counts track learning (live + bulk-mark)". But over the All-time
///     window its `_effectiveStartDate` clamp compared a local-midnight date
///     against the UTC-midnight [kChartAllTimeFloor]; in a positive-offset
///     timezone the sentinel day's local midnight is an instant *before* UTC
///     midnight, so the weekly bucket loop dropped it and the feed read zero.
///     Guarded here at UTC+3 to lock the timezone-dependent boundary.
///
///  2. **Lifetime Knowledge header vs body** (invariant guard). The header
///     aggregate ([lifetimeHeaderCountersProvider], "All sources") and the
///     per-curriculum body row ([lifetimeViewDataProvider]) must report the
///     SAME learned count for a bulkInTrack completion — proving the header
///     already rolls bulk marks up.
@Tags(['progress'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/learning/completion_constants.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/drift_memory.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

const _profileId = 1;
const _curriculumId = 'mishnayos';

/// Seeds one bulk-in-track completion exactly as the production writer does:
/// a completion_events row at the sentinel date + a matching
/// prior_completion_imports row (`source = 'bulkInTrack'`).
Future<void> _seedBulkInTrack(
  UserDatabase db, {
  required int trackId,
  required String ref,
  int stageId = 1,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: kBulkPriorSentinelDate,
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

ContentItem _leaf(String ref, {int sort = 0}) => ContentItem(
  curriculumId: _curriculumId,
  level1: 'Seder A',
  level2: 'Masechta A',
  level3: 'Perek 1',
  level4: ref,
  displayNameHe: '',
  displayNameEn: '',
  sefariaRef: ref,
  sortOrder: sort,
  isLeaf: true,
);

void main() {
  group('Recent Activity — All-time feed includes sentinel bulk marks', () {
    // The drop was timezone-sensitive: on a positive-offset host the sentinel
    // day's local midnight is an instant before UTC midnight, so the pre-fix
    // clamp excluded it. The post-fix assertion (aggregate == detail count)
    // holds in every timezone, so this guard is host-neutral while still
    // locking the regression on the offsets where it manifested.
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

    test('three bulk-marked mishnayot roll up into the All-time limud total '
        '(aggregate == detail count)', () async {
      await _seedBulkInTrack(db, trackId: trackId, ref: 'm1');
      await _seedBulkInTrack(db, trackId: trackId, ref: 'm2');
      await _seedBulkInTrack(db, trackId: trackId, ref: 'm3');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final feed = await service.getDailyLimudimAndChazaros(
        startDate: kChartAllTimeFloor,
        endDate: today,
      );

      final aggregateLimud = feed.fold<int>(0, (s, d) => s + d.limudCount);
      // Detail source of truth: 3 distinct bulk-marked mishnayot.
      expect(
        aggregateLimud,
        3,
        reason:
            'the All-time limud/chazara feed uses the trackAchievement tier '
            '(live + bulk-mark) and must reflect the 3 sentinel-dated bulk '
            'marks, matching the detail count — regression guard for the '
            'UTC/local _effectiveStartDate boundary drop',
      );
    });

    test('cumulative All-time feed also reflects the bulk marks', () async {
      await _seedBulkInTrack(db, trackId: trackId, ref: 'm1');
      await _seedBulkInTrack(db, trackId: trackId, ref: 'm2');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final points = await service.getCumulativeProgressLive(
        startDate: kChartAllTimeFloor,
        endDate: today,
      );

      // The running total at the end of the series must include both marks.
      expect(points, isNotEmpty);
      expect(
        points.last.total,
        2,
        reason:
            'cumulative All-time total shares _effectiveStartDate; both '
            'sentinel-dated bulk marks must be counted',
      );
    });
  });

  group('Lifetime Knowledge header rolls up bulk marks (== body)', () {
    setUpAll(() {
      for (final c in CurriculumId.values) {
        registerFallbackValue(c);
      }
    });

    test('header itemsLearned equals the per-curriculum body learnedLeafCount '
        'for a bulkInTrack completion', () async {
      final db = inMemoryDb();
      await seedProfile(db);
      addTearDown(db.close);
      final trackId = await seedTrack(
        db,
        profileId: _profileId,
        curriculumId: _curriculumId,
      );

      final repo = _MockContentRepository();
      final leaves = [_leaf('Berakhot 1:1'), _leaf('Berakhot 1:2', sort: 1)];
      for (final c in CurriculumId.values) {
        when(() => repo.getContentForCurriculum(c)).thenAnswer(
          (_) async => c == CurriculumId.mishnayos ? leaves : <ContentItem>[],
        );
      }

      await _seedBulkInTrack(db, trackId: trackId, ref: 'Berakhot 1:1');

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          contentRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final body = await container.read(
        lifetimeViewDataProvider((
          profileId: _profileId,
          curriculumId: CurriculumId.mishnayos,
        )).future,
      );
      final header = await container.read(
        lifetimeHeaderCountersProvider(_profileId).future,
      );

      expect(body?.learnedLeafCount, 1, reason: 'detail/body path');
      expect(
        header.itemsLearned,
        body?.learnedLeafCount,
        reason:
            'the Lifetime Knowledge header (All-sources aggregate) must match '
            'the per-curriculum body row for a bulkInTrack completion',
      );
    });
  });
}
