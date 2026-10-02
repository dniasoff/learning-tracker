/// Story 2.8 (DNI-499) AC-5 / AC-6 on Manage tracks: active and ended
/// sub-track groups, the collapsed muted *Ended sub-tracks ({n})* group and
/// the read-only ended detail.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/predicates.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_lifecycle_hub_section.dart';

import '../../../helpers/pump_app.dart';
import 'sub_track_lifecycle_harness.dart';

Future<void> _pumpHub(WidgetTester tester, LifecycleWorld world) async {
  await tester.pumpWidget(
    pumpApp(
      overrides: world.overrides,
      child: Scaffold(
        body: ListView(children: const [SubTrackLifecycleHubSection()]),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _active(int n) =>
    find.byKey(ValueKey('activeSubTrackRow:${lifecycleId(n)}'));
Finder _ended(int n) =>
    find.byKey(ValueKey('endedSubTrackRow:${lifecycleId(n)}'));

void main() {
  // School 2026–27 is live; Night seder is live and open; Shiur was ended,
  // Chavrusa deleted, and School 2025–26's window passed on 31 Jul 2026.
  List<SubTrack> tracks() => [
    schoolYear(),
    ongoing(),
    ongoing(n: 3, name: 'Shiur', endReason: SubTrackEndReason.ended),
    ongoing(n: 4, name: 'Chavrusa', endReason: SubTrackEndReason.deleted),
    schoolYear(n: 5, name: 'School', academicYear: 2025),
  ];

  testWidgets('explicitly ended and elapsed tracks leave the active rows for '
      'a collapsed Ended sub-tracks group, never "Completed"', (tester) async {
    final world = LifecycleWorld(tracks());
    addTearDown(world.dispose);
    await _pumpHub(tester, world);

    expect(_active(1), findsOneWidget);
    expect(_active(2), findsOneWidget);
    for (final n in [3, 4, 5]) {
      expect(_active(n), findsNothing);
    }
    expect(find.text('Ended sub-tracks (3)'), findsOneWidget);
    // Collapsed: the ended rows are not shown yet.
    for (final n in [3, 4, 5]) {
      expect(_ended(n), findsNothing);
    }
    expect(find.textContaining('Completed'), findsNothing);

    await tester.tap(find.text('Ended sub-tracks (3)'));
    await tester.pumpAndSettle();
    for (final n in [3, 4, 5]) {
      expect(_ended(n), findsOneWidget);
    }
    expect(find.text('School 2025–26'), findsOneWidget);
    expect(find.text('Ended Jul 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('Shiur, ended'), findsOneWidget);
    expect(find.textContaining('Completed'), findsNothing);
    expect(world.repo.calls, isEmpty, reason: 'expiry writes nothing');
  });

  testWidgets('ended rows are muted', (tester) async {
    final world = LifecycleWorld(tracks());
    addTearDown(world.dispose);
    await _pumpHub(tester, world);
    await tester.tap(find.text('Ended sub-tracks (3)'));
    await tester.pumpAndSettle();
    final active = tester.widget<Text>(
      find.descendant(of: _active(2), matching: find.text('Night seder')),
    );
    final ended = tester.widget<Text>(
      find.descendant(of: _ended(3), matching: find.text('Shiur')),
    );
    expect(ended.style?.color, isNot(active.style?.color));
  });

  testWidgets('an ended row opens a read-only detail: no ⋮ and no ground, '
      'edit, reorder or delete action', (tester) async {
    final world = LifecycleWorld(tracks());
    addTearDown(world.dispose);
    await _pumpHub(tester, world);
    await tester.tap(find.text('Ended sub-tracks (3)'));
    await tester.pumpAndSettle();
    await tester.tap(_ended(3));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('subTrackLifecycleReadOnly')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('subTrackLifecycleMenu')), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byKey(const ValueKey('subTrackAddNextYear')), findsNothing);
  });

  testWidgets('an elapsed school year is read-only but can still roll into '
      'next year (UJ-3)', (tester) async {
    final world = LifecycleWorld(tracks());
    addTearDown(world.dispose);
    await _pumpHub(tester, world);
    await tester.tap(find.text('Ended sub-tracks (3)'));
    await tester.pumpAndSettle();
    await tester.tap(_ended(5));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('subTrackLifecycleReadOnly')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('subTrackLifecycleMenu')), findsNothing);
    // 2026–27 is already held by the live School: visible but disabled.
    expect(find.text('Add next year (2026–27)'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('subTrackAddNextYear')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('a live row opens the detail with its ⋮', (tester) async {
    final world = LifecycleWorld(tracks());
    addTearDown(world.dispose);
    await _pumpHub(tester, world);
    await tester.tap(_active(2));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('subTrackLifecycleMenu')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('subTrackLifecycleReadOnly')),
      findsNothing,
    );
  });

  testWidgets('no ended group while nothing has ended', (tester) async {
    final world = LifecycleWorld([schoolYear(), ongoing()]);
    addTearDown(world.dispose);
    await _pumpHub(tester, world);
    expect(find.byKey(const ValueKey('endedSubTracksGroup')), findsNothing);
    expect(find.textContaining('Ended sub-tracks'), findsNothing);
  });

  testWidgets('one more ended track grows the count', (tester) async {
    final world = LifecycleWorld([
      ongoing(n: 3, name: 'Shiur', endReason: SubTrackEndReason.ended),
    ]);
    addTearDown(world.dispose);
    await _pumpHub(tester, world);
    expect(find.text('Ended sub-tracks (1)'), findsOneWidget);
  });

  test('ended and elapsed tracks are absent from Learn and the Dashboard: '
      'they are not onHome (AD-34)', () {
    for (final t in tracks().skip(2)) {
      expect(onHome(t, lifecycleToday), isFalse, reason: t.name);
    }
    expect(onHome(tracks().first, lifecycleToday), isTrue);
  });

  group('the read is never mistaken for no sub-tracks', () {
    final error = find.byKey(const ValueKey('subTrackLifecycleHubError'));
    final retry = find.byKey(const ValueKey('subTrackLifecycleHubRetry'));

    testWidgets('a failed read shows Could not load with Retry, and Retry '
        'reads again', (tester) async {
      final world = LifecycleWorld(tracks())
        ..readOverride = () => Stream.error(StateError('permission-denied'));
      addTearDown(world.dispose);
      await _pumpHub(tester, world);
      expect(error, findsOneWidget);
      expect(find.text("Couldn't load sub-tracks."), findsOneWidget);
      expect(_active(1), findsNothing);

      world.readOverride = null;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      expect(_active(1), findsOneWidget);
      expect(find.text('Ended sub-tracks (3)'), findsOneWidget);
    });

    testWidgets('a complete read with an undecodable sub-track is a read '
        'failure, not a shorter list', (tester) async {
      final world = LifecycleWorld(tracks());
      addTearDown(world.dispose);
      world.repo.seedRejected(world.scope, [
        RejectedRow(lifecycleId(9), const FormatException('bad ground')),
      ]);
      await _pumpHub(tester, world);
      expect(error, findsOneWidget);
      expect(_active(1), findsNothing);

      world.repo.seedRejected(world.scope, const []);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      expect(_active(1), findsOneWidget);
    });

    testWidgets('while the first read loads, a loading row shows', (
      tester,
    ) async {
      final pending = StreamController<CompleteRead<SubTrack>>();
      addTearDown(pending.close);
      final world = LifecycleWorld(tracks())
        ..readOverride = () => pending.stream;
      addTearDown(world.dispose);
      await tester.pumpWidget(
        pumpApp(
          overrides: world.overrides,
          child: Scaffold(
            body: ListView(children: const [SubTrackLifecycleHubSection()]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('subTrackLifecycleHubLoading')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Loading sub-tracks'), findsOneWidget);
      expect(error, findsNothing);
    });
  });
}
