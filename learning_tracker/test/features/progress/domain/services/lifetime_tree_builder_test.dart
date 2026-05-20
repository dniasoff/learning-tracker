import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';

// Minimal stub for LearningLedgerData — we only need entryScope + unitIdentifier.
// Using the real UserDatabase type would require a full DB setup; instead we
// use a minimal helper class with the same field names used by the builder.
import 'package:learning_tracker/core/database/user/user_database.dart'
    show LearningLedgerData;

ContentItem leaf(
  String sefariaRef, {
  String level1 = 'Zeraim',
  String? level2,
  String? level3,
  String? level4,
  int sortOrder = 0,
}) =>
    ContentItem(
      curriculumId: 'mishnayos',
      level1: level1,
      level2: level2,
      level3: level3,
      level4: level4,
      displayNameHe: '',
      displayNameEn: '',
      sefariaRef: sefariaRef,
      sortOrder: sortOrder,
      isLeaf: true,
    );

// Helper to create a LearningLedgerData-like object for testing.
// Since we can't easily construct Drift row types in isolation, we test via
// the builder's public computeLearnedLeafRefs by passing typed data.
// For this test, we use a thin wrapper that mimics the fields we need.
class _LedgerEntry {
  _LedgerEntry({required this.entryScope, required this.unitIdentifier});
  final String entryScope;
  final String unitIdentifier;
}

// Bridge: convert our test entries into the DAO data type.
// We use a whitebox approach: LearningLedgerData has `entryScope` and
// `unitIdentifier` fields exposed via the DAO. We can't easily instantiate it,
// so we test the pure logic by passing empty lists and verifying behavior
// through the completedRefs path which IS unit-testable.

void main() {
  late LifetimeTreeBuilder builder;

  setUp(() {
    builder = const LifetimeTreeBuilder();
  });

  group('LifetimeTreeBuilder', () {
    // -------------------------------------------------------------------------
    // computeLearnedLeafRefs — basic cases
    // -------------------------------------------------------------------------
    group('computeLearnedLeafRefs', () {
      test('returns empty set when no completions and no ledger', () {
        final leaves = [
          leaf('Berakhot 1:1'),
          leaf('Berakhot 1:2'),
        ];
        final result = builder.computeLearnedLeafRefs(
          leaves: leaves,
          completedRefs: {},
          ledgerEntries: [],
        );
        expect(result, isEmpty);
      });

      test('includes directly completed refs', () {
        final leaves = [
          leaf('Berakhot 1:1'),
          leaf('Berakhot 1:2'),
        ];
        final result = builder.computeLearnedLeafRefs(
          leaves: leaves,
          completedRefs: {'Berakhot 1:1'},
          ledgerEntries: [],
        );
        expect(result, {'Berakhot 1:1'});
      });

      test('does not include refs not in leaf set', () {
        final leaves = [
          leaf('Berakhot 1:1'),
        ];
        final result = builder.computeLearnedLeafRefs(
          leaves: leaves,
          completedRefs: {'Berakhot 1:1', 'Shabbat 2a'}, // Shabbat not in leaves
          ledgerEntries: [],
        );
        expect(result, {'Berakhot 1:1'});
        expect(result.contains('Shabbat 2a'), isFalse);
      });

      test('handles empty leaves gracefully', () {
        final result = builder.computeLearnedLeafRefs(
          leaves: [],
          completedRefs: {'Berakhot 1:1'},
          ledgerEntries: [],
        );
        expect(result, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // buildTree — structural tests
    // -------------------------------------------------------------------------
    group('buildTree', () {
      test('returns empty list for empty leaves', () {
        final tree = builder.buildTree(
          CurriculumId.mishnayos,
          [],
          {},
        );
        expect(tree, isEmpty);
      });

      test('single leaf creates single root node', () {
        final leaves = [
          leaf('Berakhot 1:1', level1: 'Zeraim'),
        ];
        final tree = builder.buildTree(
          CurriculumId.mishnayos,
          leaves,
          {},
        );
        expect(tree.length, 1);
        expect(tree.first.rawValue, 'Zeraim');
        expect(tree.first.level, 1);
        expect(tree.first.state, LifetimeNodeState.none);
      });

      test('learned leaf sets node state to full', () {
        final leaves = [
          leaf('Berakhot 1:1', level1: 'Zeraim'),
        ];
        final tree = builder.buildTree(
          CurriculumId.mishnayos,
          leaves,
          {'Berakhot 1:1'},
        );
        expect(tree.first.state, LifetimeNodeState.full);
      });

      test('partial completion sets partial state', () {
        final leaves = [
          leaf('Berakhot 1:1', level1: 'Zeraim', sortOrder: 1),
          leaf('Berakhot 1:2', level1: 'Zeraim', sortOrder: 2),
        ];
        final tree = builder.buildTree(
          CurriculumId.mishnayos,
          leaves,
          {'Berakhot 1:1'}, // Only first leaf learned
        );
        expect(tree.first.state, LifetimeNodeState.partial);
      });

      test('groups leaves by level1', () {
        final leaves = [
          leaf('Berakhot 1:1', level1: 'Zeraim', sortOrder: 1),
          leaf('Shabbat 1:1', level1: 'Moed', sortOrder: 10),
        ];
        final tree = builder.buildTree(
          CurriculumId.mishnayos,
          leaves,
          {},
        );
        expect(tree.length, 2);
        expect(tree.map((n) => n.rawValue).toSet(), {'Zeraim', 'Moed'});
      });

      test('sorts by sortOrder within level', () {
        final leaves = [
          leaf('Shabbat 1:1', level1: 'Moed', sortOrder: 10),
          leaf('Berakhot 1:1', level1: 'Zeraim', sortOrder: 1),
        ];
        final tree = builder.buildTree(
          CurriculumId.mishnayos,
          leaves,
          {},
        );
        expect(tree.first.rawValue, 'Zeraim'); // lower sortOrder first
      });
    });

    // -------------------------------------------------------------------------
    // buildHeLabelLookup — static helper
    // -------------------------------------------------------------------------
    group('buildHeLabelLookup', () {
      test('returns empty map for empty content', () {
        expect(LifetimeTreeBuilder.buildHeLabelLookup([]), isEmpty);
      });

      test('skips leaf items', () {
        final items = [
          leaf('Berakhot 1:1'),
        ];
        expect(LifetimeTreeBuilder.buildHeLabelLookup(items), isEmpty);
      });

      test('includes non-leaf items with Hebrew names', () {
        final items = [
          ContentItem(
            curriculumId: 'mishnayos',
            level1: 'Zeraim',
            level2: null,
            displayNameHe: 'זרעים',
            displayNameEn: 'Zeraim',
            sefariaRef: 'Zeraim',
            sortOrder: 0,
            isLeaf: false,
          ),
        ];
        final lookup = LifetimeTreeBuilder.buildHeLabelLookup(items);
        expect(lookup['Zeraim'], 'זרעים');
      });
    });
  });
}
