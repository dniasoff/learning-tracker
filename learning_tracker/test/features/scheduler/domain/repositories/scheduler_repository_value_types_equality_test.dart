/// Value-equality regression tests for the scheduler-local repository DTOs.
///
/// AUD-scheduler-19: [SchedulerCompletion] (and the content, stage and
/// order DTOs deleted with `SchedulerEngine` in DNI-477) previously had NO `==`/
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
}
