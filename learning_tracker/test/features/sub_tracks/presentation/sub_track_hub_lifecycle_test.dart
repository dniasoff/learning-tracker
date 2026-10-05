/// Story 2.8 (DNI-499) AC-5 / AC-6 on Settings → Manage tracks: DNI-495's
/// Sub-tracks group lists the sub-tracks active on the learner's civil
/// today; tombstoned and elapsed-window ones move to the collapsed, muted
/// *Ended sub-tracks ({n})* group at its foot, whose rows open the
/// (read-only) DNI-497 detail.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/domain/learner_state/predicates.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_hub_section.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_management_body.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/learner_state_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/sub_tracks/sub_track_harness.dart';
import '../../../helpers/sub_tracks/sub_track_router.dart';

class _Router extends Mock implements StackRouter {}

String _id(int n) => '01JHARN00000000000000000${n.toString().padLeft(2, '0')}';

SubTrack _ended(int n, String name, SubTrackEndReason reason) => SubTrack(
  id: _id(n),
  curriculumId: subTrackTestCurriculum,
  name: name,
  type: SubTrackType.ongoing,
  windowStart: '2026-01-01',
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [],
  lastChangeId: ulidE,
  endedAt: t1,
  endReason: reason,
);

// School 2026–27 and Rebbe are live; Shiur was ended, Chavrusa deleted,
// and School 2025–26's window passed on 31 Jul 2026 with no write.
List<SubTrack> _tracks() => [
  storedSchoolYear(_id(1), name: 'School'),
  storedOngoing(_id(2), name: 'Rebbe'),
  _ended(3, 'Shiur', SubTrackEndReason.ended),
  _ended(4, 'Chavrusa', SubTrackEndReason.deleted),
  storedSchoolYear(_id(5), name: 'School', academicYear: 2025),
];

Future<_Router> _pumpHub(WidgetTester tester, SubTrackHarness h) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1600);
  addTearDown(tester.view.reset);
  final router = _Router();
  when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
  await tester.pumpWidget(
    pumpApp(
      overrides: [...h.overrides(), ...subTrackHubCardOverrides()],
      retry: (_, _) => null,
      child: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: const TrackManagementBody(showBackButton: true),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder _row(int n) => find.byKey(ValueKey('subTrackHubRow:${_id(n)}'));
Finder _endedRow(int n) => find.byKey(ValueKey('endedSubTrackRow:${_id(n)}'));

// Only the widget tests build a harness; the plain test() cases never do,
// and with randomized ordering they can run first (fyh.330 pattern).
SubTrackHarness? _built;
SubTrackHarness get h => _built!;
set h(SubTrackHarness harness) => _built = harness;

void main() {
  setUpAll(() => registerFallbackValue(const SettingsRoute()));

  setUp(() => _built = null);
  tearDown(() async => _built?.dispose());

  testWidgets('explicitly ended and elapsed tracks leave the active rows for '
      'a collapsed Ended sub-tracks group at the foot, never "Completed"', (
    tester,
  ) async {
    h = SubTrackHarness(seed: _tracks());
    await _pumpHub(tester, h);

    expect(find.text('Sub-tracks · 2 active'), findsOneWidget);
    expect(_row(1), findsOneWidget);
    expect(_row(2), findsOneWidget);
    for (final n in [3, 4, 5]) {
      expect(_row(n), findsNothing);
    }
    expect(find.text('Ended sub-tracks (3)'), findsOneWidget);
    // At the foot of the group, after Add sub-track.
    expect(
      tester.getTopLeft(find.text('Add sub-track')).dy,
      lessThan(tester.getTopLeft(find.text('Ended sub-tracks (3)')).dy),
    );
    // Collapsed: the ended rows are not shown yet.
    for (final n in [3, 4, 5]) {
      expect(_endedRow(n), findsNothing);
    }
    expect(find.textContaining('Completed'), findsNothing);

    await tester.tap(find.text('Ended sub-tracks (3)'));
    await tester.pumpAndSettle();
    for (final n in [3, 4, 5]) {
      expect(_endedRow(n), findsOneWidget);
    }
    expect(find.text('School 2025–26'), findsOneWidget);
    expect(find.text('Ended Jul 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('Shiur, ended'), findsOneWidget);
    expect(find.textContaining('Completed'), findsNothing);
    expect(h.repo.calls, isEmpty, reason: 'expiry writes nothing');
  });

  testWidgets('ended rows are muted', (tester) async {
    h = SubTrackHarness(seed: _tracks());
    await _pumpHub(tester, h);
    await tester.tap(find.text('Ended sub-tracks (3)'));
    await tester.pumpAndSettle();
    final active = tester.widget<Text>(
      find.descendant(of: _row(2), matching: find.text('Rebbe')),
    );
    final ended = tester.widget<Text>(
      find.descendant(of: _endedRow(3), matching: find.text('Shiur')),
    );
    expect(ended.style?.color, isNot(active.style?.color));
  });

  testWidgets('an ended row opens its sub-track detail (read-only there)', (
    tester,
  ) async {
    h = SubTrackHarness(seed: _tracks());
    final router = await _pumpHub(tester, h);
    await tester.tap(find.text('Ended sub-tracks (3)'));
    await tester.pumpAndSettle();
    await tester.tap(_endedRow(5));
    await tester.pump();
    final pushed =
        verify(() => router.push<Object?>(captureAny())).captured.single
            as SubTrackDetailRoute;
    expect(pushed.args!.subTrackId, _id(5));
  });

  // The window ends 31 Jul 2027 (inclusive): active through that day, ended
  // from the learner's 1 Aug with no write.
  for (final (today, active) in [('2027-07-31', true), ('2027-08-01', false)]) {
    testWidgets('on $today the 2026–27 school year is '
        '${active ? 'still active' : 'ended, with no write'}', (tester) async {
      h = SubTrackHarness(
        today: today,
        seed: [storedSchoolYear(_id(1), name: 'School')],
      );
      await _pumpHub(tester, h);
      expect(_row(1), active ? findsOneWidget : findsNothing);
      expect(
        find.text('Ended sub-tracks (1)'),
        active ? findsNothing : findsOneWidget,
      );
      expect(h.repo.calls, isEmpty);
      expect(h.repo.entries, isEmpty);
    });
  }

  testWidgets('no ended group while nothing has ended', (tester) async {
    h = SubTrackHarness(
      seed: [storedSchoolYear(_id(1)), storedOngoing(_id(2))],
    );
    await _pumpHub(tester, h);
    expect(find.byKey(const ValueKey('endedSubTracksGroup')), findsNothing);
    expect(find.textContaining('Ended sub-tracks'), findsNothing);
  });

  testWidgets('one ended track and no live one: only the ended group', (
    tester,
  ) async {
    h = SubTrackHarness(seed: [_ended(3, 'Shiur', SubTrackEndReason.ended)]);
    await _pumpHub(tester, h);
    expect(find.text('Sub-tracks · 0 active'), findsOneWidget);
    expect(find.byType(SubTrackHubRow), findsNothing);
    expect(find.text('Ended sub-tracks (1)'), findsOneWidget);
  });

  test('ended and elapsed tracks are absent from Learn and the Dashboard: '
      'they are not onHome (AD-34), the predicate both surfaces use', () {
    for (final t in _tracks().skip(2)) {
      expect(onHome(t, subTrackTestToday), isFalse, reason: t.name);
    }
    expect(onHome(_tracks().first, subTrackTestToday), isTrue);
  });
}
