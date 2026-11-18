import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/learn_slots/daily_learning_programs_slot.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';

import '../../../../../helpers/pump_app.dart';

void main() {
  testWidgets('shows an offline-text message when today has no indexed ref', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpApp(
        child: const Scaffold(
          body: SingleChildScrollView(child: DailyLearningProgramsSlot()),
        ),
        overrides: [
          todayCalendarProvider.overrideWith(
            (ref) async => const [
              CalendarProgramEntry(
                programId: 'daf-yomi',
                displayNameEn: 'Daf Yomi',
                displayNameHe: 'דף יומי',
                todayRef: 'Berakhot 2a',
                apiSource: 'test',
              ),
            ],
          ),
          contentIndexProvider.overrideWith(
            (ref) async =>
                ContentIndex.fromCurricula({CurriculumId.mishnayos: const []}),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Today's programs"));
    await tester.pumpAndSettle();

    expect(
      find.text("This reading isn't available in the offline text library."),
      findsOneWidget,
    );
  });
}
