/// DNI-479 (Story 1.17) AC-3: streak milestone analytics are per
/// curriculum, from the engine's `LearnerState` streak transitions, and
/// carry the `curriculum_id` enum and counts only.
///
/// The R6-3 resilience guarantees carry over: a learner-state error or an
/// analytics failure never puts the observer into an error state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/analytics/streak_milestone_analytics_observer.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

import '../../helpers/learner_state/fake_learner_state.dart';

const _profileId = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';

/// A learner state whose curricula have the given current streaks.
LearnerState _state(Map<String, int> streaks) => fakeLearnerState(
  curricula: {
    for (final MapEntry(key: c, value: n) in streaks.entries)
      c: FakeCurriculumState(
        curriculumId: c,
        streak: CurriculumStreak(current: n, best: n),
      ),
  },
);

/// The active learner state the observer sees, settable by the test.
class _ActiveState extends Notifier<AsyncValue<LearnerState?>> {
  @override
  AsyncValue<LearnerState?> build() => const AsyncLoading();

  void set(AsyncValue<LearnerState?> value) => state = value;
}

final _activeState = NotifierProvider<_ActiveState, AsyncValue<LearnerState?>>(
  _ActiveState.new,
);

class _ThrowingAnalytics extends FakeAnalyticsService {
  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) =>
      Future.error(Exception('analytics backend down'));
}

void main() {
  group('StreakMilestoneTracker', () {
    test('the first state is a baseline; nothing fires for it', () {
      final tracker = StreakMilestoneTracker();
      expect(tracker.observe(_state({'mishnayos': 40})), isEmpty);
    });

    test('fires a newly crossed milestone once per curriculum', () {
      final tracker = StreakMilestoneTracker()
        ..observe(_state({'mishnayos': 6, 'bavli': 6}));
      expect(tracker.observe(_state({'mishnayos': 7, 'bavli': 6})), [
        (curriculum: CurriculumId.mishnayos, milestone: 7),
      ]);
      // A recomputed or duplicate state never fires again.
      expect(tracker.observe(_state({'mishnayos': 7, 'bavli': 6})), isEmpty);
      // A broken and rebuilt streak in the same session does not refire.
      tracker.observe(_state({'mishnayos': 0, 'bavli': 6}));
      expect(tracker.observe(_state({'mishnayos': 7, 'bavli': 7})), [
        (curriculum: CurriculumId.bavli, milestone: 7),
      ]);
    });

    test('a jump past several milestones fires each one', () {
      final tracker = StreakMilestoneTracker()..observe(_state({'bavli': 6}));
      expect(tracker.observe(_state({'bavli': 31})), [
        (curriculum: CurriculumId.bavli, milestone: 7),
        (curriculum: CurriculumId.bavli, milestone: 30),
      ]);
    });

    test('curricula without a streak or outside CurriculumId are ignored', () {
      final tracker = StreakMilestoneTracker();
      final state = fakeLearnerState(
        curricula: {
          'mishnayos': FakeCurriculumState(curriculumId: 'mishnayos'),
          'not_a_curriculum': FakeCurriculumState(
            curriculumId: 'not_a_curriculum',
            streak: const CurriculumStreak(current: 1, best: 1),
          ),
        },
      );
      tracker.observe(state);
      expect(
        tracker.observe(
          fakeLearnerState(
            curricula: {
              'not_a_curriculum': FakeCurriculumState(
                curriculumId: 'not_a_curriculum',
                streak: const CurriculumStreak(current: 9, best: 9),
              ),
            },
          ),
        ),
        isEmpty,
      );
    });
  });

  group('streakMilestoneAnalyticsObserverProvider', () {
    ProviderContainer containerWith(AnalyticsService analytics) {
      final container = ProviderContainer(
        overrides: [
          activeProfileIdProvider.overrideWithValue(_profileId),
          analyticsServiceProvider.overrideWithValue(analytics),
          activeLearnerStateProvider.overrideWith(
            (ref) => ref.watch(_activeState),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        streakMilestoneAnalyticsObserverProvider,
        (_, __) {},
      );
      addTearDown(sub.close);
      return container;
    }

    /// Publishes each of [values] in turn, letting the observer see each.
    Future<void> push(
      ProviderContainer container,
      List<AsyncValue<LearnerState?>> values,
    ) async {
      for (final value in values) {
        container.read(_activeState.notifier).set(value);
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('emits curriculum_id and the milestone count only', () async {
      final analytics = FakeAnalyticsService();
      final container = containerWith(analytics);
      await push(container, [
        AsyncData(_state({'mishnayos': 6, 'bavli': 29})),
        AsyncData(_state({'mishnayos': 7, 'bavli': 30})),
      ]);

      final events = analytics.events
          .where((e) => e.name == AnalyticsEvent.streakMilestoneReached)
          .map((e) => e.parameters)
          .toList();
      expect(events, [
        {'curriculum_id': 'mishnayos', 'milestone': 7},
        {'curriculum_id': 'bavli', 'milestone': 30},
      ]);
    });

    test('a learner-state error is skipped, not an observer error', () async {
      final analytics = FakeAnalyticsService();
      final container = containerWith(analytics);
      await push(container, [
        AsyncData(_state({'mishnayos': 6})),
        AsyncError(StateError('engine failed'), StackTrace.empty),
        AsyncData(_state({'mishnayos': 7})),
      ]);

      expect(analytics.countOf(AnalyticsEvent.streakMilestoneReached), 1);
      expect(
        container.read(streakMilestoneAnalyticsObserverProvider).hasError,
        isFalse,
      );
    });

    test('an analytics failure is logged, not propagated', () async {
      final container = containerWith(_ThrowingAnalytics());
      await push(container, [
        AsyncData(_state({'mishnayos': 6})),
        AsyncData(_state({'mishnayos': 7})),
      ]);

      expect(
        container.read(streakMilestoneAnalyticsObserverProvider).hasError,
        isFalse,
      );
    });
  });
}
