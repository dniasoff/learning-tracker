/// One locked day's planned section on erev (Story 3.1, DNI-504): the
/// "Planned for {day}" heading, the shared *Up to…* action and the
/// planner's rows for that date with live tick controls (AC-1 to AC-3).
///
/// Every capture goes through `LearningCommands.capture` as an ordinary
/// `dated` main-track event (`learned_on` = the learner's today, stamped
/// now, `pts_` attached by the command, AD-50), and shows the shared
/// recorded / Undo snackbar ([showCaptureOutcome], UX-DR-154). There is no
/// erev-only write path: a tick records its row; *Up to…* is Story 2.10's
/// picker ([showUpToPicker]) and capture ([captureLeaves]), exactly as on
/// today's list, led by this day's new-learning rows. The command's
/// `CaptureGate` re-checks the lock at the moment of the write, so a tick
/// or a picker Record after `L.start` writes nothing and is not retried;
/// a picker still open at `L.start` closes with nothing recorded (AC-8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/erev_planned_tasks_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/capture_feedback.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// A planned row's identity: curriculum, leaf and stage.
typedef ErevRowKey = (String curriculum, String leaf, int stage);

/// The [ErevRowKey] of [task].
ErevRowKey erevRowKey(DailyTask task) =>
    (task.curriculumId.storageKey, task.contentItemSefariaRef, task.stageOrder);

/// The day name of [day] for its heading: the Shabbos term (Hebrew Terms
/// aware) for Shabbos, else the localized weekday.
String erevDayName(BuildContext context, WidgetRef ref, LockedDay day) {
  if (day.weekday == DateTime.saturday) {
    return domainTermLabels(
      ref,
    ).shabbos(variant: ref.watch(currentTransliterationVariantProvider));
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.EEEE(locale).format(parseCivilDay(day.date));
}

/// Whether [task] is a review (chazara) row, recorded at its stage.
bool _isReview(DailyTask task) =>
    task.priority == DailyTaskPriority.overdueChazara ||
    task.priority == DailyTaskPriority.scheduledChazara;

/// Records [tasks] through `LearningCommands` and shows the shared
/// recorded / Undo snackbar: one `dated` main-track capture per
/// (curriculum, stage) group, in row order, `learned_on` the learner's
/// today. Calls [onRecorded] with the rows written and [onUndone] when the
/// Undo voids them. A refused capture (the lock started, AC-8) shows the
/// lock notice; the selection is dropped, never retried.
Future<void> recordErevTasks(
  BuildContext context,
  WidgetRef ref,
  List<DailyTask> tasks, {
  void Function(Set<ErevRowKey> keys)? onRecorded,
  void Function(Set<ErevRowKey> keys)? onUndone,
}) async {
  if (tasks.isEmpty) return;
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final commands = await ref.read(learningCommandsProvider.future);
  if (!context.mounted) return;
  if (commands == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.captureNotSaved)));
    return;
  }
  final groups = <(String, int?), List<DailyTask>>{};
  for (final task in tasks) {
    final stage = _isReview(task) ? task.stageOrder : null;
    (groups[(task.curriculumId.storageKey, stage)] ??= []).add(task);
  }
  final eventIds = <String>[];
  final written = <ErevRowKey>{};
  var queued = false;
  CaptureResult? refused;
  for (final MapEntry(key: (curriculum, stage), value: rows)
      in groups.entries) {
    final CaptureResult result;
    try {
      result = await commands.capture(
        curriculumId: curriculum,
        refs: [for (final t in rows) t.contentItemSefariaRef],
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
        stage: stage,
      );
    } on Exception {
      refused = const CaptureResult.rejected(CaptureRejection.notSaved);
      break;
    }
    if (result case CaptureSuccess(eventIds: final ids, queued: final q)) {
      eventIds.addAll(ids);
      written.addAll(rows.map(erevRowKey));
      queued = queued || q;
    } else {
      refused = result;
      break;
    }
  }
  if (!context.mounted) return;
  if (written.isNotEmpty) onRecorded?.call(written);
  showCaptureOutcome(
    context,
    result:
        refused ?? CaptureResult.success(eventIds: eventIds, queued: queued),
    commands: commands,
    message: l10n.captureRecordedCount(written.length),
    messenger: messenger,
    onUndone: () => onUndone?.call(written),
  );
}

/// One locked day's planned section.
class PlannedDaySection extends ConsumerWidget {
  /// Creates the section.
  const PlannedDaySection({
    super.key,
    required this.day,
    required this.recorded,
    required this.onRecord,
    required this.enabled,
  });

  /// The locked day and its planned rows (non-empty).
  final ErevPlannedDay day;

  /// Rows recorded on this screen that the live plan has not dropped yet:
  /// shown ticked.
  final Set<ErevRowKey> recorded;

  /// Records the given rows.
  final void Function(List<DailyTask> rows) onRecord;

  /// Whether the controls are live (a learner's commands are available).
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dayName = erevDayName(context, ref, day.day);
    // Leaves an Up to… on this device has just recorded (Story 2.10's
    // optimistic overlay) read as ticked until the live plan drops them.
    final pending = <String, Set<String>>{
      for (final c in {for (final t in day.tasks) t.curriculumId.storageKey})
        c: ref.watch(
          activePendingRefsProvider((
            curriculumId: c,
            source: LearningEvent.sourceMain,
          )),
        ),
    };
    bool ticked(DailyTask t) =>
        recorded.contains(erevRowKey(t)) ||
        (!_isReview(t) &&
            (pending[t.curriculumId.storageKey]?.contains(
                  t.contentItemSefariaRef,
                ) ??
                false));
    final requests = enabled
        ? mainTrackUpToRequests([
            for (final t in day.tasks)
              if (!ticked(t)) t,
          ])
        : const <MainTrackUpToRequest>[];
    return Column(
      key: ValueKey('erevPlannedSection-${day.day.date}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                container: true,
                header: true,
                child: Text(
                  l10n.erevPlannedForDay(dayName),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            for (final request in requests)
              UpToActionButton(
                key: ValueKey(
                  'erevUpTo-${day.day.date}-${request.curriculumId}',
                ),
                semanticsLabel: l10n.upToPickerActionSemantics(request.name),
                label: requests.length > 1
                    ? l10n.upToPickerTitle(request.name)
                    : null,
                onOpen: () => openErevUpTo(context, ref, request),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final task in day.tasks) ...[
          PlannedTaskRow(
            task: task,
            ticked: ticked(task),
            onTick: !enabled || ticked(task) ? null : () => onRecord([task]),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Opens Story 2.10's *Up to…* picker for [request] from an erev planned
/// section and records what it confirms with [captureLeaves], exactly as
/// on today's list (AC-3).
///
/// If the erev window closes while the picker is open (`L.start` passed,
/// or the lock moved), the picker is closed and its selection abandoned:
/// nothing is recorded now or replayed after the lock (AC-8). A Record
/// that races the boundary is refused by `CaptureGate` inside the command.
Future<void> openErevUpTo(
  BuildContext context,
  WidgetRef ref,
  MainTrackUpToRequest request,
) async {
  final navigators = {
    Navigator.of(context),
    Navigator.of(context, rootNavigator: true),
  };
  // The container, not this section's ref: the section may unmount as
  // the window closes, and the picker must still be closed then.
  final container = ProviderScope.containerOf(context, listen: false);
  final openedIn = container.read(erevWindowProvider).asData?.value;
  var open = true;
  var abandoned = false;
  final subscription = container.listen<AsyncValue<ErevWindow?>>(
    erevWindowProvider,
    (_, next) {
      if (!open || !next.hasValue || next.isLoading) return;
      final window = next.value;
      if (window != null && window.lock == openedIn?.lock) return;
      abandoned = true;
      open = false;
      // The picker is a sheet (phone) or a dialog (tablet): both are
      // popup routes, on the local or the root navigator.
      for (final navigator in navigators) {
        navigator.popUntil((route) => route is! PopupRoute);
      }
    },
  );
  final List<LeafRef> refs;
  try {
    final selection = await showUpToPicker(context, request: request);
    refs = abandoned ? const [] : selection?.includedRefs ?? const [];
  } finally {
    open = false;
    subscription.close();
  }
  if (refs.isEmpty || !context.mounted) return;
  await captureLeaves(
    context,
    ref,
    curriculumId: request.curriculumId,
    source: request.source,
    refs: refs,
    stage: request.stage,
  );
}

/// [task]'s display title: the rendered ref, without its leading seder.
String _titleOf(WidgetRef ref, DailyTask task) {
  final rendered =
      ref
          .watch(renderedDisplayForRefProvider(task.contentItemSefariaRef))
          .asData
          ?.value ??
      task.contentItemSefariaRef.replaceAll('_', ' ');
  const separator = ' › ';
  final i = rendered.indexOf(separator);
  return i == -1 ? rendered : rendered.substring(i + separator.length);
}

/// One planned row with its live tick control (48dp target, AC-11).
class PlannedTaskRow extends ConsumerWidget {
  /// Creates the row.
  const PlannedTaskRow({
    super.key,
    required this.task,
    required this.ticked,
    required this.onTick,
  });

  /// The planned task.
  final DailyTask task;

  /// Whether it was just recorded here.
  final bool ticked;

  /// Records it; null when the control is not live.
  final VoidCallback? onTick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = _titleOf(ref, task);
    final stage = domainTermLabels(ref).resolveStoredStageName(task.stageName);
    return Semantics(
      container: true,
      child: _row(context, title, stage, erevRowKey(task)),
    );
  }

  Widget _row(
    BuildContext context,
    String title,
    String stage,
    ErevRowKey key,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    return Material(
      key: ValueKey('erevPlannedRow-${key.$1}-${key.$2}-${key.$3}'),
      color: colors.brandCreamCard,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTick,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 14, 4),
            child: Row(
              children: [
                Semantics(
                  container: true,
                  checked: ticked,
                  button: true,
                  enabled: onTick != null,
                  label: l10n.erevPlannedTickSemantics(title),
                  excludeSemantics: true,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Checkbox(
                      value: ticked,
                      onChanged: onTick == null ? null : (_) => onTick!(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        softWrap: true,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.brandInk,
                          decoration: ticked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (stage.isNotEmpty)
                        Text(
                          stage,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.brandInkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
