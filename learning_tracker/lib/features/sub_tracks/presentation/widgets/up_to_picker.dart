/// The Up to… picker (Story 2.10, DNI-501; screen #02, UX-DR-18, UX-DR-72,
/// UX-DR-108, UX-DR-109, UX-DR-157, UX-DR-160, UX-DR-163..166).
///
/// A rounded-top sheet on a phone and a centred dialog of at most 480px on
/// a tablet. It lists the track's leaves from its position (lazily: rows
/// and their labels build only as they scroll into view), lets the child
/// tap the last leaf learnt and untick any skipped one, and pops the
/// [UpToSelection] on Record. Cancel, a swipe down or platform back pop
/// null: nothing is recorded (UX-DR-166). There is no source badge or
/// picker in the sheet: the source is the track itself.
///
/// Presentation only: the caller issues the capture.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/up_to_selection.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/up_to_selection_service.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_capture_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/up_to_picker_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The shortest side from which the picker is a dialog, not a sheet.
const double upToTabletBreakpoint = 600;

/// The tablet dialog's maximum width (#02).
const double upToDialogMaxWidth = 480;

/// A curriculum's leaf unit, singular and plural, as the picker writes it
/// ("mishna" / "mishnayos").
typedef UpToUnitLabels = ({String one, String many});

/// The leaf unit of a curriculum storage key, in the learner's term
/// language; English terms are lower-cased for running text.
final upToUnitLabelsProvider = Provider.autoDispose
    .family<UpToUnitLabels, String>((ref, curriculumId) {
      final useHebrew = domainTermLabelsFromRef(ref).isHebrew;
      final id =
          CurriculumId.fromStorageKey(curriculumId) ?? CurriculumId.mishnayos;
      final leaf = CurriculumLabels.leaf(id);
      String term(bool plural) {
        final s = leaf.inLanguage(useHebrew: useHebrew, plural: plural);
        return useHebrew ? s : s.toLowerCase();
      }

      return (one: term(false), many: term(true));
    });

/// A leaf's display label for a picker or row ("Berachos › Perek 2 ›
/// Mishna 1"): the breadcrumb without its leading seder segment, or the
/// raw ref while it loads or when it cannot be rendered.
final upToLeafLabelProvider = Provider.autoDispose.family<String, String>((
  ref,
  leaf,
) {
  final fallback = leaf.replaceAll('_', ' ');
  final rendered = ref.watch(renderedDisplayForRefProvider(leaf)).asData?.value;
  if (rendered == null || rendered.isEmpty) return fallback;
  const sep = ' › ';
  final at = rendered.indexOf(sep);
  return at < 0 ? rendered : rendered.substring(at + sep.length);
});

/// The count-aware leaf unit: singular for one, plural otherwise.
String upToUnitFor(UpToUnitLabels units, int count) =>
    count == 1 ? units.one : units.many;

/// Opens the picker for [request]: a sheet on a phone, a dialog of at most
/// [upToDialogMaxWidth] on a tablet. Completes with the confirmed
/// selection, or null when it was dismissed (nothing to record).
Future<UpToSelection?> showUpToPicker(
  BuildContext context, {
  required UpToRequest request,
}) {
  final size = MediaQuery.sizeOf(context);
  final picker = UpToPicker(request: request);
  if (size.shortestSide >= upToTabletBreakpoint) {
    return showDialog<UpToSelection>(
      context: context,
      builder: (_) => Dialog(
        key: const Key('upToPickerDialog'),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: upToDialogMaxWidth,
            maxHeight: size.height * 0.8,
          ),
          child: picker,
        ),
      ),
    );
  }
  return showModalBottomSheet<UpToSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    constraints: BoxConstraints(maxHeight: size.height * 0.85),
    builder: (_) =>
        KeyedSubtree(key: const Key('upToPickerSheet'), child: picker),
  );
}

/// Opens the picker for [request] and records what it confirms as ONE
/// capture ([captureLeaves]): the track's source, `dated`, today; the
/// main track adds its first stage. Dismissal records nothing (AC-4).
Future<void> openUpToAndRecord(
  BuildContext context,
  WidgetRef ref, {
  required UpToRequest request,
}) async {
  final selection = await showUpToPicker(context, request: request);
  if (selection == null || selection.count == 0 || !context.mounted) return;
  await captureLeaves(
    context,
    ref,
    curriculumId: request.curriculumId,
    source: request.source,
    refs: selection.includedRefs,
    stage: switch (request) {
      MainTrackUpToRequest(:final stage) => stage,
      SubTrackUpToRequest() => null,
    },
  );
}

/// The picker body; pops an [UpToSelection] on Record.
class UpToPicker extends ConsumerStatefulWidget {
  /// Creates the picker.
  const UpToPicker({super.key, required this.request});

  /// What the picker records.
  final UpToRequest request;

  @override
  ConsumerState<UpToPicker> createState() => _UpToPickerState();
}

class _UpToPickerState extends ConsumerState<UpToPicker> {
  final _titleFocus = FocusNode(debugLabel: 'upToPickerTitle');

  /// The rows as first loaded: the list never shifts under the child's
  /// finger while the sheet is open.
  UpToSlice? _slice;
  UpToSelection? _selection;

  @override
  void initState() {
    super.initState();
    // UX-DR-160: focus enters the sheet at its title.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    super.dispose();
  }

  void _update(UpToSelection next) {
    if (!identical(next, _selection)) setState(() => _selection = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final request = widget.request;
    final units = ref.watch(upToUnitLabelsProvider(request.curriculumId));
    final async = ref.watch(upToSliceProvider(request));
    final slice = _slice ??= async.asData?.value;
    final selection = _selection ??= slice?.select();
    final ready = slice != null && slice.availability == UpToAvailability.ready;
    final count = ready ? selection!.count : 0;
    final recordLabel = l10n.upToPickerRecord(count, upToUnitFor(units, count));

    final Widget body;
    if (slice == null) {
      body = async.hasError
          ? Padding(
              key: const Key('upToPickerError'),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: InlineAsyncError(
                  error: async.error!,
                  onRetry: () => retryUpToInputs(ref),
                ),
              ),
            )
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            );
    } else if (!ready) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          l10n.upToPickerExhausted(units.many, request.name),
          key: const Key('upToPickerExhausted'),
          style: theme.textTheme.bodyLarge,
        ),
      );
    } else {
      body = _UpToRows(selection: selection!, onChanged: _update);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          child: Focus(
            focusNode: _titleFocus,
            child: Semantics(
              header: true,
              focusable: true,
              child: Text(
                l10n.upToPickerTitle(request.name),
                key: const Key('upToPickerTitle'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        if (ready)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l10n.upToPickerInstruction(units.one),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: body,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: const Key('upToCancel'),
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              if (slice == null || ready)
                Semantics(
                  liveRegion: true,
                  child: FilledButton(
                    key: const Key('upToRecord'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.brandBlue,
                      minimumSize: const Size(64, 48),
                    ),
                    onPressed: ready && count > 0
                        ? () => Navigator.of(context).pop(selection)
                        : null,
                    child: Text(recordLabel),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The lazily built rows of a ready picker.
class _UpToRows extends StatelessWidget {
  const _UpToRows({required this.selection, required this.onChanged});

  final UpToSelection selection;
  final ValueChanged<UpToSelection> onChanged;

  @override
  Widget build(BuildContext context) => ListView.builder(
    key: const Key('upToPickerList'),
    itemCount: selection.rows.length,
    itemBuilder: (context, i) =>
        _UpToRowTile(index: i, selection: selection, onChanged: onChanged),
  );
}

class _UpToRowTile extends ConsumerWidget {
  const _UpToRowTile({
    required this.index,
    required this.selection,
    required this.onChanged,
  });

  final int index;
  final UpToSelection selection;
  final ValueChanged<UpToSelection> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final row = selection.rows[index];
    final label = ref.watch(upToLeafLabelProvider(row.ref));
    final status = selection.statusOf(index);
    final isTarget = selection.target == index;
    final selectable = selection.isSelectable(index);
    final statusText = switch (status) {
      UpToRowStatus.included => l10n.upToPickerStatusIncluded,
      UpToRowStatus.skipped => l10n.upToPickerStatusSkipped,
      UpToRowStatus.nextUp => l10n.upToPickerStatusNextUp,
      UpToRowStatus.alreadyRecorded => l10n.upToPickerStatusAlreadyRecorded,
      UpToRowStatus.notSelected => l10n.upToPickerStatusNotSelected,
    };
    final ticked =
        status == UpToRowStatus.included ||
        status == UpToRowStatus.alreadyRecorded;
    final muted = !selectable || status == UpToRowStatus.skipped;
    return Semantics(
      key: Key('upToRow-$index'),
      container: true,
      button: selectable,
      enabled: selectable,
      selected: isTarget,
      checked: selectable ? ticked : null,
      label: isTarget
          ? l10n.upToPickerRowTargetSemantics(label, statusText)
          : l10n.upToPickerRowSemantics(label, statusText),
      // The row announces itself as its tick, so a screen-reader activation
      // does what the tick does (AC-2, AC-8): inside the run it skips or
      // re-ticks the row, outside it makes the row the last one learnt.
      // Cutting the run short at a row already inside it is a custom
      // action, as the row's visible tap does.
      onTap: selectable ? () => onChanged(selection.tick(index)) : null,
      customSemanticsActions: selectable && selection.inRun(index) && !isTarget
          ? {
              CustomSemanticsAction(
                label: l10n.upToPickerSetTargetAction,
              ): () =>
                  onChanged(selection.selectTarget(index)),
            }
          : null,
      excludeSemantics: true,
      child: Material(
        color: isTarget ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: selectable
              ? () => onChanged(selection.selectTarget(index))
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Checkbox(
                    key: Key('upToRowTick-$index'),
                    value: ticked,
                    onChanged: selectable
                        ? (_) => onChanged(selection.tick(index))
                        : null,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isTarget ? FontWeight.w700 : null,
                        color: isTarget
                            ? scheme.onPrimaryContainer
                            : muted
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                        decoration: status == UpToRowStatus.skipped
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
                if (status == UpToRowStatus.alreadyRecorded ||
                    status == UpToRowStatus.nextUp ||
                    status == UpToRowStatus.skipped)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 8,
                      end: 12,
                    ),
                    child: Text(
                      statusText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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

/// The Up to… text button of a row or the today list (UX-DR-17): at least
/// 48dp, and it takes focus back when the picker it opened closes
/// (UX-DR-160). Disabled when [onOpen] is null (40% opacity, announced
/// disabled).
class UpToActionButton extends StatefulWidget {
  /// Creates the button.
  const UpToActionButton({
    super.key,
    required this.semanticsLabel,
    required this.onOpen,
    this.label,
  });

  /// The screen-reader label ("Record up to, School").
  final String semanticsLabel;

  /// The visible label; "Up to…" when null.
  final String? label;

  /// Opens the picker and completes when it closes; null disables.
  final Future<void> Function()? onOpen;

  @override
  State<UpToActionButton> createState() => _UpToActionButtonState();
}

class _UpToActionButtonState extends State<UpToActionButton> {
  final _focus = FocusNode(debugLabel: 'upToAction');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    await widget.onOpen?.call();
    if (mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onOpen != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Semantics(
        label: widget.semanticsLabel,
        button: true,
        enabled: enabled,
        excludeSemantics: true,
        onTap: enabled ? _open : null,
        child: TextButton(
          focusNode: _focus,
          style: TextButton.styleFrom(
            foregroundColor: context.colors.brandBlue,
            minimumSize: const Size(48, 48),
          ),
          onPressed: enabled ? _open : null,
          child: Text(
            widget.label ?? AppLocalizations.of(context)!.upToPickerAction,
          ),
        ),
      ),
    );
  }
}
