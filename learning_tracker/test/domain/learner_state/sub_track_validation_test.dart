/// Story 2.1 (DNI-492) AC-5: malformed sub-track intent is rejected by
/// typed validation, naming each violated rule.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';

import '../../helpers/learner_state_fixtures.dart';

const _berakhot = NodeEntry(level: 'masechta', ref: 'Berakhot');
const _shabbat = NodeEntry(level: 'masechta', ref: 'Shabbat');
const _daf = NodeEntry(level: 'daf', ref: 'Berakhot 2a');

final _shas = InMemoryCorpus('shas', [
  const CorpusNode(_berakhot, [CorpusNode(_daf)]),
  const CorpusNode(_shabbat),
]);

SubTrack _track({
  String curriculumId = 'shas',
  List<NodeEntry> ground = const [_berakhot],
  String windowStart = '2026-09-01',
  String? windowEnd,
  double rate = 5,
  double weeks = 40,
}) => SubTrack(
  id: ulidA,
  curriculumId: curriculumId,
  name: 'Night seder',
  type: SubTrackType.ongoing,
  windowStart: windowStart,
  windowEnd: windowEnd,
  ratePerWeek: rate,
  weeksPerYear: weeks,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: ulidC,
);

void main() {
  test('well-formed intent at any ContentIndex level passes', () {
    expect(
      subTrackIntentViolations(
        _track(ground: const [_shabbat, _daf]),
        corpus: _shas,
      ),
      isEmpty,
    );
  });

  test('a duplicate ground entry is named with its ref', () {
    expect(
      subTrackIntentViolations(
        _track(ground: const [_berakhot, _shabbat, _berakhot]),
      ),
      [
        const SubTrackViolation(
          SubTrackLimit.duplicateGround,
          subject: 'Berakhot',
        ),
      ],
    );
  });

  test('a node from another curriculum is cross-curriculum ground', () {
    const foreign = NodeEntry(level: 'masechta', ref: 'Mishnah Peah');
    expect(
      subTrackIntentViolations(
        _track(ground: const [_berakhot, foreign]),
        corpus: _shas,
      ),
      [
        const SubTrackViolation(
          SubTrackLimit.crossCurriculumGround,
          subject: 'Mishnah Peah',
        ),
      ],
    );
  });

  test('a known ref at the wrong level is not this curriculum\'s node', () {
    const wrongLevel = NodeEntry(level: 'perek', ref: 'Shabbat');
    expect(
      subTrackViolationCodes(
        subTrackIntentViolations(
          _track(ground: const [wrongLevel]),
          corpus: _shas,
        ),
      ),
      ['cross_curriculum_ground'],
    );
  });

  test('a corpus of another curriculum rejects every node', () {
    expect(
      subTrackViolationCodes(
        subTrackIntentViolations(
          _track(curriculumId: 'mishnayos'),
          corpus: _shas,
        ),
      ),
      ['cross_curriculum_ground'],
    );
  });

  test('without a corpus the cross-curriculum check is skipped', () {
    const foreign = NodeEntry(level: 'masechta', ref: 'Mishnah Peah');
    expect(subTrackIntentViolations(_track(ground: const [foreign])), isEmpty);
  });

  test('window_start after window_end is reversed; equal is one day', () {
    expect(
      subTrackViolationCodes(
        subTrackIntentViolations(
          _track(windowStart: '2026-12-02', windowEnd: '2026-12-01'),
        ),
      ),
      ['window_reversed'],
    );
    expect(
      subTrackIntentViolations(
        _track(windowStart: '2026-12-01', windowEnd: '2026-12-01'),
      ),
      isEmpty,
    );
  });

  test('zero, negative and non-finite rates and weeks are rejected', () {
    for (final bad in [0.0, -1.0, double.nan]) {
      expect(
        subTrackViolationCodes(
          subTrackIntentViolations(_track(rate: bad, weeks: bad)),
        ),
        ['non_positive_rate', 'non_positive_weeks'],
        reason: '$bad',
      );
    }
  });

  test('every wire code is unique and round-trips', () {
    for (final l in SubTrackLimit.values) {
      expect(SubTrackLimit.byCode[l.code], l);
    }
    expect(SubTrackLimit.byCode.length, SubTrackLimit.values.length);
  });

  test('countsTowardSubTrackLimits: ended or passed windows never count', () {
    final live = _track();
    expect(countsTowardSubTrackLimits(live, '2030-01-01'), isTrue);
    expect(
      countsTowardSubTrackLimits(_track(windowEnd: '2026-10-01'), '2026-10-01'),
      isTrue,
    );
    expect(
      countsTowardSubTrackLimits(_track(windowEnd: '2026-09-30'), '2026-10-01'),
      isFalse,
    );
    final ended = SubTrack(
      id: ulidA,
      curriculumId: 'shas',
      name: 'x',
      type: SubTrackType.ongoing,
      windowStart: '2026-09-01',
      ratePerWeek: 1,
      weeksPerYear: 1,
      learnsOnShabbos: false,
      ground: const [_berakhot],
      lastChangeId: ulidC,
      endedAt: t1,
      endReason: SubTrackEndReason.deleted,
    );
    expect(countsTowardSubTrackLimits(ended, '2026-10-01'), isFalse);
  });
}
