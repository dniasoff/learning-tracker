// Mirror test for
// `lib/features/sub_tracks/presentation/providers/sub_track_detail_actions.dart`
// (DNI-497): the ⋮ registry, hub selection, the hub-row tap and the
// no-deadline link's goal setup.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_actions.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_goal_setup_flow.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/pump_app.dart';
import '../../sub_track_detail_harness.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo<Object?> {}

/// [track] as a school-year sub-track (the fixture is ongoing).
SubTrack _schoolYear(SubTrack track) => SubTrack(
  id: track.id,
  curriculumId: track.curriculumId,
  name: track.name,
  type: SubTrackType.schoolYear,
  academicYear: 2026,
  windowStart: track.windowStart,
  windowEnd: '2027-06-30',
  ratePerWeek: track.ratePerWeek,
  weeksPerYear: track.weeksPerYear,
  learnsOnShabbos: track.learnsOnShabbos,
  ground: track.ground,
  lastChangeId: track.lastChangeId,
);

void main() {
  setUpAll(() => registerFallbackValue(_FakePageRouteInfo()));

  final school = detailSubTrack(10, 'School', const [peah]);

  group('⋮ registry', () {
    test('Edit opens the metadata form by default, for both sub-track types '
        '(school year, DNI-495; ongoing, DNI-496)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(subTrackFormLauncherProvider), isNotNull);
      final edit = c.read(subTrackDetailMenuActionsProvider).first;
      expect(edit.id, 'edit');
      expect(edit.visibleFor(engineDetail(_schoolYear(school))), isTrue);
      expect(edit.visibleFor(engineDetail(school)), isTrue, reason: 'ongoing');
    });

    test('a bound launcher adds Edit, visible to the parent on a live '
        'sub-track only', () {
      final c = ProviderContainer(
        overrides: [
          subTrackFormLauncherProvider.overrideWithValue(
            (context, track) async {},
          ),
          subTrackFormTypesProvider.overrideWithValue(
            SubTrackType.values.toSet(),
          ),
        ],
      );
      addTearDown(c.dispose);
      final edit = c.read(subTrackDetailMenuActionsProvider).first;
      expect(edit.id, 'edit');
      expect(edit.visibleFor(engineDetail(school)), isTrue);
      for (final role in [SubTrackDetailRole.child, SubTrackDetailRole.tutor]) {
        expect(edit.visibleFor(engineDetail(school, role: role)), isFalse);
      }
      final ended = detailSubTrack(11, 'Old', const [peah], ended: true);
      expect(edit.visibleFor(engineDetail(ended)), isFalse);
    });

    test('no launcher: no Edit', () {
      final c = ProviderContainer(
        overrides: [subTrackFormLauncherProvider.overrideWithValue(null)],
      );
      addTearDown(c.dispose);
      expect(
        c.read(subTrackDetailMenuActionsProvider).map((a) => a.id),
        isNot(contains('edit')),
      );
    });

    test('DNI-499 registers End and Delete after Edit, for the parent on a '
        'sub-track that is not ended (tombstoned or past its window)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final actions = c.read(subTrackDetailMenuActionsProvider);
      expect([for (final a in actions) a.id], ['edit', 'end', 'delete']);
      for (final action in actions.skip(1)) {
        expect(action.visibleFor(engineDetail(school)), isTrue);
        for (final role in [
          SubTrackDetailRole.child,
          SubTrackDetailRole.tutor,
        ]) {
          expect(
            action.visibleFor(engineDetail(school, role: role)),
            isFalse,
            reason: '${action.id} for ${role.name}',
          );
        }
        final ended = detailSubTrack(11, 'Old', const [peah], ended: true);
        expect(action.visibleFor(engineDetail(ended)), isFalse);
      }
    });

    testWidgets('the default launcher pushes the school-year form for that '
        'sub-track (UX-DR-53)', (tester) async {
      final router = _MockStackRouter();
      when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
      final track = _schoolYear(school);
      await tester.pumpWidget(
        pumpApp(
          child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => openSubTrackForm(context, track),
                child: const Text('edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('edit'));
      final pushed =
          verify(() => router.push<Object?>(captureAny())).captured.single
              as SchoolYearSubTrackFormRoute;
      expect(pushed.args!.curriculumId, engineCurriculum);
      expect(pushed.args!.subTrackId, track.id);
    });
  });

  group('openSubTrackDetail', () {
    late _MockStackRouter router;
    setUp(() {
      router = _MockStackRouter();
      when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
    });

    Future<ProviderContainer> pumpRow(
      WidgetTester tester, {
      required bool split,
    }) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final row = Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => openSubTrackDetail(context, ref, school.id),
          child: const Text('row'),
        ),
      );
      await tester.pumpWidget(
        pumpApp(
          container: container,
          child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: split ? SubTrackSplitScope(child: row) : row,
          ),
        ),
      );
      await tester.tap(find.text('row'));
      return container;
    }

    testWidgets('on a phone it selects and pushes the detail route (AC-1)', (
      tester,
    ) async {
      final container = await pumpRow(tester, split: false);
      final pushed =
          verify(() => router.push<Object?>(captureAny())).captured.single
              as SubTrackDetailRoute;
      expect(pushed.args!.subTrackId, school.id);
      expect(container.read(subTrackHubSelectionProvider), school.id);
    });

    testWidgets('inside a split it only selects (the pane updates in place)', (
      tester,
    ) async {
      final container = await pumpRow(tester, split: true);
      verifyNever(() => router.push<Object?>(any()));
      expect(container.read(subTrackHubSelectionProvider), school.id);
    });
  });

  group('openSubTrackDeadlineSetup (AC-2, Story 2.4 link)', () {
    Future<List<CurriculumId>> tapLink(
      WidgetTester tester,
      List<SubTrackGoalSetupOutcome> outcomes,
    ) async {
      final opened = <CurriculumId>[];
      final pending = [...outcomes];
      await tester.pumpWidget(
        pumpApp(
          overrides: [
            subTrackGoalSetupLauncherProvider.overrideWithValue((
              context,
              ref,
              curriculum,
            ) async {
              opened.add(curriculum);
              return pending.removeAt(0);
            }),
          ],
          child: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => ref.read(subTrackDeadlineSetupProvider)!(
                  context,
                  ref,
                  engineCurriculum,
                ),
                child: const Text('link'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('link'));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('is bound by default and opens the curriculum goal setup; a '
        'saved goal is confirmed', (tester) async {
      final opened = await tapLink(tester, [SubTrackGoalSetupOutcome.saved]);
      expect(opened, [CurriculumId.fromStorageKey(engineCurriculum)]);
      expect(find.text('Goal saved'), findsOneWidget);
    });

    testWidgets('a failed save reports it with a retry that reopens the '
        'goal setup', (tester) async {
      final opened = await tapLink(tester, [
        SubTrackGoalSetupOutcome.failed,
        SubTrackGoalSetupOutcome.cancelled,
      ]);
      expect(opened, hasLength(1));
      expect(find.text("Couldn't save the goal."), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(opened, hasLength(2));
    });

    testWidgets('a cancelled setup shows nothing', (tester) async {
      await tapLink(tester, [SubTrackGoalSetupOutcome.cancelled]);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  test('the selection survives until cleared', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(subTrackHubSelectionProvider.notifier).select(school.id);
    expect(c.read(subTrackHubSelectionProvider), school.id);
    c.read(subTrackHubSelectionProvider.notifier).clear();
    expect(c.read(subTrackHubSelectionProvider), isNull);
  });
}
