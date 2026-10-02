/// The localized copy of a Change history undo (DNI-514 / Story 4.6):
/// field labels, "changed since by <actor>" lines and the snackbar of each
/// [UndoResult] (AC-1, AC-3, AC-8, AC-9). Copy is draft (ruling B13.8).
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/undo_result.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The label of the changed field [key], e.g. "Deadline".
String undoFieldLabel(AppLocalizations l10n, ChangedFieldKey key) {
  final entity = GovernedEntity.values
      .where((e) => e.collection == key.collection)
      .firstOrNull;
  return switch (entity) {
    GovernedEntity.goal when key.field == DeadlineGoal.kTargetDate =>
      l10n.changeHistoryUndoFieldDeadline,
    GovernedEntity.goal => l10n.changeHistoryUndoFieldGoal,
    GovernedEntity.subTrack when key.field == SubTrack.kName =>
      l10n.changeHistoryUndoFieldName,
    GovernedEntity.subTrack when key.field == SubTrack.kGround =>
      l10n.changeHistoryUndoFieldGround,
    GovernedEntity.subTrack => l10n.changeHistoryUndoFieldSubTrack,
    GovernedEntity.mainTrack => l10n.changeHistoryUndoFieldTrack,
    GovernedEntity.mainTrackOrder => l10n.changeHistoryUndoFieldOrder,
    GovernedEntity.mainTrackProgram => l10n.changeHistoryUndoFieldProgram,
    GovernedEntity.mainTrackStudyDays => l10n.changeHistoryUndoFieldStudyDays,
    GovernedEntity.mainTrackStages => l10n.changeHistoryUndoFieldStages,
    GovernedEntity.mainTrackScope => l10n.changeHistoryUndoFieldScope,
    GovernedEntity.learnerSettings => l10n.changeHistoryUndoFieldSettings,
    null => l10n.changeHistoryUndoFieldTrack,
  };
}

/// One line per changed-since field label and actor, e.g.
/// "Deadline — changed since by Rav Cohen" (AC-3). Fields sharing a label
/// and an actor are listed once.
List<String> changedSinceLines(
  AppLocalizations l10n,
  List<ChangedSinceField> fields,
) {
  final lines = <String>[];
  for (final (actor, keys) in changedSinceByActor(fields)) {
    final labels = {for (final k in keys) undoFieldLabel(l10n, k)};
    for (final label in labels) {
      final line = actor.displayName.isEmpty
          ? l10n.changeHistoryUndoChangedSinceUnknown(label)
          : l10n.changeHistoryUndoChangedSince(label, actor.displayName);
      if (!lines.contains(line)) lines.add(line);
    }
  }
  return lines;
}

/// The snackbar text of [result]; null for [UndoNotSaved], whose failure
/// the pending-failure listener announces once, with Retry (AC-9).
String? undoOutcomeMessage(AppLocalizations l10n, UndoResult result) =>
    switch (result) {
      UndoApplied(isPartial: false) => l10n.changeHistoryUndoDone,
      UndoApplied(:final changedSince) => l10n.changeHistoryUndoPartlyDone(
        changedSinceLines(l10n, changedSince).join('; '),
      ),
      UndoNothingToUndo() => l10n.changeHistoryUndoNothingToUndo,
      UndoOnlineRequired() => l10n.changeHistoryUndoOnlineRequired,
      UndoNotSaved() => null,
      UndoLocked() => l10n.captureLockedNotice,
      UndoRefused() => l10n.changeHistoryUndoNotAllowed,
    };

/// The detail lines under a "nothing to undo" or partial snackbar: who
/// changed which field since (AC-3).
List<String> undoOutcomeDetails(AppLocalizations l10n, UndoResult result) =>
    switch (result) {
      UndoNothingToUndo(:final changedSince) => changedSinceLines(
        l10n,
        changedSince,
      ),
      _ => const [],
    };
