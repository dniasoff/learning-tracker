/// Up to… and +1 capture (Story 2.10, DNI-501; FR-2, FR-2a, AD-31, AD-36,
/// AD-50, AD-54, UX-DR-110, UX-DR-154).
///
/// * [captureLeaves] issues ONE `LearningCommands.capture` for the leaves a
///   picker (or +1) chose: one `dated` learn event per leaf with the track
///   as `source` and `learned_on` = the learner's civil today. The command
///   runs `CaptureGate` first, plans fixed ULIDs reused on retry, adds the
///   AD-50 `pts_` entry to each main event in the same chunk and chunks at
///   ≤ 450 writes (AD-54) — none of that is re-implemented here.
/// * [pendingCapturesProvider] is this device's optimistic overlay: the
///   leaves are marked recorded before the command returns, so the row and
///   the next picker move on in the same frame (UX-DR-154). Undo, a refused
///   capture, or a chunk the server rejects — within the ack window or
///   later (`PendingCaptureRollback`, UX-DR-110) — removes exactly its
///   leaves again; an entry is pruned once the engine counts (or
///   lock-ignores) its events.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/capture_feedback.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/up_to_picker_providers.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Whether the session may write sub-track learning: false on a tutor
/// device (tutor sub-track writes are read-only until a later epic, Story
/// 2.9 AC-9; AC-11). It gates sub-track surfaces only, never main-track
/// capture ([mainTrackCaptureAllowedProvider]).
final subTrackWritesAllowedProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(activeTutoredProfileSelectionProvider) == null,
);

/// Whether the session can capture main-track learning (AC-5): exactly
/// when the active learner has [LearningCommands]; with none the
/// main-track Up to… is absent rather than dead.
///
/// On a tutor device this is false today: the production
/// `learningCommandsProvider` binds no commands in a tutored session,
/// because no tutor capture path exists yet (`TutorWriteService` has no
/// learning methods). Story 1.24 (DNI-486) binds the talmid's tutor
/// commands there, every write a callable (AD-53); this gate then turns
/// the action on with no change here. Until then a tutor has no
/// main-track Up to…, and tutor sub-track surfaces stay read-only either
/// way (AC-11).
final mainTrackCaptureAllowedProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(learningCommandsProvider).asData?.value != null,
);

/// A sub-track a capture or a source correction may name.
typedef SubTrackSourceChoice = ({String id, String name});

/// The sub-track sources offered for [curriculumId] (AC-9, AC-10): its
/// `onHome` sub-tracks by name, in hub order. Empty in a tutored session
/// (AC-11) and while the list is loading or failed — Home and Before
/// tracking stay available either way. Watch it where the choice is
/// offered so it is ready when the sheet opens.
final subTrackSourceChoicesProvider = Provider.autoDispose
    .family<List<SubTrackSourceChoice>, String>((ref, curriculumId) {
      if (!ref.watch(subTrackWritesAllowedProvider)) return const [];
      final rows = ref.watch(onHomeSubTracksProvider).asData?.value;
      if (rows == null) return const [];
      return [
        for (final r in rows)
          if (r.curriculumId == curriculumId) (id: r.id, name: r.track.name),
      ];
    });

/// One capture this device made that the engine has not derived yet.
final class PendingCapture {
  /// Creates the entry.
  PendingCapture({
    required this.token,
    required this.curriculumId,
    required this.source,
    required Map<String, LeafRef> refs,
  }) : refs = Map.unmodifiable(refs);

  /// The local id of the capture while its event ids are unknown.
  final int token;

  /// The curriculum storage key.
  final String curriculumId;

  /// `main` or a sub-track ULID.
  final String source;

  /// The leaves by event id; `#token/i` keys while the command is in
  /// flight.
  final Map<String, LeafRef> refs;
}

/// The optimistic overlay of pending captures.
final class PendingCaptures {
  /// Creates the overlay.
  PendingCaptures(List<PendingCapture> entries)
    : entries = List.unmodifiable(entries);

  /// No pending capture.
  static final empty = PendingCaptures(const []);

  /// The entries, oldest first.
  final List<PendingCapture> entries;

  /// The leaves pending for [source] in [curriculumId].
  Set<LeafRef> refsOf(String curriculumId, String source) => {
    for (final e in entries)
      if (e.curriculumId == curriculumId && e.source == source)
        ...e.refs.values,
  };

  @override
  bool operator ==(Object other) =>
      other is PendingCaptures &&
      other.entries.length == entries.length &&
      Iterable<int>.generate(
        entries.length,
      ).every((i) => identical(other.entries[i], entries[i]));

  @override
  int get hashCode => Object.hashAll(entries.map(identityHashCode));
}

/// See [pendingCapturesProvider].
class PendingCapturesNotifier extends Notifier<PendingCaptures> {
  int _next = 0;
  final _failed = <String>{};

  @override
  PendingCaptures build() {
    // Prune what the engine has derived: counted, or kept and not counted
    // (lock-ignored, AD-36).
    ref.listen<AsyncValue<LearnerState?>>(activeLearnerStateProvider, (
      _,
      next,
    ) {
      final s = next.asData?.value;
      if (s != null) _prune(s);
    });
    return PendingCaptures.empty;
  }

  /// Marks [refs] of [source] pending; returns the capture's token.
  int add(String curriculumId, String source, List<LeafRef> refs) {
    final token = _next++;
    state = PendingCaptures([
      ...state.entries,
      PendingCapture(
        token: token,
        curriculumId: curriculumId,
        source: source,
        refs: {for (final (i, r) in refs.indexed) '#$token/$i': r},
      ),
    ]);
    return token;
  }

  /// Binds the capture [token] to [plannedIds], the ids of every event the
  /// capture planned, one per leaf in leaf order (AD-31; see
  /// `LearningCommands.capture`). A leaf whose event is in [notSaved] — a
  /// chunk the server rejected within the ack window — or was already
  /// reported failed ([rollBack]) is dropped, so only saved or queued
  /// leaves stay recorded. A plan that does not match the leaves one to
  /// one drops the whole capture (the engine then shows what was saved).
  /// The [alreadyRecorded] leaves got no event (the log already had them,
  /// AC-2): they leave the capture before the plan is lined up.
  void bind(
    int token,
    List<String> plannedIds, {
    Iterable<String> notSaved = const [],
    Iterable<LeafRef> alreadyRecorded = const [],
  }) {
    final gone = {...notSaved, ..._failed};
    final skipped = alreadyRecorded.toSet();
    state = PendingCaptures(
      [
        for (final e in state.entries)
          if (e.token != token)
            e
          else if (_planned(e, skipped) case final leaves
              when leaves.length == plannedIds.length)
            PendingCapture(
              token: token,
              curriculumId: e.curriculumId,
              source: e.source,
              refs: {
                for (final (i, r) in leaves.indexed)
                  if (!gone.contains(plannedIds[i])) plannedIds[i]: r,
              },
            ),
      ].where((e) => e.refs.isNotEmpty).toList(),
    );
  }

  static List<LeafRef> _planned(PendingCapture e, Set<LeafRef> skipped) => [
    for (final r in e.refs.values)
      if (!skipped.contains(r)) r,
  ];

  /// Drops the capture [token] (nothing was written).
  void dropToken(int token) => state = PendingCaptures([
    for (final e in state.entries)
      if (e.token != token) e,
  ]);

  /// Drops the leaves of [eventIds] (undone).
  void dropEvents(Iterable<String> eventIds) {
    final gone = eventIds.toSet();
    if (gone.isEmpty) return;
    _rebuild((id) => gone.contains(id));
  }

  /// Rolls back the leaves of [eventIds], which the server rejected for
  /// good (a pending failure, AD-54 Recovery). The ids are remembered, so
  /// a capture still awaiting its result never binds them as recorded.
  void rollBack(Iterable<String> eventIds) {
    _failed.addAll(eventIds);
    dropEvents(eventIds);
  }

  /// Forgets the failure of [eventIds]: a retry saved them.
  void retried(Iterable<String> eventIds) => _failed.removeAll(eventIds);

  void _prune(LearnerState s) => _rebuild(
    (id) =>
        s.countedEventIds.contains(id) || s.lockIgnoredEventIds.contains(id),
  );

  void _rebuild(bool Function(String eventId) drop) {
    var changed = false;
    final next = <PendingCapture>[];
    for (final e in state.entries) {
      final kept = <String, LeafRef>{};
      for (final MapEntry(:key, :value) in e.refs.entries) {
        if (drop(key)) {
          changed = true;
        } else {
          kept[key] = value;
        }
      }
      if (kept.isEmpty) continue;
      next.add(
        kept.length == e.refs.length
            ? e
            : PendingCapture(
                token: e.token,
                curriculumId: e.curriculumId,
                source: e.source,
                refs: kept,
              ),
      );
    }
    if (changed) state = PendingCaptures(next);
  }
}

/// This device's pending Up to… / +1 captures.
final pendingCapturesProvider =
    NotifierProvider<PendingCapturesNotifier, PendingCaptures>(
      PendingCapturesNotifier.new,
    );

/// Records [refs] (leaves, in track order) of [curriculumId] from [source]
/// as ONE capture: `dated`, `learned_on` = civil today, [stage] only for
/// `source = main` (AD-50). Shows "Recorded {n} · Undo"; Undo voids every
/// event of this capture (UX-DR-154). A capture that is refused, locked or
/// fails is rolled back at once; nothing is written past the gate.
Future<CaptureResult?> captureLeaves(
  BuildContext context,
  WidgetRef ref, {
  required String curriculumId,
  required String source,
  required List<LeafRef> refs,
  int? stage,
}) async {
  if (refs.isEmpty) return null;
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final warningFill = context.colors.warningSnackbarFill;
  // A tutor capture (once DNI-486 binds tutor commands) is shown only
  // when its callable has answered (AD-53): no optimistic overlay in a
  // tutored session.
  final optimistic = ref.read(activeTutoredProfileSelectionProvider) == null;
  final pending = ref.read(pendingCapturesProvider.notifier);
  final token = optimistic ? pending.add(curriculumId, source, refs) : -1;
  void notSaved() {
    if (optimistic) pending.dropToken(token);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.captureNotSaved),
        backgroundColor: warningFill,
      ),
    );
  }

  final LearningCommands? commands;
  final CaptureResult result;
  try {
    commands = await ref.read(learningCommandsProvider.future);
    if (commands == null) {
      notSaved();
      return null;
    }
    result = await commands.capture(
      curriculumId: curriculumId,
      refs: refs,
      source: source,
      dateState: DateState.dated,
      stage: source == LearningEvent.sourceMain ? stage : null,
      // AC-2: the picker's rows are frozen while it is open; a leaf another
      // device recorded meanwhile is dropped against the persisted log
      // rather than written twice.
      skipRecorded: true,
    );
  } on Exception {
    notSaved();
    return null;
  }
  if (optimistic) {
    if (result case CaptureSuccess(
      :final eventIds,
      :final rejectedEventIds,
      :final alreadyRecordedRefs,
    ) when eventIds.isNotEmpty) {
      // A partly rejected capture omits the rejected chunks from
      // `eventIds`: the sorted union is the plan, one id per leaf in leaf
      // order, after the leaves the log already recorded are dropped.
      pending.bind(
        token,
        [...eventIds, ...rejectedEventIds]..sort(),
        notSaved: rejectedEventIds,
        alreadyRecorded: alreadyRecordedRefs,
      );
    } else {
      pending.dropToken(token);
    }
  }
  if (!context.mounted) return result;
  showCaptureOutcome(
    context,
    result: result,
    commands: commands,
    // Never claim the leaves of a rejected chunk (AD-54).
    message: l10n.upToPickerRecorded(
      result is CaptureSuccess ? result.eventIds.length : refs.length,
    ),
    messenger: messenger,
    onUndone: () {
      if (result case CaptureSuccess(:final eventIds) when optimistic) {
        pending.dropEvents(eventIds);
      }
    },
  );
  return result;
}
