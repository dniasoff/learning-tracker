/// AC-4 (DNI-464): `effectiveAt` selects the original time and is the sole
/// public time accessor for rule code; the raw `recorded_at` is reachable
/// only through the AD-54 skew helper.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';

import '../../helpers/learner_state_fixtures.dart';

void main() {
  group('effectiveAt selects original time and is the sole public time rule '
      'accessor', () {
    test('null original_recorded_at → recorded_at', () {
      final event = datedLearn(recordedAt: t0);
      expect(effectiveAt(event), t0);
      expect(effectiveAt(event).isUtc, isTrue);
    });

    test('non-null original_recorded_at wins over recorded_at', () {
      final event = datedLearn(recordedAt: t0, originalRecordedAt: t2);
      expect(effectiveAt(event), t2);
    });

    test('applies to voids too (undo copies carry original_recorded_at)', () {
      final event = LearningEvent.voidOf(
        id: ulidA,
        targetId: ulidB,
        recordedAt: t1,
        originalRecordedAt: t2,
        actor: parentActor,
      );
      expect(effectiveAt(event), t2);
    });

    test('non-UTC inputs are normalised to the same UTC instant', () {
      final local = t0.toLocal();
      final event = datedLearn(recordedAt: local);
      expect(effectiveAt(event), t0);
      expect(effectiveAt(event).isUtc, isTrue);
    });

    test('raw recorded_at is not a public member of LearningEvent; only the '
        'skew helper exposes it', () {
      final event = datedLearn(recordedAt: t0, originalRecordedAt: t2);
      // Neither raw instant is a public getter: a dynamic access fails at
      // runtime exactly as a static one fails to compile.
      final dynamic dyn = event;
      // ignore: avoid_dynamic_calls
      expect(() => dyn.recordedAt, throwsNoSuchMethodError);
      // ignore: avoid_dynamic_calls
      expect(() => dyn.originalRecordedAt, throwsNoSuchMethodError);
      expect(rawRecordedAtForSkewRule(event), t0);
      expect(effectiveAt(event), isNot(rawRecordedAtForSkewRule(event)));
    });
  });

  group('value semantics', () {
    test('equal fields → equal events and hashes', () {
      expect(datedLearn(), datedLearn());
      expect(datedLearn().hashCode, datedLearn().hashCode);
      expect(datedLearn(), isNot(datedLearn(recordedAt: t1)));
      expect(datedLearn(), isNot(datedLearn(originalRecordedAt: t2)));
    });

    test('kind helpers', () {
      expect(datedLearn().isLearn, isTrue);
      expect(datedLearn().isVoid, isFalse);
      final v = LearningEvent.voidOf(
        id: ulidA,
        targetId: ulidB,
        recordedAt: t0,
        actor: parentActor,
      );
      expect(v.isVoid, isTrue);
      expect(v.kind, LearningEventKind.void_);
    });

    test('storage enums map exactly', () {
      expect(LearningEventKind.byStorage.keys.toSet(), {'learn', 'void'});
      expect(DateState.byStorage.keys.toSet(), {
        'dated',
        'catch_up',
        'before_tracking',
      });
    });
  });
}
