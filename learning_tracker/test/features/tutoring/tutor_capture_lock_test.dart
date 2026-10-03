// Story 1.24 (DNI-486) AC-6 + edge AC-6 — the TARGET learner's CaptureGate,
// computed with that learner's settings (not the tutor device's), blocks
// every tutor capture and governed write before any callable; while that
// learner is locked, the tutored context is covered with no data or
// controls readable, and exiting it leaves the tutor's own app and other
// learners usable (AD-36 multi-learner rule).

@Tags(['tutor_mode'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_governed_writes.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_preflight.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_write_availability.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/widgets/tutored_learner_lock_overlay.dart';

import '../../helpers/learner_state_fixtures.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/tutoring/tutor_learning_harness.dart';

final _lock = LockWindow(
  DateTime.utc(2026, 10, 1, 8),
  DateTime.utc(2026, 10, 2, 20),
);

/// The talmid's settings (Jerusalem) — distinct from any tutor-device
/// settings, so the test can prove which history the gate judged.
final _talmidHistory = LearnerSettingsHistory.constant(
  const LearnerSettings(profileId: profileUlid, timeZone: 'Asia/Jerusalem'),
);

/// A gate that is locked only for [_talmidHistory] (identity), so a check
/// against any other settings history would read as open.
final class _TalmidOnlyGate implements CaptureGate {
  @override
  GateDecision check(LearnerSettingsHistory settingsHistory, DateTime nowUtc) =>
      identical(settingsHistory, _talmidHistory) && _lock.contains(nowUtc)
      ? GateLocked(_lock)
      : const GateOpen();
}

void main() {
  group('blocked on the client before any callable', () {
    test(
      'capture is refused with the lock when the TALMID is locked',
      () async {
        final h = TutorHarness(
          gate: _TalmidOnlyGate(),
          history: _talmidHistory,
        );
        addTearDown(h.dispose);

        final result = await h.commands.capture(
          curriculumId: 'mishnayos',
          refs: const ['Mishnah Berakhot 2:1'],
          source: LearningEvent.sourceMain,
          dateState: DateState.dated,
        );

        expect(result, CaptureResult.locked(_lock));
        expect(h.invoker.calls, isEmpty);
      },
    );

    test('a governed write is refused the same way', () async {
      final h = TutorHarness(gate: _TalmidOnlyGate(), history: _talmidHistory);
      addTearDown(h.dispose);

      await expectLater(
        h.governed.upsertGoal(goalId: 'g1', data: const {'description': 'x'}),
        throwsA(
          isA<TutorGovernedWriteException>().having(
            (e) => e.refusal,
            'refusal',
            isA<TutorPreflightLocked>(),
          ),
        ),
      );
      expect(h.invoker.calls, isEmpty);
    });

    test('the same gate over another learner\'s settings stays open', () async {
      final h = TutorHarness(gate: _TalmidOnlyGate());
      addTearDown(h.dispose);

      final result = await h.commands.capture(
        curriculumId: 'mishnayos',
        refs: const ['Mishnah Berakhot 2:1'],
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
      );

      expect(result, isA<CaptureSuccess>());
    });
  });

  group('tutored learner lock (provider)', () {
    Future<AsyncValue<bool>> lock(TutoredProfileSelection? selection) async {
      final container = ProviderContainer(
        overrides: tutoredOverrides(
          selection: selection,
          lockSettings: _talmidHistory,
          gate: _TalmidOnlyGate(),
        ),
      );
      addTearDown(container.dispose);
      final sub = container.listen(tutoredLearnerLockProvider, (_, _) {});
      addTearDown(sub.close);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      return sub.read();
    }

    test('locked while the tutor views the locked talmid, judged on the '
        'talmid\'s settings', () async {
      expect((await lock(tutorSelection())).value, isTrue);
    });

    test('never locks the tutor\'s own app (no tutored selection)', () async {
      expect((await lock(null)).value, isFalse);
    });

    test('availability is locked for that learner', () async {
      final container = ProviderContainer(
        overrides: tutoredOverrides(
          selection: tutorSelection(),
          lockSettings: _talmidHistory,
          gate: _TalmidOnlyGate(),
        ),
      );
      addTearDown(container.dispose);
      final sub = container.listen(tutorWriteAvailabilityProvider, (_, _) {});
      addTearDown(sub.close);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(sub.read(), TutorWriteAvailability.locked);
    });
  });

  group('overlay (edge AC-6 multi-learner isolation)', () {
    Widget host() => const TutoredLearnerLockCover(
      child: Scaffold(body: Text('Talmid data')),
    );

    testWidgets('covers the locked talmid\'s screens with no data or controls '
        'reachable, and Exit returns to the tutor\'s own app', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          overrides: tutoredOverrides(
            selection: tutorSelection(),
            lockSettings: _talmidHistory,
            gate: _TalmidOnlyGate(),
          ),
          child: host(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tutoredLearnerLockOverlay')),
        findsOneWidget,
      );
      expect(find.text('Shabbos / Yom Tov'), findsOneWidget);
      // The data is below an opaque full-screen cover: not hit-testable.
      expect(find.text('Talmid data').hitTestable(), findsNothing);

      await tester.tap(find.byKey(const Key('tutoredLearnerLockExit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tutoredLearnerLockOverlay')), findsNothing);
      expect(find.text('Talmid data').hitTestable(), findsOneWidget);
    });

    testWidgets('another, unlocked learner is not covered', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          overrides: tutoredOverrides(
            selection: tutorSelection(),
            // Not the talmid's locked history: this learner is open.
            gate: _TalmidOnlyGate(),
          ),
          child: host(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tutoredLearnerLockOverlay')), findsNothing);
      expect(find.text('Talmid data').hitTestable(), findsOneWidget);
    });

    testWidgets('the tutor\'s own app is never covered by a talmid lock', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpApp(
          overrides: tutoredOverrides(
            lockSettings: _talmidHistory,
            gate: _TalmidOnlyGate(),
          ),
          child: host(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tutoredLearnerLockOverlay')), findsNothing);
      expect(
        ProviderScope.containerOf(
          tester.element(find.text('Talmid data')),
        ).read(activeTutoredProfileSelectionProvider),
        isNull,
      );
    });
  });
}
