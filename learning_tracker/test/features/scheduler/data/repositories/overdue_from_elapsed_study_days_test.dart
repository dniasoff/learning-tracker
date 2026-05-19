/// F6 — overdue derives from elapsed study days via the PURE PROJECTION.
///
/// Wave 3 removes backfillStudyDaySnapshots.  The projection (selfPacedSchedule
/// + project) now derives overdue directly from (anchor, pace, studyDayPattern,
/// completions) — no synthetic snapshot rows are written for elapsed days.
///
/// The scenario is preserved from the old test so the invariant is the same:
///   activatedAt = Sunday  2026-05-17 (weekday 7, NOT a study day)
///   elapsed day 1         Monday 2026-05-18 (weekday 1, IS a study day ✓)
///   elapsed day 2         Tuesday 2026-05-19 (weekday 2, NOT a study day)
///   today                 Wednesday 2026-05-20 (weekday 3, IS a study day ✓)
///
///   Study-day config: Mon(1) + Wed(3) + Fri(5)
///   Elapsed study days before today: Monday only → 1 elapsed study day.
///   pace = 5 → 5 overdue items.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';

void main() {
  final activatedAt = DateTime.utc(2026, 5, 17, 8, 0); // Sunday
  final today = DateTime.utc(2026, 5, 20, 9, 0); // Wednesday
  const studyWeekdays = {1, 3, 5}; // Mon, Wed, Fri
  const pattern = StudyDayPattern(studyWeekdays);

  // 10 content items — enough to fill several study-day batches.
  final orderedRefs = List.generate(10, (i) => 'ref_$i');

  // ── F6 core regression ─────────────────────────────────────────────────────

  group(
    'F6 — overdue derives from studyDayConfig × elapsed days (projection)',
    () {
      test('track with 1 elapsed study day yields pace overdue items', () {
        const pace = 5;
        // elapsedStudyDays in [activatedAt, today):
        //   Sun 17 ✗, Mon 18 ✓, Tue 19 ✗  → 1 elapsed study day.
        final elapsed = elapsedStudyDays(
          anchor: activatedAt,
          today: today,
          studyDayPattern: pattern,
        );
        expect(elapsed, 1, reason: 'Only Monday is an elapsed study day');

        final schedule = selfPacedSchedule(
          anchor: activatedAt,
          pace: pace,
          studyDayPattern: pattern,
          orderedRefs: orderedRefs,
          today: today,
        );

        final result = project(
          schedule: schedule,
          completions: {},
          today: today,
        );

        expect(
          result.overdue,
          hasLength(pace),
          reason:
              '1 elapsed study day × pace=$pace → $pace overdue items; '
              'non-study days (Sun, Tue) are skipped by the projection',
        );

        // Overdue refs must be the Monday session refs (ref_0..ref_4).
        expect(
          result.overdue,
          containsAll({'ref_0', 'ref_1', 'ref_2', 'ref_3', 'ref_4'}),
        );
      });

      test('non-study elapsed days contribute 0 overdue items', () {
        // pace=3, studyWeekdays = {1,3,5}
        // elapsed days: Sun(non-study), Mon(study), Tue(non-study)
        // → only Monday contributes; overdue = 3 (pace × 1 elapsed study day)
        const pace = 3;
        final schedule = selfPacedSchedule(
          anchor: activatedAt,
          pace: pace,
          studyDayPattern: pattern,
          orderedRefs: orderedRefs,
          today: today,
        );

        final result = project(
          schedule: schedule,
          completions: {},
          today: today,
        );

        // Sunday and Tuesday do NOT contribute — they are not study days.
        expect(
          result.overdue.length,
          pace,
          reason:
              'Only Monday is a study day in the elapsed window; '
              'non-study days (Sun, Tue) yield 0 overdue each',
        );
      });

      test('study-day ordinal determines ref position '
          '(not calendar-day index)', () {
        // pace=3, elapsed study days: Mon only (study day #1 from anchor)
        // → first 3 refs (index 0*3 .. 1*3) should be in overdue
        // NOT refs[3..5] which would be calendar-day index 1 × pace
        const pace = 3;
        final schedule = selfPacedSchedule(
          anchor: activatedAt,
          pace: pace,
          studyDayPattern: pattern,
          orderedRefs: orderedRefs,
          today: today,
        );

        final result = project(
          schedule: schedule,
          completions: {},
          today: today,
        );

        expect(
          result.overdue,
          equals({'ref_0', 'ref_1', 'ref_2'}),
          reason:
              'Monday is study day #1 → position = 0*3..1*3 = refs[0,1,2]; '
              'calendar-day index 1 would incorrectly give refs[3,4,5]',
        );
      });

      test(
        'today (Wednesday) is a study day — dueToday contains pace refs',
        () {
          const pace = 5;
          final schedule = selfPacedSchedule(
            anchor: activatedAt,
            pace: pace,
            studyDayPattern: pattern,
            orderedRefs: orderedRefs,
            today: today,
          );

          final result = project(
            schedule: schedule,
            completions: {},
            today: today,
          );

          expect(
            result.dueToday.length,
            pace,
            reason: 'Wednesday is a study day → pace refs are due today',
          );
        },
      );

      test('MissingPaceError when track has no pace (no auto-default)', () {
        expect(
          () => selfPacedSchedule(
            anchor: activatedAt,
            pace: null,
            studyDayPattern: pattern,
            orderedRefs: orderedRefs,
            today: today,
          ),
          throwsA(isA<MissingPaceError>()),
          reason:
              'Architecture §10.3: no kDefaultBackfillPace — '
              'a self-paced track without a pace must throw MissingPaceError',
        );
      });
    },
  );
}
