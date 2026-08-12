/// Regression coverage for a failed study-day write through the real screen.
@Tags(['scheduler', 'l1'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/study_day_config_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/study_day_config_screen.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

class _StudyDays extends Mock
    implements FirestoreStudyDayConfigRepositoryAdapter {}

void main() {
  setUp(() {
    AppLogger.init();
  });

  setUpAll(() {
    registerFallbackValue(DayType.review);
  });

  testWidgets('a UI write failure logs study_day_toggle_write_failed', (
    tester,
  ) async {
    final adapter = _StudyDays();
    when(
      () => adapter.setDayConfig(
        curriculumId: CurriculumId.mishnayos,
        dayOfWeek: 7,
        dayType: any(named: 'dayType'),
      ),
    ).thenThrow(StateError('Firestore write failed'));

    await tester.pumpWidget(
      pumpApp(
        child: const StudyDayConfigScreen(curriculumId: CurriculumId.mishnayos),
        overrides: [
          studyDayConfigsProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) => Stream.value(const <StudyDayConfigEntry>[])),
          curriculumTrackHasChazaraProvider(
            CurriculumId.mishnayos,
          ).overrideWith((ref) => Future.value(true)),
          studyDayConfigRepositoryAdapterProvider.overrideWithValue(adapter),
          allDailyTasksProvider.overrideWith((ref) => Future.value(const [])),
          activeTutorPermissionsProvider.overrideWithValue(null),
        ],
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Sun'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final messages = AppLogger.instance.talker.history
        .map((entry) => entry.generateTextMessage())
        .toList();
    expect(
      messages.any(
        (message) => message.contains('study_day_toggle_write_failed'),
      ),
      isTrue,
      reason: 'UI write failure was not logged: $messages',
    );
  });
}
