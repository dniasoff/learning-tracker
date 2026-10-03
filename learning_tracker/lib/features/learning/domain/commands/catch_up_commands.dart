/// The catch-up record action of a pending card (Story 3.3, DNI-506;
/// AD-40, AD-31, AD-50, AD-54).
///
/// A [CatchUpAction] is what one tap on a catch-up card asks
/// `LearningCommands.recordCatchUp` to write: the lock `L` the card
/// belongs to and one [CatchUpLeaf] per listed leaf, each dated to the
/// locked day it is listed under. Story 3.4 (DNI-507, *Adjust…*) builds
/// the same action with [CatchUpMode.adjusted].
///
/// [checkCatchUp] is the one window rule the command applies before any
/// write: the tap instant must be inside `catchUpWindow(L)` (so a stale
/// screen confirmed after the window is refused, AC-3), and every leaf's
/// `learned_on` must be one of `lockedDays(L)`. Both come from
/// `lock_windows.dart`; nothing here computes a lock or a window any other
/// way.
///
/// Pure. Imports only `lib/domain/learner_state/**` and `dart:` (C0 AC-1).
library;

import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart'
    show maxCatchUpLockedDays;
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// How a catch-up card was recorded (the `mode` of `catchup_completed`).
enum CatchUpMode {
  /// *Yes, all of it* (Story 3.3).
  all('all'),

  /// *Adjust…* then Record (Story 3.4).
  adjusted('adjusted');

  const CatchUpMode(this.storage);

  /// The analytics parameter value.
  final String storage;
}

/// One leaf a catch-up action records: a `learn` event with
/// `date_state = catch_up`.
final class CatchUpLeaf {
  /// Creates the leaf.
  const CatchUpLeaf({
    required this.curriculumId,
    required this.ref,
    required this.source,
    required this.learnedOn,
    this.stage,
  });

  /// The curriculum storage key.
  final String curriculumId;

  /// The ContentIndex leaf.
  final LeafRef ref;

  /// `main` or the sub-track ULID.
  final String source;

  /// The locked day the leaf is listed under (learner-local).
  final CivilDate learnedOn;

  /// The planner task's stage; main-track leaves only (AC-1).
  final int? stage;

  @override
  bool operator ==(Object other) =>
      other is CatchUpLeaf &&
      other.curriculumId == curriculumId &&
      other.ref == ref &&
      other.source == source &&
      other.learnedOn == learnedOn &&
      other.stage == stage;

  @override
  int get hashCode => Object.hash(curriculumId, ref, source, learnedOn, stage);

  @override
  String toString() =>
      'CatchUpLeaf($curriculumId, $ref, $source, $learnedOn'
      '${stage == null ? '' : ', stage $stage'})';
}

/// One card action: everything a tap records for lock [lock].
final class CatchUpAction {
  /// Creates the action.
  CatchUpAction({
    required this.lock,
    required this.mode,
    required this.lockedDaysOffered,
    required List<CatchUpLeaf> leaves,
  }) : leaves = List.unmodifiable(leaves);

  /// The lock `L` the card belongs to, as `lockWindows` returned it.
  final LockWindow lock;

  /// How the card was recorded.
  final CatchUpMode mode;

  /// The locked days the card offered (at most three).
  final int lockedDaysOffered;

  /// The leaves to record, in card order (curriculum, day, then source).
  final List<CatchUpLeaf> leaves;

  /// The curricula of [leaves], in first-seen order.
  List<String> get curricula => [
    for (final l in leaves) l.curriculumId,
  ].fold(<String>[], (out, c) => out.contains(c) ? out : (out..add(c)));

  @override
  String toString() =>
      'CatchUpAction($lock, ${mode.storage}, ${leaves.length} leaves)';
}

/// The verdict of [checkCatchUp].
enum CatchUpCheck {
  /// The action may be written.
  ok,

  /// The tap instant is outside the card's catch-up window, or the lock no
  /// longer exists under the learner's settings: the card has ended (AC-3).
  ended,

  /// The action is malformed (a leaf off the lock's locked days, a stage
  /// on a sub-track leaf, more than three locked days, a bad source).
  invalid,
}

/// Whether [action] may be recorded at [nowUtc] under [history] (AD-40).
///
/// * `L` must still be a lock of [history] with the same bounds, and
///   [nowUtc] must be after `L.end` and inside `catchUpWindow(L)`;
///   otherwise [CatchUpCheck.ended]. The window's last instant is in, the
///   next one is out (AC-3). The capture gate refuses an instant inside a
///   later lock before this runs.
/// * Every leaf needs a curriculum, a ref, a `main` or ULID source, a
///   `learned_on` in `lockedDays(L)`, and a stage only when it is a
///   non-negative main-track stage; the leaves span at most
///   [maxCatchUpLockedDays] days. Otherwise [CatchUpCheck.invalid].
CatchUpCheck checkCatchUp(
  CatchUpAction action,
  LearnerSettingsHistory history,
  DateTime nowUtc,
) {
  final now = nowUtc.toUtc();
  final lock = action.lock;
  if (!now.isAfter(lock.endUtc)) return CatchUpCheck.ended;
  final current = lockWindows(history, lock.startUtc, lock.endUtc);
  if (!current.any((l) => l == lock)) return CatchUpCheck.ended;
  if (!catchUpWindow(lock, history).contains(now)) return CatchUpCheck.ended;
  final days = lockedDays(lock, history);
  final used = <CivilDate>{};
  for (final leaf in action.leaves) {
    if (leaf.curriculumId.isEmpty || leaf.ref.isEmpty) {
      return CatchUpCheck.invalid;
    }
    final main = leaf.source == LearningEvent.sourceMain;
    if (!main && !isUlid(leaf.source)) return CatchUpCheck.invalid;
    final stage = leaf.stage;
    if (stage != null && (!main || stage < 0)) return CatchUpCheck.invalid;
    if (!isCivilDate(leaf.learnedOn) || !days.contains(leaf.learnedOn)) {
      return CatchUpCheck.invalid;
    }
    used.add(leaf.learnedOn);
  }
  if (used.length > maxCatchUpLockedDays) return CatchUpCheck.invalid;
  return CatchUpCheck.ok;
}
