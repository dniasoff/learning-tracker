// Tests for SiyumGranularityPreference — the per-(profile, curriculum) store
// behind the configurable siyum-granularity feature.
//
// Verifies the four contract points the feature depends on:
//   1. defaultValue is MilestoneLevel.unit (the finest tier) so an UNSET
//      preference reproduces the current shipped behaviour.
//   2. write/read round-trips per (profile, curriculum).
//   3. two curricula for the same profile are independent.
//   4. two profiles for the same curriculum are independent.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/siyum_granularity_preference.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SiyumGranularityPreference', () {
    test('defaultValue is MilestoneLevel.unit (finest tier)', () {
      expect(
        SiyumGranularityPreference(CurriculumId.bavli).defaultValue,
        MilestoneLevel.unit,
      );
    });

    test(
      'read() for a never-written (profile, curriculum) returns unit',
      () async {
        final value = await SiyumGranularityPreference(
          CurriculumId.mishnayos,
        ).read(7);
        expect(value, MilestoneLevel.unit);
      },
    );

    test('write/read round-trips every level', () async {
      final pref = SiyumGranularityPreference(CurriculumId.bavli);
      for (final level in MilestoneLevel.values) {
        await pref.write(3, level);
        expect(await pref.read(3), level);
      }
    });

    test('two curricula for the same profile are independent', () async {
      const profileId = 5;
      final bavli = SiyumGranularityPreference(CurriculumId.bavli);
      final chumash = SiyumGranularityPreference(CurriculumId.chumash);

      await bavli.write(profileId, MilestoneLevel.aggregate);
      await chumash.write(profileId, MilestoneLevel.curriculum);

      expect(await bavli.read(profileId), MilestoneLevel.aggregate);
      expect(
        await chumash.read(profileId),
        MilestoneLevel.curriculum,
        reason: 'Chumash must not read back Bavli\'s value',
      );

      // A third, never-written curriculum still defaults to unit.
      expect(
        await SiyumGranularityPreference(
          CurriculumId.mishnayos,
        ).read(profileId),
        MilestoneLevel.unit,
      );
    });

    test('two profiles for the same curriculum are independent', () async {
      final pref = SiyumGranularityPreference(CurriculumId.bavli);

      await pref.write(1, MilestoneLevel.curriculum);
      await pref.write(2, MilestoneLevel.aggregate);

      expect(await pref.read(1), MilestoneLevel.curriculum);
      expect(
        await pref.read(2),
        MilestoneLevel.aggregate,
        reason: 'profile 2 must not read back profile 1\'s value',
      );
      expect(
        await pref.read(3),
        MilestoneLevel.unit,
        reason: 'a never-written profile still defaults to unit',
      );
    });

    test(
      'observe() emits the value written for the matching profile',
      () async {
        final pref = SiyumGranularityPreference(CurriculumId.bavli);
        addTearDown(pref.dispose);

        final seen = <MilestoneLevel>[];
        final sub = pref.observe(9).listen(seen.add);
        addTearDown(sub.cancel);

        await pref.write(9, MilestoneLevel.aggregate);
        await pref.write(8, MilestoneLevel.curriculum); // different profile
        await pref.write(9, MilestoneLevel.curriculum);
        await Future<void>.delayed(Duration.zero);

        expect(seen, [
          MilestoneLevel.aggregate,
          MilestoneLevel.curriculum,
        ], reason: 'only writes for profile 9 reach the profile-9 observer');
      },
    );
  });
}
