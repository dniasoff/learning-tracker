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

Widget _host(AsyncValue<bool> lock) => pumpApp(
  overrides: [tutoredLearnerLockProvider.overrideWithValue(lock)],
  child: const TutoredLearnerLockOverlay(child: Text('Talmid data')),
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
}
