@Tags(['epic_20', 'story_20_3'])
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/domain/models/calendar_position.dart';
import 'package:learning_tracker/features/dashboard/domain/models/chazara_status.dart';
import 'package:learning_tracker/features/dashboard/domain/models/momentum_status.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_progress.dart';
import 'package:test/test.dart';

void main() {
  group('Story 20.3 -- TrackProgress Domain Models', () {
    // ── Enum cardinality ──

    group('Enum cardinality', () {
      test('TrackProgressVariant has exactly 4 values', () {
        expect(TrackProgressVariant.values, hasLength(4));
        expect(
          TrackProgressVariant.values,
          containsAll([
            TrackProgressVariant.programCalendar,
            TrackProgressVariant.deadlineGoal,
            TrackProgressVariant.velocityGoal,
            TrackProgressVariant.momentum,
          ]),
        );
      });

      test('MomentumLevel has exactly 4 values', () {
        expect(MomentumLevel.values, hasLength(4));
        expect(
          MomentumLevel.values,
          containsAll([
            MomentumLevel.gettingStarted,
            MomentumLevel.active,
            MomentumLevel.slowing,
            MomentumLevel.paused,
          ]),
        );
      });

      test('CalendarStatus has exactly 3 values', () {
        expect(CalendarStatus.values, hasLength(3));
        expect(
          CalendarStatus.values,
          containsAll([
            CalendarStatus.caughtUp,
            CalendarStatus.ahead,
            CalendarStatus.behind,
          ]),
        );
      });

      test('ChazaraSource has exactly 2 values', () {
        expect(ChazaraSource.values, hasLength(2));
        expect(
          ChazaraSource.values,
          containsAll([ChazaraSource.prescribed, ChazaraSource.userConfigured]),
        );
      });
    });

    // ── Variant resolution ──

    group('resolveVariant', () {
      test('programId non-null returns programCalendar', () {
        expect(
          resolveVariant(programId: 1, goalType: null),
          TrackProgressVariant.programCalendar,
        );
      });

      test('programId takes priority over goalType', () {
        expect(
          resolveVariant(programId: 1, goalType: 'deadline'),
          TrackProgressVariant.programCalendar,
        );
      });

      test('deadline goalType returns deadlineGoal', () {
        expect(
          resolveVariant(programId: null, goalType: 'deadline'),
          TrackProgressVariant.deadlineGoal,
        );
      });

      test('pace goalType returns velocityGoal', () {
        expect(
          resolveVariant(programId: null, goalType: 'pace'),
          TrackProgressVariant.velocityGoal,
        );
      });

      test('null goalType returns momentum', () {
        expect(
          resolveVariant(programId: null, goalType: null),
          TrackProgressVariant.momentum,
        );
      });

      test('deadline goalType does NOT return momentum', () {
        expect(
          resolveVariant(programId: null, goalType: 'deadline'),
          isNot(TrackProgressVariant.momentum),
        );
      });
    });

    // ── Freezed instantiation ──

    group('Freezed instantiation', () {
      test('TrackProgress can be instantiated and copyWith works', () {
        const progress = TrackProgress(
          trackId: 1,
          trackLabel: 'Daf Yomi',
          curriculumId: CurriculumId.bavli,
          variant: TrackProgressVariant.momentum,
          completedItems: 10,
          totalItems: 100,
          tasksToday: 3,
        );

        expect(progress.trackId, 1);
        expect(progress.trackLabel, 'Daf Yomi');
        expect(progress.curriculumId, CurriculumId.bavli);
        expect(progress.variant, TrackProgressVariant.momentum);
        expect(progress.completedItems, 10);
        expect(progress.totalItems, 100);
        expect(progress.tasksToday, 3);
        expect(progress.paceStatus, isNull);
        expect(progress.calendarPos, isNull);
        expect(progress.momentum, isNull);
        expect(progress.chazaraStatus, isNull);

        final updated = progress.copyWith(trackLabel: 'Updated');
        expect(updated.trackLabel, 'Updated');
        expect(updated.trackId, 1);
      });

      test('CalendarPosition can be instantiated and copyWith works', () {
        const pos = CalendarPosition(
          currentDay: 42,
          totalDays: 2711,
          todayRef: 'Bava Kamma 42a',
          todayDisplayHe: 'בבא קמא דף מ״ב',
          delta: -3,
          status: CalendarStatus.behind,
        );

        expect(pos.currentDay, 42);
        expect(pos.delta, -3);
        expect(pos.status, CalendarStatus.behind);

        final updated = pos.copyWith(delta: 0, status: CalendarStatus.caughtUp);
        expect(updated.delta, 0);
        expect(updated.status, CalendarStatus.caughtUp);
        expect(updated.currentDay, 42);
      });

      test('MomentumStatus can be instantiated and copyWith works', () {
        const momentum = MomentumStatus(
          recentCount: 5,
          personalAverage: 3.2,
          level: MomentumLevel.active,
        );

        expect(momentum.recentCount, 5);
        expect(momentum.personalAverage, 3.2);
        expect(momentum.level, MomentumLevel.active);
        expect(momentum.daysSinceLastCompletion, isNull);

        final updated = momentum.copyWith(
          level: MomentumLevel.paused,
          daysSinceLastCompletion: 4,
        );
        expect(updated.level, MomentumLevel.paused);
        expect(updated.daysSinceLastCompletion, 4);
      });

      test('ChazaraStatus can be instantiated and copyWith works', () {
        const chazara = ChazaraStatus(
          dueToday: 3,
          overdue: 1,
          isCaughtUp: false,
          source: ChazaraSource.userConfigured,
        );

        expect(chazara.dueToday, 3);
        expect(chazara.overdue, 1);
        expect(chazara.isCaughtUp, false);
        expect(chazara.source, ChazaraSource.userConfigured);

        final updated = chazara.copyWith(
          dueToday: 0,
          overdue: 0,
          isCaughtUp: true,
        );
        expect(updated.isCaughtUp, true);
        expect(updated.source, ChazaraSource.userConfigured);
      });
    });
  });
}
