/// My talmidim: every learner whose parent gave the tutor access, with
/// each one's standing (Story 4.3, DNI-511; FR-29, screen #11, UX-DR-39,
/// UX-DR-58, UX-DR-134, UX-DR-135).
///
/// The roster is the live set of ACTIVE grants ([talmidRosterProvider]):
/// re-read on every visit, on pull-to-refresh, and as soon as one row
/// reports its access ended, so a revoked learner leaves the list. Rows
/// are built lazily, and each row runs its learner's engine only while it
/// is built (AD-35 "Tutor list"). The list ends with the access note.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/core/widgets/info_note.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/talmid_row_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_context_opener.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_roster_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_row_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/talmid_row_card.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart'
    show TutorDisabledControl;
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The window width from which the roster and the selected learner sit
/// side by side (AC-8, UX-DR-162).
const double talmidimSplitBreakpoint = 840;

/// The tutor's My talmidim screen.
@RoutePage()
class MyTalmidimScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const MyTalmidimScreen({super.key});

  @override
  ConsumerState<MyTalmidimScreen> createState() => _MyTalmidimScreenState();
}

class _MyTalmidimScreenState extends ConsumerState<MyTalmidimScreen> {
  /// The tablet pane's selection, by grant id.
  String? _selectedGrantId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roster = ref.watch(talmidRosterProvider);
    return Scaffold(
      backgroundColor: context.colors.brandCream,
      appBar: AppBar(
        title: Text(l10n.talmidimTitle),
        backgroundColor: context.colors.brandCream,
        elevation: 0,
      ),
      body: SafeArea(
        child: roster.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => AppErrorView(
            key: const Key('talmidimError'),
            error: error,
            stackTrace: stackTrace,
            onRetry: () => ref.invalidate(talmidRosterProvider),
          ),
          data: (entries) => entries.isEmpty
              ? const _EmptyRoster()
              : LayoutBuilder(
                  builder: (context, constraints) =>
                      constraints.maxWidth >= talmidimSplitBreakpoint
                      ? _split(entries)
                      : TalmidRosterList(entries: entries),
                ),
        ),
      ),
    );
  }

  /// The tablet composition: the list (5 columns) beside the selected
  /// learner (7 columns). The selection is kept by grant id while that
  /// grant stays on the roster, and cleared the moment it leaves.
  Widget _split(List<TalmidRosterEntry> entries) {
    TalmidRosterEntry? selected;
    for (final entry in entries) {
      if (entry.grantId == _selectedGrantId) selected = entry;
    }
    if (selected == null && _selectedGrantId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedGrantId != null) {
          setState(() => _selectedGrantId = null);
        }
      });
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: TalmidRosterList(
            entries: entries,
            selectedGrantId: selected?.grantId,
            onSelect: (entry) =>
                setState(() => _selectedGrantId = entry.grantId),
          ),
        ),
        VerticalDivider(width: 1, color: context.colors.brandOutline),
        Expanded(
          flex: 7,
          child: selected == null
              ? const _NoSelection()
              : TalmidDetailPane(
                  key: ValueKey('talmidDetail-${selected.grantId}'),
                  entry: selected,
                ),
        ),
      ],
    );
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        AppLocalizations.of(context)!.talmidimSelectPrompt,
        key: const Key('talmidimSelectPrompt'),
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: context.colors.brandInkMuted),
      ),
    ),
  );
}

/// The tablet pane of the selected talmid: his standing, *Add ground* on a
/// groundless track, and *Open {name}* through the tutor PIN gate. A
/// learner who becomes locked shows only "Shabbos / Yom Tov" here too.
class TalmidDetailPane extends ConsumerWidget {
  /// Creates the pane for [entry].
  const TalmidDetailPane({super.key, required this.entry});

  /// The selected roster entry.
  final TalmidRosterEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final theme = Theme.of(context);
    final row = watchTalmidRow(ref, entry);
    if (!row.identityVisible) {
      return Center(
        child: Text(
          row is TalmidRowLocked ? l10n.talmidimLocked : l10n.onTrackLoading,
          key: const Key('talmidDetailRedacted'),
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.brandInkMuted,
          ),
        ),
      );
    }
    final name = talmidName(l10n, entry);
    final ready = row is TalmidRowReady ? row : null;
    final status = ready?.status;
    final line = ready?.line;
    final addGroundEnabled = talmidAddGroundEnabled(ref, entry);
    final opener = ref.read(talmidContextOpenerProvider);
    return ListView(
      key: const Key('talmidDetailPane'),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colors.brandBlueSoft,
              child: Text(
                talmidInitials(name),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.brandBlueDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    key: const Key('talmidDetailName'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.brandInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 6),
                    TalmidStatusChip(status: status),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (line != null) ...[
          const SizedBox(height: 20),
          Text(
            talmidLineText(ref, l10n, line),
            key: const Key('talmidDetailLine'),
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.brandInk),
          ),
        ],
        if (line is TalmidTrackNoGround) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TutorDisabledControl(
              blocked: !addGroundEnabled,
              child: TextButton.icon(
                key: const Key('talmidDetailAddGround'),
                onPressed: addGroundEnabled
                    ? () => opener.open(
                        context,
                        entry,
                        groundSubTrackId: line.subTrackId,
                      )
                    : null,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.subTrackHomeAddGround),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            key: const Key('talmidDetailOpen'),
            onPressed: row.opensLearner
                ? () => opener.open(context, entry)
                : null,
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(l10n.talmidimOpen(name)),
          ),
        ),
      ],
    );
  }
}

class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          l10n.talmidimEmpty,
          key: const Key('talmidimEmpty'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.colors.brandInkMuted),
        ),
      ),
    );
  }
}

/// The lazily built roster: one [TalmidRow] per entry, then the access note.
class TalmidRosterList extends ConsumerWidget {
  /// Creates the list.
  const TalmidRosterList({
    super.key,
    required this.entries,
    this.selectedGrantId,
    this.onSelect,
  });

  /// The active grants, in roster order.
  final List<TalmidRosterEntry> entries;

  /// The tablet pane's selection, if any.
  final String? selectedGrantId;

  /// Selects a row in place (tablet); null on a phone, where a tap opens.
  final ValueChanged<TalmidRosterEntry>? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(talmidRosterProvider.future),
      child: ListView.builder(
        key: const Key('talmidimList'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: entries.length + 1,
        itemBuilder: (context, index) {
          if (index == entries.length) {
            // The access reminder: static text, never a focus stop.
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ExcludeFocus(
                child: InfoNote(
                  key: const Key('talmidimAccessNote'),
                  text: l10n.talmidimAccessNote,
                ),
              ),
            );
          }
          final entry = entries[index];
          return Padding(
            key: ValueKey(entry.grantId),
            padding: const EdgeInsets.only(bottom: 10),
            child: TalmidRow(
              entry: entry,
              selected: entry.grantId == selectedGrantId,
              onSelect: onSelect,
            ),
          );
        },
      ),
    );
  }
}

/// The row state of [entry]: its engine projection, or a failed row when
/// the grant names no addressable learner.
TalmidRowState watchTalmidRow(WidgetRef ref, TalmidRosterEntry entry) {
  final scope = entry.scope;
  if (scope == null) {
    return const TalmidRowFailed(
      TalmidRowFailure.invalidLearner,
      identityVisible: true,
    );
  }
  return ref.watch(talmidRowStateProvider(scope));
}

/// Whether *Add ground* may be used for [entry] now: the grant's
/// `can_edit_learning` and a positive connectivity probe (AC-3; tutor
/// writes are online-only, AD-53).
bool talmidAddGroundEnabled(WidgetRef ref, TalmidRosterEntry entry) =>
    entry.canEditLearning &&
    ref.watch(connectivityStreamProvider).value == true;

/// One roster row, wired to its learner's row state and actions.
class TalmidRow extends ConsumerStatefulWidget {
  /// Creates the row.
  const TalmidRow({
    super.key,
    required this.entry,
    this.selected = false,
    this.onSelect,
  });

  /// The roster entry.
  final TalmidRosterEntry entry;

  /// Whether the tablet pane shows this row.
  final bool selected;

  /// Selects in place (tablet); null on a phone.
  final ValueChanged<TalmidRosterEntry>? onSelect;

  @override
  ConsumerState<TalmidRow> createState() => _TalmidRowState();
}

class _TalmidRowState extends ConsumerState<TalmidRow> {
  /// The roster was asked to re-read for this row's ended access; asked
  /// once per row, so a lagging grant list cannot cause a refresh loop.
  bool _rosterRefreshRequested = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final scope = entry.scope;
    final row = watchTalmidRow(ref, entry);
    if (row case TalmidRowFailed(reason: TalmidRowFailure.accessEnded)) {
      // A revoked grant: re-read the roster once, so the row leaves.
      if (!_rosterRefreshRequested) {
        _rosterRefreshRequested = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.invalidate(talmidRosterProvider);
        });
      }
      return const SizedBox.shrink();
    }
    final line = row is TalmidRowReady ? row.line : null;
    final select = widget.onSelect;
    return TalmidRowCard(
      entry: entry,
      row: row,
      selected: widget.selected,
      addGroundEnabled: talmidAddGroundEnabled(ref, entry),
      onOpen: select != null
          ? () => select(entry)
          : () => ref.read(talmidContextOpenerProvider).open(context, entry),
      onAddGround: line is TalmidTrackNoGround
          ? () => ref
                .read(talmidContextOpenerProvider)
                .open(context, entry, groundSubTrackId: line.subTrackId)
          : null,
      onRetry: scope == null
          ? null
          : () => ref.read(talmidRowTimedOutProvider(scope).notifier).retry(),
    );
  }
}
