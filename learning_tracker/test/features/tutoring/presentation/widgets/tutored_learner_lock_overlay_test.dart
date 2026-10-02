// Story 1.24 (DNI-486) AC-6 — the tutored-learner lock cover: shown while
// the tutored learner is locked or its lock cannot be read (fail closed),
// never for the tutor's own app.

@Tags(['tutor_mode'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/widgets/tutored_learner_lock_overlay.dart';

import '../../../../helpers/pump_app.dart';

const _cover = Key('tutoredLearnerLockOverlay');

Widget _host(AsyncValue<bool> lock, {VoidCallback? onTap}) => pumpApp(
  overrides: [tutoredLearnerLockProvider.overrideWithValue(lock)],
  child: TutoredLearnerLockOverlay(
    child: Column(
      children: [
        const Text('Talmid data'),
        TextButton(onPressed: onTap, child: const Text('Talmid control')),
      ],
    ),
  ),
);

void main() {
  testWidgets('covered while locked', (tester) async {
    await tester.pumpWidget(_host(const AsyncData(true)));
    expect(find.byKey(_cover), findsOneWidget);
    expect(find.text('Talmid data').hitTestable(), findsNothing);
  });

  testWidgets('covered when the lock cannot be read (fail closed)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(AsyncError<bool>(StateError('unreadable'), StackTrace.empty)),
    );
    expect(find.byKey(_cover), findsOneWidget);
  });

  testWidgets('not covered when unlocked', (tester) async {
    await tester.pumpWidget(_host(const AsyncData(false)));
    expect(find.byKey(_cover), findsNothing);
    expect(find.text('Talmid data').hitTestable(), findsOneWidget);
  });

  testWidgets('while locked the learner\'s screens are absent from the '
      'semantics tree and take no input (AC-6)', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(_host(const AsyncData(true), onTap: () => taps++));

    expect(find.bySemanticsLabel('Talmid data'), findsNothing);
    expect(find.bySemanticsLabel('Talmid control'), findsNothing);
    // The cover itself stays readable: its exit action is announced.
    expect(find.byKey(const Key('tutoredLearnerLockExit')), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('tutoredLearnerLockExit'))),
      isSemantics(isButton: true),
    );

    await tester.tap(find.text('Talmid control'), warnIfMissed: false);
    expect(taps, 0);
    semantics.dispose();
  });

  testWidgets('unlocked, the learner\'s screens are in the semantics tree', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(const AsyncData(false)));
    expect(find.bySemanticsLabel('Talmid data'), findsOneWidget);
    expect(find.bySemanticsLabel('Talmid control'), findsOneWidget);
    semantics.dispose();
  });
}
