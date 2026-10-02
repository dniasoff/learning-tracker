/// Engine stage 1: the counted-event boundary (AD-31, AD-32, AD-36).
///
/// Every later stage (learnt set, position, siyum, points) reads only the
/// [CountedEvents] this stage returns, never the raw event list. A `learn`
/// event counts iff it is not voided and not lock-ignored.
///
/// The lock rule itself is Story 1.4 (DNI-466): this stage only accepts it
/// as a [LockIgnoreHook]. Until DNI-466 fills it, the engine passes
/// [noLockIgnored].
library;

import 'package:learning_tracker/domain/learner_state/learning_event.dart';

/// Whether [event] was recorded inside a lock window and must be ignored
/// (AD-36 "enforced again by derivation"). Filled by DNI-466.
typedef LockIgnoreHook = bool Function(LearningEvent event);

/// The [LockIgnoreHook] that ignores nothing.
bool noLockIgnored(LearningEvent event) => false;

/// The single event order every engine stage uses: [effectiveAt] ascending,
/// ties broken by event id (ULIDs sort by creation), so equal instants
/// resolve deterministically.
int compareEventsByEffectiveAt(LearningEvent a, LearningEvent b) {
  final byTime = effectiveAt(a).compareTo(effectiveAt(b));
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

/// The output of [countEvents].
final class CountedEvents {
  /// Creates the result. Prefer [countEvents].
  CountedEvents({
    required List<LearningEvent> learns,
    required Set<String> voidedIds,
    required Set<String> lockIgnoredIds,
  }) : learns = List.unmodifiable(learns),
       voidedIds = Set.unmodifiable(voidedIds),
       lockIgnoredIds = Set.unmodifiable(lockIgnoredIds),
       countedIds = Set.unmodifiable(learns.map((e) => e.id));

  /// The counted `learn` events of every curriculum, ordered by
  /// [compareEventsByEffectiveAt].
  final List<LearningEvent> learns;

  /// The ids of `learn` events cancelled by a counted `void` (a set: two
  /// voids of one target equal one).
  final Set<String> voidedIds;

  /// The ids of events (either kind) the [LockIgnoreHook] rejected.
  final Set<String> lockIgnoredIds;

  /// The ids of [learns].
  final Set<String> countedIds;
}

/// Splits [events] into counted `learn` events, voided targets and
/// lock-ignored events (AD-31 void rules, AD-32 "counted").
///
/// * An event the [isLockIgnored] hook rejects takes no part at all: a
///   lock-ignored `learn` never counts and a lock-ignored `void` cancels
///   nothing.
/// * A `void` cancels its target only when the target is a `learn` event in
///   [events]. A void whose target is a void is ignored, and a void whose
///   target is absent is not an error. Voids form a set of target ids.
/// * A repeated id keeps its first occurrence (the log is keyed by id).
///
/// Voids are profile-wide: a void cancels its target whatever the
/// target's curriculum.
CountedEvents countEvents(
  List<LearningEvent> events, {
  LockIgnoreHook isLockIgnored = noLockIgnored,
}) {
  final byId = <String, LearningEvent>{};
  for (final e in events) {
    byId.putIfAbsent(e.id, () => e);
  }
  final lockIgnored = <String>{};
  final live = <LearningEvent>[];
  for (final e in byId.values) {
    if (isLockIgnored(e)) {
      lockIgnored.add(e.id);
    } else {
      live.add(e);
    }
  }
  final liveLearnIds = {
    for (final e in live)
      if (e.isLearn) e.id,
  };
  final voided = <String>{
    for (final e in live)
      if (e.isVoid && liveLearnIds.contains(e.targetId)) e.targetId!,
  };
  final learns = live.where((e) => e.isLearn && !voided.contains(e.id)).toList()
    ..sort(compareEventsByEffectiveAt);
  return CountedEvents(
    learns: learns,
    voidedIds: voided,
    lockIgnoredIds: lockIgnored,
  );
}
