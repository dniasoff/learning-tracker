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
///   capture, or a queued chunk the server later rejects (the Learn rollback
///   snackbar, UX-DR-110) removes them again; an entry is pruned once the
///   engine counts (or lock-ignores) its events.
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
/// 2.9 AC-9; AC-11). Owner-device capture (`LearningCommands`) is null in
/// a tutored session too, so the main-track Up to… follows the same flag.
final subTrackWritesAllowedProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(activeTutoredProfileSelectionProvider) == null,
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

  /// Binds the capture [token] to the [eventIds] it wrote, one per leaf in
  /// order (AD-31 capture plans one event per leaf).
  void bind(int token, List<String> eventIds) {
    state = PendingCaptures([
      for (final e in state.entries)
        if (e.token != token)
          e
        else
          PendingCapture(
            token: token,
            curriculumId: e.curriculumId,
            source: e.source,
            refs: {
              for (final (i, r) in e.refs.values.indexed)
                i < eventIds.length ? eventIds[i] : '#$token/$i': r,
            },
          ),
    ]);
  }

  /// Drops the capture [token] (nothing was written).
  void dropToken(int token) => state = PendingCaptures([
    for (final e in state.entries)
      if (e.token != token) e,
  ]);

  /// Drops the leaves of [eventIds] (undone, or rejected by the server).
  void dropEvents(Iterable<String> eventIds) {
    final gone = eventIds.toSet();
    if (gone.isEmpty) return;
    _rebuild((id) => gone.contains(id));
  }

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
  final pending = ref.read(pendingCapturesProvider.notifier);
  final token = pending.add(curriculumId, source, refs);
  void notSaved() {
    pending.dropToken(token);
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
    );
  } on Exception {
    notSaved();
    return null;
  }
  if (result case CaptureSuccess(:final eventIds) when eventIds.isNotEmpty) {
    pending.bind(token, eventIds);
  } else {
    pending.dropToken(token);
  }
  if (!context.mounted) return result;
  showCaptureOutcome(
    context,
    result: result,
    commands: commands,
    message: l10n.upToPickerRecorded(refs.length),
    messenger: messenger,
    onUndone: () {
      if (result case CaptureSuccess(:final eventIds)) {
        pending.dropEvents(eventIds);
      }
    },
  );
  return result;
}
