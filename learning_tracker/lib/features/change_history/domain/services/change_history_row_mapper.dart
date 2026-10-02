/// Maps merged history items to display rows (Story 4.5 / DNI-513 AC-3 –
/// AC-6, E-2, E-3).
///
/// Everything a row derives is read from the loaded pages, and is
/// complete for every visible row: an undo, a void and a later rename are
/// all newer than what they act on, and every item newer than a visible
/// row is loaded (`change_history_merge.dart`).
///
/// - **Day and time** use the learner's IANA `time_zone` in force at the
///   instant (AD-41), never the device's.
/// - **Undone** comes from a persisted `reverts_action_id` (AD-38), so
///   every device shows the same state.
/// - **Lock-ignored** learning is judged by [lockWindows] over the
///   learner's settings history at the event's effective instant (AD-36);
///   a lock-ignored void removes nothing.
/// - **Bell** mirrors the AD-39 push allowlist exactly: a tutor change to
///   `goal`, `mainTrack`, `mainTrackOrder`, `mainTrackProgram` or
///   `mainTrackStudyDays`. It is display only, never a push trigger.
/// - **Source names** are the sub-track name at event time: the `before`
///   of the first later rename, else the name set by the last rename up to
///   then, else today's name.
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_filter.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_row.dart';
import 'package:learning_tracker/features/change_history/domain/models/history_item.dart';
import 'package:learning_tracker/features/change_history/domain/services/change_history_merge.dart';
import 'package:timezone/timezone.dart' as tz;

/// The AD-39 parent-notification allowlist the bell mirrors.
const Set<GovernedEntity> parentNotifiedEntities = {
  GovernedEntity.goal,
  GovernedEntity.mainTrack,
  GovernedEntity.mainTrackOrder,
  GovernedEntity.mainTrackProgram,
  GovernedEntity.mainTrackStudyDays,
};

const _endReasonsThatRemove = {
  'deleted', // SubTrackEndReason.deleted
  'track_deleted', // SubTrackEndReason.trackDeleted
};

/// Builds [ChangeHistoryRow]s.
final class ChangeHistoryRowMapper {
  /// Creates a mapper judging times by [settingsHistory] and naming
  /// sub-tracks from [currentSubTrackNames] (id → today's name).
  ChangeHistoryRowMapper({
    required this.settingsHistory,
    this.currentSubTrackNames = const {},
  });

  /// The learner's settings history (time zone, lock settings).
  final LearnerSettingsHistory settingsHistory;

  /// Today's sub-track names by id.
  final Map<String, String> currentSubTrackNames;

  /// The rows of [items] (visible, newest first), reading context from
  /// [buffer].
  List<ChangeHistoryRow> map(
    List<HistoryItem> items,
    ChangeHistoryBuffer buffer,
  ) {
    final context = _Context(this, buffer);
    return [for (final item in items) context.row(item)];
  }

  /// [actor] at [at] in the learner's zone.
  HistoryStamp stamp(Actor actor, DateTime at) {
    final zoneId = settingsHistory.at(at).timeZone;
    return HistoryStamp(
      actor: actor,
      at: at,
      day: civilDate(at, settingsHistory),
      localTime: _wallClock(at, zoneId),
    );
  }

  static DateTime _wallClock(DateTime at, String zoneId) {
    final zone = LearnerZone.of(zoneId); // loads the tz database once
    final utc = at.toUtc();
    if (!zone.isKnown) {
      return DateTime(utc.year, utc.month, utc.day, utc.hour, utc.minute);
    }
    final local = tz.TZDateTime.from(
      utc,
      zoneId == 'UTC' ? tz.UTC : tz.getLocation(zoneId),
    );
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }
}

final class _Context {
  _Context(this.mapper, this.buffer) {
    final instants = [for (final e in buffer.events) effectiveAt(e)]..sort();
    _locks = instants.isEmpty
        ? const []
        : lockWindows(mapper.settingsHistory, instants.first, instants.last);
    for (final e in buffer.entries) {
      if (e.revertsActionId case final target?) {
        _keepEarliest(_reverts, target, e.actor, e.at);
      }
    }
    for (final e in buffer.events) {
      if (e.revertsActionId case final target?) {
        _keepEarliest(_reverts, target, e.actor, effectiveAt(e));
      }
      // A lock-ignored void cancels nothing (AD-36).
      if (e.isVoid && !_locked(e)) {
        _keepEarliest(_voids, e.targetId!, e.actor, effectiveAt(e));
      }
    }
    for (final e in buffer.entries) {
      if (e.entity != GovernedEntity.subTrack) continue;
      final key = ChangedFieldKey(
        GovernedEntity.subTrack.collection,
        e.entityId,
        SubTrack.kName,
      ).key;
      if (e.after.containsKey(key)) (_renames[e.entityId] ??= []).add(e);
    }
    for (final list in _renames.values) {
      list.sort((a, b) => a.at.compareTo(b.at));
    }
  }

  final ChangeHistoryRowMapper mapper;
  final ChangeHistoryBuffer buffer;
  late final List<LockWindow> _locks;
  final Map<String, (Actor, DateTime)> _reverts = {};
  final Map<String, (Actor, DateTime)> _voids = {};
  final Map<String, List<ChangeLogEntry>> _renames = {};

  static void _keepEarliest(
    Map<String, (Actor, DateTime)> into,
    String key,
    Actor actor,
    DateTime at,
  ) {
    final held = into[key];
    if (held == null || at.isBefore(held.$2)) into[key] = (actor, at);
  }

  bool _locked(LearningEvent e) => insideLock(_locks, effectiveAt(e));

  HistoryStamp? _stampOf((Actor, DateTime)? held) =>
      held == null ? null : mapper.stamp(held.$1, held.$2);

  String? _nameAt(String subTrackId, DateTime instant) {
    final renames = _renames[subTrackId] ?? const <ChangeLogEntry>[];
    final key = ChangedFieldKey(
      GovernedEntity.subTrack.collection,
      subTrackId,
      SubTrack.kName,
    ).key;
    for (final e in renames) {
      if (e.at.isAfter(instant)) {
        final before = e.before[key];
        if (before is String) return before;
        break; // created after the instant: no earlier name is known
      }
    }
    for (final e in renames.reversed) {
      if (!e.at.isAfter(instant) && e.after[key] is String) {
        return e.after[key]! as String;
      }
    }
    return mapper.currentSubTrackNames[subTrackId];
  }

  ChangeHistoryRow row(HistoryItem item) => switch (item) {
    GovernedActionItem() => _governed(item),
    LearningBatchItem() => _learning(item),
  };

  ChangeHistoryRow _governed(GovernedActionItem item) {
    final reverts = item.revertsActionId;
    // An undo reads "Reverted change: <the undone action>"; when that
    // action is not loaded, its own entries (the same fields) describe it.
    final described = reverts == null ? item : _actionItem(reverts) ?? item;
    final primary = described.primary;
    return ChangeHistoryRow(
      key: item.key,
      kind: ChangeHistoryRowKind.governed,
      stamp: mapper.stamp(item.actor, item.sortAt),
      summary: GovernedSummary(
        primary: _part(primary),
        others: [
          for (final e in described.entries)
            if (e.id != primary.id) _part(e),
        ],
      ),
      notifiesParent:
          item.actor.role == ActorRole.tutor &&
          item.entries.any((e) => parentNotifiedEntities.contains(e.entity)),
      undoneBy: _stampOf(_reverts[item.actionId]),
      isRevert: reverts != null,
      lockIgnored: false,
      eventCount: 1,
    );
  }

  GovernedActionItem? _actionItem(String actionId) {
    final entries = [
      for (final e in buffer.entries)
        if (e.actionId == actionId) e,
    ];
    return entries.isEmpty ? null : GovernedActionItem(actionId, entries);
  }

  GovernedPart _part(ChangeLogEntry e) {
    final keys = [
      for (final k in e.after.keys)
        if (ChangedFieldKey.tryParse(k) case final parsed?) parsed,
    ];
    final fields = {for (final k in keys) k.field}.toList()..sort();
    Object? afterOf(String field) {
      for (final k in keys) {
        if (k.field == field) return e.after[k.key];
      }
      return null;
    }

    final GovernedChangeKind change;
    final endedAt = afterOf(SubTrack.kEndedAt);
    if (endedAt != null) {
      change = _endReasonsThatRemove.contains(afterOf(SubTrack.kEndReason))
          ? GovernedChangeKind.removed
          : GovernedChangeKind.ended;
    } else if (e.before.values.every((v) => v == null)) {
      change = GovernedChangeKind.created;
    } else if (e.entity == GovernedEntity.subTrack &&
        fields.length == 1 &&
        fields.single == SubTrack.kName) {
      change = GovernedChangeKind.renamed;
    } else {
      change = GovernedChangeKind.updated;
    }
    final newName = afterOf(SubTrack.kName);
    final targetDate = afterOf('target_date');
    return GovernedPart(
      entity: e.entity,
      change: change,
      fields: fields,
      subjectName: e.entity == GovernedEntity.subTrack
          ? (newName is String ? newName : _nameAt(e.entityId, e.at))
          : null,
      newDate: e.entity == GovernedEntity.goal && targetDate is String
          ? targetDate
          : null,
    );
  }

  ChangeHistoryRow _learning(LearningBatchItem item) {
    final first = item.first;
    final at = item.sortAt;
    final LearningSummary summary;
    if (item.isLearn) {
      summary = _learnSummary(item.events, at);
    } else {
      final targets = [
        for (final v in item.events)
          if (buffer.eventById(v.targetId!) case final target?) target,
      ];
      summary = targets.isNotEmpty
          ? _learnSummary(targets, effectiveAt(targets.first), void_: true)
          : LearningSummary(
              kind: LearningEventKind.void_,
              refs: [
                for (final v in item.events)
                  if (v.ref case final ref?) ref,
              ],
              source: first.source == null
                  ? null
                  : _sourceOf(first.source!, at),
              dateState: first.dateState,
              learnedOn: first.learnedOn,
            );
    }
    (Actor, DateTime)? voided;
    var voidedCount = 0;
    if (item.isLearn) {
      for (final e in item.events) {
        final v = _voids[e.id];
        if (v == null) continue;
        voidedCount++;
        if (voided == null || v.$2.isBefore(voided.$2)) voided = v;
      }
    }
    return ChangeHistoryRow(
      key: item.key,
      kind: ChangeHistoryRowKind.learning,
      stamp: mapper.stamp(item.actor, at),
      summary: summary,
      notifiesParent: false,
      isRevert: first.revertsActionId != null,
      lockIgnored: _locked(first),
      eventCount: item.events.length,
      voidedBy: _stampOf(voided),
      voidedCount: voidedCount,
    );
  }

  LearningSummary _learnSummary(
    List<LearningEvent> events,
    DateTime at, {
    bool void_ = false,
  }) {
    final first = events.first;
    return LearningSummary(
      kind: void_ ? LearningEventKind.void_ : LearningEventKind.learn,
      refs: [
        for (final e in events)
          if (e.ref case final ref?) ref,
      ],
      source: _sourceOf(first.source!, at),
      dateState: first.dateState,
      learnedOn: first.learnedOn,
    );
  }

  HistorySourceLabel _sourceOf(String source, DateTime at) =>
      source == LearningEvent.sourceMain
      ? const MainTrackSource()
      : SubTrackSource(_nameAt(source, at));
}
