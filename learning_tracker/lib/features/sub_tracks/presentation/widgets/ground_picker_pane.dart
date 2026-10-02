/// The ground picker body (Story 2.7 / DNI-498, screens.md #08, UX-DR-30):
/// "Add ground to {name}", search, *Available only*, the progress legend,
/// the ContentIndex tree and a sticky footer with *Reset changes*, the live
/// "Add {n} {unit} to {name}" pill and the home-schedule note.
///
/// One widget for both compositions: the phone route fills the screen
/// with it; on a tablet the sub-track detail shows it as the right pane.
/// It fails closed: without a parent session, on a calendar-program
/// curriculum, or for an unknown or ended sub-track it shows no editable
/// control (AC-7, AC-8). Overlap with other sub-tracks is shown, never
/// reconciled (UX-DR-167).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart'
    show TriState;
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ground_selection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ground_assignment_rollbacks_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ground_picker_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_labels.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_row.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_tree.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows the rollback snackbar (UX-DR-127) when a queued ground assignment
/// of [subTrackId] the server later refused has been reverted. Call from
/// `build` of every widget that outlives or hosts the picker (the picker
/// itself and *Add ground*); each rollback is announced once, by whichever
/// listener takes it first.
void listenForGroundRollbacks(
  WidgetRef ref,
  BuildContext context,
  String subTrackId,
) {
  ref.listen(
    groundAssignmentRollbacksProvider.select((s) => s[subTrackId] ?? 0),
    (previous, next) {
      if (next <= (previous ?? 0)) return;
      if (!ref
          .read(groundAssignmentRollbacksProvider.notifier)
          .take(subTrackId)) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      if (l10n == null) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.groundPickerRejected)));
    },
  );
}

/// The picker for sub-track [subTrackId].
class GroundPickerPane extends ConsumerStatefulWidget {
  /// Creates the picker.
  const GroundPickerPane({
    super.key,
    required this.subTrackId,
    required this.onClose,
  });

  /// The sub-track receiving ground.
  final String subTrackId;

  /// Closes the picker (pops the route, or closes the tablet pane); the
  /// caller returns focus to *Add ground* (UX-DR-160).
  final VoidCallback onClose;

  @override
  ConsumerState<GroundPickerPane> createState() => _GroundPickerPaneState();
}

class _GroundPickerPaneState extends ConsumerState<GroundPickerPane> {
  final _titleFocus = FocusNode(debugLabel: 'groundPickerTitle');
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = ref
        .read(groundPickerControllerProvider(widget.subTrackId))
        .query;
    // Focus lands on the title when the picker opens (UX-DR-160).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  GroundPickerController get _controller =>
      ref.read(groundPickerControllerProvider(widget.subTrackId).notifier);

  /// Re-reads every input that can fail to load (UX-DR-126).
  void _retry() {
    ref
      ..invalidate(corporaProvider)
      ..invalidate(learnerStateProvider)
      ..invalidate(groundPickerSubTracksProvider)
      ..invalidate(groundPickerCalendarProgramProvider)
      ..invalidate(groundPickerAccessProvider(widget.subTrackId));
  }

  Future<void> _confirm(GroundPickerInputs inputs, GroundDraft draft) async {
    final model = inputs.model;
    final ground = [...model.ownGround, ...model.appended(draft)];
    final picks = draft.picks.toList();
    // Read before the await: the picker may close while the write runs.
    final rollbacks = ref.read(groundAssignmentRollbacksProvider.notifier);
    _controller.submitting(ground);
    CaptureResult result;
    LearningCommands? commands;
    try {
      commands = await ref.read(learningCommandsProvider.future);
      result = commands == null
          ? const CaptureResult.onlineRequired()
          : await commands.editSubTrack(
              inputs.track.id,
              SubTrackEdit(appendGround: picks),
            );
    } on Object {
      result = const CaptureResult.rejected(CaptureRejection.notSaved);
    }
    // Queued offline: the local write shows at once, but the server may
    // still refuse it. Watch for that, past this picker's lifetime, so a
    // late refusal is announced once the data layer has reverted it.
    if (result case CaptureSuccess(queued: true) when commands != null) {
      rollbacks.trackQueued(commands, inputs.track.id, result);
    }
    if (!mounted) return;
    if (result is CaptureSuccess) {
      _controller.accepted();
      widget.onClose();
      return;
    }
    // Rolled back to the last accepted ground (UX-DR-127).
    _controller.rejected();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.groundPickerRejected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    listenForGroundRollbacks(ref, context, widget.subTrackId);
    final access = ref.watch(groundPickerAccessProvider(widget.subTrackId));
    final name = switch (access) {
      AsyncData(value: GroundPickerReady(:final inputs)) => inputs.track.name,
      _ => null,
    };
    final body = switch (access) {
      AsyncData(value: GroundPickerReady(:final inputs)) => _ready(inputs),
      AsyncData(value: GroundPickerUnavailable()) => _Unavailable(
        message: l10n.groundPickerUnavailable,
      ),
      AsyncError(:final error, :final stackTrace) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l10n.groundPickerLoadError, textAlign: TextAlign.center),
          Flexible(
            child: AppErrorView(
              error: error,
              stackTrace: stackTrace,
              onRetry: _retry,
            ),
          ),
        ],
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              focusNode: _titleFocus,
              title: name == null
                  ? l10n.groundPickerAddGround
                  : l10n.groundPickerTitle(name),
              closeTooltip: l10n.groundPickerClose,
              onClose: widget.onClose,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _ready(GroundPickerInputs inputs) {
    final l10n = AppLocalizations.of(context)!;
    final ui = ref.watch(groundPickerControllerProvider(widget.subTrackId));
    final optimistic = ui.optimisticGround;
    final model = optimistic == null
        ? inputs.model
        : inputs.model.withOwnGround(optimistic);
    final draft = GroundDraft.of(model, ui.picks);
    final labels = GroundPickerLabels(
      curriculum: inputs.curriculum,
      curriculumId: inputs.track.curriculumId,
      index: inputs.index,
      corpus: model.corpus,
      useHebrew: ref.watch(effectiveUseHebrewTermsProvider),
      variant: ref.watch(currentTransliterationVariantProvider),
    );
    final summary = model.summaryOf(draft);
    final sample = summary.sample;
    final trackName = inputs.track.name;
    final pill = summary.count == 0 || sample == null
        ? l10n.groundPickerConfirmEmpty(trackName)
        : l10n.groundPickerConfirm(
            summary.count,
            labels.unitOf(sample, summary.count),
            trackName,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: _controller.setQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.groundPickerSearchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: Text(l10n.groundPickerAvailableOnly),
                selected: ui.availableOnly,
                onSelected: _controller.setAvailableOnly,
              ),
              _Legend(l10n: l10n),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
        Expanded(
          child: GroundPickerTree(
            model: model,
            draft: draft,
            labels: labels,
            trackName: trackName,
            query: ui.query,
            availableOnly: ui.availableOnly,
            expanded: ui.expanded,
            onToggleSelected: ui.submitting
                ? (_) {}
                : (node) => _controller.setPicks(draft.toggle(node).picks),
            onToggleExpanded: _controller.toggleExpanded,
          ),
        ),
        _Footer(
          pill: pill,
          note: l10n.groundPickerScheduleNote(trackName),
          reset: l10n.groundPickerReset,
          onReset: draft.isEmpty || ui.submitting ? null : _controller.reset,
          onConfirm: summary.count == 0 || ui.submitting
              ? null
              : () => _confirm(inputs, draft),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.focusNode,
    required this.title,
    required this.closeTooltip,
    required this.onClose,
  });

  final FocusNode focusNode;
  final String title;
  final String closeTooltip;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 16, 4),
    child: Row(
      children: [
        IconButton(
          tooltip: closeTooltip,
          onPressed: onClose,
          icon: const Icon(Icons.close),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Focus(
            focusNode: focusNode,
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.colors.brandInkMuted);
    Widget entry(TriState state, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GroundProgressMark(state: state),
        const SizedBox(width: 4),
        Text(text, style: style),
      ],
    );
    return Wrap(
      spacing: 12,
      children: [
        entry(TriState.complete, l10n.groundPickerLegendComplete),
        entry(TriState.partial, l10n.groundPickerLegendPartial),
        entry(TriState.empty, l10n.groundPickerLegendEmpty),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.pill,
    required this.note,
    required this.reset,
    required this.onReset,
    required this.onConfirm,
  });

  final String pill;
  final String note;
  final String reset;
  final VoidCallback? onReset;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(onPressed: onReset, child: Text(reset)),
                  FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check),
                    label: Text(pill),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.colors.brandInkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
