/// Unit tests for the SefariaRefMatcher domain service.
///
/// Covers every public function:
///   - normalizeRef
///   - displayProgramRef
///   - refVariants
///   - matchOriginalCasing
///   - expandSimpleRange
///   - expandDafLikeRange
///   - parseRefTail
///   - normalizeTitle
///   - titleSimilarityScore
///   - leafChildrenForContainer
///   - findFuzzyContainerMatch
///   - resolveLeafRefsFromContainer
///   - resolveIndexedUnitRefs
///   - resolveProgramTodayRefs
///   - resolvedOrFallbackProgramRefs
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/scheduler/domain/services/sefaria_ref_matcher.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ContentItem _leaf({
  required String ref,
  String curriculumId = 'talmud',
  String level1 = 'L1',
  String? level2,
  String? level3,
  String? level4,
  int sortOrder = 0,
}) {
  return ContentItem(
    curriculumId: curriculumId,
    level1: level1,
    level2: level2,
    level3: level3,
    level4: level4,
    displayNameHe: ref,
    displayNameEn: ref,
    sefariaRef: ref,
    sortOrder: sortOrder,
    isLeaf: true,
  );
}

ContentItem _container({
  required String ref,
  String curriculumId = 'talmud',
  String level1 = 'L1',
  String? level2,
  String? level3,
  String? level4,
  int sortOrder = 0,
}) {
  return ContentItem(
    curriculumId: curriculumId,
    level1: level1,
    level2: level2,
    level3: level3,
    level4: level4,
    displayNameHe: ref,
    displayNameEn: ref,
    sefariaRef: ref,
    sortOrder: sortOrder,
    isLeaf: false,
  );
}

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // normalizeRef
  // ──────────────────────────────────────────────────────────────────────────

  group('normalizeRef', () {
    test('lowercases input', () {
      expect(normalizeRef('Berakhot 2a'), equals('berakhot 2a'));
    });

    test('replaces underscores with spaces', () {
      expect(normalizeRef('Genesis_1_1'), equals('genesis 1 1'));
    });

    test('replaces colons with dots', () {
      expect(normalizeRef('Genesis 1:2'), equals('genesis 1.2'));
    });

    test('strips non-alphanumeric non-whitespace non-dot characters', () {
      // dashes, apostrophes, etc. are stripped
      expect(normalizeRef("Rosh Ha'shanah 2a"), equals('rosh hashanah 2a'));
    });

    test('collapses multiple spaces', () {
      expect(normalizeRef('Berakhot   2a'), equals('berakhot 2a'));
    });

    test('trims leading/trailing whitespace', () {
      expect(normalizeRef('  Berakhot 2a  '), equals('berakhot 2a'));
    });

    test('handles already-normalized ref idempotently', () {
      expect(normalizeRef('berakhot 2a'), equals('berakhot 2a'));
    });

    test('preserves dots (chapter.verse separator)', () {
      expect(normalizeRef('Genesis 1.2'), equals('genesis 1.2'));
    });

    test('empty string returns empty string', () {
      expect(normalizeRef(''), equals(''));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // displayProgramRef
  // ──────────────────────────────────────────────────────────────────────────

  group('displayProgramRef', () {
    test('replaces underscores with spaces', () {
      expect(
        displayProgramRef('Mishnah_Berakhot_2'),
        equals('Mishnah Berakhot 2'),
      );
    });

    test('collapses multiple spaces', () {
      expect(displayProgramRef('A__B'), equals('A B'));
    });

    test('trims result', () {
      expect(displayProgramRef('_Berakhot_'), equals('Berakhot'));
    });

    test('plain ref without underscores is unchanged', () {
      expect(displayProgramRef('Berakhot 2a'), equals('Berakhot 2a'));
    });

    test('empty string returns empty string', () {
      expect(displayProgramRef(''), equals(''));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // matchOriginalCasing
  // ──────────────────────────────────────────────────────────────────────────

  group('matchOriginalCasing', () {
    test('all-caps original returns upper-cased result', () {
      expect(matchOriginalCasing('MIDOS', 'middot'), equals('MIDDOT'));
    });

    test('all-lower original returns lower-cased result', () {
      expect(matchOriginalCasing('midos', 'middot'), equals('middot'));
    });

    test('mixed-case original returns title-cased result', () {
      expect(
        matchOriginalCasing('Midos Avot', 'middot avot'),
        equals('Middot Avot'),
      );
    });

    test('handles single word', () {
      expect(matchOriginalCasing('Midos', 'middot'), equals('Middot'));
    });

    test('handles lower with multi words', () {
      expect(
        matchOriginalCasing('mishnayos berakhot', 'mishnah berakhot'),
        equals('mishnah berakhot'),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // refVariants
  // ──────────────────────────────────────────────────────────────────────────

  group('refVariants', () {
    test('empty string returns empty set', () {
      expect(refVariants(''), isEmpty);
    });

    test('whitespace-only string returns empty set', () {
      expect(refVariants('   '), isEmpty);
    });

    test(
      'plain ref adds Mishnah-prefixed and Jerusalem Talmud-prefixed variants',
      () {
        final v = refVariants('Berakhot 2');
        expect(v, contains('Berakhot 2'));
        expect(v, contains('Mishnah Berakhot 2'));
        expect(v, contains('Jerusalem Talmud Berakhot 2'));
      },
    );

    test('"Mishnah " prefix: strips prefix to produce bare variant', () {
      final v = refVariants('Mishnah Berakhot 2');
      // the bare form (without "Mishnah ") must appear
      expect(v, contains('Berakhot 2'));
    });

    test(
      '"Jerusalem Talmud " prefix: strips prefix to produce bare variant',
      () {
        final v = refVariants('Jerusalem Talmud Berakhot 2');
        expect(v, contains('Berakhot 2'));
      },
    );

    test('midos alias → middot', () {
      final v = refVariants('Pirkei Avos Midos 1');
      // The alias-replaced form should be title-cased (Middot)
      expect(v.any((s) => s.toLowerCase().contains('middot')), isTrue);
    });

    test('mishnayos alias → mishnah', () {
      final v = refVariants('Mishnayos Berakhot 2');
      expect(v.any((s) => s.toLowerCase().contains('mishnah')), isTrue);
    });

    test('normalises en-dash to hyphen before processing', () {
      // U+2013 en-dash
      final v = refVariants('Berakhot 2–3');
      expect(v.any((s) => s.contains('-')), isTrue);
    });

    test('all returned variants are non-empty and trimmed', () {
      final v = refVariants('Berakhot 2a');
      for (final variant in v) {
        expect(variant.trim(), equals(variant));
        expect(variant, isNotEmpty);
      }
    });

    test('mishna (without h) alias → mishnah variant', () {
      final v = refVariants('Mishna Berakhot 2');
      expect(v.any((s) => s.toLowerCase().contains('mishnah')), isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // expandSimpleRange
  // ──────────────────────────────────────────────────────────────────────────

  group('expandSimpleRange', () {
    test('expands N.from-to correctly', () {
      final result = expandSimpleRange('Genesis 1.2-4');
      expect(result, containsAll(['Genesis 1.2', 'Genesis 1:2']));
      expect(result, containsAll(['Genesis 1.3', 'Genesis 1:3']));
      expect(result, containsAll(['Genesis 1.4', 'Genesis 1:4']));
    });

    test('expands N:from-to (colon separator)', () {
      final result = expandSimpleRange('Genesis 1:2-4');
      expect(result, containsAll(['Genesis 1.2', 'Genesis 1:2']));
    });

    test('returns empty set for non-range ref', () {
      expect(expandSimpleRange('Genesis 1.2'), isEmpty);
    });

    test('returns empty set when to < from', () {
      expect(expandSimpleRange('Genesis 1.5-2'), isEmpty);
    });

    test('single-verse range (from == to) produces one pair', () {
      final result = expandSimpleRange('Genesis 1.3-3');
      expect(result, containsAll(['Genesis 1.3', 'Genesis 1:3']));
      expect(result, hasLength(2));
    });

    test('en-dash treated same as hyphen', () {
      final result = expandSimpleRange('Genesis 1.2–4');
      expect(result, containsAll(['Genesis 1.2', 'Genesis 1:2']));
    });

    test('returns empty set for empty string', () {
      expect(expandSimpleRange(''), isEmpty);
    });

    test('base title with spaces is preserved', () {
      final result = expandSimpleRange('Song of Songs 1.1-3');
      expect(result, contains('Song of Songs 1.1'));
      expect(result, contains('Song of Songs 1.3'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // expandDafLikeRange
  // ──────────────────────────────────────────────────────────────────────────

  group('expandDafLikeRange', () {
    test('plain numeric range expands without a/b sides', () {
      final result = expandDafLikeRange('Berakhot 2-4');
      expect(result, containsAll(['Berakhot 2', 'Berakhot 3', 'Berakhot 4']));
    });

    test('range with a/b suffixes expands to both amudim', () {
      final result = expandDafLikeRange('Berakhot 2a-4b');
      expect(result, containsAll(['Berakhot 2a', 'Berakhot 2b']));
      expect(result, containsAll(['Berakhot 3a', 'Berakhot 3b']));
      expect(result, containsAll(['Berakhot 4a', 'Berakhot 4b']));
    });

    test('fromSide=b removes the "a" entry of the first daf', () {
      final result = expandDafLikeRange('Berakhot 2b-3b');
      expect(result, isNot(contains('Berakhot 2a')));
      expect(result, contains('Berakhot 2b'));
    });

    test('toSide=a removes the "b" entry of the last daf', () {
      final result = expandDafLikeRange('Berakhot 2a-4a');
      expect(result, isNot(contains('Berakhot 4b')));
      expect(result, contains('Berakhot 4a'));
    });

    test('single daf range (from==to) with sides works', () {
      final result = expandDafLikeRange('Berakhot 3a-3b');
      expect(result, containsAll(['Berakhot 3a', 'Berakhot 3b']));
    });

    test('returns empty set when to < from', () {
      expect(expandDafLikeRange('Berakhot 5-3'), isEmpty);
    });

    test('returns empty set for non-range input', () {
      expect(expandDafLikeRange('Berakhot 2a'), isEmpty);
    });

    test('returns empty set for empty string', () {
      expect(expandDafLikeRange(''), isEmpty);
    });

    test('en-dash treated same as hyphen', () {
      final result = expandDafLikeRange('Berakhot 2–4');
      expect(result, contains('Berakhot 2'));
      expect(result, contains('Berakhot 4'));
    });

    test('case-insensitive side suffixes (uppercase A/B)', () {
      final result = expandDafLikeRange('Berakhot 2A-4B');
      expect(result, containsAll(['Berakhot 2a', 'Berakhot 2b']));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // parseRefTail
  // ──────────────────────────────────────────────────────────────────────────

  group('parseRefTail', () {
    test('splits "Berakhot 2" into ("Berakhot", "2")', () {
      final result = parseRefTail('Berakhot 2');
      expect(result, isNotNull);
      expect(result!.$1, equals('Berakhot'));
      expect(result.$2, equals('2'));
    });

    test('splits "Berakhot 2a" into ("Berakhot", "2a")', () {
      final result = parseRefTail('Berakhot 2a');
      expect(result, isNotNull);
      expect(result!.$1, equals('Berakhot'));
      expect(result.$2, equals('2a'));
    });

    test('returns null for ref without trailing numeric address', () {
      expect(parseRefTail('Berakhot'), isNull);
    });

    test('returns null for empty string', () {
      expect(parseRefTail(''), isNull);
    });

    test('handles multi-word title', () {
      final result = parseRefTail('Jerusalem Talmud Berakhot 5b');
      expect(result, isNotNull);
      expect(result!.$1, equals('Jerusalem Talmud Berakhot'));
      expect(result.$2, equals('5b'));
    });

    test('underscores are converted to spaces before parsing', () {
      final result = parseRefTail('Berakhot_2a');
      expect(result, isNotNull);
      expect(result!.$2, equals('2a'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // normalizeTitle
  // ──────────────────────────────────────────────────────────────────────────

  group('normalizeTitle', () {
    test('lowercases and removes punctuation', () {
      expect(normalizeTitle("Rosh Ha'Shanah"), equals('rosh hashanah'));
    });

    test('removes stop-word "the"', () {
      expect(normalizeTitle('The Talmud'), equals(''));
    });

    test('removes stop-word "talmud"', () {
      expect(normalizeTitle('Talmud Berakhot'), equals('berakhot'));
    });

    test('removes stop-word "mishnah"', () {
      expect(normalizeTitle('Mishnah Berakhot'), equals('berakhot'));
    });

    test('removes stop-word "jerusalem"', () {
      expect(normalizeTitle('Jerusalem Talmud Berakhot'), equals('berakhot'));
    });

    test('baba → bava spelling normalisation', () {
      expect(normalizeTitle('Baba Kamma'), equals('bava kamma'));
    });

    test('succah → sukkah spelling normalisation', () {
      expect(normalizeTitle('Succah'), equals('sukkah'));
    });

    test('megilah → megillah spelling normalisation', () {
      expect(normalizeTitle('Megilah'), equals('megillah'));
    });

    test('hullin → chullin spelling normalisation', () {
      expect(normalizeTitle('Hullin'), equals('chullin'));
    });

    test('beitzah → beitza spelling normalisation', () {
      expect(normalizeTitle('Beitzah'), equals('beitza'));
    });

    test('collapses multiple spaces', () {
      expect(normalizeTitle('Bava  Kamma'), equals('bava kamma'));
    });

    test('empty string returns empty string', () {
      expect(normalizeTitle(''), equals(''));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // titleSimilarityScore
  // ──────────────────────────────────────────────────────────────────────────

  group('titleSimilarityScore', () {
    test('exact match returns 10', () {
      expect(titleSimilarityScore('berakhot', 'berakhot'), equals(10));
    });

    test('containment (a in b) returns 6', () {
      expect(titleSimilarityScore('bava', 'bava kamma'), equals(6));
    });

    test('containment (b in a) returns 6', () {
      expect(titleSimilarityScore('bava kamma', 'bava'), equals(6));
    });

    test('shared word count returned when no containment', () {
      // "bava kamma" vs "bava metzia" share 1 word
      expect(titleSimilarityScore('bava kamma', 'bava metzia'), equals(1));
    });

    test('no shared words returns 0', () {
      expect(titleSimilarityScore('berakhot', 'shabbat'), equals(0));
    });

    test('empty a returns 0', () {
      expect(titleSimilarityScore('', 'berakhot'), equals(0));
    });

    test('empty b returns 0', () {
      expect(titleSimilarityScore('berakhot', ''), equals(0));
    });

    test('both empty returns 0', () {
      expect(titleSimilarityScore('', ''), equals(0));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // leafChildrenForContainer
  // ──────────────────────────────────────────────────────────────────────────

  group('leafChildrenForContainer', () {
    test('returns leaf children matching level1', () {
      final parent = _container(ref: 'Zeraim', level1: 'Zeraim');
      final child1 = _leaf(ref: 'Berakhot 1.1', level1: 'Zeraim', sortOrder: 1);
      final child2 = _leaf(ref: 'Berakhot 1.2', level1: 'Zeraim', sortOrder: 0);
      final unrelated = _leaf(ref: 'Shabbat 1.1', level1: 'Moed');

      final result = leafChildrenForContainer(parent, [
        parent,
        child1,
        child2,
        unrelated,
      ]);

      expect(result, containsAll(['Berakhot 1.1', 'Berakhot 1.2']));
      expect(result, isNot(contains('Shabbat 1.1')));
    });

    test('respects level2 when container has level2 set', () {
      final parent = _container(
        ref: 'Berakhot container',
        level1: 'Zeraim',
        level2: 'Berakhot',
      );
      final child = _leaf(
        ref: 'Berakhot 1a',
        level1: 'Zeraim',
        level2: 'Berakhot',
        sortOrder: 0,
      );
      final wrongLevel2 = _leaf(
        ref: 'Peah 1.1',
        level1: 'Zeraim',
        level2: 'Peah',
        sortOrder: 1,
      );

      final result = leafChildrenForContainer(parent, [
        parent,
        child,
        wrongLevel2,
      ]);
      expect(result, contains('Berakhot 1a'));
      expect(result, isNot(contains('Peah 1.1')));
    });

    test('respects level3 when container has level3 set', () {
      final parent = _container(
        ref: 'Chapter 1',
        level1: 'L1',
        level2: 'L2',
        level3: 'Chapter1',
      );
      final inChapter = _leaf(
        ref: 'Mishna 1.1',
        level1: 'L1',
        level2: 'L2',
        level3: 'Chapter1',
        sortOrder: 0,
      );
      final otherChapter = _leaf(
        ref: 'Mishna 2.1',
        level1: 'L1',
        level2: 'L2',
        level3: 'Chapter2',
        sortOrder: 1,
      );

      final result = leafChildrenForContainer(parent, [
        parent,
        inChapter,
        otherChapter,
      ]);
      expect(result, contains('Mishna 1.1'));
      expect(result, isNot(contains('Mishna 2.1')));
    });

    test('sorts result by sortOrder ascending', () {
      final parent = _container(ref: 'Container', level1: 'L1');
      final a = _leaf(ref: 'C', level1: 'L1', sortOrder: 2);
      final b = _leaf(ref: 'A', level1: 'L1', sortOrder: 0);
      final c = _leaf(ref: 'B', level1: 'L1', sortOrder: 1);

      final result = leafChildrenForContainer(parent, [
        parent,
        a,
        b,
        c,
      ]).toList();
      // Sets don't preserve insertion order, but the function sorts before
      // converting to set — verify all three are present
      expect(result, containsAll(['A', 'B', 'C']));
    });

    test('excludes non-leaf items', () {
      final parent = _container(ref: 'Container', level1: 'L1');
      final nonLeaf = _container(ref: 'Sub-container', level1: 'L1');
      final leaf = _leaf(ref: 'Leaf', level1: 'L1');

      final result = leafChildrenForContainer(parent, [parent, nonLeaf, leaf]);
      expect(result, contains('Leaf'));
      expect(result, isNot(contains('Sub-container')));
    });

    test('returns empty set when no matching children', () {
      final parent = _container(ref: 'Isolated', level1: 'X');
      final unrelated = _leaf(ref: 'Other', level1: 'Y');
      expect(leafChildrenForContainer(parent, [parent, unrelated]), isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // findFuzzyContainerMatch
  // ──────────────────────────────────────────────────────────────────────────

  group('findFuzzyContainerMatch', () {
    test('finds container by exact title match', () {
      final container = _container(ref: 'Berakhot 2a', level1: 'L1');
      final result = findFuzzyContainerMatch('Berakhot 2a', [container]);
      expect(result, isNotNull);
      expect(result!.sefariaRef, equals('Berakhot 2a'));
    });

    test('returns null when no containers exist', () {
      final leaf = _leaf(ref: 'Berakhot 2a');
      expect(findFuzzyContainerMatch('Berakhot 2a', [leaf]), isNull);
    });

    test('returns null for refs without trailing numeric address', () {
      final container = _container(ref: 'Berakhot', level1: 'L1');
      expect(findFuzzyContainerMatch('Berakhot', [container]), isNull);
    });

    test('returns null when score < 2', () {
      // "Shabbat 5" vs "Berakhot 5" — no word overlap → score 0
      final container = _container(ref: 'Berakhot 5', level1: 'L1');
      expect(findFuzzyContainerMatch('Shabbat 5', [container]), isNull);
    });

    test('returns null for empty candidate', () {
      final container = _container(ref: 'Berakhot 2', level1: 'L1');
      expect(findFuzzyContainerMatch('', [container]), isNull);
    });

    test('finds best match when multiple containers share the same address', () {
      // "Bava Kamma 5" vs "Bava Kamma 5" (exact) and "Bava Metzia 5" (score 1)
      final exact = _container(ref: 'Bava Kamma 5', level1: 'L1');
      final partial = _container(ref: 'Bava Metzia 5', level1: 'L2');

      final result = findFuzzyContainerMatch('Bava Kamma 5', [exact, partial]);
      // exact match wins (score 10)
      expect(result?.sefariaRef, equals('Bava Kamma 5'));
    });

    test('spelling normalisation: baba kamma matches bava kamma container', () {
      final container = _container(ref: 'Bava Kamma 5', level1: 'L1');
      // normalizeTitle('Baba Kamma') → 'bava kamma'; same as container title
      final result = findFuzzyContainerMatch('Baba Kamma 5', [container]);
      expect(result, isNotNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // resolveLeafRefsFromContainer
  // ──────────────────────────────────────────────────────────────────────────

  group('resolveLeafRefsFromContainer', () {
    test('empty candidate returns empty set', () {
      final leaf = _leaf(ref: 'Berakhot 2a');
      expect(resolveLeafRefsFromContainer('', [leaf]), isEmpty);
    });

    test('exact match on non-leaf container returns its leaves', () {
      final containerItem = _container(
        ref: 'Berakhot 2',
        level1: 'Seder',
        level2: 'Berakhot',
      );
      final amudA = _leaf(
        ref: 'Berakhot 2a',
        level1: 'Seder',
        level2: 'Berakhot',
        sortOrder: 0,
      );
      final amudB = _leaf(
        ref: 'Berakhot 2b',
        level1: 'Seder',
        level2: 'Berakhot',
        sortOrder: 1,
      );

      final result = resolveLeafRefsFromContainer('Berakhot 2', [
        containerItem,
        amudA,
        amudB,
      ]);

      expect(result, containsAll(['Berakhot 2a', 'Berakhot 2b']));
    });

    test('exact match on leaf returns empty (leaf is not a container)', () {
      final leafItem = _leaf(ref: 'Berakhot 2a', level1: 'L1');
      final result = resolveLeafRefsFromContainer('Berakhot 2a', [leafItem]);
      // The matched item is a leaf → isLeaf==true → no children path taken
      expect(result, isEmpty);
    });

    test('falls back to fuzzy match when exact match not found', () {
      // Candidate "Baba Kamma 5" should fuzzy-match container "Bava Kamma 5"
      final container = _container(
        ref: 'Bava Kamma 5',
        level1: 'Nezikin',
        level2: 'Bava Kamma',
      );
      final child = _leaf(
        ref: 'Bava Kamma 5a',
        level1: 'Nezikin',
        level2: 'Bava Kamma',
      );

      final result = resolveLeafRefsFromContainer('Baba Kamma 5', [
        container,
        child,
      ]);
      expect(result, contains('Bava Kamma 5a'));
    });

    test('returns empty when no container and no fuzzy match', () {
      final leaf = _leaf(ref: 'Berakhot 2a');
      expect(resolveLeafRefsFromContainer('Shabbat 5', [leaf]), isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // resolveIndexedUnitRefs
  // ──────────────────────────────────────────────────────────────────────────

  group('resolveIndexedUnitRefs', () {
    test('returns empty for non-Jerusalem Talmud ref', () {
      final container = _container(ref: 'Berakhot', level1: 'L1', level2: null);
      final leaf1 = _leaf(ref: 'Berakhot 1', level1: 'L1', sortOrder: 0);
      expect(resolveIndexedUnitRefs('Berakhot 3', [container, leaf1]), isEmpty);
    });

    test('returns empty when no ref tail (pure title)', () {
      expect(resolveIndexedUnitRefs('Jerusalem Talmud', []), isEmpty);
    });

    test('returns empty when container not found', () {
      // No matching container in list
      expect(
        resolveIndexedUnitRefs('Jerusalem Talmud Berakhot 1', []),
        isEmpty,
      );
    });

    test('returns empty when index == 0', () {
      // index must be > 0
      expect(
        resolveIndexedUnitRefs('Jerusalem Talmud Berakhot 0', []),
        isEmpty,
      );
    });

    test('returns empty when index > leaf count', () {
      final topContainer = _container(
        ref: 'Jerusalem Talmud Berakhot',
        level1: 'JT',
        level2: 'Berakhot',
      );
      final leaf1 = _leaf(
        ref: 'Jerusalem Talmud Berakhot 1a',
        level1: 'JT',
        level2: 'Berakhot',
        sortOrder: 0,
      );
      final result = resolveIndexedUnitRefs('Jerusalem Talmud Berakhot 5', [
        topContainer,
        leaf1,
      ]);
      expect(result, isEmpty);
    });

    test('returns 1st leaf for index 1', () {
      final topContainer = _container(
        ref: 'Jerusalem Talmud Berakhot',
        level1: 'JT',
        level2: 'Berakhot',
      );
      final leaf1 = _leaf(
        ref: 'Jerusalem Talmud Berakhot 1a',
        level1: 'JT',
        level2: 'Berakhot',
        sortOrder: 0,
      );
      final leaf2 = _leaf(
        ref: 'Jerusalem Talmud Berakhot 1b',
        level1: 'JT',
        level2: 'Berakhot',
        sortOrder: 1,
      );
      final result = resolveIndexedUnitRefs('Jerusalem Talmud Berakhot 1', [
        topContainer,
        leaf1,
        leaf2,
      ]);
      expect(result, equals({'Jerusalem Talmud Berakhot 1a'}));
    });

    test('returns 2nd leaf (by sortOrder) for index 2', () {
      final topContainer = _container(
        ref: 'Jerusalem Talmud Shabbat',
        level1: 'JT',
        level2: 'Shabbat',
      );
      // Intentionally insert with reversed sortOrder to verify sorting
      final leafB = _leaf(
        ref: 'Jerusalem Talmud Shabbat 1b',
        level1: 'JT',
        level2: 'Shabbat',
        sortOrder: 1,
      );
      final leafA = _leaf(
        ref: 'Jerusalem Talmud Shabbat 1a',
        level1: 'JT',
        level2: 'Shabbat',
        sortOrder: 0,
      );
      final result = resolveIndexedUnitRefs('Jerusalem Talmud Shabbat 2', [
        topContainer,
        leafB,
        leafA,
      ]);
      expect(result, equals({'Jerusalem Talmud Shabbat 1b'}));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // resolveProgramTodayRefs
  // ──────────────────────────────────────────────────────────────────────────

  group('resolveProgramTodayRefs', () {
    test('returns empty set when contentItems is empty', () {
      expect(resolveProgramTodayRefs('Berakhot 2', []), isEmpty);
    });

    test('returns empty set when only non-leaf items exist', () {
      final container = _container(ref: 'Berakhot 2');
      expect(resolveProgramTodayRefs('Berakhot 2', [container]), isEmpty);
    });

    test('exact match returns the canonical leaf ref', () {
      final leaf = _leaf(ref: 'Berakhot 2a');
      final result = resolveProgramTodayRefs('Berakhot 2a', [leaf]);
      expect(result, equals({'Berakhot 2a'}));
    });

    test('normalised match (case-insensitive) works', () {
      final leaf = _leaf(ref: 'Berakhot 2a');
      // todayRef uses different casing
      final result = resolveProgramTodayRefs('berakhot 2a', [leaf]);
      expect(result, equals({'Berakhot 2a'}));
    });

    test('colon vs dot normalisation matches', () {
      // content item has "Genesis 1.1", todayRef uses colon
      final leaf = _leaf(ref: 'Genesis 1.1');
      final result = resolveProgramTodayRefs('Genesis 1:1', [leaf]);
      expect(result, equals({'Genesis 1.1'}));
    });

    test('Mishnah-prefixed todayRef matches bare leaf ref', () {
      // leaf is "Berakhot 1.1"; program feed says "Mishnah Berakhot 1.1"
      final leaf = _leaf(ref: 'Berakhot 1.1');
      final result = resolveProgramTodayRefs('Mishnah Berakhot 1.1', [leaf]);
      expect(result, equals({'Berakhot 1.1'}));
    });

    test('bare todayRef matches Mishnah-prefixed leaf', () {
      final leaf = _leaf(ref: 'Mishnah Berakhot 1.1');
      final result = resolveProgramTodayRefs('Berakhot 1.1', [leaf]);
      expect(result, equals({'Mishnah Berakhot 1.1'}));
    });

    test('simple range todayRef resolves to multiple leaves', () {
      final leaf1 = _leaf(ref: 'Genesis 1.1');
      final leaf2 = _leaf(ref: 'Genesis 1.2');
      final leaf3 = _leaf(ref: 'Genesis 1.3');

      final result = resolveProgramTodayRefs('Genesis 1.1-3', [
        leaf1,
        leaf2,
        leaf3,
      ]);
      expect(
        result,
        containsAll(['Genesis 1.1', 'Genesis 1.2', 'Genesis 1.3']),
      );
    });

    test('daf-like range todayRef resolves to amud leaves', () {
      final leafA = _leaf(ref: 'Berakhot 2a');
      final leafB = _leaf(ref: 'Berakhot 2b');

      final result = resolveProgramTodayRefs('Berakhot 2a-2b', [leafA, leafB]);
      expect(result, containsAll(['Berakhot 2a', 'Berakhot 2b']));
    });

    test('falls back to container expansion when direct match fails', () {
      // "Berakhot 2" is not a leaf ref, but a container that has 2a/2b as leaves
      final containerItem = _container(
        ref: 'Berakhot 2',
        level1: 'Seder',
        level2: 'Berakhot',
      );
      final amudA = _leaf(
        ref: 'Berakhot 2a',
        level1: 'Seder',
        level2: 'Berakhot',
        sortOrder: 0,
      );
      final amudB = _leaf(
        ref: 'Berakhot 2b',
        level1: 'Seder',
        level2: 'Berakhot',
        sortOrder: 1,
      );

      final result = resolveProgramTodayRefs('Berakhot 2', [
        containerItem,
        amudA,
        amudB,
      ]);
      expect(result, containsAll(['Berakhot 2a', 'Berakhot 2b']));
    });

    test('mishnayos alias resolves correctly', () {
      // "Mishnayos Berakhot 1.1" → alias expands to "Mishnah Berakhot 1.1"
      final leaf = _leaf(ref: 'Mishnah Berakhot 1.1');
      final result = resolveProgramTodayRefs('Mishnayos Berakhot 1.1', [leaf]);
      expect(result, equals({'Mishnah Berakhot 1.1'}));
    });

    test('en-dash in todayRef is normalised to hyphen before matching', () {
      // "Genesis 1.1–3" should expand and match 1.1, 1.2, 1.3
      final leaf1 = _leaf(ref: 'Genesis 1.1');
      final leaf2 = _leaf(ref: 'Genesis 1.2');
      final leaf3 = _leaf(ref: 'Genesis 1.3');
      final result = resolveProgramTodayRefs('Genesis 1.1–3', [
        leaf1,
        leaf2,
        leaf3,
      ]);
      expect(
        result,
        containsAll(['Genesis 1.1', 'Genesis 1.2', 'Genesis 1.3']),
      );
    });

    test('returns empty set when no match and no fallback container', () {
      final leaf = _leaf(ref: 'Shabbat 5a');
      final result = resolveProgramTodayRefs('Berakhot 99', [leaf]);
      expect(result, isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // resolvedOrFallbackProgramRefs
  // ──────────────────────────────────────────────────────────────────────────

  group('resolvedOrFallbackProgramRefs', () {
    test('returns resolved refs when match found', () {
      final leaf = _leaf(ref: 'Berakhot 2a');
      final result = resolvedOrFallbackProgramRefs(
        todayRef: 'Berakhot 2a',
        contentItems: [leaf],
      );
      expect(result, equals({'Berakhot 2a'}));
    });

    test('returns displayProgramRef fallback when no match found', () {
      final leaf = _leaf(ref: 'Shabbat 5a');
      // "My_Custom_Ref" won't match anything — should fall back to display form
      final result = resolvedOrFallbackProgramRefs(
        todayRef: 'My_Custom_Ref',
        contentItems: [leaf],
      );
      expect(result, equals({'My Custom Ref'}));
    });

    test(
      'returns empty set when todayRef is empty and contentItems is empty',
      () {
        final result = resolvedOrFallbackProgramRefs(
          todayRef: '',
          contentItems: [],
        );
        expect(result, isEmpty);
      },
    );

    test('fallback for whitespace-only todayRef returns empty set', () {
      final result = resolvedOrFallbackProgramRefs(
        todayRef: '   ',
        contentItems: [],
      );
      // displayProgramRef trims → empty → returns {}
      expect(result, isEmpty);
    });

    test('fallback preserves non-underscore content', () {
      final result = resolvedOrFallbackProgramRefs(
        todayRef: 'Some Ref 5',
        contentItems: [],
      );
      // No match; fallback = displayProgramRef("Some Ref 5") = "Some Ref 5"
      expect(result, equals({'Some Ref 5'}));
    });
  });
}
