/// Screen #13 — Mishna history (Story 1.13, DNI-475; FR-30, UX-DR-41,
/// UX-DR-60, UX-DR-140, UX-DR-141, UX-DR-157, UX-DR-161).
///
/// Shows the engine's Learnt state and "Learning events" count for one
/// leaf, then every learn event newest first with its date or Before
/// tracking badge, source chip, and catch-up / chazara tags, and a footer
/// explaining that repeats never add goal progress. It displays the engine
/// output and never recomputes it.
///
/// Reached from any leaf in Browse or the lifetime tree; the route carries
/// the curriculum storage key and leaf ref, so sub-track detail and ground
/// rows can reuse it later. During the sacred-time lock of the learner
/// whose history it shows ([mishnaHistoryLockProvider]: that learner's lock
/// settings, or the device lock) the screen renders no event content at
/// all and closes any correction sheet or picker it opened (AD-36: history
/// is unreadable and unusable under the lock).
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/models/mishna_history_item.dart';
import 'package:learning_tracker/features/learning/presentation/providers/mishna_history_provider.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The history of one leaf ([leafRef]) of one curriculum ([curriculumId],
/// a `CurriculumId.storageKey`).
@RoutePage()
class MishnaHistoryScreen extends ConsumerWidget {
  /// Creates the screen.
  const MishnaHistoryScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
    @PathParam('leafRef') required this.leafRef,
  });

  /// The curriculum storage key.
  final String curriculumId;

  /// The leaf sefariaRef.
  final String leafRef;

  MishnaHistoryArgs get _args => (curriculumId: curriculumId, leafRef: leafRef);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // A queued correction the server rejected after it returned: its row is
    // already restored, so announce the rollback (UX-DR-142).
    ref.listen(
      mishnaHistoryCorrectionsProvider(_args).select((s) => s.lateRollbacks),
      (previous, next) {
        if (next <= (previous ?? 0)) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.mishnaHistoryCorrectionRolledBack)),
        );
      },
    );
    // AD-36: when the learner's lock starts, close any correction sheet or
    // picker this screen opened, so no control stays usable above it.
    ref.listen(mishnaHistoryLockProvider, (previous, next) {
      if (next.value != true || previous?.value == true) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) closeMishnaHistoryPopups(context);
      });
    });
    // AD-36: nothing of the history is built while the learner's lock is
    // up, or while it is still unknown (fail closed).
    final lock = ref.watch(mishnaHistoryLockProvider);
    // Locked, unknown or unreadable: a title-only app bar with its back
    // action, so the pushed route is always leavable. The title carries no
    // event content, and no breadcrumb or Open text action is built.
    Scaffold titleOnly({Key? key, required Widget body}) => Scaffold(
      key: key,
      backgroundColor: context.colors.surfaceF4,
      appBar: AppBar(
        foregroundColor: context.colors.brandInk,
        title: Text(l10n.mishnaHistoryTitle),
      ),
      body: SafeArea(child: body),
    );
    if (lock case AsyncError(:final error, :final stackTrace)) {
      return titleOnly(
        body: AppErrorView(
          error: error,
          stackTrace: stackTrace,
          onRetry: () => retryMishnaHistory(ref),
        ),
      );
    }
    if (lock.value != false) {
      return titleOnly(
        key: const Key('mishnaHistoryLocked'),
        body: lock.hasValue
            ? const SizedBox.shrink()
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final viewer = ref.watch(mishnaHistoryViewerProvider);
    // Story 1.24 (DNI-486, AC-4/AC-5): a tutor reads what the grant allows;
    // without editing access or a connection the corrections stay visible
    // but disabled, with one note saying why.
    final writeBlocked =
        viewer == MishnaHistoryViewer.tutor &&
        ref.watch(tutorWriteAvailabilityProvider).blocksTutor;
    final history = ref.watch(mishnaHistoryViewProvider(_args));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.colors.surfaceF4,
      appBar: AppBar(
        foregroundColor: context.colors.brandInk,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.mishnaHistoryTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.colors.brandInk,
              ),
            ),
            CurriculumLabel.breadcrumb(
              leafRef,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.colors.brandInkMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('mishnaHistoryOpenText'),
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: l10n.mishnaHistoryOpenText,
            onPressed: () =>
                context.router.push(TextDisplayRoute(sefariaRef: leafRef)),
          ),
        ],
      ),
      body: SafeArea(
        child: history.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => AppErrorView(
            error: error,
            stackTrace: stackTrace,
            onRetry: () => retryMishnaHistory(ref),
          ),
          data: (data) => MishnaHistoryBody(
            history: data,
            viewer: viewer,
            writeBlocked: writeBlocked,
            onRowTap: writeBlocked
                ? null
                : (item, actions) => openMishnaCorrections(
                    context,
                    ref,
                    args: _args,
                    history: data,
                    item: item,
                    actions: actions,
                  ),
          ),
        ),
      ),
    );
  }
}

/// The scrollable header, event rows and footer of a [MishnaHistory].
class MishnaHistoryBody extends StatelessWidget {
  /// Creates the body.
  const MishnaHistoryBody({
    super.key,
    required this.history,
    required this.viewer,
    required this.onRowTap,
    this.writeBlocked = false,
  });

  /// The history to show.
  final MishnaHistory history;

  /// The viewer role.
  final MishnaHistoryViewer viewer;

  /// Called when a row with corrections is tapped; null disables taps.
  final void Function(MishnaHistoryItem item, Set<MishnaCorrection> actions)?
  onRowTap;

  /// A tutor who may not write now: the correction controls stay visible
  /// but disabled, under the tutor write note (DNI-486).
  final bool writeBlocked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rows = history.visibleTo(viewer);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 32),
      children: [
        if (viewer == MishnaHistoryViewer.tutor)
          const TutorWriteNote(padding: EdgeInsets.only(bottom: 12)),
        _HistoryHeader(history: history),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.mishnaHistoryNewestFirst,
            style: theme.textTheme.labelLarge?.copyWith(
              color: context.colors.brandInkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in rows) ...[
            MishnaHistoryEventRow(
              key: ValueKey('mishnaHistoryRow-${item.eventId}'),
              item: item,
              actions: allowedCorrections(
                item,
                viewer,
                hasPlaceChoices: history.placeChoices.isNotEmpty,
              ),
              onTap: onRowTap,
              writeBlocked: writeBlocked,
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 16),
        Semantics(
          container: true,
          child: Text(
            l10n.mishnaHistoryFooter,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.colors.brandInkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.history});

  final MishnaHistory history;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final learnt = history.learnt;
    final stateLabel = learnt
        ? l10n.mishnaHistoryLearnt
        : l10n.mishnaHistoryNotLearntYet;
    return Card(
      margin: EdgeInsets.zero,
      color: context.colors.brandCreamCard,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Row(
          children: [
            Icon(
              learnt ? Icons.check_circle : Icons.radio_button_unchecked,
              color: learnt
                  ? context.colors.brandGold
                  : context.colors.brandOutline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stateLabel,
                    key: const Key('mishnaHistoryLearntState'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.colors.brandInk,
                    ),
                  ),
                  if (history.showsEventCount)
                    Text(
                      l10n.mishnaHistoryEventCount(history.eventCount),
                      key: const Key('mishnaHistoryEventCount'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.colors.brandInkMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One event row: number, date or Before tracking, source and tags.
///
/// Status is always spelled out as text (UX-DR-157), and the row's
/// semantics announce date, source and tags as one label.
class MishnaHistoryEventRow extends StatelessWidget {
  /// Creates the row.
  const MishnaHistoryEventRow({
    super.key,
    required this.item,
    required this.actions,
    required this.onTap,
    this.writeBlocked = false,
  });

  /// The row.
  final MishnaHistoryItem item;

  /// The corrections it offers.
  final Set<MishnaCorrection> actions;

  /// Opens the corrections; null disables taps.
  final void Function(MishnaHistoryItem item, Set<MishnaCorrection> actions)?
  onTap;

  /// The row's corrections exist but the tutor may not write now: the
  /// actions control shows at 40% opacity with disabled semantics.
  final bool writeBlocked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final dateText = item.isBeforeTracking
        ? l10n.mishnaHistoryBeforeTracking
        : formatCivilDate(item.learnedOn!, Localizations.localeOf(context));
    final sourceText = sourceLabel(item, l10n);
    final notes = <String>[
      if (item.isCatchUp) l10n.mishnaHistoryTagCatchUp,
      if (item.isChazara) l10n.mishnaHistoryTagChazara,
      if (item.status == MishnaHistoryStatus.lockIgnored)
        l10n.mishnaHistoryLockIgnored,
      if (item.status == MishnaHistoryStatus.voided) l10n.mishnaHistoryRemoved,
      if (item.pending) l10n.mishnaHistorySaving,
    ];
    final ordinal = item.ordinal;
    final tappable = onTap != null && actions.isNotEmpty && !writeBlocked;
    final disabledControl = writeBlocked && actions.isNotEmpty;
    final dimmed = item.status != MishnaHistoryStatus.counted || item.pending;

    final content = Opacity(
      opacity: dimmed ? 0.72 : 1,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Leading(item: item, ordinal: ordinal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.isBeforeTracking)
                    _Tag(
                      text: dateText,
                      background: colors.brandGoldSoft,
                      foreground: colors.curriculumMishna,
                    )
                  else
                    Text(
                      dateText,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.brandInk,
                        decoration: item.status == MishnaHistoryStatus.voided
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _SourceChip(item: item, label: sourceText),
                      if (item.isCatchUp)
                        _Tag(
                          text: l10n.mishnaHistoryTagCatchUp,
                          background: colors.brandCoralSoft,
                          foreground: colors.brandCoralDeep,
                        ),
                      if (item.isChazara)
                        _Tag(
                          text: l10n.mishnaHistoryTagChazara,
                          background: colors.brandBlueSoft,
                          foreground: colors.brandBlueDeep,
                        ),
                      if (item.status == MishnaHistoryStatus.voided)
                        _Tag(
                          text: l10n.mishnaHistoryRemoved,
                          background: colors.brandErrorSoft,
                          foreground: colors.brandError,
                        ),
                    ],
                  ),
                  if (item.status == MishnaHistoryStatus.lockIgnored) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.mishnaHistoryLockIgnored,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.brandWarningDeep,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (item.pending) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.mishnaHistorySaving,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.brandInkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (tappable)
              Icon(Icons.more_vert, size: 20, color: colors.brandInkMuted),
            if (disabledControl)
              Opacity(
                key: const Key('mishnaHistoryActionsDisabled'),
                opacity: tutorDisabledControlOpacity,
                child: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: colors.brandInkMuted,
                ),
              ),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      button: tappable || disabledControl,
      enabled: disabledControl ? false : null,
      hint: tappable ? l10n.mishnaHistoryActionsHint : null,
      onTap: tappable ? () => onTap!(item, actions) : null,
      label: [
        if (ordinal != null) l10n.mishnaHistoryEventNumber(ordinal),
        dateText,
        sourceText,
        ...notes,
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: colors.brandCreamCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: tappable ? () => onTap!(item, actions) : null,
          child: content,
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.item, required this.ordinal});

  final MishnaHistoryItem item;
  final int? ordinal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final n = ordinal;
    if (n == null) {
      return Icon(
        item.status == MishnaHistoryStatus.voided
            ? Icons.remove_circle_outline
            : Icons.do_not_disturb_on_outlined,
        color: colors.brandInkMuted,
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: colors.brandBlueSoft,
      child: Text(
        l10n.mishnaHistoryEventNumber(n),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: colors.brandBlueDeep,
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.item, required this.label});

  final MishnaHistoryItem item;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 10, 3),
      decoration: BoxDecoration(
        color: colors.brandCreamSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.brandOutline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.sourceKind == MishnaHistorySourceKind.home
                ? Icons.home_outlined
                : Icons.alt_route,
            size: 14,
            color: colors.brandInk2,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.brandInk2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// Pops every popup (correction sheet, picker or dialog) above the history
/// route, on its own navigator and on the root navigator that `showDialog`
/// uses. Called when the learner's lock starts (AD-36).
void closeMishnaHistoryPopups(BuildContext context) {
  for (final root in [false, true]) {
    final navigator = Navigator.maybeOf(context, rootNavigator: root);
    navigator?.popUntil((route) => route is! PopupRoute);
  }
}

/// Opens the corrections of [item] and runs the chosen one (FR-4).
///
/// Every write goes through `LearningCommands` via
/// [mishnaHistoryCorrectionsProvider]; a refused or failed write has
/// already restored the original row when the snackbar is shown
/// (UX-DR-142). A queued write rejected later is announced by the screen's
/// `lateRollbacks` listener.
Future<void> openMishnaCorrections(
  BuildContext context,
  WidgetRef ref, {
  required MishnaHistoryArgs args,
  required MishnaHistory history,
  required MishnaHistoryItem item,
  required Set<MishnaCorrection> actions,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final corrections = ref.read(mishnaHistoryCorrectionsProvider(args).notifier);
  final choice = await showModalBottomSheet<MishnaCorrection>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              l10n.mishnaHistoryActionsTitle,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          for (final action in MishnaCorrection.values)
            if (actions.contains(action))
              ListTile(
                key: Key('mishnaHistoryAction-${action.name}'),
                leading: Icon(_actionIcon(action)),
                title: Text(_actionLabel(action, l10n)),
                onTap: () => Navigator.of(sheetContext).pop(action),
              ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final request = await _requestFor(
    context,
    choice,
    item,
    history,
    ref.read(localDayClockProvider).today(),
  );
  if (request == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final outcome = await corrections.correct(item, request);
  final message = switch (outcome) {
    // Queued offline: the row stays pending; a later server rejection is
    // announced through `lateRollbacks`.
    MishnaCorrectionOutcome.applied || MishnaCorrectionOutcome.queued => null,
    MishnaCorrectionOutcome.childLimit =>
      l10n.mishnaHistoryCorrectionChildLimit,
    MishnaCorrectionOutcome.rolledBack =>
      l10n.mishnaHistoryCorrectionRolledBack,
    MishnaCorrectionOutcome.keptNotCounted => l10n.tutorCaptureKeptNotCounted,
    MishnaCorrectionOutcome.editingTurnedOff => tutorEditingTurnedOffText(
      l10n,
      learnerName: ref.read(tutorLearnerNameProvider),
    ),
  };
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

IconData _actionIcon(MishnaCorrection action) => switch (action) {
  MishnaCorrection.remove => Icons.delete_outline,
  MishnaCorrection.changePlace => Icons.swap_horiz,
  MishnaCorrection.changeSource => Icons.alt_route,
  MishnaCorrection.changeDate => Icons.event_outlined,
};

String _actionLabel(MishnaCorrection action, AppLocalizations l10n) =>
    switch (action) {
      MishnaCorrection.remove => l10n.mishnaHistoryActionRemove,
      MishnaCorrection.changePlace => l10n.mishnaHistoryActionChangePlace,
      MishnaCorrection.changeSource => l10n.mishnaHistoryActionChangeSource,
      MishnaCorrection.changeDate => l10n.mishnaHistoryActionChangeDate,
    };

/// Asks for the details of [action] and builds its request; null when the
/// user cancels or the choice changes nothing. Source choices are Home and
/// Before tracking only in this story (sub-track sources: Story 2.10).
Future<MishnaCorrectionRequest?> _requestFor(
  BuildContext context,
  MishnaCorrection action,
  MishnaHistoryItem item,
  MishnaHistory history,
  DateTime today,
) async {
  switch (action) {
    case MishnaCorrection.remove:
      return const RemoveEventRequest();
    case MishnaCorrection.changeDate:
      final date = await _pickDate(context, item, today);
      if (date == null) return null;
      return ReplaceEventRequest(
        EventReplacement(
          learnedOn: date,
          dateState: item.isBeforeTracking ? DateState.dated : null,
        ),
      );
    case MishnaCorrection.changePlace:
      final ref = await _pickPlace(context, history.placeChoices);
      if (ref == null) return null;
      return ReplaceEventRequest(EventReplacement(ref: ref));
    case MishnaCorrection.changeSource:
      final toBeforeTracking = await _pickSource(context, item);
      if (toBeforeTracking == null) return null;
      if (toBeforeTracking) {
        if (item.isBeforeTracking) return null;
        return const ReplaceEventRequest(
          EventReplacement(
            source: LearningEvent.sourceMain,
            dateState: DateState.beforeTracking,
          ),
        );
      }
      if (item.isBeforeTracking) {
        // Home needs the day it was learnt.
        if (!context.mounted) return null;
        final date = await _pickDate(context, item, today);
        if (date == null) return null;
        return ReplaceEventRequest(
          EventReplacement(
            source: LearningEvent.sourceMain,
            dateState: DateState.dated,
            learnedOn: date,
          ),
        );
      }
      if (item.sourceKind == MishnaHistorySourceKind.home) return null;
      return const ReplaceEventRequest(
        EventReplacement(source: LearningEvent.sourceMain),
      );
  }
}

/// A civil date (`YYYY-MM-DD`) picked on or before today.
Future<String?> _pickDate(
  BuildContext context,
  MishnaHistoryItem item,
  DateTime today,
) async {
  final current = item.learnedOn;
  var initial = today;
  if (current != null) {
    final p = current.split('-').map(int.parse).toList();
    final d = DateTime(p[0], p[1], p[2]);
    if (!d.isAfter(today)) initial = d;
  }
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: today,
  );
  if (picked == null) return null;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${picked.year.toString().padLeft(4, '0')}-${two(picked.month)}-'
      '${two(picked.day)}';
}

Future<String?> _pickPlace(BuildContext context, List<String> choices) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(l10n.mishnaHistoryChoosePlace),
      children: [
        for (final ref in choices)
          SimpleDialogOption(
            key: Key('mishnaHistoryPlace-$ref'),
            onPressed: () => Navigator.of(dialogContext).pop(ref),
            child: CurriculumLabel.local(ref),
          ),
      ],
    ),
  );
}

/// True for Before tracking, false for Home, null when cancelled.
Future<bool?> _pickSource(BuildContext context, MishnaHistoryItem item) {
  final l10n = AppLocalizations.of(context)!;
  Widget option(BuildContext dialogContext, bool beforeTracking) {
    final selected = beforeTracking
        ? item.isBeforeTracking
        : !item.isBeforeTracking &&
              item.sourceKind == MishnaHistorySourceKind.home;
    return SimpleDialogOption(
      key: Key('mishnaHistorySource-${beforeTracking ? 'before' : 'home'}'),
      onPressed: () => Navigator.of(dialogContext).pop(beforeTracking),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            beforeTracking
                ? l10n.mishnaHistoryBeforeTracking
                : l10n.mishnaHistorySourceHome,
          ),
        ],
      ),
    );
  }

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(l10n.mishnaHistoryChooseSource),
      children: [option(dialogContext, false), option(dialogContext, true)],
    ),
  );
}

/// The source chip label of [item]: Home, the sub-track's stored name
/// (marked ended when tombstoned), or a generic label — never a ULID.
String sourceLabel(MishnaHistoryItem item, AppLocalizations l10n) =>
    switch (item.sourceKind) {
      MishnaHistorySourceKind.home => l10n.mishnaHistorySourceHome,
      MishnaHistorySourceKind.subTrack =>
        item.sourceEnded
            ? l10n.mishnaHistorySourceEnded(item.sourceName!)
            : item.sourceName!,
      MishnaHistorySourceKind.unknownSubTrack =>
        l10n.mishnaHistorySourceUnknown,
    };

/// Formats a `YYYY-MM-DD` civil date for [locale] (the learner's calendar
/// day; no time-zone shift is applied to a civil date).
String formatCivilDate(String civilDate, Locale locale) {
  final parts = civilDate.split('-').map(int.parse).toList();
  final day = DateTime(parts[0], parts[1], parts[2]);
  return DateFormat.yMMMd(locale.toLanguageTag()).format(day);
}
