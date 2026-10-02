/// One Learn-tab sub-track row (Story 2.10, DNI-501; UX-DR-16, UX-DR-17).
///
/// DNI-500 SEAM: Story 2.9 (DNI-500) owns the Learn-tab row, its +1, its
/// role states and its detail navigation; it did not land on
/// `integ/sub-tracks`. This minimal row exists so the Up to… action has a
/// home. It shows the name and "Next: …" (or the groundless / all-recorded
/// state), then exactly *Up to…* and *+1*, both at least 48dp, with no
/// source, rate or pace badge. When DNI-500 lands it replaces this row and
/// keeps [UpToActionButton] + `openSubTrackUpTo` as its Up to… action
/// (follow-up bead recorded in the DNI-501 summary).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/on_home_sub_tracks.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/up_to_selection_service.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/up_to_picker.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// A sub-track row: name, position and its two capture actions.
class SubTrackRow extends ConsumerWidget {
  /// Creates the row.
  const SubTrackRow({
    super.key,
    required this.item,
    required this.position,
    this.onUpTo,
    this.onPlusOne,
  });

  /// The sub-track and its engine state.
  final OnHomeSubTrack item;

  /// The position this device shows (the engine's, moved on by pending
  /// captures); null when the ground is all recorded or there is none.
  final LeafRef? position;

  /// Opens the Up to… picker; null disables the action (tutor, groundless).
  final Future<void> Function()? onUpTo;

  /// Records the position; null disables the action.
  final VoidCallback? onPlusOne;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final name = item.track.name;
    final at = position;
    final groundless = isGroundless(item.state);
    final positionLabel = at == null
        ? null
        : ref.watch(upToLeafLabelProvider(at));
    final status = groundless
        ? l10n.subTrackRowNoGround
        : positionLabel == null
        ? l10n.subTrackRowAllRecorded
        : l10n.subTrackRowNext(positionLabel);
    final units = ref.watch(upToUnitLabelsProvider(item.curriculumId));
    final canPlusOne = onPlusOne != null && at != null;
    return Container(
      key: Key('subTrackRow-${item.id}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: positionLabel == null
                ? l10n.upToPickerRowSemantics(name, status)
                : l10n.subTrackRowSemantics(name, positionLabel),
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  key: Key('subTrackRowStatus-${item.id}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              UpToActionButton(
                key: Key('subTrackUpTo-${item.id}'),
                semanticsLabel: l10n.upToPickerActionSemantics(name),
                onOpen: groundless ? null : onUpTo,
              ),
              Opacity(
                opacity: canPlusOne ? 1 : 0.4,
                child: Semantics(
                  label: l10n.subTrackRowPlusOneSemantics(units.one, name),
                  button: true,
                  enabled: canPlusOne,
                  excludeSemantics: true,
                  onTap: canPlusOne ? onPlusOne : null,
                  child: FilledButton(
                    key: Key('subTrackPlusOne-${item.id}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.brandBlue,
                      minimumSize: const Size(48, 48),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: canPlusOne ? onPlusOne : null,
                    child: Text(l10n.subTrackRowPlusOne),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
