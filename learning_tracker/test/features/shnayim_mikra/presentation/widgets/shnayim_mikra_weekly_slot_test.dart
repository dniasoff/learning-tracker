import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/providers/shnayim_mikra_schedule_provider.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/widgets/shnayim_mikra_weekly_slot.dart';

void main() {
  testWidgets('weekly slot is hidden when no assignment is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shnayimMikraScheduleProjectionProvider.overrideWith(
            (ref) async => null,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ShnayimMikraWeeklySlot()),
        ),
      ),
    );

    expect(find.byType(Card), findsNothing);
  });
}
