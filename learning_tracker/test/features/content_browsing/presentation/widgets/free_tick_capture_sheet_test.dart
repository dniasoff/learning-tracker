// Mirror test for
// `lib/features/content_browsing/presentation/widgets/free_tick_capture_sheet.dart`
// (Story 1.11, DNI-473; UX-DR-20, UX-DR-74): the source is asked once (Home
// by default, Before tracking offered), the date defaults to today and is
// editable, and one "Record {count}" button confirms.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/free_tick_capture_sheet.dart';

import '../../../../helpers/pump_app.dart';

final _today = DateTime(2026, 9, 10);

Future<FreeTickChoice?> _open(
  WidgetTester tester, {
  int count = 3,
  List<FreeTickSourceOption> extraSources = const [],
  required Future<void> Function() interact,
}) async {
  FreeTickChoice? choice;
  var closed = false;
  await tester.pumpWidget(
    pumpApp(
      child: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              choice = await showFreeTickCaptureSheet(
                context,
                title: 'Berakhot',
                count: count,
                today: _today,
                extraSources: extraSources,
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await interact();
  await tester.pumpAndSettle();
  expect(closed, isTrue, reason: 'the sheet closed');
  return choice;
}

void main() {
  testWidgets('Home is preselected, the date defaults to today, and Record '
      'returns a main dated choice with no explicit date', (tester) async {
    final choice = await _open(
      tester,
      interact: () async {
        expect(find.text('Record 3'), findsOneWidget);
        expect(find.text('Where did you learn this?'), findsOneWidget);
        final home = tester.widget<RadioListTile<String>>(
          find.byKey(const Key('freeTickSourceHome')),
        );
        expect(home.value, LearningEvent.sourceMain);
        expect(find.text('Sep 10, 2026'), findsOneWidget);
        await tester.tap(find.text('Record 3'));
      },
    );
    expect(
      choice,
      const FreeTickChoice(
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
      ),
    );
  });

  testWidgets('an earlier date edits learned_on', (tester) async {
    final choice = await _open(
      tester,
      interact: () async {
        await tester.tap(find.text('Change'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('7'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.text('Sep 7, 2026'), findsOneWidget);
        await tester.tap(find.text('Record 3'));
      },
    );
    expect(
      choice,
      const FreeTickChoice(
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
        learnedOn: '2026-09-07',
        taps: 4,
      ),
    );
  });

  testWidgets('Before tracking hides the date and records no learned_on', (
    tester,
  ) async {
    final choice = await _open(
      tester,
      interact: () async {
        await tester.tap(find.byKey(const Key('freeTickSourceBeforeTracking')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('freeTickDate')), findsNothing);
        await tester.tap(find.text('Record 3'));
      },
    );
    expect(
      choice,
      const FreeTickChoice(
        source: LearningEvent.sourceMain,
        dateState: DateState.beforeTracking,
        taps: 3,
      ),
    );
  });

  testWidgets('another active source is offered and chosen once for the '
      'batch', (tester) async {
    const ulid = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
    final choice = await _open(
      tester,
      extraSources: const [FreeTickSourceOption(id: ulid, label: 'Shiur')],
      interact: () async {
        await tester.tap(find.text('Shiur'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Record 3'));
      },
    );
    expect(
      choice,
      const FreeTickChoice(source: ulid, dateState: DateState.dated, taps: 3),
    );
  });

  testWidgets('Cancel returns nothing', (tester) async {
    final choice = await _open(
      tester,
      interact: () => tester.tap(find.text('Cancel')),
    );
    expect(choice, isNull);
  });

  testWidgets('an empty batch cannot be recorded', (tester) async {
    await _open(
      tester,
      count: 0,
      interact: () async {
        final record = tester.widget<FilledButton>(
          find.byKey(const Key('freeTickRecord')),
        );
        expect(record.onPressed, isNull);
        await tester.tap(find.text('Cancel'));
      },
    );
  });
}
