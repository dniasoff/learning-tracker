// Mirror test for
// `lib/features/progress/presentation/widgets/learnt_tri_state.dart`
// (DNI-474 AC-3: checkbox, count and semantics carry the FR-15 state).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/learnt_tri_state.dart';
import 'package:learning_tracker/l10n/app_localizations_en.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('the semantics label carries name, state word and count', () {
    expect(
      learntTriStateSemantics(
        l10n,
        name: 'Berakhot',
        state: TriState.partial,
        learnt: 3,
        total: 12,
      ),
      'Berakhot, partial, 3 of 12 learnt',
    );
    expect(learntTriStateWord(l10n, TriState.complete), 'complete');
    expect(learntTriStateWord(l10n, TriState.empty), 'not learnt');
  });

  test('state from counts: none learnt is empty, all is complete', () {
    expect(triStateFromCounts(0, 12), TriState.empty);
    expect(triStateFromCounts(3, 12), TriState.partial);
    expect(triStateFromCounts(12, 12), TriState.complete);
    expect(triStateFromCounts(0, 0), TriState.empty);
  });

  testWidgets('the box is checked / dash / empty and excluded from '
      'semantics; the count reads n/total', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        child: const Scaffold(
          body: Column(
            children: [
              LearntTriStateBox(state: TriState.complete),
              LearntTriStateBox(state: TriState.partial),
              LearntTriStateBox(state: TriState.empty),
              LearntCountLabel(learnt: 3, total: 12),
            ],
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
    expect(find.byIcon(Icons.indeterminate_check_box_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);
    expect(find.text('3/12'), findsOneWidget);
    final context = tester.element(find.byType(Column));
    expect(
      learntTriStateColor(context, TriState.partial),
      isNot(learntTriStateColor(context, TriState.complete)),
    );
    expect(learntTriStateTintAlpha, 0.12);
  });
}
