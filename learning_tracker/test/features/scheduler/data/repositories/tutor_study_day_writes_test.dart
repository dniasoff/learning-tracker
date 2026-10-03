// Story 1.24 (DNI-486) — a tutor's study-day replace is ONE governed
// tutorReplaceStudyDays action: every chosen day is upserted and every
// existing day absent from the new schedule is tombstoned.

@Tags(['tutor_mode'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/tutor_study_day_writes.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';

import '../../../../helpers/tutoring/tutor_learning_harness.dart';

void main() {
  test('upserts the new days and tombstones dropped existing days in one '
      'tutorReplaceStudyDays call', () async {
    final h = TutorHarness();
    addTearDown(h.dispose);
    final replace = FutureProvider<void>(
      (ref) => tutorReplaceStudyDays(
        ref,
        curriculumId: CurriculumId.mishnayos,
        studyDays: {1: DayType.study, 2: DayType.review},
        existing: const [
          StudyDayConfigEntry(dayOfWeek: 1, dayType: DayType.study),
          StudyDayConfigEntry(dayOfWeek: 7, dayType: DayType.study),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        tutorGovernedWritesProvider.overrideWith((ref) async => h.governed),
      ],
    );
    addTearDown(container.dispose);

    await container.read(replace.future);

    final call = h.invoker.calls.single;
    expect(call.fn, 'tutorReplaceStudyDays');
    expect(call.args['curriculumId'], CurriculumId.mishnayos.storageKey);
    final upserts = (call.args['upserts']! as List)
        .cast<Map<String, Object?>>();
    expect(upserts, hasLength(2));
    final removed = (call.args['removedConfigIds']! as List).cast<String>();
    expect(removed, hasLength(1));
    expect(removed.single, endsWith('7'));
  });

  test('throws and calls nothing when the tutored context is not ready', () {
    final h = TutorHarness();
    addTearDown(h.dispose);
    final replace = FutureProvider<void>(
      (ref) => tutorReplaceStudyDays(
        ref,
        curriculumId: CurriculumId.mishnayos,
        studyDays: {1: DayType.study},
        existing: const [],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        tutorGovernedWritesProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(replace.future), throwsStateError);
    expect(h.invoker.calls, isEmpty);
  });
}
