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

const profileA = '01J5K7M2N4P6Q8R0S1T3V5W7X9';
const profileB = '01J5K7M2N4P6Q8R0S1T3V5W7Y9';
const profileC = '01J5K7M2N4P6Q8R0S1T3V5W8X9';
const profileD = '01J5K7M2N4P6Q8R0S1T3V6W7X9';
const profileE = '01J5K7M2N4P6Q8R0S1T4V5W7X9';

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
        ).read(profileA);
        expect(value, MilestoneLevel.unit);
      },
    );

    test('write/read round-trips every level', () async {
      final pref = SiyumGranularityPreference(CurriculumId.bavli);
      for (final level in MilestoneLevel.values) {
        await pref.write(profileA, level);
        expect(await pref.read(profileA), level);
      }
    });

    test('two curricula for the same profile are independent', () async {
      const profileId = profileB;
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

      await pref.write(profileC, MilestoneLevel.curriculum);
      await pref.write(profileD, MilestoneLevel.aggregate);

      expect(await pref.read(profileC), MilestoneLevel.curriculum);
      expect(
        await pref.read(profileD),
        MilestoneLevel.aggregate,
        reason: 'profile D must not read back profile C\'s value',
      );
      expect(
        await pref.read(profileE),
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
        final sub = pref.observe(profileD).listen(seen.add);
        addTearDown(sub.cancel);

        await pref.write(profileD, MilestoneLevel.aggregate);
        await pref.write(
          profileE,
          MilestoneLevel.curriculum,
        ); // different profile
        await pref.write(profileD, MilestoneLevel.curriculum);
        await Future<void>.delayed(Duration.zero);

        expect(seen, [
          MilestoneLevel.aggregate,
          MilestoneLevel.curriculum,
        ], reason: 'only writes for profile D reach the profile-D observer');
      },
    );
  });
}
