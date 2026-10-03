// Story 1.24 (DNI-486): tutor track creation is refused before a governed
// action or wizard write can begin.

@Tags(['tutor_mode'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/add_track_action_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:mocktail/mocktail.dart';

class _Actions extends Mock implements AddTrackActionRepository {}

class _Wizard extends Mock implements LearningProcessWizardService {}

void main() {
  test('a tutor cannot create a track before any repository write', () async {
    final actions = _Actions();
    final wizard = _Wizard();
    final service = TrackCreationService(
      actionRepository: actions,
      wizardService: wizard,
      isTutoredSession: () => true,
    );

    await expectLater(
      service.createTrack(
        result: const AddTrackResult(
          curriculumId: CurriculumId.mishnayos,
          label: 'Mishnayos',
          studyDays: {1: 'study'},
        ),
      ),
      throwsA(isA<TutorTrackCreationUnsupportedException>()),
    );

    verifyZeroInteractions(actions);
    verifyZeroInteractions(wizard);
  });
}
