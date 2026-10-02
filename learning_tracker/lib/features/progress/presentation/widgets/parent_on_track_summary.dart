/// The parent Dashboard's on-track summary (Story 5.3, DNI-518, AC-11;
/// FR-18; UX-DR-23, UX-DR-24, UX-DR-94, UX-DR-95, UX-DR-157).
///
/// AC-11 needs the Dashboard and the lifetime report to show one status,
/// projected finish and daily target for one `LearnerState`. This widget
/// is the Dashboard consumer of that state: for each active curriculum it
/// reads the curriculum's [CurriculumState] from the one shared learner
/// state ([activeLearnerStateProvider], the state the report reads), maps
/// it with the report's own [OnTrackView.of], and paints it with the
/// report's own [OnTrackReportBlock]. Nothing here computes a status,
/// projection or target, so the two surfaces cannot drift.
///
/// Parent only (UX-DR-48, NFR-9): outside a parent session (a child
/// without the parent PIN, or a tutor) it paints nothing and reads no
/// learner state. A curriculum the engine does not evaluate, or one with
/// no projection, gets no card.
///
/// Seam: Story 2.11 (DNI-502, bead fyh.44) owns the full Dashboard
/// on-track card (deadline suffix, "All covered", shortfall cards with
/// *View {name}*, child encouragement). It replaces or extends this
/// widget, keeping [OnTrackView.of] as its mapping; the AC-11 parity test
/// (lifetime_report_dashboard_parity_test.dart) then covers its card.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/pace_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/on_track_report_block.dart';

/// One on-track card per active curriculum, in [curricula] order, for a
/// parent session; nothing otherwise.
class ParentOnTrackSummary extends ConsumerWidget {
  /// Creates the summary for the Dashboard's active [curricula].
  const ParentOnTrackSummary({super.key, required this.curricula});

  /// The Dashboard's active curricula, in display order.
  final List<CurriculumId> curricula;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (curricula.isEmpty) return const SizedBox.shrink();
    if (ref.watch(parentSessionProvider).value != true) {
      return const SizedBox.shrink();
    }
    final learner = ref.watch(activeLearnerStateProvider).value;
    if (learner == null) return const SizedBox.shrink();
    final cards = <Widget>[
      for (final curriculum in curricula)
        if (_view(learner[curriculum.storageKey]) case final OnTrackView view)
          OnTrackReportBlock(
            key: ValueKey('dashboardOnTrack-${curriculum.storageKey}'),
            view: view,
            curriculum: curriculum,
            title: curriculumLabelText(ref, curriculum: curriculum),
            showShortfalls: false,
          ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('dashboardOnTrackSummary'),
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, card) in cards.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            card,
          ],
        ],
      ),
    );
  }

  /// The report's on-track view of [state], under the report's own rule
  /// (an evaluated curriculum with measured velocity, AC-9); null when the
  /// report would show none.
  static OnTrackView? _view(CurriculumState? state) {
    if (state == null || !state.evaluated) return null;
    if (state.report.allSources == null) return null;
    return OnTrackView.of(state, state.report);
  }
}
