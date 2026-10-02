// Mirror test for
// `lib/features/progress/domain/services/siyum_celebration_policy.dart`
// (DNI-474 AC-4: per-device key, void, re-completion, idempotency).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/progress/domain/services/siyum_celebration_policy.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _peah = NodeEntry(level: 'masechta', ref: 'Mishnah Peah');

LearnerState _peahDone({int secondAt = 2}) => progressState([
  progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
  progressLearn(2, 'Mishnah Peah 1:2', minutes: secondAt),
]);

/// Applies [plan] to [stored] like the listener does.
Set<String> _apply(Set<String> stored, SiyumCelebrationPlan plan) => {...stored}
  ..removeAll(plan.keysToRemove)
  ..addAll(plan.keysToAdd);

void main() {
  final peahKey = ProfileScopedPreferenceKeys.siyumShown(
    profileUlid,
    engineCurriculum,
    'Mishnah Peah',
    engineAt(2),
  );

  test('the shown key is scoped by profile, unit and first completion', () {
    expect(peahKey, startsWith('siyum_shown_p${profileUlid}_mishnayos_'));
    expect(
      ProfileScopedPreferenceKeys.siyumShown(
        'other',
        engineCurriculum,
        'Mishnah Peah',
        engineAt(2),
      ),
      isNot(peahKey),
    );
    expect(
      ProfileScopedPreferenceKeys.siyumShown(
        profileUlid,
        engineCurriculum,
        'Mishnah Peah',
        engineAt(3),
      ),
      isNot(peahKey),
    );
  });

  test('the first evaluation on a device seeds existing siyumim without '
      'celebrating', () {
    final plan = planSiyumCelebrations(
      profileId: profileUlid,
      state: _peahDone(),
      storedKeys: const {},
      seeded: false,
    );
    expect(plan.celebrate, isEmpty);
    expect(plan.keysToAdd, {peahKey});
    expect(plan.markSeeded, isTrue);
  });

  test('a newly completed unit celebrates once; the same state again '
      '(rebuild, resume, retry) does not', () {
    final first = planSiyumCelebrations(
      profileId: profileUlid,
      state: _peahDone(),
      storedKeys: const {},
      seeded: true,
    );
    expect(first.celebrate, [
      SiyumToCelebrate(
        curriculumId: engineCurriculum,
        unit: _peah,
        completedAt: engineAt(2),
      ),
    ]);
    final again = planSiyumCelebrations(
      profileId: profileUlid,
      state: _peahDone(),
      storedKeys: _apply(const {}, first),
      seeded: true,
    );
    expect(again.isEmpty, isTrue);
  });

  test('chazara and repeats of a complete unit never re-fire', () {
    final stored = {peahKey};
    final plan = planSiyumCelebrations(
      profileId: profileUlid,
      state: progressState([
        progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
        progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
        progressLearn(3, 'Mishnah Peah 1:1', minutes: 3, stage: 2),
        progressLearn(4, 'Mishnah Peah 1:1', minutes: 4),
        progressLearn(5, 'Mishnah Peah 1:2', minutes: 5),
      ]),
      storedKeys: stored,
      seeded: true,
    );
    expect(plan.celebrate, isEmpty);
    expect(plan.keysToRemove, isEmpty);
  });

  test('a void that removes the unit clears its key; the re-completion '
      'celebrates again with its new key', () {
    final voided = planSiyumCelebrations(
      profileId: profileUlid,
      state: progressState([
        progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
        progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
        engineVoid(3, 2, minutes: 5),
      ]),
      storedKeys: {peahKey},
      seeded: true,
    );
    expect(voided.keysToRemove, {peahKey});
    expect(voided.celebrate, isEmpty);

    final recompleted = planSiyumCelebrations(
      profileId: profileUlid,
      state: progressState([
        progressLearn(1, 'Mishnah Peah 1:1', minutes: 1),
        progressLearn(2, 'Mishnah Peah 1:2', minutes: 2),
        engineVoid(3, 2, minutes: 5),
        progressLearn(4, 'Mishnah Peah 1:2', minutes: 8),
      ]),
      storedKeys: _apply({peahKey}, voided),
      seeded: true,
    );
    expect(recompleted.celebrate.single.completedAt, engineAt(8));
    expect(
      recompleted.keysToAdd,
      contains(
        ProfileScopedPreferenceKeys.siyumShown(
          profileUlid,
          engineCurriculum,
          'Mishnah Peah',
          engineAt(8),
        ),
      ),
    );
  });

  test("another profile's keys are left alone", () {
    final otherKey = ProfileScopedPreferenceKeys.siyumShown(
      'other',
      engineCurriculum,
      'Mishnah Peah',
      engineAt(2),
    );
    final plan = planSiyumCelebrations(
      profileId: profileUlid,
      state: progressState(const []),
      storedKeys: {otherKey},
      seeded: true,
    );
    expect(plan.keysToRemove, isEmpty);
  });

  test('a unit the granularity filter rejects is recorded, not '
      'celebrated', () {
    final plan = planSiyumCelebrations(
      profileId: profileUlid,
      state: _peahDone(),
      storedKeys: const {},
      seeded: true,
      celebrates: (_, unit) => unit.level != 'masechta',
    );
    expect(plan.celebrate, isEmpty);
    expect(plan.keysToAdd, {peahKey});
  });
}
