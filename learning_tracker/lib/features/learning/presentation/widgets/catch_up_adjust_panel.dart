/// The *Adjust…* panel of a catch-up card (Story 3.4, DNI-507; screen #10,
/// UX-DR-18, UX-DR-37, UX-DR-108, UX-DR-109, UX-DR-155..157, UX-DR-160,
/// UX-DR-163..166).
///
/// It expands in place inside the card (no new route): one section per
/// locked day the card covers (at most three), each with a group per
/// source — "Home · Main track" and "{name} (learns on shabbos)" — whose
/// planned rows start ticked. The child unticks or re-ticks a row, or
/// opens the shared Up to… picker on a group to include later leaves of
/// that track. A *Record {n} …* pill carries the live count; it is
/// disabled (and announced so) at zero, while the track data loads or
/// fails, and while a record runs.
///
/// The selection ([CatchUpSelection]) lives only in this widget's state:
/// collapsing the panel drops it and writes nothing (AC-1). Record hands
/// one adjusted `CatchUpAction` to [CatchUpAdjustPanel.onRecord]; the
/// command decides everything else (Story 3.3).
///
/// The rows come from the card (the planner's output, Story 3.2) and the
/// track order from the shared picker's engine slice
/// ([upToSliceProvider], Story 2.10). Nothing here plans or positions
/// (AD-33), and there is no Firestore access (AD-23).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/features/learning/domain/commands/catch_up_commands.dart';
import 'package:learning_tracker/features/learning/domain/models/catch_up_selection.dart';
import 'package:learning_tracker/features/learning/domain/services/catch_up_selection_service.dart';
import 'package:learning_tracker/features/learning/presentation/providers/catch_up_cards_provider.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/planned_day_section.dart'
    show erevDayName;
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The opening selection of [card] (AC-1): the planner's rows, ticked.
CatchUpSelection catchUpAdjustSelectionOf(CatchUpTaskCard card) =>
    catchUpSelectionOf<DailyTask>(
      card,
      refOf: (task) => task.contentItemSefariaRef,
      stageOf: (task) => task.stageOrder,
      isNewLearning: (task) =>
          task.priority != DailyTaskPriority.overdueChazara &&
          task.priority != DailyTaskPriority.scheduledChazara,
    );

/// The in-place Adjust panel of one pending catch-up card.
class CatchUpAdjustPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const CatchUpAdjustPanel({
    super.key,
    required this.card,
    required this.onRecord,
    required this.onCollapse,
    this.recording = false,
  });

  /// The pending card.
  final CatchUpTaskCard card;

  /// Records the adjusted action; null disables Record.
  final void Function(CatchUpAction action)? onRecord;

  /// Collapses the panel, discarding the selection.
  final VoidCallback onCollapse;

  /// Whether a record action of this card is running.
  final bool recording;

  @override
  ConsumerState<CatchUpAdjustPanel> createState() => _CatchUpAdjustPanelState();
}

class _CatchUpAdjustPanelState extends ConsumerState<CatchUpAdjustPanel> {
  late CatchUpSelection _selection = catchUpAdjustSelectionOf(widget.card);

  @override
  void didUpdateWidget(CatchUpAdjustPanel old) {
    super.didUpdateWidget(old);
    // Another lock's card in the same slot starts afresh; a live update of
    // the same card keeps the child's edits.
    if (old.card.window.key != widget.card.window.key) {
      _selection = catchUpAdjustSelectionOf(widget.card);
    }
  }

  /// The Up to… request whose engine slice gives [group]'s track order;
  /// [name] titles the picker.
  UpToRequest _requestOf(CatchUpGroupSelection group, String name) =>
      group.key.isMain
      ? MainTrackUpToRequest(
          curriculumId: group.key.curriculumId,
          name: name,
          leadRefs: const [],
        )
      : SubTrackUpToRequest(
          subTrackId: group.key.source,
          curriculumId: group.key.curriculumId,
          name: group.subTrackName ?? name,
        );

  /// Opens the shared Up to… picker on [group] (AC-2): its rows from the
  /// group's first planned leaf through the end of the track's order,
  /// opening with the group's current ticks. Confirming merges the
  /// selection into [group] only; nothing is written. Dismissal (Cancel,
  /// swipe, platform back) changes nothing.
  Future<void> _openUpTo(
    CatchUpGroupSelection group,
    String name,
    CatchUpPickerRows rows,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showUpToPicker(
      context,
      request: _requestOf(group, name),
      selection: catchUpUpToSelectionOf(rows),
      confirmLabel: l10n.catchUpAdjustPickerConfirm,
    );
    if (confirmed == null || !mounted) return;
    setState(() {
      _selection = applyCatchUpPicker(_selection, rows, confirmed.includedRefs);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final curricula = {
      for (final d in _selection.days)
        for (final g in d.groups) g.key.curriculumId,
    };
    String nameOf(CatchUpGroupSelection g) => catchUpAdjustGroupLabel(
      ref,
      l10n,
      g,
      multiCurriculum: curricula.length > 1,
    );

    // The track order of every group, from the shared picker's slice.
    final slices = <CatchUpGroupKey, AsyncValue<UpToSlice>>{
      for (final d in _selection.days)
        for (final g in d.groups)
          g.key: ref.watch(upToSliceProvider(_requestOf(g, nameOf(g)))),
    };
    final failed = slices.values.any((s) => s.hasError);
    CatchUpPickerRows? pickerRowsOf(CatchUpGroupKey key) {
      final slice = slices[key]?.asData?.value;
      if (slice == null) return null;
      return catchUpPickerRows(
        _selection,
        key,
        trackOrder: [for (final r in slice.rows) r.ref],
        recorded: {
          for (final r in slice.rows)
            if (r.recorded) r.ref,
        },
      );
    }

    final loading = !failed && slices.values.any((s) => !s.hasValue);

    final count = _selection.count;
    final String recordLabel;
    if (curricula.length == 1) {
      final units = ref.watch(upToUnitLabelsProvider(curricula.first));
      recordLabel = l10n.upToPickerRecord(count, upToUnitFor(units, count));
    } else {
      recordLabel = l10n.catchUpAdjustRecordItems(count);
    }
    final onRecord = widget.onRecord;
    final canRecord =
        onRecord != null && !failed && !widget.recording && count > 0;

    final view = _selection.view;
    return Container(
      key: const ValueKey('catchUpAdjustPanel'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.brandCreamCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.brandOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failed)
            _LoadError(
              onRetry: () {
                retryUpToInputs(ref);
                for (final d in _selection.days) {
                  for (final g in d.groups) {
                    ref.invalidate(upToSliceProvider(_requestOf(g, nameOf(g))));
                  }
                }
              },
            )
          else ...[
            if (loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(
                  key: ValueKey('catchUpAdjustLoading'),
                ),
              ),
            for (final (i, day) in view.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              _DaySection(
                key: ValueKey('catchUpAdjustDay-${day.day.date}'),
                day: day,
                nameOf: nameOf,
                pickerRowsOf: pickerRowsOf,
                onUpTo: (group, rows) => _openUpTo(group, nameOf(group), rows),
                enabled: !widget.recording,
                onToggle: (key, leaf) =>
                    setState(() => _selection = _selection.toggle(key, leaf)),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: const ValueKey('catchUpAdjustCancel'),
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: widget.onCollapse,
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              Semantics(
                liveRegion: true,
                child: FilledButton.icon(
                  key: const ValueKey('catchUpAdjustRecord'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                    shape: const StadiumBorder(),
                    backgroundColor: colors.brandBlue,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  onPressed: canRecord
                      ? () {
                          final action = catchUpAdjustedAction(
                            _selection,
                            widget.card.window,
                          );
                          if (action != null) onRecord(action);
                        }
                      : null,
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(recordLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The shared picker's starting selection over [rows] (AC-2): the rows
/// from the group's first planned leaf, targeted at its last ticked leaf
/// with every unticked leaf before it skipped; no target when none is
/// ticked.
UpToSelection catchUpUpToSelectionOf(CatchUpPickerRows rows) {
  var selection = UpToSelection([
    for (final r in rows.rows)
      UpToRow(r.ref, recorded: rows.recorded.contains(r.ref)),
  ]);
  final included = rows.included.toSet();
  var target = -1;
  for (var i = 0; i < rows.rows.length; i++) {
    if (included.contains(rows.rows[i].ref)) target = i;
  }
  if (target < 0) return selection;
  selection = selection.selectTarget(target);
  for (var i = 0; i < target; i++) {
    if (selection.isSelectable(i) && !included.contains(rows.rows[i].ref)) {
      selection = selection.toggle(i);
    }
  }
  return selection;
}

/// The heading of [group]: "Home · Main track" (with the curriculum's
/// unit when the card spans several), or "{name} (learns on shabbos)".
String catchUpAdjustGroupLabel(
  WidgetRef ref,
  AppLocalizations l10n,
  CatchUpGroupSelection group, {
  bool multiCurriculum = false,
}) {
  if (group.key.isMain) {
    if (!multiCurriculum) return l10n.catchUpAdjustMainGroup;
    final id = CurriculumId.fromStorageKey(group.key.curriculumId);
    if (id == null) return l10n.catchUpAdjustMainGroup;
    final units = ref.watch(upToUnitLabelsProvider(group.key.curriculumId));
    return l10n.catchUpAdjustMainGroupOf(units.many);
  }
  final terms = domainTermLabels(ref);
  final shabbos = terms.shabbos(
    variant: ref.watch(currentTransliterationVariantProvider),
  );
  return l10n.catchUpAdjustSubTrackGroup(
    group.subTrackName ?? '',
    terms.isHebrew ? shabbos : shabbos.toLowerCase(),
  );
}

/// One locked day's section.
class _DaySection extends ConsumerWidget {
  const _DaySection({
    super.key,
    required this.day,
    required this.nameOf,
    required this.pickerRowsOf,
    required this.onUpTo,
    required this.enabled,
    required this.onToggle,
  });

  final CatchUpDayView day;
  final String Function(CatchUpGroupSelection group) nameOf;
  final CatchUpPickerRows? Function(CatchUpGroupKey key) pickerRowsOf;
  final Future<void> Function(
    CatchUpGroupSelection group,
    CatchUpPickerRows rows,
  )
  onUpTo;
  final bool enabled;
  final void Function(CatchUpGroupKey key, LeafRef leaf) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final dayName = erevDayName(context, ref, day.day);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              dayName,
              key: ValueKey('catchUpAdjustDayTitle-${day.day.date}'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.brandInk,
              ),
            ),
          ),
          for (final g in day.groups)
            _GroupSection(
              key: ValueKey(
                'catchUpAdjustGroup-${day.day.date}-'
                '${g.key.curriculumId}-${g.key.source}',
              ),
              group: g,
              name: nameOf(g.group),
              pickerRows: pickerRowsOf(g.key),
              onUpTo: (rows) => onUpTo(g.group, rows),
              enabled: enabled,
              onToggle: (leaf) => onToggle(g.key, leaf),
            ),
        ],
      ),
    );
  }
}

/// One source's group: heading, *Up to…*, and its rows.
class _GroupSection extends ConsumerWidget {
  const _GroupSection({
    super.key,
    required this.group,
    required this.name,
    required this.pickerRows,
    required this.onUpTo,
    required this.enabled,
    required this.onToggle,
  });

  final CatchUpGroupView group;
  final String name;

  /// The group's Up to… rows once its track order loaded; null before.
  final CatchUpPickerRows? pickerRows;

  /// Opens the picker over the group's rows.
  final Future<void> Function(CatchUpPickerRows rows) onUpTo;
  final bool enabled;
  final ValueChanged<LeafRef> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final key = group.key;
    final rows = pickerRows;
    // AC-6: a sub-track with no leaf after the planned ones.
    final exhausted = !key.isMain && rows != null && !rows.hasFurther;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.brandInkMuted,
                  ),
                ),
              ),
              UpToActionButton(
                key: ValueKey(
                  'catchUpAdjustUpTo-${key.learnedOn}-${key.source}',
                ),
                semanticsLabel: l10n.upToPickerActionSemantics(name),
                onOpen:
                    !enabled || rows == null || exhausted || !rows.selectable
                    ? null
                    : () => onUpTo(rows),
              ),
            ],
          ),
          if (exhausted)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l10n.catchUpAdjustNoMoreGround(
                  ref.watch(upToUnitLabelsProvider(key.curriculumId)).many,
                ),
                key: ValueKey(
                  'catchUpAdjustNoMore-${key.learnedOn}-${key.source}',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.brandInkMuted,
                ),
              ),
            ),
          for (final r in group.rows)
            _AdjustRow(
              key: ValueKey(
                'catchUpAdjustRow-${key.learnedOn}-${key.source}-${r.ref}',
              ),
              leaf: r.ref,
              included: group.isIncluded(r.ref),
              onToggle: enabled ? () => onToggle(r.ref) : null,
            ),
        ],
      ),
    );
  }
}

/// One leaf row: its ref and an included / skipped tick (48dp).
class _AdjustRow extends ConsumerWidget {
  const _AdjustRow({
    super.key,
    required this.leaf,
    required this.included,
    required this.onToggle,
  });

  final LeafRef leaf;
  final bool included;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final label = ref.watch(upToLeafLabelProvider(leaf));
    final status = included
        ? l10n.upToPickerStatusIncluded
        : l10n.upToPickerStatusSkipped;
    return Semantics(
      container: true,
      button: true,
      enabled: onToggle != null,
      checked: included,
      label: l10n.upToPickerRowSemantics(label, status),
      onTap: onToggle,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Checkbox(
                  value: included,
                  activeColor: colors.brandBlue,
                  onChanged: onToggle == null ? null : (_) => onToggle!(),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: included ? colors.brandInk : colors.brandInkMuted,
                      decoration: included ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
                child: Text(
                  status,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.brandInkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The inline load error with a 48dp Retry (AC-7, UX-DR-109).
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const ValueKey('catchUpAdjustLoadError'),
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.catchUpAdjustLoadError,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('catchUpAdjustRetry'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onRetry,
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
