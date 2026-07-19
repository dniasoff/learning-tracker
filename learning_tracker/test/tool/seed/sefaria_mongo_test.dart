// Unit tests for `tool/seed/lib/sefaria_mongo.dart`'s pure ref/address
// parsing engine (AUD-guardrails-04).
//
// Before this finding, `find test/tool -type f` returned no file touching
// this 542-line Sefaria ref-resolution engine — the only check was
// `tool/seed/sample_validate.dart`, a 34-line script that prints 9 hardcoded
// refs for a human to eyeball against a live local Mongo; it asserts
// nothing and isn't wired into `make ci`/`make seed`.
//
// The four pure helpers this finding names (`_parseTuple`/`_addressToIndex`,
// `_collectAddressed`, the schema-walk child matcher, `_flatten`) never
// touch the class's `Db`, so they were made `static` + `@visibleForTesting`
// (dropping their leading underscore) to be reachable from a test file with
// no live Mongo/Docker connection — see the doc comments on
// `SefariaMongo.addressToIndex`, `SefariaMongo.matchChild`, and
// `SefariaMongo.collectAddressed` in the library file for the rationale.
//
// Covers the four scenarios this finding names:
//   1. Talmud daf→index (2a→2, 2b→3, 3a→4).
//   2. A multi-section range flatten.
//   3. Longest-prefix title matching against a comma-bearing child title.
//   4. Version-priority merge-first-non-empty.

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../../tool/seed/lib/sefaria_mongo.dart';

void main() {
  group(
    'SefariaMongo.addressToIndex — Talmud daf→index (AUD-guardrails-04)',
    () {
      test('2a → 2, 2b → 3, 3a → 4 (Sefaria stores daf 1a at chapter index 0: '
          '(daf-1)*2+amud)', () {
        expect(SefariaMongo.addressToIndex('2a', 'Talmud'), 2);
        expect(SefariaMongo.addressToIndex('2b', 'Talmud'), 3);
        expect(SefariaMongo.addressToIndex('3a', 'Talmud'), 4);
      });

      test('bare daf number defaults to amud a', () {
        expect(SefariaMongo.addressToIndex('3', 'Talmud'), 4);
      });

      test('non-Talmud address types are plain 1-based integers (contrast '
          'case: no daf/amud arithmetic)', () {
        expect(SefariaMongo.addressToIndex('1', 'Integer'), 0);
        expect(SefariaMongo.addressToIndex('12', 'Perek'), 11);
      });

      test('malformed token returns null instead of throwing', () {
        expect(SefariaMongo.addressToIndex('not-a-number', 'Talmud'), isNull);
        expect(SefariaMongo.addressToIndex('not-a-number', 'Integer'), isNull);
      });
    },
  );

  group('SefariaMongo.matchChild — longest-prefix title matching '
      '(AUD-guardrails-04)', () {
    test('matches a comma-bearing child title as ONE longest prefix, never '
        'splitting on the embedded comma, even when a shorter sibling '
        'title is also a valid (shorter) prefix', () {
      const longTitle = 'Part One, The Prohibition Against Lashon Hara';
      final shortSibling = SchemaNode(
        key: 'part_one_short_key',
        nodeType: 'JaggedArrayNode',
        enTitles: const ['Part One'],
        addressTypes: const ['Integer'],
        children: const [],
      );
      final commaChild = SchemaNode(
        key: 'part_one_full_key',
        nodeType: 'JaggedArrayNode',
        enTitles: const [longTitle],
        addressTypes: const ['Integer'],
        children: const [],
      );
      final root = SchemaNode(
        key: 'default',
        nodeType: 'SchemaNode',
        enTitles: const [],
        addressTypes: const [],
        children: [shortSibling, commaChild],
      );

      final match = SefariaMongo.matchChild(root, '$longTitle 5');

      expect(match, isNotNull);
      expect(
        match!.node.key,
        'part_one_full_key',
        reason:
            'the longer, comma-bearing title must win over the shorter '
            'sibling prefix ("Part One") — this is the longest-prefix '
            'matching rule the finding calls out',
      );
      expect(
        match.matchedLength,
        longTitle.length,
        reason:
            'the full comma-bearing title must be consumed as one unit, '
            'not truncated at the embedded comma',
      );
    });

    test(
      'a node key is a valid fallback candidate when no en-title is set',
      () {
        final keyOnlyChild = SchemaNode(
          key: 'Introduction',
          nodeType: 'JaggedArrayNode',
          enTitles: const [],
          addressTypes: const ['Integer'],
          children: const [],
        );
        final root = SchemaNode(
          key: 'default',
          nodeType: 'SchemaNode',
          enTitles: const [],
          addressTypes: const [],
          children: [keyOnlyChild],
        );

        final match = SefariaMongo.matchChild(root, 'Introduction 1');

        expect(match, isNotNull);
        expect(match!.node.key, 'Introduction');
        expect(match.matchedLength, 'Introduction'.length);
      },
    );

    test('returns null when no child title prefixes the remainder', () {
      final child = SchemaNode(
        key: 'child',
        nodeType: 'JaggedArrayNode',
        enTitles: const ['Chapter One'],
        addressTypes: const ['Integer'],
        children: const [],
      );
      final root = SchemaNode(
        key: 'default',
        nodeType: 'SchemaNode',
        enTitles: const [],
        addressTypes: const [],
        children: [child],
      );

      expect(SefariaMongo.matchChild(root, 'Something Else 1'), isNull);
    });
  });

  group('SefariaMongo.collectAddressed — range flatten + version-priority '
      'merge (AUD-guardrails-04)', () {
    test('multi-section range flatten: enumerates every segment from the '
        'start section/segment through the end section/segment inclusive, '
        'across a section boundary', () {
      // A single version's navigated node: 2 sections of 3 and 2 segments.
      final version = [
        ['s0seg0', 's0seg1', 's0seg2'],
        ['s1seg0', 's1seg1'],
      ];

      // Range "section 0, segment 1" .. "section 1, segment 0" — crosses the
      // section boundary, so the flatten must run to the end of section 0's
      // row (via `_rowLen`) before starting section 1 at its own segment 0.
      final result = SefariaMongo.collectAddressed(
        [version],
        start: [0, 1],
        end: [1, 0],
        addressTypes: const ['Perek', 'Halakhah'],
      );

      expect(result, 's0seg1\ns0seg2\ns1seg0');
    });

    test('version-priority merge-first-non-empty: an empty cell in the '
        'higher-priority (first) version falls through to the same cell in '
        'the next version, not to a default/blank result', () {
      // perVersionNodes is priority-ordered (highest first), mirroring
      // `_mergedVersions`' `sort: {priority: -1, _id: 1}`.
      final highPriorityVersion = ['', 'high-text-at-1'];
      final lowPriorityVersion = ['low-text-at-0', 'low-text-at-1'];

      final result = SefariaMongo.collectAddressed(
        [highPriorityVersion, lowPriorityVersion],
        start: const [0],
        end: null,
        addressTypes: const ['Integer'],
      );

      expect(
        result,
        'low-text-at-0',
        reason:
            'index 0 is empty in the higher-priority version, so the merge '
            'must fall through to the lower-priority version\'s non-empty '
            'text at the same index',
      );
    });

    test('version-priority merge-first-non-empty: a non-empty cell in the '
        'higher-priority version wins outright, ignoring lower-priority '
        'versions', () {
      final highPriorityVersion = ['high-text-at-0'];
      final lowPriorityVersion = ['low-text-at-0'];

      final result = SefariaMongo.collectAddressed(
        [highPriorityVersion, lowPriorityVersion],
        start: const [0],
        end: null,
        addressTypes: const ['Integer'],
      );

      expect(result, 'high-text-at-0');
    });
  });
}
