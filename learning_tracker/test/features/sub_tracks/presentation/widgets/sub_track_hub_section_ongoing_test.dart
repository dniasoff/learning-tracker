// DNI-496 (Story 2.5) through the Story 2.4 (DNI-495) Manage tracks hub:
// Add sub-track → Ongoing opens the ongoing form (AC-1), the chooser's
// five-ongoing limit counted on the learner's civil today (AC-5, UX-DR-82,
// UX-DR-103), a future-start row reads "Starts {date}" (AC-4, UX-DR-89) and
// an ongoing row opens its edit form (AC-6).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ongoing_sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_hub_section.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/sub_track_harness.dart';

String _id(int n) => '01JHARN${n.toString().padLeft(19, '0')}';

/// An ongoing sub-track of the test curriculum (the harness's today is
/// 2026-10-02).
SubTrack _ongoing(
  int n, {
  String name = 'Rebbe',
  String start = '2026-09-01',
  String? end,
  bool ended = false,
}) => SubTrack(
  id: _id(n),
  curriculumId: subTrackTestCurriculum,
  name: name,
  type: SubTrackType.ongoing,
  windowStart: start,
  windowEnd: end,
  ratePerWeek: 5,
  weeksPerYear: 52,
  learnsOnShabbos: false,
  ground: const [],
  lastChangeId: ulidE,
  endedAt: ended ? DateTime.utc(2026, 9, 15) : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

Future<SubTrackHarness> _pump(
  WidgetTester tester, {
  List<SubTrack> seed = const [],
}) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = SubTrackHarness(seed: seed);
  addTearDown(h.dispose);
  await tester.pumpWidget(
    pumpApp(
      overrides: [
        ...h.overrides(),
        localDayClockProvider.overrideWithValue(
          FakeLocalDayClock(DateTime.utc(2026, 10, 2, 12)),
        ),
        ongoingSubTrackParentSessionProvider.overrideWith((ref) async => true),
        ongoingSubTrackWriteScopeProvider.overrideWith(
          (ref) async => c0Scope(),
        ),
      ],
      retry: (_, _) => null,
      child: const Scaffold(
        body: SingleChildScrollView(
          child: SubTrackHubSection(curriculumId: subTrackTestCurriculum),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

Finder _ongoingOption() =>
    find.ancestor(of: find.text('Ongoing'), matching: find.byType(ListTile));

void main() {
  testWidgets('Add sub-track → Ongoing opens the ongoing create form', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Add sub-track'));
    await tester.pumpAndSettle();
    expect(
      find.text('You can have up to 5 ongoing sub-tracks. 0 in use.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();
    expect(find.text('Ongoing sub-track'), findsOneWidget);
    expect(find.byKey(const ValueKey('ongoingSubTrackName')), findsOneWidget);
  });

  testWidgets('five counting ongoing sub-tracks disable Ongoing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      seed: [
        for (var i = 1; i <= 4; i++) _ongoing(i, name: 'Rebbe $i'),
        // A future start counts (AD-45).
        _ongoing(5, name: 'Later', start: '2026-11-01'),
      ],
    );
    await tester.tap(find.text('Add sub-track'));
    await tester.pumpAndSettle();
    expect(
      find.text('You can have up to 5 ongoing sub-tracks. 5 in use.'),
      findsOneWidget,
    );
    expect(tester.widget<ListTile>(_ongoingOption()).enabled, isFalse);
    expect(
      tester.getSemantics(_ongoingOption()),
      isSemantics(hasEnabledState: true, isEnabled: false),
    );
    await tester.tap(find.text('Ongoing'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Ongoing sub-track'), findsNothing);
    semantics.dispose();
  });

  testWidgets('ended and expired-window sub-tracks do not count (UX-DR-82)', (
    tester,
  ) async {
    await _pump(
      tester,
      seed: [
        for (var i = 1; i <= 4; i++) _ongoing(i, name: 'Rebbe $i'),
        _ongoing(5, name: 'Ended', ended: true),
        _ongoing(6, name: 'Expired', end: '2026-10-01'),
      ],
    );
    await tester.tap(find.text('Add sub-track'));
    await tester.pumpAndSettle();
    expect(
      find.text('You can have up to 5 ongoing sub-tracks. 4 in use.'),
      findsOneWidget,
    );
    expect(tester.widget<ListTile>(_ongoingOption()).enabled, isTrue);
  });

  testWidgets('AC-4: a future-start ongoing row reads "Starts {date}"', (
    tester,
  ) async {
    await _pump(
      tester,
      seed: [
        _ongoing(1, name: 'Chavrusa', start: '2026-11-01'),
        _ongoing(2, name: 'Rebbe'),
      ],
    );
    expect(find.text('Starts Nov 1, 2026'), findsOneWidget);
    // A started row keeps its rate subtitle.
    expect(find.text('Ongoing · 5/week'), findsOneWidget);
  });

  testWidgets('AC-6: an ongoing row opens its edit form', (tester) async {
    await _pump(tester, seed: [_ongoing(1, name: 'Rebbe Cohen')]);
    await tester.tap(find.text('Rebbe Cohen'));
    await tester.pumpAndSettle();
    expect(find.text('Edit ongoing sub-track'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('ongoingSubTrackName')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'Rebbe Cohen',
    );
  });
}
