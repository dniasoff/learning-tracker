/// Tests for pure model classes in lifetime_knowledge_providers.dart.
///
/// Covers:
///  - [LifetimeNodeState] enum values
///  - [LifetimeTreeNode] construction
///  - [CurriculumLifetimeSummary] construction
///  - [TrackDualProgressMetric] construction and optional fields
///  - [LifetimeTotals.percentage] computed getter
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';

void main() {
  // ─── LifetimeNodeState ────────────────────────────────────────────────────

  group('LifetimeNodeState', () {
    test('has three values: none, partial, full', () {
      expect(LifetimeNodeState.values, hasLength(3));
      expect(LifetimeNodeState.values, contains(LifetimeNodeState.none));
      expect(LifetimeNodeState.values, contains(LifetimeNodeState.partial));
      expect(LifetimeNodeState.values, contains(LifetimeNodeState.full));
    });
  });

  // ─── LifetimeTreeNode ─────────────────────────────────────────────────────

  group('LifetimeTreeNode', () {
    test('constructs with all required fields', () {
      const node = LifetimeTreeNode(
        curriculumId: CurriculumId.mishnayos,
        level: 1,
        rawValue: 'Zeraim',
        parentL1Value: 'Zeraim',
        hebrewName: 'זרעים',
        state: LifetimeNodeState.partial,
        children: [],
      );
      expect(node.curriculumId, CurriculumId.mishnayos);
      expect(node.level, 1);
      expect(node.rawValue, 'Zeraim');
      expect(node.parentL1Value, 'Zeraim');
      expect(node.hebrewName, 'זרעים');
      expect(node.state, LifetimeNodeState.partial);
      expect(node.children, isEmpty);
    });

    test('hebrewName can be null', () {
      const node = LifetimeTreeNode(
        curriculumId: CurriculumId.bavli,
        level: 2,
        rawValue: 'Berakhot',
        parentL1Value: 'Zeraim',
        hebrewName: null,
        state: LifetimeNodeState.none,
        children: [],
      );
      expect(node.hebrewName, isNull);
    });

    test('constructs with nested children', () {
      const child = LifetimeTreeNode(
        curriculumId: CurriculumId.mishnayos,
        level: 2,
        rawValue: 'Berakhot',
        parentL1Value: 'Zeraim',
        hebrewName: 'ברכות',
        state: LifetimeNodeState.full,
        children: [],
      );
      const parent = LifetimeTreeNode(
        curriculumId: CurriculumId.mishnayos,
        level: 1,
        rawValue: 'Zeraim',
        parentL1Value: 'Zeraim',
        hebrewName: 'זרעים',
        state: LifetimeNodeState.partial,
        children: [child],
      );
      expect(parent.children, hasLength(1));
      expect(parent.children.first.rawValue, 'Berakhot');
    });
  });

  // ─── CurriculumLifetimeSummary ────────────────────────────────────────────

  group('CurriculumLifetimeSummary', () {
    test('constructs with correct values', () {
      const summary = CurriculumLifetimeSummary(
        curriculumId: CurriculumId.mishnayos,
        learnedLeafCount: 30,
        totalLeafCount: 525,
        percentage: 30 / 525,
        tree: [],
      );
      expect(summary.curriculumId, CurriculumId.mishnayos);
      expect(summary.learnedLeafCount, 30);
      expect(summary.totalLeafCount, 525);
      expect(summary.percentage, closeTo(30 / 525, 1e-10));
      expect(summary.tree, isEmpty);
    });
  });

  // ─── TrackDualProgressMetric ──────────────────────────────────────────────

  group('TrackDualProgressMetric', () {
    test('constructs with required fields', () {
      const metric = TrackDualProgressMetric(
        trackId: 42,
        trackLabel: 'Mishnayos (personal)',
        curriculumId: CurriculumId.mishnayos,
        currentCyclePercentage: 0.25,
        lifetimePercentage: 0.60,
        isProgramTrack: true,
      );
      expect(metric.trackId, 42);
      expect(metric.trackLabel, 'Mishnayos (personal)');
      expect(metric.curriculumId, CurriculumId.mishnayos);
      expect(metric.currentCyclePercentage, 0.25);
      expect(metric.lifetimePercentage, 0.60);
      expect(metric.isProgramTrack, isTrue);
      expect(metric.todayDueCount, isNull);
      expect(metric.overdueCount, isNull);
    });

    test('constructs with optional todayDueCount and overdueCount', () {
      const metric = TrackDualProgressMetric(
        trackId: 1,
        trackLabel: 'Bavli',
        curriculumId: CurriculumId.bavli,
        currentCyclePercentage: 0.5,
        lifetimePercentage: 0.8,
        isProgramTrack: false,
        todayDueCount: 3,
        overdueCount: 7,
      );
      expect(metric.todayDueCount, 3);
      expect(metric.overdueCount, 7);
    });
  });

  // ─── LifetimeTotals ───────────────────────────────────────────────────────

  group('LifetimeTotals', () {
    test('percentage is 0 when totalSections is 0', () {
      const totals = LifetimeTotals(
        learnedSections: 0,
        totalSections: 0,
        totalCurricula: 9,
      );
      expect(totals.percentage, 0.0);
    });

    test('percentage is learnedSections / totalSections', () {
      const totals = LifetimeTotals(
        learnedSections: 30,
        totalSections: 100,
        totalCurricula: 9,
      );
      expect(totals.percentage, closeTo(0.30, 1e-10));
    });

    test('percentage is 1.0 when fully learned', () {
      const totals = LifetimeTotals(
        learnedSections: 525,
        totalSections: 525,
        totalCurricula: 9,
      );
      expect(totals.percentage, closeTo(1.0, 1e-10));
    });

    test('totalCurricula is stored correctly', () {
      const totals = LifetimeTotals(
        learnedSections: 0,
        totalSections: 1000,
        totalCurricula: 9,
      );
      expect(totals.totalCurricula, 9);
    });
  });
}
