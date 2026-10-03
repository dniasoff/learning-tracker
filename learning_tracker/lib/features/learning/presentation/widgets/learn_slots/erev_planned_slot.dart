/// Learn-tab slot for the erev planned-day sections, between today's tasks
/// and "Also learning" (DNI-504 AC-1 order).
///
/// Same path and name as the slot DNI-500 introduces for this region
/// (merge-hotspot ruling), so that story's empty slot and this filled one
/// reconcile to this file.
///
/// Zero size outside the erev window. Inside it, one [PlannedDaySection]
/// per locked day that has planned rows; a day with none shows no section
/// and the banner stays (AC-7). The planned data's loading and error
/// states stay inside this region with an inline retry that re-reads only
/// the erev data (AC-10): today's list above is never gated by it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/features/learning/presentation/providers/erev_planned_tasks_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/planned_day_section.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';

/// The erev planned slot.
class ErevPlannedSlot extends ConsumerStatefulWidget {
  /// Creates the slot.
  const ErevPlannedSlot({super.key});

  /// Gap above the region when it renders.
  static const double topSpacing = 36;

  @override
  ConsumerState<ErevPlannedSlot> createState() => _ErevPlannedSlotState();
}

class _ErevPlannedSlotState extends ConsumerState<ErevPlannedSlot> {
  /// Rows recorded here that the live plan still lists (it drops them as
  /// soon as the learner state recomputes).
  final _recorded = <ErevRowKey>{};

  /// Rows whose capture is in flight: marked before the first await so a
  /// second tap (even one landing before the next frame, on the old
  /// callback) records nothing twice, and shown disabled until the
  /// capture settles. A capture that was not saved frees its rows for a
  /// deliberate retry.
  final _inFlight = <ErevRowKey>{};

  Future<void> _record(List<DailyTask> rows) async {
    final fresh = [
      for (final t in rows)
        if (!_inFlight.contains(erevRowKey(t)) &&
            !_recorded.contains(erevRowKey(t)))
          t,
    ];
    if (fresh.isEmpty) return;
    final keys = {for (final t in fresh) erevRowKey(t)};
    setState(() => _inFlight.addAll(keys));
    try {
      await recordErevTasks(
        context,
        ref,
        fresh,
        onRecorded: (keys) {
          if (mounted) setState(() => _recorded.addAll(keys));
        },
        onUndone: (keys) {
          if (mounted) setState(() => _recorded.removeAll(keys));
        },
      );
    } finally {
      if (mounted) {
        setState(() => _inFlight.removeAll(keys));
      } else {
        _inFlight.removeAll(keys);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final window = ref.watch(erevWindowProvider).asData?.value;
    if (window == null) return const SizedBox.shrink();
    final planned = ref.watch(erevPlannedDaysProvider);
    final enabled = ref.watch(learningCommandsProvider).asData?.value != null;
    final Widget body;
    if (planned.hasError) {
      body = Align(
        key: const ValueKey('erevPlannedError'),
        alignment: AlignmentDirectional.centerStart,
        child: InlineAsyncError(
          error: planned.error!,
          onRetry: () => ref.invalidate(erevPlannedDaysProvider),
        ),
      );
    } else if (!planned.hasValue) {
      body = const Padding(
        key: ValueKey('erevPlannedLoading'),
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      final value = planned.value;
      if (value == null) return const SizedBox.shrink();
      // Forget rows the live plan no longer lists.
      final listed = {for (final d in value) ...d.tasks.map(erevRowKey)};
      _recorded.removeWhere((k) => !listed.contains(k));
      final days = [
        for (final d in value)
          if (d.tasks.isNotEmpty) d,
      ];
      if (days.isEmpty) return const SizedBox.shrink();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, day) in days.indexed) ...[
            if (i > 0) const SizedBox(height: 24),
            PlannedDaySection(
              day: day,
              recorded: _recorded,
              inFlight: _inFlight,
              enabled: enabled,
              onRecord: _record,
            ),
          ],
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: ErevPlannedSlot.topSpacing),
      child: body,
    );
  }
}
