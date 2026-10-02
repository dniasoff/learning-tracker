// DNI-500 named Learn slot: empty, and zero size until its story fills it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/learn_slots/erev_planned_slot.dart';

void main() {
  testWidgets('ErevPlannedSlot takes no space while empty', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [ErevPlannedSlot()]),
      ),
    );
    expect(tester.getSize(find.byType(ErevPlannedSlot)), Size.zero);
  });
}
