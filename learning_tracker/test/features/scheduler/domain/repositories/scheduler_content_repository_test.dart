/// Tests for [SchedulerContentItem.coarseUnitKey].
///
/// Covers:
///  - [SchedulerContentItem.coarseUnitKey] for all hierarchy depth scenarios
///
/// AUD-t-scheduler-01: [SchedulerContentRepositoryImpl.getLeafItems]
/// filtering/sorting coverage used to be duplicated here as well as in
/// test/features/scheduler/data/repositories/scheduler_content_repository_impl_test.dart
/// — that suite now lives solely in the data/repositories/ file, which is
/// the AG-5-correct mirrored home for
/// lib/features/scheduler/data/repositories/scheduler_content_repository_impl.dart.
/// This file keeps only the coarseUnitKey coverage, which is not exercised
/// anywhere else.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';

void main() {
  // ─── SchedulerContentItem.coarseUnitKey ──────────────────────────────────

  group('SchedulerContentItem.coarseUnitKey', () {
    test('returns level1|level2|level3 for 4-level item (mishnayos style)', () {
      const item = SchedulerContentItem(
        sefariaRef: 'Berakhot.1.1',
        sortOrder: 1,
        level1: 'Zeraim',
        level2: 'Berakhot',
        level3: '1',
        level4: '1',
      );
      expect(item.coarseUnitKey, 'Zeraim|Berakhot|1');
    });

    test('returns level1|level2 for 3-level item (chumash style)', () {
      const item = SchedulerContentItem(
        sefariaRef: 'Genesis.1.1',
        sortOrder: 1,
        level1: 'Genesis',
        level2: '1',
        level3: '1',
        level4: null,
      );
      expect(item.coarseUnitKey, 'Genesis|1');
    });

    test('returns level1 for 2-level item', () {
      const item = SchedulerContentItem(
        sefariaRef: 'Bavli.2a',
        sortOrder: 1,
        level1: 'Berakhot',
        level2: '2a',
        level3: null,
        level4: null,
      );
      expect(item.coarseUnitKey, 'Berakhot');
    });

    test('returns null for single-level item (no parent)', () {
      const item = SchedulerContentItem(
        sefariaRef: 'SomeBook.1',
        sortOrder: 1,
        level1: null,
        level2: null,
        level3: null,
        level4: null,
      );
      expect(item.coarseUnitKey, isNull);
    });

    test('returns null when all level fields are null', () {
      const item = SchedulerContentItem(sefariaRef: 'ref-1', sortOrder: 0);
      expect(item.coarseUnitKey, isNull);
    });
  });
}
