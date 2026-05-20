import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';

ContentItem leaf(
  String sefariaRef, {
  String level1 = 'Zeraim',
  String? level2,
  String? level3,
  String? level4,
  int sortOrder = 0,
}) => ContentItem(
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
        final leaves = [leaf('Berakhot 1:1'), leaf('Berakhot 1:2')];
        final result = builder.computeLearnedLeafRefs(
          leaves: leaves,
          completedRefs: {},
          ledgerEntries: [],
        );
        expect(result, isEmpty);
      });

      test('includes directly completed refs', () {
        final leaves = [leaf('Berakhot 1:1'), leaf('Berakhot 1:2')];
        final result = builder.computeLearnedLeafRefs(
          leaves: leaves,
          completedRefs: {'Berakhot 1:1'},
          ledgerEntries: [],
        );
        expect(result, {'Berakhot 1:1'});
      });

      test('does not include refs not in leaf set', () {
        final leaves = [leaf('Berakhot 1:1')];
        final result = builder.computeLearnedLeafRefs(
          leaves: leaves,
          completedRefs: {
            'Berakhot 1:1',
            'Shabbat 2a',
          }, // Shabbat not in leaves
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
        final tree = builder.buildTree(CurriculumId.mishnayos, [], {});
        expect(tree, isEmpty);
      });

      test('single leaf creates single root node', () {
        final leaves = [leaf('Berakhot 1:1', level1: 'Zeraim')];
        final tree = builder.buildTree(CurriculumId.mishnayos, leaves, {});
        expect(tree.length, 1);
        expect(tree.first.rawValue, 'Zeraim');
        expect(tree.first.level, 1);
        expect(tree.first.state, LifetimeNodeState.none);
      });

      test('learned leaf sets node state to full', () {
        final leaves = [leaf('Berakhot 1:1', level1: 'Zeraim')];
        final tree = builder.buildTree(CurriculumId.mishnayos, leaves, {
          'Berakhot 1:1',
        });
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
        final tree = builder.buildTree(CurriculumId.mishnayos, leaves, {});
        expect(tree.length, 2);
        expect(tree.map((n) => n.rawValue).toSet(), {'Zeraim', 'Moed'});
      });

      test('sorts by sortOrder within level', () {
        final leaves = [
          leaf('Shabbat 1:1', level1: 'Moed', sortOrder: 10),
          leaf('Berakhot 1:1', level1: 'Zeraim', sortOrder: 1),
        ];
        final tree = builder.buildTree(CurriculumId.mishnayos, leaves, {});
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
        final items = [leaf('Berakhot 1:1')];
        expect(LifetimeTreeBuilder.buildHeLabelLookup(items), isEmpty);
      });

      test('includes non-leaf items with Hebrew names', () {
        final items = [
          const ContentItem(
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

    // -------------------------------------------------------------------------
    // computeLeafProvenance — F12 regression guard
    //
    // The classification "live if count > 0 && !hasImportRow" is correct ONLY
    // because CompletionWriter._upgradePriorMarkRow DELETES the import row
    // when a live event commits for an existing bulk natural key. This test
    // simulates the post-upgrade state — an event row remains, but the import
    // row has been removed — and asserts the ref classifies as `live`.
    // If the deletion contract is ever broken, this test fails first.
    // -------------------------------------------------------------------------
    group('computeLeafProvenance — F12 upgrade case', () {
      test('a ref with completion events AND no remaining import row '
          'classifies as live (post-upgrade state)', () {
        const ref = 'Mishnah Berakhot 1:1';

        // Simulated post-upgrade state:
        //   * completionEventRefs has both the original bulk-import event AND
        //     the new live event for `ref` (count = 2).
        //   * bulkImportedRefs is EMPTY — the import row was deleted by
        //     CompletionWriter._upgradePriorMarkRow.
        final provenance = LifetimeTreeBuilder.computeLeafProvenance(
          completionEventRefs: [ref, ref],
          bulkImportedRefs: const <String>{},
          lifetimeImportedRefs: const <String>{},
        );

        expect(provenance, contains(ref));
        expect(
          provenance[ref]!.source,
          LifetimeLeafSource.live,
          reason:
              'After upgrade the import row is gone, so Rule 1 (count > 0 '
              '&& !hasImportRow) fires and the leaf is classified live',
        );
        expect(
          provenance[ref]!.chazarosCount,
          2,
          reason: 'chazarosCount must reflect the total event count (2)',
        );
      });

      test('a ref with completion events AND a bulk import row still present '
          'classifies as bulkMarked (pre-upgrade state)', () {
        const ref = 'Mishnah Berakhot 1:1';

        // Pre-upgrade state: bulk row imported but no live event has hit
        // it yet — the row in prior_completion_imports is still present.
        final provenance = LifetimeTreeBuilder.computeLeafProvenance(
          completionEventRefs: [ref],
          bulkImportedRefs: const {ref},
          lifetimeImportedRefs: const <String>{},
        );

        expect(provenance[ref]!.source, LifetimeLeafSource.bulkMarked);
      });
    });
  });
}
