/// Overflow guard for the Firestore-backed study-day screen.
@Tags(['overflow'])
library;

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/study_day_config_screen.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../../../../helpers/overflow_harness.dart';

void main() {
  testWidgets(
    'StudyDayConfigScreen does not overflow across vertical stress sizes',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => const StudyDayConfigScreen(curriculumId: CurriculumId.mishnayos),
        sizes: const [Size(320, 568), Size(280, 653), Size(412, 915)],
        overrides: [
          studyDayConfigsProvider(CurriculumId.mishnayos).overrideWith(
            (ref) => Stream<List<StudyDayConfigEntry>>.value(const []),
          ),
          curriculumTrackHasChazaraProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) => Future.value(true)),
          allDailyTasksProvider.overrideWith((ref) => Future.value(const [])),
          activeTutorPermissionsProvider.overrideWithValue(null),
        ],
      );
    },
  );
}
