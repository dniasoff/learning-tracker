/// The sub-track detail's "Ground (in order)" list (Story 2.6 / DNI-497,
/// AC-3 to AC-7).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_ground_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_ground_row.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The ground of [detail] in stored entry order, as the engine expands it.
///
/// Each stored entry is one tri-state row; a non-leaf row expands into its
/// ContentIndex children (indented 20dp per depth), a leaf's label opens
/// its history through [onOpenLeaf]. A groundless sub-track shows the
/// groundless state (UX-DR-122); the detail screen puts *+ Add ground*
/// (Story 2.7 / DNI-498) under it.
///
/// The parent ([SubTrackDetail.canEdit]) also gets, per entry, a drag
/// handle and a ⋮ menu with *Move up*, *Move down* (the non-drag
/// equivalents, UX-DR-155) and *Remove from {name}* (confirmed). Each
/// committed change goes through [subTrackGroundEditorProvider]; a
/// rejected one rolls back with a snackbar (UX-DR-124). The child and
/// tutor get neither control (AC-7).
class SubTrackGroundTree extends ConsumerStatefulWidget {
  /// Creates the tree.
  const SubTrackGroundTree({
    super.key,
    required this.detail,
    required this.onOpenLeaf,
  });

  /// The detail to render.
  final SubTrackDetail detail;

  /// Opens the Mishna history of a leaf (Story 1.13).
  final ValueChanged<LeafRef> onOpenLeaf;

  @override
  ConsumerState<SubTrackGroundTree> createState() => _SubTrackGroundTreeState();
}

class _SubTrackGroundTreeState extends ConsumerState<SubTrackGroundTree> {
  /// Expanded rows by `depth:ref`.
  final Set<String> _expanded = {};

  static String _key(SubTrackGroundRow row) => '${row.depth}:${row.node.ref}';

  void _toggle(SubTrackGroundRow row) => setState(() {
    final key = _key(row);
    if (!_expanded.remove(key)) _expanded.add(key);
  });

  List<NodeEntry> get _order => [
    for (final row in widget.detail.ground.entries) row.node,
  ];

  /// Moves entry [from] to index [to] (already adjusted for the removal).
  void _move(int from, int to) {
    if (from == to) return;
    final next = [..._order];
    next.insert(to, next.removeAt(from));
    unawaited(_commit(next, removal: false));
  }

  Future<void> _remove(SubTrackGroundRow row) async {
    final l10n = AppLocalizations.of(context)!;
    final name = widget.detail.track.name;
    final node = ref.read(subTrackRefLabelProvider(row.node.ref));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.subTrackDetailRemoveTitle(node, name)),
        content: Text(l10n.subTrackDetailRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('subTrackRemoveConfirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.subTrackDetailRemoveConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final next = [..._order]..removeAt(row.entryIndex!);
    await _commit(next, removal: true);
  }

  Future<void> _commit(List<NodeEntry> next, {required bool removal}) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final accepted = await ref
        .read(subTrackGroundEditorProvider(widget.detail.track.id).notifier)
        .commit(next, prior: _order, removal: removal);
    if (accepted) return;
    _showRolledBack(messenger, l10n, removal: removal);
  }

  static void _showRolledBack(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n, {
    required bool removal,
  }) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          removal
              ? l10n.subTrackDetailRemoveFailed
              : l10n.subTrackDetailReorderFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    // A queued edit the server refused later rolls back with the same
    // snackbar as an immediate refusal (UX-DR-124).
    ref.listen(subTrackGroundEditorProvider(detail.track.id), (prev, next) {
      final rollback = next.rollback;
      if (rollback == null ||
          next.lateRejections <= (prev?.lateRejections ?? 0)) {
        return;
      }
      _showRolledBack(
        ScaffoldMessenger.of(context),
        AppLocalizations.of(context)!,
        removal: rollback.removal,
      );
    });
    final ground = detail.ground;
    if (ground.isGroundless) return const _GroundlessState();
    if (!detail.canEdit) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in ground.entries) ..._block(ground, entry),
        ],
      );
    }
    final busy = ref.watch(subTrackGroundEditorProvider(detail.track.id)).busy;
    final count = ground.entries.length;
    return ReorderableListView.builder(
      key: const ValueKey('subTrackGroundReorderable'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: count,
      onReorderItem: busy ? (_, _) {} : _move,
      itemBuilder: (context, i) {
        final entry = ground.entries[i];
        return Column(
          key: ValueKey('subTrackGroundEntry:${entry.node.ref}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _block(
            ground,
            entry,
            leading: _DragHandle(row: entry, index: i, enabled: !busy),
            trailing: _EntryMenu(
              row: entry,
              trackName: detail.track.name,
              enabled: !busy,
              canMoveUp: i > 0,
              canMoveDown: i < count - 1,
              onMoveUp: () => _move(i, i - 1),
              onMoveDown: () => _move(i, i + 1),
              onRemove: () => unawaited(_remove(entry)),
            ),
          ),
        );
      },
    );
  }

  /// [row] and, when expanded, its descendants. Only an entry row carries
  /// the parent's [leading] / [trailing] controls.
  List<Widget> _block(
    SubTrackGroundProjection ground,
    SubTrackGroundRow row, {
    Widget? leading,
    Widget? trailing,
  }) {
    final expanded = _expanded.contains(_key(row));
    return [
      SubTrackGroundRowTile(
        row: row,
        expanded: expanded,
        onToggle: () => _toggle(row),
        onOpenLeaf: () => widget.onOpenLeaf(row.node.ref),
        leading: leading,
        trailing: trailing,
      ),
      if (expanded)
        for (final child in ground.childrenOf(row)) ..._block(ground, child),
    ];
  }
}

/// The entry's drag handle (48dp target), announced as "Reorder {node}".
class _DragHandle extends ConsumerWidget {
  const _DragHandle({
    required this.row,
    required this.index,
    required this.enabled,
  });

  final SubTrackGroundRow row;
  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = AppLocalizations.of(context)!.subTrackDetailDragHandle(
      ref.watch(subTrackRefLabelProvider(row.node.ref)),
    );
    return ReorderableDragStartListener(
      key: ValueKey('subTrackDragHandle:${row.node.ref}'),
      index: index,
      enabled: enabled,
      child: Semantics(
        container: true,
        label: label,
        excludeSemantics: true,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            Icons.drag_indicator,
            color: context.colors.brandInkMuted,
          ),
        ),
      ),
    );
  }
}

enum _EntryAction { moveUp, moveDown, remove }

/// The entry's ⋮ menu: the drag-equivalent moves and the removal.
class _EntryMenu extends ConsumerWidget {
  const _EntryMenu({
    required this.row,
    required this.trackName,
    required this.enabled,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final SubTrackGroundRow row;
  final String trackName;
  final bool enabled;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final node = ref.watch(subTrackRefLabelProvider(row.node.ref));
    return PopupMenuButton<_EntryAction>(
      key: ValueKey('subTrackEntryMenu:${row.node.ref}'),
      enabled: enabled,
      tooltip: l10n.subTrackDetailEntryActions(node),
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => switch (action) {
        _EntryAction.moveUp => onMoveUp(),
        _EntryAction.moveDown => onMoveDown(),
        _EntryAction.remove => onRemove(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const ValueKey('subTrackMoveUp'),
          value: _EntryAction.moveUp,
          enabled: canMoveUp,
          child: Text(l10n.subTrackDetailMoveUp),
        ),
        PopupMenuItem(
          key: const ValueKey('subTrackMoveDown'),
          value: _EntryAction.moveDown,
          enabled: canMoveDown,
          child: Text(l10n.subTrackDetailMoveDown),
        ),
        PopupMenuItem(
          key: const ValueKey('subTrackRemove'),
          value: _EntryAction.remove,
          child: Text(l10n.subTrackDetailRemoveFrom(trackName)),
        ),
      ],
    );
  }
}

/// The groundless state: the list is empty and says so.
class _GroundlessState extends StatelessWidget {
  const _GroundlessState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const ValueKey('subTrackGroundless'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: colors.brandCreamCard,
        border: Border.all(color: colors.brandOutline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.layers_clear_outlined, color: colors.brandInkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.subTrackDetailGroundEmpty,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.brandInkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
