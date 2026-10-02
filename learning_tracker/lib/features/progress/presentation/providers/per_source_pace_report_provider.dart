/// The lifetime report's Per-source pace and On-track state (Story 5.3,
/// DNI-518; FR-18, FR-21, FR-32; AD-35, AD-48).
///
/// [perSourcePaceReportProvider] selects, for the report's curriculum,
/// the engine's report projection ([lifetimeReportProvider]) and the same
/// curriculum's [CurriculumState] from the one shared learner state
/// ([activeLearnerStateProvider]): the state the Dashboard reads too, so
/// both surfaces show one status, projected finish and daily target
/// (AC-11). It derives no total, velocity, status or shortfall.
///
/// A parent surface (UX-DR-48, NFR-9): it follows [lifetimeReportProvider],
/// which builds nothing outside a parent session, so a child or tutor
/// context never receives a velocity, status or shortfall (AC-10).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/pace_report_view.dart';

/// The Per-source pace and On-track view of the lifetime report for the
/// curriculum [requested] (as [lifetimeReportProvider]).
///
/// Loading and error follow the report itself (one paged input, one
/// state). Data null means the curriculum is not evaluated (retired,
/// archived, or its corpus is not ready): the report keeps only its
/// lifetime totals (AC-9).
final perSourcePaceReportProvider = Provider.autoDispose
    .family<AsyncValue<PaceReportView?>, String?>((ref, requested) {
      final report = ref.watch(lifetimeReportProvider(requested));
      switch (report) {
        case AsyncError(:final error, :final stackTrace):
          return AsyncError<PaceReportView?>(error, stackTrace);
        case AsyncData(:final value):
          // The report emits data only once the learner state it read is
          // complete; the curriculum's state comes from that same value.
          final learner = ref.watch(activeLearnerStateProvider).value;
          return AsyncData(
            PaceReportView.of(value, learner?[value.curriculumId]),
          );
        default:
          return const AsyncLoading<PaceReportView?>();
      }
    });
