// AD-43/AD-44 study-day model: weekday sets from the live study_day_configs
// docs and the study-day arithmetic the daily target divides by.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/study_days.dart';

MainTrackConfigDoc _day(int dow, String type, {DateTime? endedAt}) =>
    MainTrackConfigDoc(
      collection: MainTrackConfigDoc.studyDays,
      docId: 'mishnayos_$dow',
      curriculumId: 'mishnayos',
      fields: {'day_of_week': dow, 'day_type': type},
      endedAt: endedAt,
    );

void main() {
  test('no live docs means every day is a study day', () {
    expect(StudyDays.fromFields(const []), StudyDays.everyDay());
    expect(
      StudyDays.fromDocs([_day(1, 'study', endedAt: DateTime.utc(2026))]),
      StudyDays.everyDay(),
    );
  });

  test('review days are active but not study days; malformed docs are '
      'skipped', () {
    final days = StudyDays.fromFields([
      {'day_of_week': 1, 'day_type': 'study'},
      {'day_of_week': 3, 'day_type': 'review'},
      {'day_of_week': 9, 'day_type': 'study'},
      {'day_of_week': 2, 'day_type': 7},
    ]);
    expect(days.studyWeekdays, {1});
    expect(days.activeWeekdays, {1, 3});
  });

  test('isStudyDay and countStudyDays follow the weekday set', () {
    // 2026-09-07 is a Monday.
    final days = StudyDays(studyWeekdays: {1, 3}, activeWeekdays: {1, 3});
    expect(weekdayOf('2026-09-07'), 1);
    expect(days.isStudyDay('2026-09-07'), isTrue);
    expect(days.isStudyDay('2026-09-08'), isFalse);
    expect(days.countStudyDays('2026-09-07', '2026-09-20'), 4);
    expect(days.countStudyDays('2026-09-08', '2026-09-08'), 0);
    expect(days.countStudyDays('2026-09-10', '2026-09-07'), 0);
  });

  test('nextActiveOnOrAfter skips inactive weekdays', () {
    final days = StudyDays(studyWeekdays: {1}, activeWeekdays: {1, 3});
    expect(days.nextActiveOnOrAfter('2026-09-07'), '2026-09-07');
    expect(days.nextActiveOnOrAfter('2026-09-08'), '2026-09-09');
    expect(days.nextActiveOnOrAfter('2026-09-10'), '2026-09-14');
    expect(shiftCivilDate('2026-09-30', 1), '2026-10-01');
  });
}
