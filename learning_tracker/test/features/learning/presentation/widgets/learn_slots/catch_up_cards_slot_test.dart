// DNI-500 named Learn slot, filled by DNI-505: zero size with no pending
// catch-up card; the catch-up cards section otherwise.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/presentation/providers/erev_planned_tasks_provider.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/catch_up_card.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/learn_slots/catch_up_cards_slot.dart';

void main() {
  testWidgets('CatchUpCardsSlot takes no space with no pending card', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // No active learner: no settings history, so no card.
          erevSettingsHistoryProvider.overrideWith((ref) async => null),
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [CatchUpCardsSlot()]),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CatchUpCardsSection), findsOneWidget);
    expect(tester.getSize(find.byType(CatchUpCardsSlot)), Size.zero);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
