// Mirror test for
// `lib/features/progress/domain/services/curriculum_progress_service.dart`
// (DNI-474: per-level distinct learnt counts from the engine).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/progress/domain/services/curriculum_progress_service.dart';
import 'package:learning_tracker/features/progress/domain/services/learner_progress.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';

StageDefinition _stage(int order) => StageDefinition(
  curriculumId: CurriculumId.mishnayos,
  stageOrder: order,
  stageName: 'Stage $order',
  delayDays: 0,
  isDefault: true,
);

void main() {
  final state = progressState([
    progressLearn(1, 'Mishnah Berakhot 1:1', stage: 1),
    progressLearn(2, 'Mishnah Berakhot 1:1', minutes: 1, stage: 2),
    progressLearn(3, 'Mishnah Berakhot 1:1', minutes: 2, stage: 1),
    progressLearn(4, 'Mishnah Peah 1:1', minutes: 3, stage: 1),
  ]);
  final data = CurriculumProgressService.compute(
    curriculumId: engineCurriculum,
    contentItems: progressContent(),
    learnt: state[engineCurriculum]!.learntLeaves,
    activity: leafActivityOf(state, progressCorpus()),
    stageDefinitions: [_stage(1), _stage(2)],
    levelLabels: progressLevelLabels,
  );

  test('overall stats count distinct leaves and stage completion', () {
    expect(data.overallStats.totalItems, 9);
    expect(data.overallStats.completedAllStages, 1);
    expect(data.overallStats.inProgress, 1);
    expect(data.overallStats.notStarted, 7);
  });

  test('each level counts learnt leaves once, with stage breakdowns', () {
    final zeraim = data.hierarchyLevels.first;
    expect(zeraim.levelName, 'Zeraim');
    expect(zeraim.completedItems, 2);
    expect(zeraim.totalItems, 7);
    expect(zeraim.stageBreakdown.map((s) => s.count), [2, 1]);
    final berakhot = zeraim.subLevels!.first;
    expect(berakhot.levelName, 'Mishnah Berakhot');
    expect(berakhot.completedItems, 1);
    expect(data.hierarchyLevels.last.completedItems, 0);
  });

  test('completion percentage is the distinct learnt share', () {
    expect(
      CurriculumProgressService.computeCompletionPercentage(
        leafItems: progressContent().where((i) => i.isLeaf).toList(),
        learnt: state[engineCurriculum]!.learntLeaves,
      ),
      closeTo(2 / 9, 1e-9),
    );
  });
}
