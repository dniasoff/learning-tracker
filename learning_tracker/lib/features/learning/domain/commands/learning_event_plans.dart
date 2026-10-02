/// Event construction for the AD-31 learning commands: capture, void,
/// replace, un-learn and undo.
///
/// Pure. Every id and timestamp is fixed here, once, BEFORE the first write
/// attempt: a [CommandStamp] reads no clock (the command read it once) and
/// mints every ULID up front, so a retry re-sends identical events (AD-31
/// "The ULID is generated client-side before the write and reused on
/// retry", AD-46 "Retry payloads never contain a freshly stamped time").
/// Every client timestamp is the command's `nowUtc` or an earlier
/// `effectiveAt` (AD-54 skew rule).
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/counted_events.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learning_event_stamp.dart';
import 'package:learning_tracker/domain/learner_state/lock_filter.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_write_chunker.dart';
import 'package:learning_tracker/features/learning/domain/commands/unlearn_plan.dart';

/// The fixed identity of one command: its actor, its single `nowUtc` and
/// its ids.
final class CommandStamp {
  /// Creates the stamp. [newUlid] is called only by [ids].
  CommandStamp({
    required this.actor,
    required DateTime nowUtc,
    required UlidSource newUlid,
  }) : nowUtc = nowUtc.toUtc(),
       _newUlid = newUlid;

  /// The author of every event.
  final Actor actor;

  /// `recorded_at` of every new event and `created_at` of every award.
  final DateTime nowUtc;

  final UlidSource _newUlid;

  /// [count] fresh ULIDs, ascending, so the events of one command keep
  /// their write order under the (`effectiveAt`, id) event order.
  List<String> ids(int count) =>
      [for (var i = 0; i < count; i++) _newUlid(nowUtc)]..sort();
}

/// Whether AD-50 pairs [e] with a `pts_{eventId}` entry: every
/// `source = main` `dated` or `catch_up` learn event. Eligibility is the
/// engine's call (`earningEventIds`); writers attach to every such event.
bool earnsPointsEntry(LearningEvent e) =>
    e.isLearn &&
    e.source == LearningEvent.sourceMain &&
    (e.dateState == DateState.dated || e.dateState == DateState.catchUp);

/// The [WriteUnit] of a new learn [event] (plus any [alongside] events,
/// e.g. the void a replacement pairs with): with its award of [amount] at
/// `created_at = recorded_at` when it earns one. No reversal entry is ever
/// written (AD-50).
WriteUnit learnUnit(
  LearningEvent event,
  int? amount,
  DateTime recordedAt, {
  List<LearningEvent> alongside = const [],
}) => WriteUnit(
  [event, ...alongside],
  [
    if (earnsPointsEntry(event) && amount != null)
      PointsAward(eventId: event.id, amount: amount, createdAt: recordedAt),
  ],
);

/// The events of `capture`: one `learn` per leaf in [leaves] and, for
/// `before_tracking` only, one node event (carrying `level`) per node in
/// [nodes], each paired with its award of [amount] when it earns one.
List<WriteUnit> planCapture({
  required CommandStamp stamp,
  required String curriculumId,
  required List<LeafRef> leaves,
  required List<NodeEntry> nodes,
  required String source,
  required DateState dateState,
  required CivilDate? learnedOn,
  required int? stage,
  required int? amount,
}) {
  final ids = stamp.ids(leaves.length + nodes.length);
  var i = 0;
  LearningEvent learn(String ref, String? level) => LearningEvent.learn(
    id: ids[i++],
    curriculumId: curriculumId,
    ref: ref,
    level: level,
    source: source,
    dateState: dateState,
    learnedOn: dateState == DateState.beforeTracking ? null : learnedOn,
    stage: stage,
    recordedAt: stamp.nowUtc,
    actor: stamp.actor,
  );
  return [
    for (final leaf in leaves)
      learnUnit(learn(leaf, null), amount, stamp.nowUtc),
    for (final node in nodes)
      learnUnit(learn(node.ref, node.level), amount, stamp.nowUtc),
  ];
}

/// A `void` of [targetId]; [revertsActionId] only when written by an undo.
LearningEvent voidEventOf(
  CommandStamp stamp,
  String id,
  String targetId, {
  String? revertsActionId,
}) => LearningEvent.voidOf(
  id: id,
  targetId: targetId,
  recordedAt: stamp.nowUtc,
  actor: stamp.actor,
  revertsActionId: revertsActionId,
);

/// A new `learn` copy of [target] with [id], keeping every learn field
/// and `original_recorded_at = effectiveAt(target)`, so it counts at the
/// target's instant and creates no new streak day (AD-31, FR-4).
LearningEvent copyOf(CommandStamp stamp, String id, LearningEvent target) =>
    LearningEvent.learn(
      id: id,
      curriculumId: target.curriculumId!,
      ref: target.ref!,
      level: target.level,
      source: target.source!,
      dateState: target.dateState!,
      learnedOn: target.learnedOn,
      stage: target.stage,
      originalRecordedAt: effectiveAt(target),
      recordedAt: stamp.nowUtc,
      actor: stamp.actor,
    );

/// The fields of a replacement event, resolved against its target.
final class ResolvedReplacement {
  /// Creates the resolution.
  const ResolvedReplacement({
    required this.ref,
    required this.level,
    required this.source,
    required this.dateState,
    required this.learnedOn,
    required this.stage,
    required this.redate,
  });

  /// The new `ref`.
  final String ref;

  /// The new `level` (kept only for an unchanged node ref).
  final String? level;

  /// The new `source`.
  final String source;

  /// The new `date_state`.
  final DateState dateState;

  /// The new `learned_on`.
  final CivilDate? learnedOn;

  /// The new `stage`.
  final int? stage;

  /// Whether `learned_on` or `date_state` changes (a re-date).
  final bool redate;

  /// Whether nothing changes.
  bool sameAs(LearningEvent t) =>
      ref == t.ref &&
      level == t.level &&
      source == t.source &&
      dateState == t.dateState &&
      learnedOn == t.learnedOn &&
      stage == t.stage;
}

/// The replacement event of [target] with [fields] (AD-31, FR-4).
///
/// A replacement that does not re-date keeps the target's `learned_on`
/// and `date_state` and carries `original_recorded_at = effectiveAt
/// (target)`, so it creates no new streak day. A re-date is a new
/// statement made now: it carries no `original_recorded_at`, so a
/// `catch_up` re-date counts only inside its catch-up window (AD-40).
LearningEvent replacementOf(
  CommandStamp stamp,
  String id,
  LearningEvent target,
  ResolvedReplacement fields,
) => LearningEvent.learn(
  id: id,
  curriculumId: target.curriculumId!,
  ref: fields.ref,
  level: fields.level,
  source: fields.source,
  dateState: fields.dateState,
  learnedOn: fields.learnedOn,
  stage: fields.stage,
  originalRecordedAt: fields.redate ? null : effectiveAt(target),
  recordedAt: stamp.nowUtc,
  actor: stamp.actor,
);

/// The `unlearn` writes of [plan]: one unit per counted node event (its
/// `before_tracking` re-issues, each with `original_recorded_at =
/// effectiveAt(N)`, then the void of N, so a split unit never drops
/// coverage first), then one void per leaf event.
List<WriteUnit> planUnlearnWrites(CommandStamp stamp, UnlearnPlan plan) {
  final count =
      plan.leafVoids.length +
      plan.nodes.fold<int>(0, (n, r) => n + 1 + r.reissues.length);
  final ids = stamp.ids(count);
  var i = 0;
  return [
    for (final node in plan.nodes)
      WriteUnit([
        for (final entry in node.reissues)
          LearningEvent.learn(
            id: ids[i++],
            curriculumId: node.target.curriculumId!,
            ref: entry.ref,
            level: entry.level,
            source: node.target.source!,
            dateState: DateState.beforeTracking,
            learnedOn: null,
            stage: node.target.stage,
            originalRecordedAt: effectiveAt(node.target),
            recordedAt: stamp.nowUtc,
            actor: stamp.actor,
          ),
        voidEventOf(stamp, ids[i++], node.target.id),
      ]),
    for (final leaf in plan.leafVoids)
      WriteUnit([voidEventOf(stamp, ids[i++], leaf.id)]),
  ];
}

/// The event log as the commands judge it: every event by id, which are
/// counted, voided and lock-ignored, with the AD-36 lock rule applied
/// under the settings in force at each event (as the engine does).
final class LearningLogView {
  /// Builds the view of [events] at [nowUtc].
  factory LearningLogView.of(
    List<LearningEvent> events,
    LearnerSettingsHistory settingsHistory,
    DateTime nowUtc,
  ) {
    final locks = engineLockWindows(settingsHistory, events, nowUtc);
    final byId = <String, LearningEvent>{};
    for (final e in events) {
      byId.putIfAbsent(e.id, () => e);
    }
    return LearningLogView._(
      byId,
      countEvents(events, isLockIgnored: lockIgnoreHook(locks)),
    );
  }

  LearningLogView._(this.byId, this.counted);

  /// Every event by id.
  final Map<String, LearningEvent> byId;

  /// The counted-event split (AD-31, AD-36).
  final CountedEvents counted;

  /// Whether [id] is a lock-ignored event (no undo, no correction).
  bool isLockIgnored(String id) => counted.lockIgnoredIds.contains(id);

  /// Whether [id] is a `learn` event a counted void cancels.
  bool isVoided(String id) => counted.voidedIds.contains(id);

  /// Whether [id] is a counted `learn` event.
  bool isCounted(String id) => counted.countedIds.contains(id);
}
