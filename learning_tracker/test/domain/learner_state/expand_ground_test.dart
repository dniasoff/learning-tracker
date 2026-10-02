// Mirror test for `lib/domain/learner_state/expand_ground.dart` (DNI-465
// AC-3: AD-34 ground expansion).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/expand_ground.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

import '../../helpers/learner_state/chumash_fixtures.dart';
import '../../helpers/learner_state/engine_fixtures.dart';

void main() {
  final corpus = mishnayosCorpus();

  group('AC-3', () {
    test('expands before-tracking nodes in stable ContentIndex order', () {
      // Entries in list order (Moed before Zeraim's Berakhot perek 2), each
      // in ContentIndex order, later duplicates dropped.
      final leaves = expandGround(const [
        shabbat,
        berakhot2,
        berakhot,
        NodeEntry(level: 'mishnah', ref: 'Mishnah Shabbat 1:2'),
      ], corpus);
      expect(leaves, [
        'Mishnah Shabbat 1:1',
        'Mishnah Shabbat 1:2',
        'Mishnah Berakhot 2:1',
        'Mishnah Berakhot 2:2',
        'Mishnah Berakhot 1:1',
        'Mishnah Berakhot 1:2',
        'Mishnah Berakhot 1:3',
      ]);
    });

    test('every covered leaf of a seder is listed once', () {
      expect(expandGround(const [zeraim], corpus), [
        'Mishnah Berakhot 1:1',
        'Mishnah Berakhot 1:2',
        'Mishnah Berakhot 1:3',
        'Mishnah Berakhot 2:1',
        'Mishnah Berakhot 2:2',
        'Mishnah Peah 1:1',
        'Mishnah Peah 1:2',
      ]);
    });
  });

  test('a leaf entry yields itself', () {
    expect(
      expandGround(const [
        NodeEntry(level: 'mishnah', ref: 'Mishnah Peah 1:2'),
      ], corpus),
      ['Mishnah Peah 1:2'],
    );
  });

  test('unknown refs and level mismatches expand to nothing', () {
    expect(
      expandGround(const [
        NodeEntry(level: 'masechta', ref: 'Mishnah Nope'),
        NodeEntry(level: 'seder', ref: 'Mishnah Berakhot'),
      ], corpus),
      isEmpty,
    );
  });

  test('empty entries or an empty corpus give no leaves', () {
    expect(expandGround(const [], corpus), isEmpty);
    expect(
      expandGround(const [zeraim], InMemoryCorpus('c', const [])),
      isEmpty,
    );
  });

  test('the result is unmodifiable', () {
    expect(
      () => expandGround(const [berakhot], corpus).add('x'),
      throwsUnsupportedError,
    );
  });

  group('DNI-493 AC-1/AC-7: sub-track ground at every ContentIndex level', () {
    test('masechta, perek and leaf entries mixed keep list order and drop '
        'later duplicates', () {
      expect(
        expandGround(const [
          NodeEntry(level: 'mishnah', ref: 'Mishnah Peah 1:2'),
          berakhot2,
          berakhot,
          NodeEntry(level: 'chapter', ref: 'Mishnah Peah 1'),
          NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 2:1'),
        ], corpus),
        [
          'Mishnah Peah 1:2',
          'Mishnah Berakhot 2:1',
          'Mishnah Berakhot 2:2',
          'Mishnah Berakhot 1:1',
          'Mishnah Berakhot 1:2',
          'Mishnah Berakhot 1:3',
          'Mishnah Peah 1:1',
        ],
      );
    });

    test('a non-Mishnayos curriculum expands its own levels the same way '
        '(prd-deviations #12)', () {
      final chumash = chumashCorpus();
      expect(
        expandGround([
          exodus,
          verse('Genesis 2:2'),
          genesis2,
          genesis,
        ], chumash),
        [
          'Exodus 1:1',
          'Exodus 1:2',
          'Genesis 2:2',
          'Genesis 2:1',
          'Genesis 1:1',
          'Genesis 1:2',
          'Genesis 1:3',
        ],
      );
      expect(expandGround(const [genesis1], chumash), [
        'Genesis 1:1',
        'Genesis 1:2',
        'Genesis 1:3',
      ]);
      // A Mishnayos entry means nothing in the Chumash corpus.
      expect(expandGround(const [berakhot], chumash), isEmpty);
    });
  });
}
