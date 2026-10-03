// Mirror test for `lib/features/sub_tracks/presentation/widgets/
// sub_track_lifecycle_actions.dart` (Story 2.8 / DNI-499, AC-3, AC-4): the
// detail ⋮ entries and "return to the hub" (a pop on a phone; inside the
// tablet split, the selection clears). The full flows run on the real
// detail in `sub_track_detail_lifecycle_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_actions.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_lifecycle_actions.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/pump_app.dart';
import '../../sub_track_detail_harness.dart';

void main() {
  final live = detailSubTrack(10, 'School', const [peah]);

  test('End then Delete, labelled and iconned, parent-only on a live '
      'sub-track', () {
    final actions = subTrackLifecycleDetailMenuActions;
    expect([for (final a in actions) a.id], ['end', 'delete']);
    expect(actions.first.icon, Icons.event_busy_outlined);
    expect(actions.last.icon, Icons.delete_outline);
    for (final a in actions) {
      expect(a.visibleFor(engineDetail(live)), isTrue);
      expect(
        a.visibleFor(engineDetail(live, role: SubTrackDetailRole.child)),
        isFalse,
      );
    }
  });

  testWidgets('on a phone, returning to the hub pops the detail', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Consumer(
                    builder: (context, ref, _) => TextButton(
                      onPressed: subTrackHubReturn(context, ref.read),
                      child: const Text('back to hub'),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('open detail'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('back to hub'));
    await tester.pumpAndSettle();
    expect(find.text('open detail'), findsOneWidget);
    expect(find.text('back to hub'), findsNothing);
  });

  testWidgets('inside the tablet split, returning to the hub clears the '
      'selection and pushes or pops nothing', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      pumpApp(
        child: Scaffold(
          body: SubTrackSplitScope(
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return TextButton(
                  onPressed: subTrackHubReturn(context, ref.read),
                  child: const Text('back to hub'),
                );
              },
            ),
          ),
        ),
      ),
    );
    container.read(subTrackHubSelectionProvider.notifier).select(live.id);
    await tester.tap(find.text('back to hub'));
    await tester.pumpAndSettle();
    expect(container.read(subTrackHubSelectionProvider), isNull);
    expect(find.text('back to hub'), findsOneWidget);
  });
}
