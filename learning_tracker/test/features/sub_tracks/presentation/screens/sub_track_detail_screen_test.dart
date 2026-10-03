// DNI-497 (Story 2.6) AC-1, AC-3/AC-5 (fully ticked), AC-7: the detail
// renders from a hub selection with the engine's values; the child is
// read-only.
import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_actions.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_detail_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/pump_app.dart';
import '../../sub_track_detail_harness.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo<Object?> {}

void main() {
  setUpAll(() => registerFallbackValue(_FakePageRouteInfo()));

  late DetailHarness h;
  late _MockStackRouter router;
  setUp(() {
    h = DetailHarness();
    router = _MockStackRouter();
    when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
    when(() => router.canPop()).thenReturn(false);
  });
  tearDown(() => h.dispose());

  final school = detailSubTrack(10, 'School 2026–27', const [
    berakhot1,
    peah,
  ], windowEnd: '2027-07-31');

  Future<void> pump(
    WidgetTester tester, {
    String? id,
    SubTrackDetailRole role = SubTrackDetailRole.parent,
    List<Override> extra = const [],
    Stream<LearnerState> Function()? engine,
  }) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          ...h.overrides(role: role, engine: engine),
          ...extra,
        ],
        child: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: SubTrackDetailScreen(subTrackId: id ?? school.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the window, engine position, distinct ticked count, '
      'capacity and the ordered ground', (tester) async {
    h
      ..seed(
        subTracks: [school],
        learnEvents: [
          engineLearn(1, 'Mishnah Berakhot 1:1', source: school.id),
          engineLearn(2, 'Mishnah Berakhot 1:1', source: school.id),
          engineLearn(3, 'Mishnah Berakhot 1:2'),
        ],
      )
      ..deadline = '2026-12-31';
    await pump(tester);
    final engine = h.curriculum.subTracks[school.id]!;
    expect(engine.capacity, isNotNull, reason: 'DNI-494 capacity');

    expect(find.text('School 2026–27'), findsOneWidget);
    expect(find.text('Sep 2026 – Jul 2027'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    expect(
      find.text(h.curriculum.subTracks[school.id]!.position!),
      findsOneWidget,
    );
    expect(find.text('Mishnah Berakhot 1:2'), findsOneWidget);
    expect(find.text('1 ticked'), findsOneWidget, reason: 'distinct leaves');
    expect(find.text('Capacity vs Path'), findsOneWidget);
    expect(
      find.text('${engine.remainingPath.length} / ${engine.capacity}'),
      findsOneWidget,
      reason: 'the engine values, not recomputed',
    );
    expect(
      find.text(
        'Remaining path: ${engine.remainingPath.length} · '
        'Total capacity: ${engine.capacity}',
      ),
      findsOneWidget,
    );
    expect(find.text('Ground (in order)'), findsOneWidget);
    final berakhotRow = tester.getTopLeft(
      find.byKey(const ValueKey('subTrackGroundRow:0:Mishnah Berakhot 1')),
    );
    final peahRow = tester.getTopLeft(
      find.byKey(const ValueKey('subTrackGroundRow:0:Mishnah Peah')),
    );
    expect(berakhotRow.dy, lessThan(peahRow.dy), reason: 'stored order');
  });

  testWidgets('an open window reads "From {start}"', (tester) async {
    final open = detailSubTrack(20, 'Rebbe', const [peah]);
    h.seed(subTracks: [open]);
    await pump(tester, id: open.id);
    expect(find.text('From Sep 2026'), findsOneWidget);
  });

  testWidgets('"Up next" is none when every ground leaf is ticked here', (
    tester,
  ) async {
    final small = detailSubTrack(30, 'Peah', const [peah]);
    h.seed(
      subTracks: [small],
      learnEvents: [
        engineLearn(1, 'Mishnah Peah 1:1', source: small.id),
        engineLearn(2, 'Mishnah Peah 1:2', source: small.id),
      ],
    );
    await pump(tester, id: small.id);
    expect(find.text('All ground ticked'), findsOneWidget);
    expect(find.text('2 ticked'), findsOneWidget);
  });

  testWidgets('a leaf label opens the Story 1.13 history route', (
    tester,
  ) async {
    h.seed(subTracks: [school]);
    await pump(tester);
    for (final ref in ['Mishnah Peah', 'Mishnah Peah 1', 'Mishnah Peah 1:2']) {
      final label = find.byKey(ValueKey('subTrackGroundLabel:$ref'));
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      await tester.tap(label);
      await tester.pumpAndSettle();
    }
    final pushed =
        verify(() => router.push<Object?>(captureAny())).captured.single
            as MishnaHistoryRoute;
    expect(pushed.args!.curriculumId, engineCurriculum);
    expect(pushed.args!.leafRef, 'Mishnah Peah 1:2');
  });

  testWidgets('a load failure shows AppErrorView; retry refreshes the '
      'provider', (tester) async {
    h.seed(subTracks: [school]);
    var runs = 0;
    await pump(
      tester,
      engine: () {
        runs++;
        return runs == 1
            ? Stream<LearnerState>.error(StateError('offline'))
            : Stream.value(engineDetailState(school));
      },
    );
    expect(find.byType(AppErrorView), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorView), findsNothing);
    expect(find.text('Ground (in order)'), findsOneWidget);
    expect(runs, 2);
  });

  group('⋮ actions', () {
    final launched = <String>[];
    final launcher = [
      subTrackFormLauncherProvider.overrideWithValue(
        (context, track) async => launched.add(track.id),
      ),
      subTrackFormTypesProvider.overrideWithValue(SubTrackType.values.toSet()),
    ];
    setUp(launched.clear);

    testWidgets('the parent edits metadata from ⋮ → Edit', (tester) async {
      h.seed(subTracks: [school]);
      await pump(tester, extra: launcher);
      await tester.tap(find.byKey(const ValueKey('subTrackDetailMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(launched, [school.id]);
    });

    testWidgets('the menu is hidden while no action applies (the ongoing '
        'form is DNI-496, so Edit has no form to open yet)', (tester) async {
      h.seed(subTracks: [school]);
      await pump(tester);
      expect(find.byKey(const ValueKey('subTrackDetailMenu')), findsNothing);
    });
  });

  testWidgets('the child is read-only: no drag handles, no ⋮ edit, delete or '
      'remove, and no judgemental copy (AC-7)', (tester) async {
    h
      ..seed(subTracks: [school])
      ..capacities[school.id] = (capacity: 2, shortfall: 2);
    await pump(
      tester,
      role: SubTrackDetailRole.child,
      extra: [
        subTrackFormLauncherProvider.overrideWithValue(
          (context, track) async {},
        ),
        subTrackFormTypesProvider.overrideWithValue(
          SubTrackType.values.toSet(),
        ),
      ],
    );
    expect(find.text('Ground (in order)'), findsOneWidget);
    expect(find.byKey(const ValueKey('subTrackDetailMenu')), findsNothing);
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text('Edit'), findsNothing);
    for (final word in [
      'Remove',
      'Delete',
      'Move',
      'Shortfall',
      'behind',
      'Behind',
      'late',
      'off track',
      'short',
    ]) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
  });
}
