// DNI-495 (story 2.4) AC-7 — the school-year form saved OFFLINE through the
// real Story 2.1 SubTrackCommands shows its row on Manage tracks at once and
// recomputes the daily target on the same screen; when the queued batch is
// later rejected for good at sync, the row disappears and the hub says
// "Your change couldn't be saved."
//
// Real AppRouter (permissive guards except the parent-session gate), real
// hub, form and commands; the C0 InMemorySubTrackRepository models
// Firestore latency compensation (offline = applied locally, ack held) and
// the rollback of a permanently rejected write. The Firestore/rules side of
// the same batch is proven by sub_track_offline_write_test.dart (DNI-492).
//   flutter test integration_test/sub_track_offline_create_test.dart -d <device>

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';

import '../test/helpers/pump_app.dart';
import '../test/helpers/sub_tracks/sub_track_harness.dart';
import '../test/helpers/sub_tracks/sub_track_router.dart';

Finder _chip(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip));

/// Pumps in 50 ms steps until [finder] matches, at most [maxPumps] times.
/// The integration binding runs on real time, so `pumpAndSettle` can return
/// while the hub's async reads (scope, intent, sub-tracks) have not emitted
/// yet: no frame is pending until they do.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _createFromHub(WidgetTester tester, SubTrackHarness h) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1800);
  addTearDown(tester.view.reset);
  final router = subTrackTestRouter(isParentSession: () => true);
  await tester.pumpWidget(
    pumpApp(
      routerConfig: router.config(
        deepLinkBuilder: (_) => const DeepLink.path('/settings/tracks'),
      ),
      overrides: [...h.overrides(), ...subTrackHubCardOverrides()],
      retry: (_, _) => null,
    ),
  );
  await tester.pumpAndSettle();
  await _pumpUntilFound(tester, find.text('Sub-tracks · 0 active'));
  expect(find.text('Sub-tracks · 0 active'), findsOneWidget);

  await tester.tap(find.text('Add sub-track'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('School year'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('subTrackFormName')),
    'Cheder',
  );
  await tester.tap(_chip('2026–27'));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const ValueKey('subTrackFormSave')));
  await tester.tap(find.byKey(const ValueKey('subTrackFormSave')));
  // Past the commands' 50 ms ack window: the batch counts as queued.
  await settleCommands(tester);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline: the new row and recomputed target appear at once', (
    tester,
  ) async {
    final h = SubTrackHarness(deadline: '2028-06-01')..repo.offline = true;
    addTearDown(h.dispose);
    await _createFromHub(tester, h);

    expect(find.text('Sub-tracks · 1 active'), findsOneWidget);
    expect(find.text('Cheder'), findsOneWidget);
    expect(find.text('Daily target: 20 mishnayos'), findsOneWidget);
    expect(h.repo.heldCount, 1);

    await tester.runAsync(() async => h.repo.settleHeld());
    await tester.pumpAndSettle();
    expect(find.text('Cheder'), findsOneWidget);
    expect(find.text("Your change couldn't be saved."), findsNothing);
  });

  testWidgets('a batch rejected at sync removes the row and says so', (
    tester,
  ) async {
    final h = SubTrackHarness()
      ..repo.offline = true
      ..repo.failNextWith(const PermanentWriteRejection('permission-denied'));
    addTearDown(h.dispose);
    await _createFromHub(tester, h);
    expect(find.text('Cheder'), findsOneWidget);

    await tester.runAsync(() async {
      h.repo.settleHeld();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();
    expect(find.text('Cheder'), findsNothing);
    expect(find.text('Sub-tracks · 0 active'), findsOneWidget);
    expect(find.text("Your change couldn't be saved."), findsOneWidget);
  });
}
