// DNI-494 (Story 2.3) AC-7 widget contract (NFR-5, UX-DR-86, UX-DR-102):
// when a change lands in the local cache, the engine recomputes and the
// new daily target reaches the same, still-mounted target surface within
// a few frames, with no spinner and no screen swap.
//
// The parent target surface itself is a later Epic 2 UI story; this test
// pins the contract it will read: `activeLearnerStateProvider` over
// `learnerStateProvider` (C0), fed by the real engine on every cache
// change, keeps its data through a recompute (never AsyncLoading).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/engine_fixtures.dart';

final _now = DateTime.utc(2026, 9, 7, 12);
final _subTrackId = engineUlid(800);

/// Shiur over Peah (2 leaves) at [rate] a week, against a 2026-09-13
/// deadline over the 9-leaf fixture corpus: rate 2 → target 2, rate 200 →
/// target 0 (see daily_target_test.dart, AC-5).
SubTrack _shiur(double rate) => SubTrack(
  id: _subTrackId,
  curriculumId: engineCurriculum,
  name: 'Shiur',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: rate,
  weeksPerYear: 52,
  learnsOnShabbos: false,
  ground: const [NodeEntry(level: 'masechta', ref: 'Mishnah Peah')],
  lastChangeId: engineUlid(801),
);

/// The local cache plus the engine: every change recomputes the complete
/// state and emits it, as the C0 `learnerStateProvider` does.
final class _LocalCache {
  final _states = StreamController<LearnerState>();
  List<SubTrack> _subTracks = [_shiur(2)];

  Stream<LearnerState> get states => _states.stream;

  void emit() => _states.add(
    const LearnerStateEngine().run(
      engineInputs(
        nowUtc: _now,
        subTracks: _subTracks,
        goals: {
          engineCurriculum: const CurriculumGoals(
            deadline: DeadlineGoal(
              curriculumId: engineCurriculum,
              targetDate: '2026-09-13',
            ),
          ),
        },
      ),
    ),
  );

  void setSubTracks(List<SubTrack> subTracks) {
    _subTracks = subTracks;
    emit();
  }

  Future<void> close() => _states.close();
}

/// Stand-in for the parent target surface: shows the daily target, and a
/// spinner only while there has never been a state.
class _TargetSurface extends ConsumerStatefulWidget {
  const _TargetSurface();

  @override
  ConsumerState<_TargetSurface> createState() => _TargetSurfaceState();
}

class _TargetSurfaceState extends ConsumerState<_TargetSurface> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeLearnerStateProvider);
    final value = state.value;
    if (value == null) return const CircularProgressIndicator();
    return Text('Daily target: ${value[engineCurriculum]?.dailyTarget}');
  }
}

/// Pumps frames until [text] shows, failing if any frame on the way shows
/// a spinner or no target at all, or if it takes more than a few frames
/// (the recompute is synchronous; only stream delivery and Riverpod's
/// notification are deferred).
Future<void> _pumpUntil(WidgetTester tester, String text) async {
  for (var frame = 0; frame < 4; frame++) {
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Daily target: '), findsOneWidget);
    if (find.text(text).evaluate().isNotEmpty) return;
    await tester.pump();
  }
  expect(find.text(text), findsOneWidget);
}

void main() {
  testWidgets('a rate change shows the new target on the same screen within '
      'a few frames, without a spinner', (tester) async {
    final cache = _LocalCache();
    addTearDown(() => unawaited(cache.close()));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          learnerStateProvider.overrideWith((ref, scope) => cache.states),
        ],
        child: const MaterialApp(home: Scaffold(body: _TargetSurface())),
      ),
    );
    cache.emit();
    // The scope future and the first stream event resolve over a few
    // microtask turns (the spinner animates, so no pumpAndSettle).
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('Daily target: 2'), findsOneWidget);
    final surface = tester.state(find.byType(_TargetSurface));

    cache.setSubTracks([_shiur(200)]);
    await _pumpUntil(tester, 'Daily target: 0');
    expect(tester.state(find.byType(_TargetSurface)), same(surface));

    // And back again (a further local-cache change).
    cache.setSubTracks([_shiur(2)]);
    await _pumpUntil(tester, 'Daily target: 2');
    expect(tester.state(find.byType(_TargetSurface)), same(surface));
  });
}
