/// The tutor-device read path for a talmid's learning state (Story 4.2a,
/// DNI-523, ruling B10).
///
/// A tutor's roster needs N learners from different parents at once, while
/// the tutored-session seam (`activeTutoredProfileSelectionProvider`)
/// handles one. [learnerStateForScopeProvider] serves any number of
/// [LearnerScope]s side by side. Per C0 (DNI-524) it adds ONLY grant
/// validation on top of [learnerStateProvider]: the same `LearnerScope`-
/// keyed repositories and engine the owner uses, addressed at
/// `users/{ownerUid}/learner_profiles/{profileId}` with the tutor's own
/// Firestore handle, which the rules authorize through
/// `hasActiveTutorAccess`. No new callable, collection, index or server
/// summary (AD-35).
///
/// Contract for consumers (DNI-511 roster rows, DNI-512 revocation):
/// - loading until the grant verdict and the state have both resolved;
/// - `AsyncData(state)` while an active grant authorizes the tutor;
/// - `AsyncError(TutorScopeAccessDeniedException)` with NO value when the
///   grant is missing, not active, the account is signed out, or a read is
///   `permission-denied`. That clears the scope's state: a revoked row never
///   shows stale numbers. While denied, [learnerStateProvider] for the scope
///   is not watched, so it is disposed and its listeners close;
/// - any other grant-listener failure is an `AsyncError` with no value
///   (fail closed); any other learner-state failure is forwarded as is.
///
/// Warm only while visible: both families are `autoDispose`, so a row that
/// scrolls away releases its listeners and its [LearnerState].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';

/// The live grant verdict for [LearnerScope], for the signed-in tutor.
/// [TutorScopeDenialReason.notSignedIn] while no account is ready.
final tutorScopeGrantProvider = StreamProvider.autoDispose
    .family<TutorScopeGrantVerdict, LearnerScope>((ref, scope) async* {
      final source = await ref.watch(tutorScopeGrantSourceProvider.future);
      if (source == null) {
        yield const TutorScopeDenied(TutorScopeDenialReason.notSignedIn);
        return;
      }
      yield* source.watch(scope);
    }, retry: (retryCount, error) => null);

/// The [LearnerState] of another owner's learner, gated on an active
/// `tutor_grants` document for the signed-in tutor. See the library doc for
/// the loading / data / error contract.
final learnerStateForScopeProvider = Provider.autoDispose
    .family<AsyncValue<LearnerState>, LearnerScope>((ref, scope) {
      final verdict = ref.watch(tutorScopeGrantProvider(scope));
      if (verdict case AsyncError(:final error, :final stackTrace)) {
        return _cleared(scope, error, stackTrace);
      }
      if (!verdict.hasValue) return const AsyncLoading<LearnerState>();
      if (verdict.requireValue case TutorScopeDenied(:final reason)) {
        return AsyncError<LearnerState>(
          TutorScopeAccessDeniedException(scope, reason),
          StackTrace.current,
        );
      }

      final state = ref.watch(learnerStateProvider(scope));
      if (state case AsyncError(
        :final error,
        :final stackTrace,
      ) when isLearnerScopeAccessDenied(error)) {
        return _cleared(scope, error, stackTrace);
      }
      return state;
    });

/// A fresh [AsyncError] that carries no previous value, mapping an
/// access-loss [error] to [TutorScopeAccessDeniedException].
AsyncValue<LearnerState> _cleared(
  LearnerScope scope,
  Object error,
  StackTrace stackTrace,
) => AsyncError<LearnerState>(
  isLearnerScopeAccessDenied(error) && error is! TutorScopeAccessDeniedException
      ? TutorScopeAccessDeniedException(
          scope,
          TutorScopeDenialReason.permissionDenied,
        )
      : error,
  stackTrace,
);
