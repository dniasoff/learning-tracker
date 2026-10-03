/// The lifetime report's presentation state (Story 5.2, DNI-517; AD-35,
/// AD-48).
///
/// [lifetimeReportProvider] reads the single shared learner state of the
/// active learner ([activeLearnerStateProvider]): the engine emits it only
/// once every paged input (`learning_events`, `intent_history`, …) has
/// been read completely, so the report is loading until then and never
/// shows partial totals (AC-10). A new counted event recomputes that
/// state and the report follows it live (AC-11).
///
/// The report is a parent surface (UX-DR-153): the provider builds nothing
/// unless [parentSessionProvider] says the session is a parent's, so a
/// child or tutor context never reads a cached parent report (AC-2).
///
/// Plain Riverpod providers (no codegen), matching the C0 provider style.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';

/// The report was asked for outside a parent session.
final class LifetimeReportAccessDenied implements Exception {
  /// Creates the exception.
  const LifetimeReportAccessDenied();

  @override
  String toString() => 'LifetimeReportAccessDenied';
}

/// No learner is active, so there is no report to show.
final class LifetimeReportNoLearner implements Exception {
  /// Creates the exception.
  const LifetimeReportNoLearner();

  @override
  String toString() => 'LifetimeReportNoLearner';
}

/// The curriculum shown when the learner has no report anywhere and none
/// was asked for.
const _fallbackCurriculum = 'mishnayos';

/// The lifetime report of the active learner for the curriculum
/// [requested] (a storage key); null picks the first curriculum, in the
/// app's curriculum order, with any counted event.
///
/// The switcher lists every curriculum with a counted event, retired ones
/// included (their lifetime totals stay available, AC-9), plus [requested].
/// A curriculum without a state reads as the empty projection (AC-8).
final lifetimeReportProvider = Provider.autoDispose
    .family<AsyncValue<LifetimeReportView>, String?>((ref, requested) {
      // Fail closed: a session still resolving, or re-resolving after a
      // PIN, profile or tutor change, is not a parent's yet, even while it
      // retains an earlier `true` (AC-2).
      final access = ref.watch(parentSessionProvider);
      if (access.isLoading) return const AsyncLoading<LifetimeReportView>();
      if (access.hasError || access.value != true) {
        return AsyncError<LifetimeReportView>(
          const LifetimeReportAccessDenied(),
          StackTrace.current,
        );
      }
      // The learner identity: while it re-resolves (a profile switch) the
      // active state still serves the previous learner's scope, so nothing
      // of it is shown until the new scope settles.
      if (ref.watch(activeLearnerScopeProvider).isLoading) {
        return const AsyncLoading<LifetimeReportView>();
      }
      final state = ref.watch(activeLearnerStateProvider);
      // A retry after an error is loading again, not the old error; a
      // refresh over a complete state of this same scope keeps showing
      // that complete state.
      if (state.isLoading && !state.hasValue) {
        return const AsyncLoading<LifetimeReportView>();
      }
      if (state case AsyncError(:final error, :final stackTrace)) {
        return AsyncError<LifetimeReportView>(error, stackTrace);
      }
      if (!state.hasValue) return const AsyncLoading<LifetimeReportView>();
      final learner = state.requireValue;
      if (learner == null) {
        return AsyncError<LifetimeReportView>(
          const LifetimeReportNoLearner(),
          StackTrace.current,
        );
      }
      final withEvents = {
        for (final MapEntry(:key, :value) in learner.curricula.entries)
          if (value.report.totalEvents > 0) key,
        ?requested,
      };
      final curricula = LifetimeReportView.orderCurricula(withEvents);
      final selected =
          requested ??
          (curricula.isNotEmpty
              ? curricula.first
              : LifetimeReportView.orderCurricula(
                  learner.curricula.keys,
                ).firstOrNull) ??
          _fallbackCurriculum;
      return AsyncData(
        LifetimeReportView(
          curriculumId: selected,
          curricula: curricula.isEmpty ? [selected] : curricula,
          report: learner[selected]?.report ?? ReportProjection.empty(selected),
        ),
      );
    });

/// Re-reads every input of the report (the AppErrorView retry): the
/// session, the learner scope, the complete learner-state reads and the
/// corpora. The selected curriculum is unchanged.
void retryLifetimeReport(WidgetRef ref) {
  ref
    ..invalidate(parentSessionProvider)
    ..invalidate(activeLearnerScopeProvider)
    ..invalidate(learnerStateProvider)
    ..invalidate(corporaProvider);
}
