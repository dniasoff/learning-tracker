/// Riverpod access to the learner-state engine (AD-35), keyed by
/// [LearnerScope] (ruling B10).
///
/// C0 (DNI-524) fixes the names and types. DNI-474 (1.12) fills
/// [learnerStateProvider] and [corporaProvider]; owner UI reads
/// [activeLearnerStateProvider]. DNI-523's `learnerStateForScopeProvider`
/// adds only grant validation on top of [learnerStateProvider].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/c0_stub.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';

/// The pure engine.
final learnerStateEngineProvider = Provider<LearnerStateEngine>(
  (ref) => const LearnerStateEngine(),
);

/// The unscoped ContentIndex corpora by curriculum id.
///
/// C0 stub, filled by DNI-474 (1.12).
final corporaProvider = FutureProvider<Map<String, Corpus>>(
  (ref) => c0Stub('DNI-474', 'corporaProvider'),
  retry: (retryCount, error) => null,
);

/// The [LearnerState] of [LearnerScope], recomputed whenever a complete
/// input changes.
///
/// C0 stub, filled by DNI-474 (1.12).
final learnerStateProvider = StreamProvider.autoDispose
    .family<LearnerState, LearnerScope>(
      (ref, scope) => c0Stub('DNI-474', 'learnerStateProvider'),
      retry: (retryCount, error) => null,
    );

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
