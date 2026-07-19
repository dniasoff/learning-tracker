import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/widgets/reorder_confirm_dialog.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';

/// Shared reorder-amnesty guard for the tracks reorder screens
/// (`TrackLearningOrderScreen`, `LearningOrderScreen`).
///
/// Before a reorder is applied, the guard reads the outstanding overdue
/// count for [curriculumId] and — if there are overdue items — shows
/// [ReorderConfirmDialog] and awaits the user's decision.
mixin ReorderAmnestyGuardMixin<T extends StatefulWidget> on State<T> {
  /// Runs the reorder-amnesty guard for [curriculumId].
  ///
  /// Returns `true` when the caller should proceed with the reorder (no
  /// outstanding overdue items, or the user confirmed anyway); `false` when
  /// the caller should bail out (the user declined, or this state became
  /// unmounted while either await above was in flight).
  Future<bool> confirmReorderAmnesty(
    WidgetRef ref,
    BuildContext context,
    CurriculumId curriculumId,
  ) async {
    final overdueCount = await ref.read(
      overdueCountForCurriculumProvider(curriculumId).future,
    );
    if (!context.mounted) return false;
    final confirmed = await ReorderConfirmDialog.showIfNeeded(
      context,
      overdueCount: overdueCount,
    );
    return confirmed && context.mounted;
  }
}
