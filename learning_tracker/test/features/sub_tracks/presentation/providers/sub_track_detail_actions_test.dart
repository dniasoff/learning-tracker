// Mirror test for
// `lib/features/sub_tracks/presentation/providers/sub_track_detail_actions.dart`
// (DNI-497): the ⋮ registry, hub selection and the hub-row tap.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_actions.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/pump_app.dart';
import '../../sub_track_detail_harness.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo<Object?> {}

void main() {
  setUpAll(() => registerFallbackValue(_FakePageRouteInfo()));

  final school = detailSubTrack(10, 'School', const [peah]);

  group('⋮ registry', () {
    test('Edit is absent until a form launcher is bound', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(subTrackDetailMenuActionsProvider), isEmpty);
    });

    test('a bound launcher adds Edit, visible to the parent on a live '
        'sub-track only', () {
      final c = ProviderContainer(
        overrides: [
          subTrackFormLauncherProvider.overrideWithValue(
            (context, track) async {},
          ),
        ],
      );
      addTearDown(c.dispose);
      final edit = c.read(subTrackDetailMenuActionsProvider).single;
      expect(edit.id, 'edit');
      expect(edit.visibleFor(engineDetail(school)), isTrue);
      for (final role in [SubTrackDetailRole.child, SubTrackDetailRole.tutor]) {
        expect(edit.visibleFor(engineDetail(school, role: role)), isFalse);
      }
      final ended = detailSubTrack(11, 'Old', const [peah], ended: true);
      expect(edit.visibleFor(engineDetail(ended)), isFalse);
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

  test('the selection survives until cleared', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(subTrackHubSelectionProvider.notifier).select(school.id);
    expect(c.read(subTrackHubSelectionProvider), school.id);
    c.read(subTrackHubSelectionProvider.notifier).clear();
    expect(c.read(subTrackHubSelectionProvider), isNull);
  });
}
