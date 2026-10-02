/// Maps merged history items to display rows (Story 4.5 / DNI-513 AC-3 –
/// AC-6, E-2, E-3).
///
/// Undone, voided and source-name state is read from the loaded pages,
/// and is complete for every visible row: an undo, a void and a later
/// rename are all newer than what they act on, and every item newer than a
/// visible row is loaded (`change_history_merge.dart`). The reverse — what
/// a visible undo or void acts on — may be older than every loaded page,
/// so the pager reads it by `action_id` / id (`change_history_pager.dart`).
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
/// - **Created** is proved by the entry itself, by the rule the undo
///   command uses to tombstone a create (`governed_action_commands.dart`):
///   it wrote a doc's immutable `curriculum_id` (written once, at
///   creation) and every field it wrote was absent before. An all-null
///   `before` alone is not proof: an update logs only its changed fields,
///   so setting a field that was unset (a `window_end` going from null to
///   a date) is an edit.
/// - **Source names** are the sub-track name at event time, read only
///   when every rename after that instant is loaded: the `before` of the
///   first later rename, else (no rename since) the name set by the
///   last-written loaded rename, else the name the history opened with.
///   Below that bound — the target of a void or the action an undo
///   reverts, read by id under every loaded page — a later rename may sit
///   on an unread page, so the row names the source as it was at the
///   row's own instant (the void or the undo), which is always above the
///   bound. A sub-track named only after the instant, or gone with no
///   rename loaded, has no known name (null: the "unnamed sub-track"
///   label); a newer name is never shown as the historical one.
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_filter.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart'
    show GovernedKeys;
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

/// Whether [e] created the doc(s) it describes: outside `learnerSettings`
/// (whose seed entry is a settings change, never a create), it wrote the
/// immutable `curriculum_id` and every field it wrote was absent before.
/// Mirrors the create test of `GovernedActionCommands.undoAction`.
bool createsGovernedDoc(ChangeLogEntry e) =>
    e.entity != GovernedEntity.learnerSettings &&
    e.after.keys.any(
      (k) => ChangedFieldKey.tryParse(k)?.field == GovernedKeys.curriculumId,
    ) &&
    e.before.values.every((v) => v == null);

final _civilDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

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

  /// Sub-track names by id as the history opened: the names after every
  /// loaded rename. Not followed live: a rename made after the pages were
  /// read is not on them, so a live name would label older rows with it.
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
        _keepEarliest(_reverts, target, e.actor, changeAt(e));
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
      list.sort((a, b) => changeAt(a).compareTo(changeAt(b)));
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

  /// Whether every `change_log` entry taking effect after [instant] is
  /// loaded: the log is read to its end, or [instant] is at or above its
  /// `at` watermark. An unread entry's `at` is at or below the watermark
  /// and its effective instant ([changeAt]) never later than its `at`.
  bool _changesLoadedAfter(DateTime instant) {
    final log = buffer.changeLog;
    if (!log.started) return false;
    if (log.exhausted) return true;
    final watermark = log.watermark;
    return watermark != null && !instant.isBefore(watermark);
  }

  /// The name of sub-track [subTrackId] at [instant], when the loaded
  /// pages prove it; else its name at [fallback] (the row's own instant),
  /// when given and proved; else null (unknown). See the library doc.
  String? _nameAt(String subTrackId, DateTime instant, {DateTime? fallback}) {
    if (!_changesLoadedAfter(instant)) {
      return fallback == null ? null : _nameAt(subTrackId, fallback);
    }
    final renames = _renames[subTrackId] ?? const <ChangeLogEntry>[];
    final key = ChangedFieldKey(
      GovernedEntity.subTrack.collection,
      subTrackId,
      SubTrack.kName,
    ).key;
    for (final e in renames) {
      if (changeAt(e).isAfter(instant)) {
        // The first later rename: its `before` is the name then. A null
        // `before` means the name was first set later (no name then).
        final before = e.before[key];
        return before is String ? before : null;
      }
    }
    // No rename after the instant: the name then is the name the pages
    // end on, set by the last-written rename (the greatest `at`: every
    // entry written after a loaded one is loaded), else, with none loaded,
    // the name the history opened with.
    if (renames.isEmpty) return mapper.currentSubTrackNames[subTrackId];
    final latest = renames
        .reduce((a, b) => b.at.isAfter(a.at) ? b : a)
        .after[key];
    return latest is String ? latest : null;
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
        primary: _part(primary, item.sortAt),
        others: [
          for (final e in described.entries)
            if (e.id != primary.id) _part(e, item.sortAt),
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

  /// The reverted action [actionId], from the loaded pages and the
  /// pager's by-`action_id` lookups (it may be older than every page).
  GovernedActionItem? _actionItem(String actionId) {
    final entries = buffer.entriesOfAction(actionId);
    return entries.isEmpty ? null : GovernedActionItem(actionId, entries);
  }

  /// The part [e] contributes to a row stamped [rowAt] (the fallback
  /// instant for its sub-track's name).
  GovernedPart _part(ChangeLogEntry e, DateTime rowAt) {
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
    } else if (createsGovernedDoc(e)) {
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
          ? (newName is String
                ? newName
                : _nameAt(e.entityId, changeAt(e), fallback: rowAt))
          : null,
      newDate:
          e.entity == GovernedEntity.goal &&
              targetDate is String &&
              _civilDatePattern.hasMatch(targetDate)
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
      // Only a `learn` target carries refs and a source. A void whose
      // target is itself a void cancels nothing (`countEvents`), so it
      // reads as the generic "removed an earlier record" below, never as
      // a learn summary of a source-less event.
      final targets = [
        for (final v in item.events)
          if (buffer.eventById(v.targetId!) case final target?)
            if (target.isLearn) target,
      ];
      summary = targets.isNotEmpty
          ? _learnSummary(
              targets,
              effectiveAt(targets.first),
              void_: true,
              rowAt: at,
            )
          : LearningSummary(
              kind: LearningEventKind.void_,
              refs: [
                for (final v in item.events)
                  if (v.ref case final ref?) ref,
              ],
              source: first.source == null
                  ? null
                  : _sourceOf(first.source!, at, at),
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

  /// The summary of [events] recorded at [at], in a row stamped [rowAt]
  /// (the fallback instant for the source name; [at] when omitted).
  LearningSummary _learnSummary(
    List<LearningEvent> events,
    DateTime at, {
    bool void_ = false,
    DateTime? rowAt,
  }) {
    final first = events.first;
    final source = first.source;
    return LearningSummary(
      kind: void_ ? LearningEventKind.void_ : LearningEventKind.learn,
      refs: [
        for (final e in events)
          if (e.ref case final ref?) ref,
      ],
      source: source == null ? null : _sourceOf(source, at, rowAt ?? at),
      dateState: first.dateState,
      learnedOn: first.learnedOn,
    );
  }

  HistorySourceLabel _sourceOf(String source, DateTime at, DateTime rowAt) =>
      source == LearningEvent.sourceMain
      ? const MainTrackSource()
      : SubTrackSource(_nameAt(source, at, fallback: rowAt));
}
