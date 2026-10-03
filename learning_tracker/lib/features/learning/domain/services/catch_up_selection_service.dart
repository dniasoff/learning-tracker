/// Builds, edits and submits the *Adjust…* selection of a catch-up card
/// (Story 3.4, DNI-507; AD-33, AD-40).
///
/// Pure Dart. Nothing here plans or positions anything (AD-33):
///
/// * the rows and their default ticks come from the pending card, which
///   is Story 3.2's planner output (DNI-505) — never a recomputed amount;
/// * the leaves *Up to…* can add come from the track order the shared Up
///   to… picker reads from the engine (Story 2.10, DNI-501): a sub-track's
///   remaining path, or the main track's schedulable leaves;
/// * the write is Story 3.3's `CatchUpAction` (DNI-506) with
///   [CatchUpMode.adjusted]; the command owns the window, events, points,
///   chunking and analytics.
///
/// Earliest-day ownership (AC-5) is [CatchUpSelection.view]; this service
/// only feeds it and reads it.
library;

import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/catch_up_commands.dart';
import 'package:learning_tracker/features/learning/domain/models/catch_up_selection.dart';

/// The selection [card] opens with (AC-1): one section per covered locked
/// day that plans something (at most three, ascending), and per
/// curriculum the main track's planner rows then each sub-track's planned
/// leaves, every row ticked.
///
/// [refOf] and [stageOf] read a main-track task's leaf and planner stage;
/// [isNewLearning] tells which tasks set a main group's
/// [CatchUpGroupSelection.extensionStage] (all, by default). A leaf the
/// planner lists twice for one day and source is one row.
CatchUpSelection catchUpSelectionOf<T>(
  CatchUpCard<T> card, {
  required LeafRef Function(T task) refOf,
  required int? Function(T task) stageOf,
  bool Function(T task)? isNewLearning,
}) {
  final days = <CatchUpDaySelection>[];
  for (final day in card.window.lockedDays) {
    final groups = <CatchUpGroupSelection>[];
    for (final c in card.groups) {
      for (final d in c.days) {
        if (d.day.date != day.date) continue;
        if (d.mainTasks.isNotEmpty) {
          final rows = <CatchUpRow>[];
          final seen = <LeafRef>{};
          int? extensionStage;
          for (final task in d.mainTasks) {
            final ref = refOf(task);
            final stage = stageOf(task);
            if (extensionStage == null && (isNewLearning?.call(task) ?? true)) {
              extensionStage = stage;
            }
            if (seen.add(ref)) {
              rows.add(CatchUpRow(ref, stage: stage, planned: true));
            }
          }
          extensionStage ??= rows.first.stage;
          groups.add(
            CatchUpGroupSelection(
              key: CatchUpGroupKey(
                curriculumId: c.curriculumId,
                source: LearningEvent.sourceMain,
                learnedOn: day.date,
              ),
              rows: rows,
              included: seen,
              extensionStage: extensionStage,
            ),
          );
        }
        for (final plan in d.subTracks) {
          final refs = <LeafRef>{...plan.leaves};
          groups.add(
            CatchUpGroupSelection(
              key: CatchUpGroupKey(
                curriculumId: c.curriculumId,
                source: plan.subTrackId,
                learnedOn: day.date,
              ),
              subTrackName: plan.name,
              rows: [for (final r in refs) CatchUpRow(r, planned: true)],
              included: refs,
            ),
          );
        }
      }
    }
    if (groups.isNotEmpty) {
      days.add(CatchUpDaySelection(day: day, groups: groups));
    }
  }
  return CatchUpSelection(days);
}

/// The rows the shared Up to… picker shows for one group (AC-2).
final class CatchUpPickerRows {
  /// Creates the rows.
  CatchUpPickerRows({
    required this.key,
    required List<CatchUpRow> rows,
    required Set<LeafRef> recorded,
    required List<LeafRef> included,
  }) : rows = List.unmodifiable(rows),
       recorded = Set.unmodifiable(recorded),
       included = List.unmodifiable(included);

  /// The group they belong to.
  final CatchUpGroupKey key;

  /// From the group's first planned leaf: its planned rows, then every
  /// later leaf of the track's order. Leaves an earlier section shows are
  /// left out (AC-5).
  final List<CatchUpRow> rows;

  /// Leaves of [rows] already ticked in this track: shown, never
  /// selectable.
  final Set<LeafRef> recorded;

  /// The leaves the group ticks now, in [rows] order: the picker opens
  /// with them included.
  final List<LeafRef> included;

  /// Whether any row can be ticked in the picker.
  bool get selectable => rows.any((r) => !recorded.contains(r.ref));

  /// Whether the track has a leaf after the planned ones that could still
  /// be included (AC-6: false shows "No more … in this track's ground"
  /// and disables *Up to…*).
  bool get hasFurther =>
      rows.any((r) => !r.planned && !recorded.contains(r.ref));
}

/// The picker rows of [key]'s group in [selection] (AC-2), or null for an
/// unknown group.
///
/// [trackOrder] is the track's order from its position, as the shared
/// picker reads it from the engine; [recorded] are its leaves already
/// ticked in this track (or pending on this device). The rows start at the
/// group's first planned leaf: its planned rows, then the leaves of
/// [trackOrder] after the last planned leaf found in it (all of
/// [trackOrder] when none is), skipping planned leaves and leaves an
/// earlier section shows. A main-track leaf added this way carries the
/// group's [CatchUpGroupSelection.extensionStage].
CatchUpPickerRows? catchUpPickerRows(
  CatchUpSelection selection,
  CatchUpGroupKey key, {
  required List<LeafRef> trackOrder,
  Set<LeafRef> recorded = const {},
}) {
  for (final day in selection.view) {
    for (final g in day.groups) {
      if (g.key != key) continue;
      final planned = g.group.plannedRows;
      final plannedRefs = {for (final r in planned) r.ref};
      var last = -1;
      for (var i = 0; i < trackOrder.length; i++) {
        if (plannedRefs.contains(trackOrder[i])) last = i;
      }
      final stage = key.isMain ? g.group.extensionStage : null;
      final rows = <CatchUpRow>[
        for (final r in planned)
          if (!g.claimedEarlier.contains(r.ref)) r,
        for (final ref in trackOrder.skip(last + 1))
          if (!plannedRefs.contains(ref) && !g.claimedEarlier.contains(ref))
            CatchUpRow(ref, stage: stage),
      ];
      final unique = <LeafRef>{};
      final deduped = [
        for (final r in rows)
          if (unique.add(r.ref)) r,
      ];
      return CatchUpPickerRows(
        key: key,
        rows: deduped,
        recorded: {
          for (final r in deduped)
            if (recorded.contains(r.ref) && !r.planned) r.ref,
        },
        included: [
          for (final r in deduped)
            if (g.isIncluded(r.ref)) r.ref,
        ],
      );
    }
  }
  return null;
}

/// [selection] with [picker]'s group set to what the picker confirmed
/// (AC-2): the run is every picker row through the last included one, of
/// which only [includedRefs] stay ticked. The group keeps all its planned
/// rows (a planned row past the run is shown unticked); *Up to…* rows past
/// the run are dropped. Every other group is untouched, and nothing is
/// written.
CatchUpSelection applyCatchUpPicker(
  CatchUpSelection selection,
  CatchUpPickerRows picker,
  List<LeafRef> includedRefs,
) {
  final group = selection.group(picker.key);
  if (group == null) return selection;
  final chosen = includedRefs.toSet();
  var target = -1;
  for (var i = 0; i < picker.rows.length; i++) {
    if (chosen.contains(picker.rows[i].ref)) target = i;
  }
  final added = [
    for (final r in picker.rows.take(target + 1))
      if (!r.planned && !picker.recorded.contains(r.ref)) r,
  ];
  final pickerRefs = {for (final r in picker.rows) r.ref};
  return selection.replace(
    group.copyWith(
      rows: [...group.plannedRows, ...added],
      included: {
        // Rows the picker did not show (an earlier section owns them) keep
        // their stored tick; the picker decides every row it showed.
        for (final ref in group.included)
          if (!pickerRefs.contains(ref)) ref,
        for (final r in picker.rows)
          if (chosen.contains(r.ref) && !picker.recorded.contains(r.ref)) r.ref,
      },
    ),
  );
}

/// The *Record {n}* action of [selection] for [window] (AC-3), or null
/// when nothing is ticked (AC-4: an empty selection never reaches the
/// command).
///
/// One [CatchUpLeaf] per ticked row of [CatchUpSelection.view] — so a leaf
/// is recorded once, on the earliest day that shows it (AC-5) — dated to
/// its section's locked day, with its source, and its stage on the main
/// track only. Order is card order: curriculum, then day, then the main
/// track before sub-tracks.
CatchUpAction? catchUpAdjustedAction(
  CatchUpSelection selection,
  CatchUpCardWindow window,
) {
  final byCurriculum = <String, List<CatchUpLeaf>>{};
  for (final day in selection.view) {
    for (final g in day.groups) {
      for (final r in g.includedRows) {
        (byCurriculum[g.key.curriculumId] ??= []).add(
          CatchUpLeaf(
            curriculumId: g.key.curriculumId,
            ref: r.ref,
            source: g.key.source,
            learnedOn: day.day.date,
            stage: g.key.isMain ? r.stage : null,
          ),
        );
      }
    }
  }
  final leaves = [for (final l in byCurriculum.values) ...l];
  if (leaves.isEmpty) return null;
  return CatchUpAction(
    lock: window.lock,
    mode: CatchUpMode.adjusted,
    lockedDaysOffered: window.lockedDays.length,
    leaves: leaves,
  );
}
