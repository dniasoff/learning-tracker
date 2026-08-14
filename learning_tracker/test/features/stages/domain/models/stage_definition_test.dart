import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

void main() {
  const mishnayos = CurriculumId.mishnayos;

  const stage = StageDefinition(
    curriculumId: mishnayos,
    stageOrder: 1,
    stageName: 'Learn',
    delayDays: 0,
    isDefault: true,
  );

  group('StageDefinition', () {
    test('equality — identical instances are equal', () {
      const other = StageDefinition(
        curriculumId: mishnayos,
        stageOrder: 1,
        stageName: 'Learn',
        delayDays: 0,
        isDefault: true,
      );
      expect(stage, equals(other));
    });

    test('equality — different stageOrder produces unequal instances', () {
      const other = StageDefinition(
        curriculumId: mishnayos,
        stageOrder: 2,
        stageName: 'Learn',
        delayDays: 0,
        isDefault: true,
      );
      expect(stage, isNot(equals(other)));
    });

    test('copyWith — updates stageName', () {
      final updated = stage.copyWith(stageName: 'Chazara 1');
      expect(updated.stageName, 'Chazara 1');
      expect(updated.curriculumId, stage.curriculumId);
      expect(updated.stageOrder, stage.stageOrder);
    });

    test('copyWith — updates delayDays', () {
      final updated = stage.copyWith(delayDays: 7);
      expect(updated.delayDays, 7);
      expect(updated.stageName, stage.stageName);
    });

    test('copyWith — does not mutate original', () {
      final _ = stage.copyWith(stageName: 'Other');
      expect(stage.stageName, 'Learn');
    });
  });
}
