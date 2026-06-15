/// Unit tests for the active-track-card unit-naming logic (UI-3).
///
/// Covers:
///   - [programUnitDayLabel] prefers the seed-sourced day-level label and
///     picks the Hebrew/English form per the Hebrew-terms toggle, with
///     graceful fallback when one form is missing or both are absent.
///   - [collapseAmudToDaf] collapses a Daf-Yomi amud breadcrumb to the daf.
///   - [collapseRefRange] collapses a mishnayos multi-ref day to a range.
@Tags(['dashboard'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

DailyTask _task({
  String ref = 'Chullin 25a',
  String? unitDisplayHe,
  String? unitDisplayEn,
}) {
  return DailyTask(
    curriculumId: CurriculumId.bavli,
    contentItemSefariaRef: ref,
    stageOrder: 1,
    stageDefinitionId: 1,
    priority: DailyTaskPriority.todayProgram,
    isOverdue: false,
    reason: 'test',
    stageName: 'Learn',
    trackId: 1,
    trackLabel: 'Test',
    estimatedEffortMinutes: 5,
    unitDisplayHe: unitDisplayHe,
    unitDisplayEn: unitDisplayEn,
  );
}

void main() {
  group('programUnitDayLabel', () {
    test('Hebrew mode prefers the seeded day-level Hebrew daf label', () {
      // Daf-Yomi day = whole daf; the seed carries "חולין דף כ״ה", not a
      // single amud. The label must be that collapsed daf, not an amud ref.
      final task = _task(
        unitDisplayHe: 'חולין דף כ״ה',
        unitDisplayEn: 'Chullin 25',
      );
      expect(programUnitDayLabel(task, useHebrew: true), 'חולין דף כ״ה');
    });

    test('English mode picks the seeded English daf label', () {
      final task = _task(
        unitDisplayHe: 'חולין דף כ״ה',
        unitDisplayEn: 'Chullin 25',
      );
      expect(programUnitDayLabel(task, useHebrew: false), 'Chullin 25');
    });

    test('mishnayos range is surfaced as a single range label', () {
      // Mishna-Yomit day spanning multiple mishnayos → one range label.
      final task = _task(
        ref: 'Kelim 5:7',
        unitDisplayHe: 'כלים 5:7-8',
        unitDisplayEn: 'Kelim 5:7-8',
      );
      expect(programUnitDayLabel(task, useHebrew: true), 'כלים 5:7-8');
      expect(programUnitDayLabel(task, useHebrew: false), 'Kelim 5:7-8');
    });

    test('falls back to the other locale when preferred form is empty', () {
      final heOnly = _task(unitDisplayHe: 'חולין דף כ״ה', unitDisplayEn: null);
      expect(programUnitDayLabel(heOnly, useHebrew: false), 'חולין דף כ״ה');

      final enOnly = _task(unitDisplayHe: null, unitDisplayEn: 'Chullin 25');
      expect(programUnitDayLabel(enOnly, useHebrew: true), 'Chullin 25');
    });

    test(
      'returns null when no seeded label is present (renderer fallback)',
      () {
        final task = _task(unitDisplayHe: null, unitDisplayEn: null);
        expect(programUnitDayLabel(task, useHebrew: true), isNull);
        expect(programUnitDayLabel(task, useHebrew: false), isNull);
      },
    );
  });

  group('collapseAmudToDaf', () {
    test('drops the trailing amud leaf (Hebrew)', () {
      expect(collapseAmudToDaf('חולין › דף כה › עמוד א'), 'חולין › דף כה');
    });

    test('drops the trailing amud leaf (English)', () {
      expect(
        collapseAmudToDaf('Chullin › Daf 25 › Amud A'),
        'Chullin › Daf 25',
      );
    });

    test('leaves a non-amud breadcrumb untouched', () {
      // Already daf/perek/mishna level — nothing to collapse.
      expect(
        collapseAmudToDaf('כלים › פרק ה › משנה ז'),
        'כלים › פרק ה › משנה ז',
      );
    });

    test('single-segment label is returned unchanged', () {
      expect(collapseAmudToDaf('חולין'), 'חולין');
    });
  });

  group('collapseRefRange', () {
    test('collapses multiple refs to first–last leaf range', () {
      final result = collapseRefRange([
        'כלים › פרק ה › משנה ז',
        'כלים › פרק ה › משנה ח',
        'כלים › פרק ה › משנה ט',
      ]);
      expect(result, 'משנה ז – משנה ט');
    });

    test('single ref is returned unchanged', () {
      expect(collapseRefRange(['כלים › משנה ז']), 'כלים › משנה ז');
    });

    test('all-equal leaves collapse to the first ref', () {
      expect(collapseRefRange(['א › משנה ז', 'ב › משנה ז']), 'א › משנה ז');
    });

    test('empty input yields empty string', () {
      expect(collapseRefRange(const []), '');
      expect(collapseRefRange(['', '  ']), '');
    });
  });

  group('compareSefariaRefs (current-focus range ordering)', () {
    test('orders by verse number ascending within a chapter', () {
      expect(compareSefariaRefs('Genesis 1:6', 'Genesis 1:7'), lessThan(0));
      expect(compareSefariaRefs('Genesis 1:7', 'Genesis 1:6'), greaterThan(0));
      expect(compareSefariaRefs('Genesis 1:7', 'Genesis 1:7'), 0);
    });

    test('orders by chapter before verse', () {
      expect(compareSefariaRefs('Genesis 1:9', 'Genesis 2:1'), lessThan(0));
    });

    test('handles dot and colon separators identically', () {
      expect(compareSefariaRefs('Genesis 1.6', 'Genesis 1:7'), lessThan(0));
    });

    test(
      'sorting a reversed verse list yields an ascending range (regression: '
      'Pasuk 7 – Pasuk 6 was shown reversed)',
      () {
        // Refs arrive high→low (the bug condition). After sorting ascending
        // the collapsed range must read low→high.
        final refs = ['Genesis 1:7', 'Genesis 1:6']
          ..sort(compareSefariaRefs);
        expect(refs, ['Genesis 1:6', 'Genesis 1:7']);

        final rendered = [
          for (final r in refs)
            r == 'Genesis 1:6'
                ? 'בראשית › פרק א › פסוק ו'
                : 'בראשית › פרק א › פסוק ז',
        ];
        // Ascending: Pasuk ו (6) first, Pasuk ז (7) last — never reversed.
        expect(collapseRefRange(rendered), 'פסוק ו – פסוק ז');
      },
    );
  });
}
