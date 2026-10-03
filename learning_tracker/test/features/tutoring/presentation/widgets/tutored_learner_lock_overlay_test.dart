// Story 1.24 (DNI-486) AC-6 — the tutored-learner lock cover: the learner's
// screens show only on an explicit "not locked"; while the lock loads, is
// locked or cannot be read they are covered (fail closed), never for the
// tutor's own app.

@Tags(['tutor_mode'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/widgets/tutored_learner_lock_overlay.dart';

import '../../../../helpers/pump_app.dart';

const _cover = Key('tutoredLearnerLockOverlay');
const _pending = Key('tutoredLearnerLockPending');

/// A lock state the test can change while the overlay is mounted.
final class _LockState extends Notifier<AsyncValue<bool>> {
  @override
  AsyncValue<bool> build() => const AsyncLoading<bool>();

  // ignore: use_setters_to_change_properties — a test hook.
  void emit(AsyncValue<bool> value) => state = value;
}

final _lockState = NotifierProvider<_LockState, AsyncValue<bool>>(
  _LockState.new,
);

Widget _host(AsyncValue<bool> lock, {VoidCallback? onTap}) => pumpApp(
  overrides: [tutoredLearnerLockProvider.overrideWithValue(lock)],
  child: TutoredLearnerLockCover(
    child: Column(
      children: [
        const Text('Talmid data'),
        TextButton(onPressed: onTap, child: const Text('Talmid control')),
      ],
    ),
  ),
);

void main() {
  testWidgets('covered while the lock is still loading: no data, no '
      'controls, no lock claim (AC-6, fail closed)', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(const AsyncLoading<bool>(), onTap: () => taps++),
    );

    expect(find.byKey(_pending), findsOneWidget);
    expect(find.byKey(_cover), findsNothing);
    expect(find.text('Talmid data').hitTestable(), findsNothing);
    expect(find.bySemanticsLabel('Talmid data'), findsNothing);
    expect(find.bySemanticsLabel('Talmid control'), findsNothing);
    expect(find.byKey(const Key('tutoredLearnerLockExit')), findsOneWidget);
    await tester.tap(find.text('Talmid control'), warnIfMissed: false);
    expect(taps, 0);
    semantics.dispose();
  });

  testWidgets('follows the lock as it changes: loading, unlocked, locked, '
      'unlocked', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          tutoredLearnerLockProvider.overrideWith(
            (ref) => ref.watch(_lockState),
          ),
        ],
        child: const TutoredLearnerLockCover(child: Text('Talmid data')),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TutoredLearnerLockCover)),
    );
    expect(find.byKey(_pending), findsOneWidget);

    container.read(_lockState.notifier).emit(const AsyncData(false));
    await tester.pump();
    expect(find.byKey(_pending), findsNothing);
    expect(find.byKey(_cover), findsNothing);
    expect(find.text('Talmid data').hitTestable(), findsOneWidget);

    container.read(_lockState.notifier).emit(const AsyncData(true));
    await tester.pump();
    expect(find.byKey(_cover), findsOneWidget);
    expect(find.text('Talmid data').hitTestable(), findsNothing);

    container.read(_lockState.notifier).emit(const AsyncData(false));
    await tester.pump();
    expect(find.byKey(_cover), findsNothing);
    expect(find.text('Talmid data').hitTestable(), findsOneWidget);
  });

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
