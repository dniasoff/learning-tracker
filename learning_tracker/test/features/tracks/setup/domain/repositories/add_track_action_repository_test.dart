// DNI-476 AC-5: the Add track plan value — a self-paced track with no
// scope, program or goal by default (each is ended by the action).

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/add_track_action_repository.dart';

void main() {
  test('defaults: whole curriculum, self-paced, no goal', () {
    const plan = AddTrackPlan(
      curriculumId: CurriculumId.bavli,
      stages: [],
      studyDays: {1: DayType.study},
    );
    expect(plan.scopes, isEmpty);
    expect(plan.program, isNull);
    expect(plan.goal, isNull);
  });

  test('a program enrolment carries its tracking window', () {
    final program = AddTrackProgram(
      programId: 3,
      trackingStartDate: DateTime.utc(2026, 9),
      trackingStartRef: 'Berakhot 2a',
    );
    expect(program.programId, 3);
    expect(program.trackingStartDate, DateTime.utc(2026, 9));
    expect(program.trackingStartRef, 'Berakhot 2a');
  });
}
