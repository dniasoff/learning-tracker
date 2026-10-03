// Mirror test for
// `lib/features/progress/presentation/providers/lifetime_knowledge_providers.dart`
// (DNI-474: lifetime trees, totals, header counters and dual metrics read
// the engine's LearnerState only).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';
import '../../../../helpers/learner_state/provider_settle.dart';

ProviderContainer _container(
  LearnerState? state, {
  List<Override> extra = const [],
}) {
  final container = ProviderContainer.test(
    overrides: [
      ...progressOverrides(state),
      profileProgramsByProfileProvider.overrideWith((ref) async => const {}),
      ...extra,
    ],
  );
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final repeats = progressState([
    progressGround(1, 'Mishnah Peah', 'masechta'),
    progressLearn(2, 'Mishnah Peah 1:1', minutes: 1),
    progressLearn(3, 'Mishnah Berakhot 1:1', minutes: 2),
    progressLearn(4, 'Mishnah Berakhot 1:1', minutes: 3),
    progressLearn(5, 'Mishnah Shabbat 1:1', minutes: 4),
    engineVoid(6, 5, minutes: 5),
  ]);

  group('lifetimeDataProvider', () {
    test('marks the curriculum tree with the engine learnt set: repeats '
        'once, before-tracking counted, voided learning gone', () async {
      final container = _container(repeats);
      final summary = (await readFuture(
        container,
        lifetimeDataProvider(CurriculumId.mishnayos).future,
      ))!;
      expect(summary.learnedLeafCount, 3);
      expect(summary.totalLeafCount, 9);
      final zeraim = summary.tree.first;
      expect(zeraim.state, LifetimeNodeState.partial);
      expect((zeraim.learntCount, zeraim.totalCount), (3, 7));
      expect(summary.tree.last.state, LifetimeNodeState.none);
    });

    test('a curriculum with no content is skipped (null)', () async {
      final container = _container(repeats);
      expect(
        await readFuture(
          container,
          lifetimeDataProvider(CurriculumId.bavli).future,
        ),
        isNull,
      );
    });

    test('no active learner fails loudly', () async {
      final none = ProviderContainer.test(
        overrides: progressOverrides(null, learner: false),
      );
      final value = await settledAsync(
        none,
        lifetimeDataProvider(CurriculumId.mishnayos),
      );
      expect(value.error, isA<LifetimeKnowledgeNoActiveProfileException>());
    });

    test('summaries collect every curriculum with content', () async {
      final container = _container(repeats);
      final all = await readFuture(container, lifetimeSummariesProvider.future);
      expect(all.map((s) => s.curriculumId), [CurriculumId.mishnayos]);
    });
  });

  test('lifetime totals union learnt leaves across curricula', () async {
    final container = _container(repeats);
    final totals = await readFuture(
      container,
      lifetimeTotalsAcrossAllCurriculaProvider.future,
    );
    expect(totals.learnedSections, 3);
    expect(totals.totalSections, 9);
  });

  group('header counters', () {
    test('all sources: distinct learnt items and the derived chazara '
        'count', () async {
      final container = _container(repeats);
      final counters = await readFuture(
        container,
        lifetimeHeaderCountersProvider.future,
      );
      expect(counters.itemsLearned, 3);
      // Peah 1:1 after its before-tracking mark, and the Berakhot repeat.
      expect(counters.totalChazaros, 2);
    });

    test('track learning only excludes before-tracking marks', () async {
      final container = _container(repeats);
      final counters = await readFuture(
        container,
        trackOnlyHeaderCountersProvider.future,
      );
      expect(counters.itemsLearned, 2);
      expect(counters.totalChazaros, 2);
    });
  });

  test('dual progress: goal progress is the distinct learnt count over the '
      'scoped leaves; lifetime over every leaf', () async {
    final track = CurriculumTrackEntity(
      curriculumId: CurriculumId.mishnayos,
      state: CurriculumTrackState.active.storageKey,
      activatedAt: DateTime.utc(2026),
    );
    final container = _container(
      repeats,
      extra: [
        activeTracksProvider.overrideWith((ref) => Stream.value([track])),
      ],
    );
    final metrics = await readFuture(
      container,
      trackDualProgressMetricsProvider.future,
    );
    expect(metrics.single.currentCyclePercentage, closeTo(3 / 9, 1e-9));
    expect(metrics.single.lifetimePercentage, closeTo(3 / 9, 1e-9));
    expect(metrics.single.isProgramTrack, isFalse);
  });
}
