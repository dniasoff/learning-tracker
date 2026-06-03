// Overflow guard for [DailyTaskCard] (P2 row fix).
//
// The card's metadata Row (curriculum badge + stage-name text) previously let
// the stage-name [Text] overflow horizontally on narrow viewports / large
// accessibility text. The fix wraps it in a [Flexible] with
// `TextOverflow.ellipsis`. This guard pumps the card across the device matrix
// with a deliberately long stage name and asserts no RenderFlex overflow.

@Tags(['overflow'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_task_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/overflow_harness.dart';

DailyTask _task({
  String ref = 'Mishnah_Berakhot_Chapter_With_A_Very_Long_Name_That_Wraps_1.10',
  int stageOrder = 3,
  bool isOverdue = true,
  String stageName =
      'Chazara 3 — a deliberately very long stage label that must ellipsize',
}) {
  return DailyTask(
    curriculumId: CurriculumId.mishnayos,
    contentItemSefariaRef: ref,
    stageOrder: stageOrder,
    stageDefinitionId: stageOrder,
    priority: isOverdue
        ? DailyTaskPriority.overdueChazara
        : DailyTaskPriority.newLearning,
    isOverdue: isOverdue,
    reason: 'test reason',
    stageName: stageName,
    trackId: 1,
    trackLabel: 'Test Track',
    estimatedEffortMinutes: 5,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'DailyTaskCard (long ref + long stage label + overdue badge) does not '
    'overflow across the device matrix',
    (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        () => DailyTaskCard(
          task: _task(),
          onDismissed: () {},
          onCompleted: () {},
        ),
        overrides: [
          // English mode so resolveStoredStageName returns the literal stage
          // name regardless of the (empty) SharedPreferences mock.
          useHebrewTermsProvider.overrideWithValue(false),
        ],
      );
    },
  );
}
