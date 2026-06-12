import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';

ContentItem _leaf(
  String sefariaRef, {
  required String level1,
  required String level2,
  required String level3,
  String? level4,
  int sortOrder = 0,
}) => ContentItem(
  curriculumId: 'bavli',
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

LearningLedgerData _ledger({
  required String entryScope,
  required String unitIdentifier,
}) => LearningLedgerData(
  id: 0,
  profileId: 1,
  ulid: '',
  curriculumId: 'bavli',
  entryScope: entryScope,
  unitIdentifier: unitIdentifier,
  unitDisplayNameHe: '',
  unitDisplayNameEn: '',
  trackType: 'personal',
  trackId: null,
  completedAt: DateTime.utc(2026, 1, 1),
  completionNumber: 1,
  markedBy: 1,
  isManual: false,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('scopeUnitIdentifier', () {
    test('level1 is bare (curriculum root)', () {
      expect(
        scopeUnitIdentifier(level: 1, level1: 'Moed', level2: 'Shabbos'),
        'Moed',
      );
    });

    test('level2 is qualified with its level1 ancestor', () {
      // Talmud: masechta names are globally unique, so the seder prefix is
      // harmless. Chumash: perek '1' repeats across sefarim, so the sefer
      // prefix is REQUIRED to keep Bereishis perek 1 distinct from Shemos
      // perek 1.
      expect(
        scopeUnitIdentifier(level: 2, level1: 'Moed', level2: 'Shabbos'),
        'Moed${kScopeIdSeparator}Shabbos',
      );
      expect(
        scopeUnitIdentifier(level: 2, level1: 'Bereishis', level2: '1'),
        'Bereishis${kScopeIdSeparator}1',
      );
    });

    test('level3 is qualified with the full ancestor path', () {
      expect(
        scopeUnitIdentifier(
          level: 3,
          level1: 'Zeraim',
          level2: 'Berakhos',
          level3: '2',
        ),
        'Zeraim${kScopeIdSeparator}Berakhos${kScopeIdSeparator}2',
      );
    });

    test('level4 is qualified with the full ancestor path', () {
      expect(
        scopeUnitIdentifier(
          level: 4,
          level1: 'Zeraim',
          level2: 'Berakhos',
          level3: '2',
          level4: 'a',
        ),
        'Zeraim${kScopeIdSeparator}Berakhos'
        '${kScopeIdSeparator}2${kScopeIdSeparator}a',
      );
    });

    test('scopeUnitIdentifierForItem mirrors scopeUnitIdentifier', () {
      final item = _leaf(
        'Berakhos 2a',
        level1: 'Zeraim',
        level2: 'Berakhos',
        level3: '2',
        level4: 'a',
      );
      expect(scopeUnitIdentifierForItem(item, 1), 'Zeraim');
      expect(
        scopeUnitIdentifierForItem(item, 2),
        'Zeraim${kScopeIdSeparator}Berakhos',
      );
      expect(
        scopeUnitIdentifierForItem(item, 3),
        'Zeraim${kScopeIdSeparator}Berakhos${kScopeIdSeparator}2',
      );
      expect(
        scopeUnitIdentifierForItem(item, 4),
        'Zeraim${kScopeIdSeparator}Berakhos'
        '${kScopeIdSeparator}2${kScopeIdSeparator}a',
      );
    });

    test('returns empty string for out-of-range levels', () {
      expect(scopeUnitIdentifier(level: 0, level1: 'X'), '');
      expect(scopeUnitIdentifier(level: 5, level1: 'X'), '');
    });
  });

  group('computeLearnedLeafRefs — level3 cross-masechta collision', () {
    const builder = LifetimeTreeBuilder();

    // Two masechtas, each with a daf '2'. A bare daf-'2' mark used to credit
    // BOTH; a qualified level3 mark must credit ONLY the masechta it targets.
    final leaves = [
      _leaf('Berakhos 2a', level1: 'Zeraim', level2: 'Berakhos', level3: '2'),
      _leaf('Berakhos 2b', level1: 'Zeraim', level2: 'Berakhos', level3: '2'),
      _leaf('Shabbos 2a', level1: 'Moed', level2: 'Shabbos', level3: '2'),
      _leaf('Shabbos 2b', level1: 'Moed', level2: 'Shabbos', level3: '2'),
    ];

    test('qualified level3 mark credits ONLY the targeted masechta', () {
      final markId = scopeUnitIdentifier(
        level: 3,
        level1: 'Zeraim',
        level2: 'Berakhos',
        level3: '2',
      );
      final result = builder.computeLearnedLeafRefs(
        leaves: leaves,
        completedRefs: const {},
        ledgerEntries: [_ledger(entryScope: 'level3', unitIdentifier: markId)],
      );

      expect(result, {'Berakhos 2a', 'Berakhos 2b'});
      expect(result.contains('Shabbos 2a'), isFalse);
      expect(result.contains('Shabbos 2b'), isFalse);
    });

    test(
      'a bare daf-2 mark no longer credits any leaf (legacy id ignored)',
      () {
        // Legacy unqualified marks should not match the new qualified leaf ids.
        final result = builder.computeLearnedLeafRefs(
          leaves: leaves,
          completedRefs: const {},
          ledgerEntries: [_ledger(entryScope: 'level3', unitIdentifier: '2')],
        );
        expect(result, isEmpty);
      },
    );

    test('level1 (seder) scope mark still credits its whole seder (bare)', () {
      final result = builder.computeLearnedLeafRefs(
        leaves: leaves,
        completedRefs: const {},
        ledgerEntries: [_ledger(entryScope: 'level1', unitIdentifier: 'Moed')],
      );
      expect(result, {'Shabbos 2a', 'Shabbos 2b'});
    });
  });

  group('computeLearnedLeafRefs — level2 cross-sefer collision (Chumash)', () {
    const builder = LifetimeTreeBuilder();

    // Chumash hierarchy: level1 = sefer, level2 = perek, level3 = pasuk. Perek
    // '1' exists in EVERY sefer, so a bare perek-'1' mark used to credit perek 1
    // of all five chumashim (the +170-pesukim over-crediting the resweep found).
    final chumashLeaves = [
      _leaf('Genesis 1:1', level1: 'Bereishis', level2: '1', level3: '1'),
      _leaf('Genesis 1:2', level1: 'Bereishis', level2: '1', level3: '2'),
      _leaf('Exodus 1:1', level1: 'Shemos', level2: '1', level3: '1'),
      _leaf('Exodus 1:2', level1: 'Shemos', level2: '1', level3: '2'),
    ];

    test('qualified level2 mark credits ONLY the targeted sefer', () {
      final markId = scopeUnitIdentifier(
        level: 2,
        level1: 'Bereishis',
        level2: '1',
      );
      final result = builder.computeLearnedLeafRefs(
        leaves: chumashLeaves,
        completedRefs: const {},
        ledgerEntries: [_ledger(entryScope: 'level2', unitIdentifier: markId)],
      );

      expect(result, {'Genesis 1:1', 'Genesis 1:2'});
      expect(result.contains('Exodus 1:1'), isFalse);
      expect(result.contains('Exodus 1:2'), isFalse);
    });

    test(
      'a bare perek-1 mark no longer credits any leaf (legacy id ignored)',
      () {
        final result = builder.computeLearnedLeafRefs(
          leaves: chumashLeaves,
          completedRefs: const {},
          ledgerEntries: [_ledger(entryScope: 'level2', unitIdentifier: '1')],
        );
        expect(result, isEmpty);
      },
    );
  });
}
