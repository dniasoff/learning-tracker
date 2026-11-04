/// Riverpod access to the learner-state engine (AD-35), keyed by
/// [LearnerScope] (ruling B10).
///
/// C0 (DNI-524) fixed the names and types; DNI-474 (1.12) fills
/// [learnerStateProvider] and [corporaProvider]. Owner UI reads
/// [activeLearnerStateProvider]. DNI-523's `learnerStateForScopeProvider`
/// adds only grant validation on top of [learnerStateProvider].
///
/// Every progress number, tri-state and siyum on the progress, lifetime and
/// Browse surfaces reads this one state (AD-35 "Reads"); no screen queries
/// `learning_events` itself.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderBase;
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/calendar_plan.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_calendar_loader.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_composition.dart';

/// The pure engine.
final learnerStateEngineProvider = Provider<LearnerStateEngine>(
  (ref) => const LearnerStateEngine(),
);

/// The unscoped ContentIndex corpora by curriculum id (AD-42): every
/// curriculum's bundled hierarchy, through [contentIndexCorpus]. Built once
/// and kept for the app's lifetime, like `contentIndexProvider`.
final corporaProvider = FutureProvider<Map<String, Corpus>>((ref) async {
  final out = <String, Corpus>{};
  for (final curriculum in CurriculumId.all) {
    final items = await ref.watch(curriculumContentProvider(curriculum).future);
    final config = await ref.watch(
      curriculumHierarchyConfigProvider(curriculum).future,
    );
    out[curriculum.storageKey] = contentIndexCorpus(
      curriculumId: curriculum.storageKey,
      items: items,
      levelLabels: config.levelLabels,
    );
  }
  return Map.unmodifiable(out);
}, retry: (retryCount, error) => null);

/// The calendar input loader [learnerStateProvider] passes to the
/// composition (AD-35: calendars are loaded by the provider from
/// `CalendarProgramService` and passed in as data). Overridden in tests.
final learnerCalendarLoaderProvider = Provider<LearnerCalendarLoader>((ref) {
  return (intent, settingsHistory, nowUtc) async {
    if (!intent.mainTracks.values.any(followsCalendarProgram)) {
      return const {};
    }
    final service = await ref.read(calendarProgramServiceProvider.future);
    final corpora = await ref.read(corporaProvider.future);
    return loadLearnerCalendars(
      intent: intent,
      settingsHistory: settingsHistory,
      nowUtc: nowUtc,
      corpora: corpora,
      entriesForRange: service.getEntriesForRange,
      itemsFor: (curriculumId) async {
        final curriculum = CurriculumId.fromStorageKey(curriculumId);
        if (curriculum == null) return const [];
        return ref.read(curriculumContentProvider(curriculum).future);
      },
    );
  };
});

/// Fires at each local midnight while watched, so "today" in the engine
/// (AD-41) moves on without an input change.
final learnerStateDayTickProvider = Provider.autoDispose<Stream<void>>((ref) {
  final clock = ref.watch(localDayClockProvider);
  final controller = StreamController<void>.broadcast();
  Timer? timer;
  void schedule() {
    final now = clock.nowUtc().toLocal();
    final next = DateTime(now.year, now.month, now.day + 1);
    timer = Timer(next.difference(now), () {
      controller.add(null);
      schedule();
    });
  }

  schedule();
  ref.onDispose(() {
    timer?.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});

/// The [LearnerState] of [LearnerScope], recomputed whenever a complete
/// input changes (DNI-474 AC-1).
///
/// Loading while the account is not ready, while the corpora load, and
/// while any source is still paging (never a partial state). A read or
/// engine failure is an `AsyncError`; [retryLearnerState] re-reads every
/// dependency.
final learnerStateProvider = StreamProvider.autoDispose
    .family<LearnerState, LearnerScope>((ref, scope) async* {
      final events = await ref.watch(learningEventRepositoryProvider.future);
      final subTracks = await ref.watch(subTrackRepositoryProvider.future);
      final changeLog = await ref.watch(changeLogRepositoryProvider.future);
      final intent = await ref.watch(governedIntentRepositoryProvider.future);
      if (events == null ||
          subTracks == null ||
          changeLog == null ||
          intent == null) {
        return; // not ready: loading
      }
      final corpora = await ref.watch(corporaProvider.future);
      final clock = ref.watch(localDayClockProvider);
      yield* composeLearnerState(
        events: events.watchAll(scope),
        subTracks: subTracks.watchAll(scope),
        intentHistory: changeLog.watchIntentHistory(scope),
        intent: intent.watch(scope),
        corpora: corpora,
        loadCalendars: ref.watch(learnerCalendarLoaderProvider),
        nowUtc: clock.nowUtc,
        recompute: ref.watch(learnerStateDayTickProvider),
        engine: ref.watch(learnerStateEngineProvider),
      );
    }, retry: (retryCount, error) => null);

/// The active learner's state: `AsyncData(null)` while no learner is
/// active, otherwise [learnerStateProvider] for [activeLearnerScopeProvider].
/// A scope error is forwarded; a scope still resolving is loading.
final activeLearnerStateProvider =
    Provider.autoDispose<AsyncValue<LearnerState?>>((ref) {
      final scope = ref.watch(activeLearnerScopeProvider);
      if (scope case AsyncError(:final error, :final stackTrace)) {
        return AsyncError<LearnerState?>(error, stackTrace);
      }
      if (!scope.hasValue) return const AsyncLoading<LearnerState?>();
      final active = scope.requireValue;
      if (active == null) return const AsyncData<LearnerState?>(null);
      return ref.watch(learnerStateProvider(active));
    });

/// Re-reads every dependency of the active learner's state after a failure:
/// the scope, the repositories, the corpora, the calendar inputs and the
/// composition itself (DNI-474 AC-1: retry re-reads the failed dependency
/// and can recover).
///
/// The kept-alive inputs — the corpora, the content items and hierarchy
/// configs they are built from, and the content database the calendar
/// service reads — are re-read only when they failed, so a working corpus
/// set or open database is never rebuilt. The calendar loader reads its
/// inputs with `ref.read`, so a failure there is not cleared by
/// invalidating [learnerStateProvider]; it must be invalidated here.
void retryLearnerState(WidgetRef ref) {
  ref
    ..invalidate(activeLearnerScopeProvider)
    ..invalidate(learningEventRepositoryProvider)
    ..invalidate(subTrackRepositoryProvider)
    ..invalidate(changeLogRepositoryProvider)
    ..invalidate(governedIntentRepositoryProvider)
    ..invalidate(learnerStateProvider);
  for (final curriculum in CurriculumId.all) {
    _reReadIfFailed(ref, curriculumContentProvider(curriculum));
    _reReadIfFailed(ref, curriculumHierarchyConfigProvider(curriculum));
  }
  _reReadIfFailed(ref, corporaProvider);
  _reReadIfFailed(ref, contentDbPathProvider);
  _reReadIfFailed(ref, contentDatabaseProvider);
  _reReadIfFailed(ref, localCalendarEngineProvider);
  _reReadIfFailed(ref, calendarProgramServiceProvider);
}

/// Invalidates [provider] when it was built and holds an error. A provider
/// never built is left alone (reading it would start it).
void _reReadIfFailed(
  WidgetRef ref,
  ProviderBase<AsyncValue<Object?>> provider,
) {
  if (ref.exists(provider) && ref.read(provider).hasError) {
    ref.invalidate(provider);
  }
}
