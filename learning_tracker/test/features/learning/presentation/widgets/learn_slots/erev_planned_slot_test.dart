// DNI-500 named Learn slot, filled by DNI-504: zero size outside the erev
// window and when nothing is planned (AC-7); one section per locked day
// with rows; the planned data's error stays inside the slot (AC-10).
@Tags(['learning'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/features/learning/presentation/providers/erev_planned_tasks_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/learn_slots/erev_planned_slot.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../../helpers/pump_app.dart';

class _EnglishTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

/// Friday 2026-10-09 09:00 New York: erev of Shabbos 2026-10-10.
final _erev = LearnerZone.of(
  'America/New_York',
).at(DateTime.utc(2026, 10, 9), hour: 9);

DailyTask _task(String ref) => DailyTask(
  curriculumId: CurriculumId.mishnayos,
  contentItemSefariaRef: ref,
  stageOrder: 1,
  priority: DailyTaskPriority.newLearning,
  isOverdue: false,
  reason: 'test',
  stageName: 'Learn',
  trackLabel: 'Mishnayos',
);

Future<void> _pump(
  WidgetTester tester, {
  DateTime? now,
  LearnerSettingsHistory? history,
  Map<String, List<DailyTask>> planned = const {},
  bool fail = false,
}) async {
  await tester.pumpWidget(
    pumpApp(
      retry: (_, _) => null,
      overrides: [
        ...learnerStateOverrides(),
        useHebrewTermsProvider.overrideWith(_EnglishTerms.new),
        currentTransliterationVariantProvider.overrideWithValue(
          TransliterationVariant.ashkenazi,
        ),
        renderedDisplayForRefProvider.overrideWith((ref, r) async => r),
        erevSettingsHistoryProvider.overrideWith((ref) async => history),
        learningCommandClockProvider.overrideWithValue(() => now ?? _erev),
        erevSequencePlannerProvider.overrideWithValue((ref, dates) async {
          if (fail) throw StateError('planner down');
          return [for (final d in dates) planned[d] ?? const []];
        }),
      ],
      child: const Scaffold(body: Column(children: [ErevPlannedSlot()])),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('takes no space without a learner', (tester) async {
    await _pump(tester);
    expect(tester.getSize(find.byType(ErevPlannedSlot)), Size.zero);
  });

  testWidgets('takes no space outside the erev window', (tester) async {
    await _pump(
      tester,
      now: _erev.subtract(const Duration(days: 1)),
      history: constantHistory(lakewood),
      planned: {
        '2026-10-10': [_task('Mishnah Peah 1:1')],
      },
    );
    expect(tester.getSize(find.byType(ErevPlannedSlot)), Size.zero);
  });

  testWidgets('takes no space on erev when nothing is planned (AC-7)', (
    tester,
  ) async {
    await _pump(tester, history: constantHistory(lakewood));
    expect(tester.getSize(find.byType(ErevPlannedSlot)), Size.zero);
  });

  testWidgets('one section per locked day with rows', (tester) async {
    await _pump(
      tester,
      history: constantHistory(lakewood),
      planned: {
        '2026-10-10': [_task('Mishnah Peah 1:1')],
      },
    );
    expect(find.text('Planned for Shabbos'), findsOneWidget);
    expect(find.text('Mishnah Peah 1:1'), findsOneWidget);
  });

  testWidgets('a planner failure is an inline retry inside the slot', (
    tester,
  ) async {
    await _pump(tester, history: constantHistory(lakewood), fail: true);
    expect(
      find.descendant(
        of: find.byType(ErevPlannedSlot),
        matching: find.byType(InlineAsyncError),
      ),
      findsOneWidget,
    );
  });
}
