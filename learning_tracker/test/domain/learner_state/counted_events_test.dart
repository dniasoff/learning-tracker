// Mirror test for `lib/domain/learner_state/counted_events.dart` (DNI-465
// T1/T2: the counted-event boundary, void normalization, lock hook).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/counted_events.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

void main() {
  const ref = 'Mishnah Berakhot 1:1';

  test('learn events count, ordered by effectiveAt then id', () {
    final counted = countEvents([
      engineLearn(3, ref, minutes: 5),
      engineLearn(2, ref, minutes: 5),
      engineLearn(1, ref, minutes: 9, originalMinutes: 1),
    ]);
    expect(counted.learns.map((e) => e.id), [
      engineUlid(1),
      engineUlid(2),
      engineUlid(3),
    ]);
    expect(counted.countedIds, {engineUlid(1), engineUlid(2), engineUlid(3)});
    expect(counted.voidedIds, isEmpty);
    expect(counted.lockIgnoredIds, isEmpty);
  });

  test('a void cancels its learn target; duplicate voids equal one', () {
    final counted = countEvents([
      engineLearn(1, ref),
      engineVoid(2, 1),
      engineVoid(3, 1),
    ]);
    expect(counted.learns, isEmpty);
    expect(counted.voidedIds, {engineUlid(1)});
  });

  test('a void of a void is ignored, so a void chain leaves the learn '
      'voided', () {
    final counted = countEvents([
      engineLearn(1, ref),
      engineVoid(2, 1),
      engineVoid(3, 2),
    ]);
    expect(counted.learns, isEmpty);
    expect(counted.voidedIds, {engineUlid(1)});
  });

  test('a void whose target is absent is harmless', () {
    final counted = countEvents([engineLearn(1, ref), engineVoid(2, 99)]);
    expect(counted.countedIds, {engineUlid(1)});
    expect(counted.voidedIds, isEmpty);
  });

  test('a void cancels a learn of another curriculum (profile-wide)', () {
    final counted = countEvents([
      engineLearn(1, 'Berakhot 2a', curriculumId: 'bavli'),
      engineVoid(2, 1),
    ]);
    expect(counted.learns, isEmpty);
  });

  test('the lock hook removes learns and voids from counting', () {
    final ignored = {engineUlid(1), engineUlid(4)};
    final counted = countEvents([
      engineLearn(1, ref),
      engineLearn(3, ref),
      engineVoid(4, 3),
    ], isLockIgnored: (e) => ignored.contains(e.id));
    expect(counted.countedIds, {engineUlid(3)});
    expect(counted.lockIgnoredIds, ignored);
    expect(counted.voidedIds, isEmpty);
  });

  test('a repeated id keeps its first occurrence', () {
    final counted = countEvents([
      engineLearn(1, ref),
      engineLearn(1, 'Mishnah Berakhot 1:2'),
    ]);
    expect(counted.learns.single.ref, ref);
  });

  test('noLockIgnored ignores nothing', () {
    expect(noLockIgnored(engineLearn(1, ref)), isFalse);
  });
}
