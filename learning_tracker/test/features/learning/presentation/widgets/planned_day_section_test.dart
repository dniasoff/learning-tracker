// DNI-504 AC-2 / AC-3 / AC-11: a planned row's identity, its day heading,
// and the live tick control. The section on the Learn tab is covered by
// test/features/learning/presentation/screens/erev_learning_screen_test.dart
// and its captures by test/features/learning/domain/erev_capture_gate_test.dart.
@Tags(['learning'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/planned_day_section.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/pump_app.dart';

DailyTask _task(String ref, {int stage = 1}) => DailyTask(
  curriculumId: CurriculumId.mishnayos,
  contentItemSefariaRef: ref,
  stageOrder: stage,
  priority: stage == 1
      ? DailyTaskPriority.newLearning
      : DailyTaskPriority.scheduledChazara,
  isOverdue: false,
  reason: 'test',
  stageName: stage == 1 ? 'Learn' : 'Chazara A',
  trackLabel: 'Mishnayos',
);

class _EnglishTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

Widget _host(Widget child) => pumpApp(
  overrides: [
    useHebrewTermsProvider.overrideWith(_EnglishTerms.new),
    renderedDisplayForRefProvider.overrideWith((ref, r) async => r),
    currentTransliterationVariantProvider.overrideWithValue(
      TransliterationVariant.ashkenazi,
    ),
  ],
  child: Scaffold(body: child),
);

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  test('a row is keyed by curriculum, leaf and stage', () {
    expect(erevRowKey(_task('Mishnah Peah 1:1')), (
      'mishnayos',
      'Mishnah Peah 1:1',
      1,
    ));
    expect(
      erevRowKey(_task('Mishnah Peah 1:1', stage: 2)),
      isNot(erevRowKey(_task('Mishnah Peah 1:1'))),
    );
  });

  testWidgets('a locked day is headed by its weekday, or Shabbos', (
    tester,
  ) async {
    final names = <String>[];
    await tester.pumpWidget(
      _host(
        Consumer(
          builder: (context, ref, _) {
            names
              ..clear()
              ..add(
                erevDayName(
                  context,
                  ref,
                  const LockedDay(
                    date: '2027-04-22',
                    kind: LockedDayKind.yomTov,
                  ),
                ),
              )
              ..add(
                erevDayName(
                  context,
                  ref,
                  const LockedDay(
                    date: '2027-04-24',
                    kind: LockedDayKind.shabbos,
                  ),
                ),
              );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(names, ['Thursday', 'Shabbos']);
  });

  group('PlannedTaskRow', () {
    testWidgets('an open row ticks through its callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PlannedTaskRow(
            task: _task('Mishnah Peah 1:1'),
            ticked: false,
            onTick: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      expect(taps, 1);
      // The whole row is the target too.
      await tester.tap(find.text('Mishnah Peah 1:1'));
      expect(taps, 2);
    });

    testWidgets('a recorded row is ticked, struck through and inert', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PlannedTaskRow(
            task: _task('Mishnah Peah 1:1'),
            ticked: true,
            onTick: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      final title = tester.widget<Text>(find.text('Mishnah Peah 1:1'));
      expect(title.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('a review row shows its stage', (tester) async {
      await tester.pumpWidget(
        _host(
          PlannedTaskRow(
            task: _task('Mishnah Peah 1:1', stage: 2),
            ticked: false,
            onTick: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Chazara'), findsOneWidget);
    });
  });
}
