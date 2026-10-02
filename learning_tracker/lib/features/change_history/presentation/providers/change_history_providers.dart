/// Riverpod wiring of the parent Change history (Story 4.5 / DNI-513).
///
/// - [changeHistoryAccessProvider]: the parent role (AC-1) — an own,
///   non-tutored session whose parent PIN is unlocked for the active
///   profile. The screen reads nothing without it.
/// - [changeHistoryControllerProvider]: per-learner paging state over a
///   [ChangeHistoryPager]; filter, lazy "load more" and retry.
///   Keyed by [LearnerScope], so switching learner starts a fresh history
///   and the previous learner's rows are never shown for the new one.
/// - [changeHistoryViewProvider]: the rows of the loaded pages under the
///   chosen filter, judged with the learner's settings history (time zone
///   and locks, AD-36/AD-41).
/// - [changeHistoryUndoHandlerProvider]: the Story 4.6 seam. Null here, so
///   no Undo control is shown until 4.6 supplies the action.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_filter.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/change_history/data/repositories/change_history_sources.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_filter.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_row.dart';
import 'package:learning_tracker/features/change_history/domain/services/change_history_merge.dart';
import 'package:learning_tracker/features/change_history/domain/services/change_history_pager.dart';
import 'package:learning_tracker/features/change_history/domain/services/change_history_row_mapper.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// Rows asked for before the first scroll, and added per "load more".
const int kChangeHistoryViewStep = 30;

/// Whether the parent role is active for the active learner: not a
/// tutored session, and the parent PIN unlocked for that profile.
final changeHistoryAccessProvider = Provider.autoDispose<bool>((ref) {
  if (ref.watch(activeTutoredProfileSelectionProvider) != null) return false;
  final active = ref.watch(activeProfileIdProvider);
  final unlocked = ref.watch(parentPinAuthenticatedProfileIdProvider);
  return active != null && unlocked == active;
});

/// The clock day headers compare against ("Today", "Yesterday").
final changeHistoryClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Whether the history must be unreadable now (AD-36, E-4): the device's
/// sacred-time window, or the learner's own lock judged by [lockWindows]
/// with the learner's settings history. Loading or failing while the
/// learner's settings are unknown (fail closed).
final changeHistoryLockedProvider = Provider.autoDispose
    .family<AsyncValue<bool>, LearnerScope>((ref, scope) {
      if (ref.watch(currentSacredWindowProvider) != null) {
        return const AsyncData(true);
      }
      final now = ref.watch(changeHistoryClockProvider)().toUtc();
      return ref
          .watch(learnerLockSettingsProvider(scope))
          .whenData((h) => insideLock(lockWindows(h, now, now), now));
    });

/// The display label of a content ref (falls back to the ref itself).
final changeHistoryRefLabelProvider = FutureProvider.autoDispose
    .family<String, String>(
      (ref, sefariaRef) =>
          ref.watch(renderedDisplayForRefProvider(sefariaRef).future),
    );

/// Performs Undo of a row (Story 4.6). Null: Undo is not offered.
typedef ChangeHistoryUndoHandler = Future<void> Function(ChangeHistoryRow row);

/// The Story 4.6 Undo seam; null until that story supplies it.
final changeHistoryUndoHandlerProvider = Provider<ChangeHistoryUndoHandler?>(
  (ref) => null,
);

/// Paging state of one learner's history.
final class ChangeHistoryState {
  /// Creates a state.
  const ChangeHistoryState({
    required this.filter,
    required this.target,
    this.buffer,
    this.revision = 0,
    this.loading = false,
    this.error,
    this.stackTrace,
  });

  /// The chosen chip.
  final ChangeHistoryFilter filter;

  /// Rows the filtered view should hold before paging stops.
  final int target;

  /// The pages read so far (null until the repository is ready).
  final ChangeHistoryBuffer? buffer;

  /// Bumped whenever [buffer] changes.
  final int revision;

  /// Whether a page read is in flight.
  final bool loading;

  /// The last read failure, until a retry.
  final Object? error;

  /// Its stack trace.
  final StackTrace? stackTrace;

  /// Whether both first pages have been read.
  bool get started => buffer?.started ?? false;

  /// Whether both sources are read to their end.
  bool get exhausted => buffer?.exhausted ?? false;

  ChangeHistoryState _copy({
    ChangeHistoryFilter? filter,
    int? target,
    ChangeHistoryBuffer? buffer,
    bool? loading,
    Object? error,
    StackTrace? stackTrace,
    bool clearError = false,
    bool bump = false,
  }) => ChangeHistoryState(
    filter: filter ?? this.filter,
    target: target ?? this.target,
    buffer: buffer ?? this.buffer,
    revision: bump ? revision + 1 : revision,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    stackTrace: clearError ? null : (stackTrace ?? this.stackTrace),
  );
}

/// Pages and filters one learner's history.
class ChangeHistoryController extends Notifier<ChangeHistoryState> {
  /// Creates the controller for [scope].
  ChangeHistoryController(this.scope);

  /// The learner.
  final LearnerScope scope;

  ChangeHistoryPager? _pager;
  Future<void>? _filling;
  bool _again = false;

  @override
  ChangeHistoryState build() {
    _pager = null;
    _filling = null;
    const initial = ChangeHistoryState(
      filter: ChangeHistoryFilter.all,
      target: kChangeHistoryViewStep,
      loading: true,
    );
    final repository = ref.watch(changeHistoryRepositoryProvider);
    switch (repository) {
      case AsyncData(value: final repo?):
        final pager = ChangeHistoryPager(repository: repo, scope: scope);
        _pager = pager;
        scheduleMicrotask(_fill);
        return initial._copy(buffer: pager.buffer);
      case AsyncError(:final error, :final stackTrace):
        return initial._copy(
          loading: false,
          error: error,
          stackTrace: stackTrace,
        );
      default:
        return initial; // not ready yet: loading
    }
  }

  /// Shows only rows passing [filter], paging further if it needs more.
  void setFilter(ChangeHistoryFilter filter) {
    if (filter == state.filter) return;
    state = state._copy(filter: filter, target: kChangeHistoryViewStep);
    unawaited(_fill());
  }

  /// The merged list reached its end: ask for more rows.
  void loadMore() {
    if (state.exhausted || state.loading || state.error != null) return;
    state = state._copy(target: state.target + kChangeHistoryViewStep);
    unawaited(_fill());
  }

  /// Retries the failed read (the same page; no row is duplicated).
  void retry() {
    if (_pager == null) {
      ref.invalidate(changeHistoryRepositoryProvider);
      return;
    }
    state = state._copy(clearError: true);
    unawaited(_fill());
  }

  Future<void> _fill() {
    final running = _filling;
    if (running != null) {
      _again = true;
      return running;
    }
    final run = _run();
    _filling = run;
    return run.whenComplete(() {
      // A rebuild may have started a newer run meanwhile; keep it.
      if (identical(_filling, run)) _filling = null;
    });
  }

  Future<void> _run() async {
    final pager = _pager;
    if (pager == null) return;
    do {
      _again = false;
      if (!ref.mounted) return;
      state = state._copy(loading: true, clearError: true);
      final filter = state.filter;
      final target = state.target;
      try {
        await pager.fill(
          (visible) => visible.where(filter.acceptsItem).length >= target,
        );
        if (!ref.mounted || !identical(_pager, pager)) return;
        state = state._copy(loading: false, bump: true);
      } on Object catch (error, stackTrace) {
        if (!ref.mounted || !identical(_pager, pager)) return;
        state = state._copy(
          loading: false,
          error: error,
          stackTrace: stackTrace,
          bump: true,
        );
        return;
      }
    } while (_again);
  }
}

/// The paging controller of each learner's history.
final changeHistoryControllerProvider = NotifierProvider.autoDispose
    .family<ChangeHistoryController, ChangeHistoryState, LearnerScope>(
      ChangeHistoryController.new,
    );

/// The selected row of one learner's history (the details pane).
class ChangeHistorySelection extends Notifier<String?> {
  @override
  String? build() => null;

  /// Selects the row with [key] (null clears).
  void select(String? key) => state = key;
}

/// The selected row key of each learner's history.
final changeHistorySelectionProvider = NotifierProvider.autoDispose
    .family<ChangeHistorySelection, String?, LearnerScope>(
      (scope) => ChangeHistorySelection(),
    );

/// Today's sub-track names of [LearnerScope] (empty while unavailable;
/// names at event time come from the change log first).
final changeHistorySubTrackNamesProvider = StreamProvider.autoDispose
    .family<Map<String, String>, LearnerScope>((ref, scope) async* {
      final repo = await ref.watch(subTrackRepositoryProvider.future);
      if (repo == null) return;
      await for (final read in repo.watchAll(scope)) {
        if (read case CompleteReadReady<SubTrack>(:final items)) {
          yield {for (final s in items) s.id: s.name};
        }
      }
    }, retry: (retryCount, error) => null);

/// What the screen shows for one learner.
final class ChangeHistoryView {
  /// Creates a view.
  ChangeHistoryView({
    required List<ChangeHistoryRow> rows,
    required this.hasAnyRows,
    required this.filter,
    required this.loadingMore,
    required this.exhausted,
    required this.settingsHistory,
    this.pageError,
    this.pageErrorStack,
  }) : rows = List.unmodifiable(rows);

  /// The filtered rows, newest first.
  final List<ChangeHistoryRow> rows;

  /// Whether any row is loaded under any filter.
  final bool hasAnyRows;

  /// The chosen chip.
  final ChangeHistoryFilter filter;

  /// A further page is being read.
  final bool loadingMore;

  /// Both sources are read to their end.
  final bool exhausted;

  /// The learner's settings history (for "today").
  final LearnerSettingsHistory settingsHistory;

  /// A failed further-page read (loaded rows stay).
  final Object? pageError;

  /// Its stack trace.
  final StackTrace? pageErrorStack;

  /// The row with [key], when it is in [rows].
  ChangeHistoryRow? rowWithKey(String? key) {
    for (final r in rows) {
      if (r.key == key) return r;
    }
    return null;
  }
}

/// The view of [LearnerScope]'s history: loading until the first pages
/// and the settings history are in; an error when either first read
/// fails.
final changeHistoryViewProvider = Provider.autoDispose
    .family<AsyncValue<ChangeHistoryView>, LearnerScope>((ref, scope) {
      final state = ref.watch(changeHistoryControllerProvider(scope));
      final settings = ref.watch(learnerLockSettingsProvider(scope));
      final names =
          ref.watch(changeHistorySubTrackNamesProvider(scope)).asData?.value ??
          const <String, String>{};
      final buffer = state.buffer;
      if (!state.started || buffer == null) {
        final error = state.error;
        if (error != null) {
          return AsyncError(error, state.stackTrace ?? StackTrace.empty);
        }
        return const AsyncLoading();
      }
      return switch (settings) {
        AsyncError(:final error, :final stackTrace) => AsyncError(
          error,
          stackTrace,
        ),
        AsyncData(:final value) => AsyncData(
          _view(state, buffer, value, names),
        ),
        _ => const AsyncLoading(),
      };
    });

ChangeHistoryView _view(
  ChangeHistoryState state,
  ChangeHistoryBuffer buffer,
  LearnerSettingsHistory settings,
  Map<String, String> names,
) {
  final visible = buffer.visibleItems();
  final shown = [
    for (final item in visible)
      if (state.filter.acceptsItem(item)) item,
  ];
  final rows = ChangeHistoryRowMapper(
    settingsHistory: settings,
    currentSubTrackNames: names,
  ).map(shown, buffer);
  return ChangeHistoryView(
    rows: rows,
    hasAnyRows: visible.isNotEmpty,
    filter: state.filter,
    loadingMore: state.loading,
    exhausted: state.exhausted,
    settingsHistory: settings,
    pageError: state.error,
    pageErrorStack: state.stackTrace,
  );
}
