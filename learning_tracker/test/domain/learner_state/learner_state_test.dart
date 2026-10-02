// Mirror test for `lib/domain/learner_state/learner_state.dart` (AG-5):
// sub-tracks story 1.1 (DNI-463) placeholder, replaced by the C0 (DNI-524)
// engine-output contract.
//
// AD-35 purity is checked by running the dependency-direction gate for
// real (subprocess + output assertions, never a lib/ source read, R7); the
// value types are exercised directly.
@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

void main() {
  const libPath = 'lib/domain/learner_state/learner_state.dart';
  final packageDir = Directory.current.path;
  final now = DateTime.utc(2026, 9, 1, 12);

  test(' exists and the AD-35 pure-domain gate reports no '
      'violation for it', () async {
    expect(File('$packageDir/$libPath').existsSync(), isTrue);

    final result = await Process.run('dart', [
      'run',
      'tool/check_dependency_direction.dart',
      '--report',
    ], workingDirectory: packageDir);

    expect(
      result.exitCode,
      0,
      reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
    );
    expect(
      result.stdout.toString(),
      allOf(
        contains('dependency-direction violation(s)'),
        isNot(contains(libPath)),
      ),
    );
  });

  group('LearnerState', () {
    test('empty has no curricula and no event sets', () {
      final s = LearnerState.empty(now);
      expect(s.nowUtc, now);
      expect(s.curricula, isEmpty);
      expect(s['mishnayos'], isNull);
      expect(s.countedEventIds, isEmpty);
      expect(s.earningEventIds, isEmpty);
      expect(s.lockIgnoredEventIds, isEmpty);
      expect(s.rejectedRows, isEmpty);
    });
  });

  group('value types compare by value', () {
    const unit = NodeEntry(level: 'masechta', ref: 'Mishnah Berakhot');

    test('CompletedUnit', () {
      CompletedUnit u(int k) => CompletedUnit(
        unit: unit,
        completionNumber: k,
        firstCompletedAt: {for (var i = 1; i <= k; i++) i: now},
      );
      expect(u(2), u(2));
      expect(u(2).hashCode, u(2).hashCode);
      expect(u(1), isNot(u(2)));
    });

    test('ReviewDue, CurriculumStreak, Projection, SubTrackState', () {
      expect(const ReviewDue('a', 1), const ReviewDue('a', 1));
      expect(const ReviewDue('a', 1), isNot(const ReviewDue('a', 2)));
      expect(
        const CurriculumStreak(current: 2, best: 5, lastDay: '2026-09-01'),
        const CurriculumStreak(current: 2, best: 5, lastDay: '2026-09-01'),
      );
      expect(
        const Projection(status: ProjectionStatus.onTrack, velocityPerDay: 2),
        const Projection(status: ProjectionStatus.onTrack, velocityPerDay: 2),
      );
      const st = SubTrackState(
        subTrackId: 's',
        holdsGround: true,
        inForecast: false,
        onHome: true,
      );
      expect(st.groundExhausted, isFalse);
      expect(st.expectedNewGround, 0);
      expect(st.shortfall, 0);
      expect(
        st,
        const SubTrackState(
          subTrackId: 's',
          holdsGround: true,
          inForecast: false,
          onHome: true,
        ),
      );
    });
  });
}
