import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/shnayim_mikra/domain/shnayim_mikra_weekly_assignment.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/screens/shnayim_mikra_reader_screen.dart';

void main() {
  testWidgets('reader waits while no active learner scope is available', (
    tester,
  ) async {
    final assignment = ShnayimMikraWeeklyAssignment(
      portionKey: 'NOACH',
      shabbosDate: DateTime.utc(2026, 11, 14),
      dueDate: DateTime.utc(2026, 11, 13),
      dueAt: DateTime.utc(2026, 11, 13, 18),
      catchUpThrough: DateTime.utc(2027, 10, 3),
      inIsrael: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          home: ShnayimMikraReaderScreen(assignment: assignment),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
