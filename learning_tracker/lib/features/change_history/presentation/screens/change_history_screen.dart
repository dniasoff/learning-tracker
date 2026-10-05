/// Settings (parent) → Change history (Story 4.5 / DNI-513; screen #12).
///
/// A NEW parent-scoped timeline of every change to the active learner's
/// tracks, goals and learning — by the parent, the child and every tutor.
/// It is not the per-grant `/tutor/audit-log`.
///
/// - Parent role only (AC-1): outside an own session with the parent PIN
///   unlocked for the active profile the screen reads nothing and says so,
///   even when opened by a deep link the route guards somehow let through.
/// - Covered by the app-wide [SacredTimeLockOverlay] (E-4): during a lock
///   nothing of the timeline is readable.
/// - Rows group under learner-time-zone day headers (AD-41), behind the
///   All · Tutor · Parent · Learning chips (AC-8). Reaching the end of the
///   list reads the next page (AD-38); a failed read shows [AppErrorView]
///   with retry and keeps the loaded rows (AC-9).
/// - At ≥ 840dp the timeline and the selected change's details sit side by
///   side, list first in focus order (AC-10, UX-DR-160/164); below, a tap
///   opens the details in a sheet.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/change_history/data/repositories/change_history_sources.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_filter.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_row.dart';
import 'package:learning_tracker/features/change_history/presentation/providers/change_history_providers.dart';
import 'package:learning_tracker/features/change_history/presentation/widgets/change_history_details.dart';
import 'package:learning_tracker/features/change_history/presentation/widgets/change_history_row_tile.dart';
import 'package:learning_tracker/features/change_history/presentation/widgets/change_history_text.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The width from which details sit beside the timeline (UX-DR-164).
const double kChangeHistoryTwoPaneWidth = 840;

/// The parent Change history of the active learner.
@RoutePage()
class ChangeHistoryScreen extends ConsumerWidget {
  /// Creates the screen.
  const ChangeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return SacredTimeLockOverlay(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.changeHistoryTitle)),
        body: const SafeArea(child: _Body()),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (!ref.watch(changeHistoryAccessProvider)) {
      return _Message(l10n.changeHistoryNotAvailable);
    }
    // E-4: nothing of the timeline is built under the device's lock.
    if (ref.watch(currentSacredWindowProvider) != null) {
      return const SizedBox.shrink(key: ValueKey('changeHistoryLocked'));
    }
    return switch (ref.watch(activeLearnerScopeProvider)) {
      AsyncData(value: final scope?) => _History(
        // A new learner is a new history: never the old learner's rows.
        key: ValueKey(scope),
        scope: scope,
      ),
      AsyncError(:final error, :final stackTrace) => AppErrorView(
        error: error,
        stackTrace: stackTrace,
        onRetry: () => ref.invalidate(activeLearnerScopeProvider),
      ),
      _ => const _Loading(),
    };
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: context.colors.brandInkMuted),
      ),
    ),
  );
}

class _History extends ConsumerWidget {
  const _History({required this.scope, super.key});

  final LearnerScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AD-36: an available sacred window or configured-location lock keeps
    // this learner's history covered. Missing or unreadable settings are
    // not a lock; dependent history formatting may still be loading below.
    final locked = ref.watch(changeHistoryLockedProvider(scope));
    if (locked case AsyncError(:final error, :final stackTrace)) {
      return AppErrorView(
        error: error,
        stackTrace: stackTrace,
        onRetry: () => ref.invalidate(learnerLockSettingsProvider(scope)),
      );
    }
    if (locked.value != false) {
      return locked.hasValue
          ? const SizedBox.shrink(key: ValueKey('changeHistoryLocked'))
          : const _Loading();
    }
    return _UnlockedHistory(scope: scope);
  }
}

/// The timeline of an unlocked learner: the only place that creates the
/// paging controller (and so the only place that reads history).
class _UnlockedHistory extends ConsumerWidget {
  const _UnlockedHistory({required this.scope});

  final LearnerScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      changeHistoryControllerProvider(scope).notifier,
    );
    final filter = ref.watch(
      changeHistoryControllerProvider(scope).select((s) => s.filter),
    );
    final view = ref.watch(changeHistoryViewProvider(scope));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterChips(selected: filter, onSelected: controller.setFilter),
        Expanded(
          child: switch (view) {
            AsyncData(:final value) => _Loaded(scope: scope, view: value),
            AsyncError(:final error, :final stackTrace) => AppErrorView(
              error: error,
              stackTrace: stackTrace,
              onRetry: () {
                ref.invalidate(learnerLockSettingsProvider(scope));
                controller.retry();
              },
            ),
            _ => const _Loading(),
          },
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final ChangeHistoryFilter selected;
  final ValueChanged<ChangeHistoryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String label(ChangeHistoryFilter f) => switch (f) {
      ChangeHistoryFilter.all => l10n.changeHistoryFilterAll,
      ChangeHistoryFilter.tutor => l10n.changeHistoryFilterTutor,
      ChangeHistoryFilter.parent => l10n.changeHistoryFilterParent,
      ChangeHistoryFilter.learning => l10n.changeHistoryFilterLearning,
    };
    return Semantics(
      container: true,
      label: l10n.changeHistoryFilterLabel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final f in ChangeHistoryFilter.values)
              ChoiceChip(
                key: ValueKey('changeHistoryFilter.${f.name}'),
                label: Text(label(f)),
                selected: f == selected,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) => onSelected(f),
              ),
          ],
        ),
      ),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.scope, required this.view});

  final LearnerScope scope;
  final ChangeHistoryView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(
      changeHistoryControllerProvider(scope).notifier,
    );
    if (view.rows.isEmpty) {
      if (view.pageError case final error?) {
        return AppErrorView(
          error: error,
          stackTrace: view.pageErrorStack,
          onRetry: controller.retry,
        );
      }
      if (view.exhausted) {
        return _Message(
          view.hasAnyRows
              ? l10n.changeHistoryNoMatches
              : l10n.changeHistoryEmpty,
        );
      }
      // The filter has no row yet in what is loaded; paging continues.
      return const _Loading();
    }
    final selectedKey = ref.watch(changeHistorySelectionProvider(scope));
    final selection = ref.read(changeHistorySelectionProvider(scope).notifier);
    final undo = ref.watch(changeHistoryUndoHandlerProvider);
    VoidCallback? undoOf(ChangeHistoryRow row) =>
        undo == null ? null : () => undo(row);

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= kChangeHistoryTwoPaneWidth;
        final list = _Timeline(
          view: view,
          selectedKey: twoPane ? selectedKey : null,
          onLoadMore: controller.loadMore,
          onRetry: controller.retry,
          undoOf: undoOf,
          onOpen: (row) {
            selection.select(row.key);
            if (!twoPane) {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => FractionallySizedBox(
                  heightFactor: 0.75,
                  child: ChangeHistoryDetails(row: row, onUndo: undoOf(row)),
                ),
              );
            }
          },
        );
        if (!twoPane) return list;
        final selected = view.rowWithKey(selectedKey);
        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: list,
                ),
              ),
              VerticalDivider(width: 1, color: context.colors.brandOutline),
              Expanded(
                flex: 4,
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: KeyedSubtree(
                    key: const ValueKey('changeHistoryDetailPane'),
                    child: selected == null
                        ? _Message(l10n.changeHistorySelectPrompt)
                        : ChangeHistoryDetails(
                            row: selected,
                            onUndo: undoOf(selected),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

sealed class _Entry {
  const _Entry();
}

final class _DayHeader extends _Entry {
  const _DayHeader(this.day, this.count);
  final CivilDate day;
  final int count;
}

final class _RowEntry extends _Entry {
  const _RowEntry(this.row);
  final ChangeHistoryRow row;
}

class _Timeline extends ConsumerWidget {
  const _Timeline({
    required this.view,
    required this.selectedKey,
    required this.onLoadMore,
    required this.onRetry,
    required this.onOpen,
    required this.undoOf,
  });

  final ChangeHistoryView view;
  final String? selectedKey;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final ValueChanged<ChangeHistoryRow> onOpen;
  final VoidCallback? Function(ChangeHistoryRow row) undoOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final formats = ChangeHistoryFormats.of(context);
    final now = ref.watch(changeHistoryClockProvider)().toUtc();
    final today = civilDate(now, view.settingsHistory);
    final yesterday = formatCivilDay(addCivilDays(parseCivilDay(today), -1));

    final counts = <CivilDate, int>{};
    for (final r in view.rows) {
      counts[r.stamp.day] = (counts[r.stamp.day] ?? 0) + 1;
    }
    final entries = <_Entry>[];
    CivilDate? day;
    for (final r in view.rows) {
      if (r.stamp.day != day) {
        day = r.stamp.day;
        entries.add(_DayHeader(day, counts[day]!));
      }
      entries.add(_RowEntry(r));
    }

    String header(_DayHeader h) => [
      if (h.day == today) l10n.changeHistoryDayToday,
      if (h.day == yesterday) l10n.changeHistoryDayYesterday,
      formats.dayDate(h.day),
      l10n.changeHistoryUpdates(h.count),
    ].join(' · ');

    return ListView.builder(
      key: const ValueKey('changeHistoryTimeline'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == entries.length) return _footer(context);
        return switch (entries[index]) {
          _DayHeader() && final h => Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                header(h),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: context.colors.brandInkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _RowEntry(:final row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ChangeHistoryRowTile(
              key: ValueKey(row.key),
              row: row,
              selected: row.key == selectedKey,
              onTap: () => onOpen(row),
              onUndo: undoOf(row),
            ),
          ),
        };
      },
    );
  }

  /// The end of the merged list: a failed page offers retry; otherwise
  /// reaching it reads the next page (AD-38 "fetched only when the merged
  /// list reaches its end").
  Widget _footer(BuildContext context) {
    if (view.pageError case final error?) {
      return AppErrorView(
        key: const ValueKey('changeHistoryPageError'),
        error: error,
        stackTrace: view.pageErrorStack,
        onRetry: onRetry,
      );
    }
    if (view.exhausted) return const SizedBox(height: 8);
    if (!view.loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
