// DNI-500 named Learn slot: empty, and zero size until its story fills it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/learn_slots/catch_up_cards_slot.dart';

void main() {
  testWidgets('CatchUpCardsSlot takes no space while empty', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [CatchUpCardsSlot()]),
      ),
    );
    expect(tester.getSize(find.byType(CatchUpCardsSlot)), Size.zero);
  });
}
