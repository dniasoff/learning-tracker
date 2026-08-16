/// Value-equality regression tests for the scheduler-local repository DTOs.
///
/// AUD-scheduler-19: [SchedulerCompletion], [SchedulerContentItem],
/// [SchedulerStage], and [SchedulerOrderItem] previously had NO `==`/
/// `hashCode` override at all, so two structurally-identical instances
/// compared by identity (`==` was `false` unless it was the exact same
/// object). Converted to `@freezed`, which generates value equality —
/// these tests pin that behavior so it cannot silently regress back to
/// identity comparison.
///
/// Every instance below is built via a plain (non-`const`) constructor call,
/// mirroring how these types are actually produced in production — from
/// DB/Firestore rows in the `*_repository_impl.dart` files, never as `const`
/// literals. Using `const` here would let the Dart compiler canonicalize
/// structurally-identical literals to the same object, which would make
/// these tests pass on identity alone even without a real `==` override —
/// masking exactly the defect this finding describes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';

void main() {
  group('SchedulerCompletion value equality', () {
    SchedulerCompletion build({String sefariaRef = 'Berakhot.2a'}) =>
        SchedulerCompletion(
          sefariaRef: sefariaRef,
          stageOrder: 1,
          trackType: 'program',
          completedAt: DateTime.utc(2026, 7, 1),
        );

    test('two separately-built instances with identical fields are ==', () {
      final a = build();
      final b = build();

      expect(identical(a, b), isFalse); // sanity: genuinely distinct objects
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('instances differing by one field are not ==', () {
      expect(build(), isNot(equals(build(sefariaRef: 'Berakhot.2b'))));
    });

    test('a Set dedupes value-equal completions', () {
      final set = <SchedulerCompletion>{build(), build()};

      expect(set, hasLength(1));
    });
  });

  group('SchedulerContentItem value equality', () {
    SchedulerContentItem build({int sortOrder = 1}) => SchedulerContentItem(
      sefariaRef: 'Genesis.1.1',
      sortOrder: sortOrder,
      level1: 'Genesis',
      level2: '1',
    );

    test('two separately-built instances with identical fields are ==', () {
      final a = build();
      final b = build();

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('instances differing by one field are not ==', () {
      expect(build(), isNot(equals(build(sortOrder: 2))));
    });
  });

  group('SchedulerStage value equality', () {
    SchedulerStage build({int stageOrder = 1}) => SchedulerStage(
      stageOrder: stageOrder,
      stageName: 'Learn',
      delayDays: 0,
    );

    test('two separately-built instances with identical fields are ==', () {
      final a = build();
      final b = build();

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('instances differing by stageOrder are not ==', () {
      expect(build(), isNot(equals(build(stageOrder: 2))));
    });

    test('scheduleType and daysOfWeek participate in equality', () {
      SchedulerStage buildWeekly(List<int> daysOfWeek) => SchedulerStage(
        stageOrder: 2,
        stageName: 'Weekly Review',
        delayDays: 0,
        scheduleType: ScheduleType.weekly,
        daysOfWeek: daysOfWeek,
      );

      final weekly1 = buildWeekly([1, 3]);
      final weekly2 = buildWeekly([1, 3]);
      final weeklyDifferentDays = buildWeekly([1, 5]);

      expect(identical(weekly1, weekly2), isFalse);
      expect(weekly1, equals(weekly2));
      expect(weekly1, isNot(equals(weeklyDifferentDays)));
    });
  });

  group('SchedulerOrderItem value equality', () {
    SchedulerOrderItem build({int userSortOrder = 0}) =>
        SchedulerOrderItem(sefariaRef: 'ref-0', userSortOrder: userSortOrder);

    test('two separately-built instances with identical fields are ==', () {
      final a = build();
      final b = build();

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('instances differing by userSortOrder are not ==', () {
      expect(build(), isNot(equals(build(userSortOrder: 1))));
    });
  });
}
