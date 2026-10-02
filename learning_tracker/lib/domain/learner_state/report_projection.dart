/// Engine stage 8: the per-curriculum report projection (AD-48, FR-31,
/// FR-32; DNI-516).
///
/// Every lifetime and per-source number a report renders comes from this
/// projection, built inside `LearnerStateEngine.run` from the engine's own
/// classified inputs: the curriculum's counted `learn` events (stage 1:
/// voids and lock-ignored events are already gone), the learnt set
/// (stage 2) and `coveredLeaves` / `expandGround` for node events. No
/// report consumer (screen, provider, PDF builder) computes a total, a
/// count or a velocity of its own (AD-48).
///
/// * **Distinct leaves learnt** is the engine learnt set's size, the same
///   number as FR-14 goal progress and the lifetime tree.
/// * **Total learning events** is, over every leaf of the learner's corpus,
///   the number of counted events covering it: a leaf event counts once, a
///   `before_tracking` node event once per leaf it covers (gap G-3). This
///   is the FR-30 per-leaf count restricted to counted events, so a
///   lock-ignored event (AD-36) adds nothing (AC-3).
/// * **Per-source totals** are keyed by `source` (`main` or a sub-track
///   ULID); a `main` `before_tracking` event goes to the separate
///   Before-tracking bucket instead of Home ([ReportProjection.beforeTracking]).
///   A sub-track's own `before_tracking` events stay with that sub-track.
/// * **Sub-track roll-up**: sub-tracks whose current (or tombstoned) `name`
///   matches after trimming and case-folding form one [ReportGroup] (gap
///   G-5); each member is one [ReportMemberLine]. Events are grouped by
///   the sub-track's current name: there is no name history (gap G-4).
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    identical(a, b) || (a.length == b.length && a.containsAll(b));

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final MapEntry(:key, :value) in a.entries) {
    if (!b.containsKey(key) || b[key] != value) return false;
  }
  return true;
}

/// What a [ReportSourceTotals] row stands for.
enum ReportSourceKind {
  /// The main track (`source == main`): Home.
  main,

  /// A sub-track whose `sub_tracks` doc (live or tombstoned) is known.
  subTrack,

  /// A sub-track ULID with no `sub_tracks` doc for this curriculum. Its
  /// events are kept under the raw ULID, never dropped.
  unknownSubTrack,

  /// The Before-tracking bucket: the `main` source's `before_tracking`
  /// events.
  beforeTracking,
}

/// The key of the Before-tracking bucket; never a valid `source` value.
const reportBeforeTrackingKey = 'before_tracking';

/// The counted totals of one source (or the Before-tracking bucket).
final class ReportSourceTotals {
  /// Creates the totals.
  ReportSourceTotals({
    required this.source,
    required this.kind,
    required this.events,
    required Set<LeafRef> leaves,
  }) : leaves = Set.unmodifiable(leaves);

  /// No events from [source].
  ReportSourceTotals.zero(this.source, this.kind)
    : events = 0,
      leaves = const {};

  /// `main`, a sub-track ULID, or [reportBeforeTrackingKey].
  final String source;

  /// What the row stands for.
  final ReportSourceKind kind;

  /// Counted learning events from this source, one per covered leaf.
  final int events;

  /// The distinct leaves of the learner's corpus with a counted event from
  /// this source. Kept so a roll-up unions it without recounting.
  final Set<LeafRef> leaves;

  /// `leaves.length`.
  int get distinctLeaves => leaves.length;

  @override
  bool operator ==(Object other) =>
      other is ReportSourceTotals &&
      other.source == source &&
      other.kind == kind &&
      other.events == events &&
      _setEquals(other.leaves, leaves);

  @override
  int get hashCode =>
      Object.hash(source, kind, events, Object.hashAllUnordered(leaves));

  @override
  String toString() =>
      'ReportSourceTotals($source, ${kind.name}, events: $events, '
      'distinct: $distinctLeaves)';
}

/// The roll-up key of a sub-track [name]: trimmed and case-folded, so
/// "School", "school " and "SCHOOL" share one group (gap G-5).
String reportGroupKey(String name) => name.trim().toLowerCase();

/// The year line label of a `school_year` sub-track starting in
/// [academicYear]: "YYYY–YY" with an en dash (2024 → "2024–25").
String reportSchoolYearLabel(int academicYear) =>
    '$academicYear–${((academicYear + 1) % 100).toString().padLeft(2, '0')}';

/// The line label of an `ongoing` sub-track from its inclusive window
/// endpoints: "start – end", or "start –" for an open window.
String reportWindowLabel(CivilDate windowStart, CivilDate? windowEnd) =>
    windowEnd == null ? '$windowStart –' : '$windowStart – $windowEnd';

/// Whether a member line is still running.
///
/// Computed only from the stored end state (`ended_at`): a line is never
/// "completed" from a finished date, zero activity or exhausted ground
/// (UX-DR-70).
enum ReportLineStatus {
  /// No `ended_at`.
  active,

  /// Ended or deleted (`ended_at` set, any `end_reason`): "Ended".
  ended,
}

/// One sub-track in the roll-up: a year line (`school_year`) or a window
/// line (`ongoing`).
final class ReportMemberLine {
  /// Creates the line.
  const ReportMemberLine({
    required this.subTrackId,
    required this.name,
    required this.type,
    required this.windowStart,
    required this.label,
    required this.totals,
    this.academicYear,
    this.windowEnd,
    this.endedAt,
    this.endedOn,
    this.endReason,
  });

  /// The sub-track ULID (the `source` of its events).
  final String subTrackId;

  /// The stored (current or tombstoned) `name`, as stored.
  final String name;

  /// `school_year` or `ongoing`.
  final SubTrackType type;

  /// The year line key of a `school_year` member.
  final int? academicYear;

  /// The stored `window_start`.
  final CivilDate windowStart;

  /// The stored `window_end`; null for an open window.
  final CivilDate? windowEnd;

  /// "YYYY–YY" for a school year ([reportSchoolYearLabel]); the window
  /// otherwise ([reportWindowLabel]).
  final String label;

  /// The stored `ended_at`.
  final DateTime? endedAt;

  /// The learner civil date of [endedAt] (AD-41).
  final CivilDate? endedOn;

  /// The stored `end_reason`.
  final SubTrackEndReason? endReason;

  /// The sub-track's source totals (also in [ReportProjection.sources]).
  final ReportSourceTotals totals;

  /// [ReportLineStatus.ended] iff the doc has `ended_at`.
  ReportLineStatus get status =>
      endedAt == null ? ReportLineStatus.active : ReportLineStatus.ended;

  @override
  bool operator ==(Object other) =>
      other is ReportMemberLine &&
      other.subTrackId == subTrackId &&
      other.name == name &&
      other.type == type &&
      other.academicYear == academicYear &&
      other.windowStart == windowStart &&
      other.windowEnd == windowEnd &&
      other.label == label &&
      other.endedAt == endedAt &&
      other.endedOn == endedOn &&
      other.endReason == endReason &&
      other.totals == totals;

  @override
  int get hashCode => Object.hash(
    subTrackId,
    name,
    type,
    academicYear,
    windowStart,
    windowEnd,
    label,
    endedAt,
    endedOn,
    endReason,
    totals,
  );

  @override
  String toString() => 'ReportMemberLine($subTrackId, $label, ${status.name})';
}

/// Sub-tracks of one curriculum sharing a [reportGroupKey].
final class ReportGroup {
  /// Creates the group.
  ReportGroup({
    required this.key,
    required this.name,
    required List<ReportMemberLine> members,
  }) : members = List.unmodifiable(members),
       events = members.fold(0, (n, m) => n + m.totals.events),
       leaves = Set.unmodifiable({for (final m in members) ...m.totals.leaves});

  /// The normalized name ([reportGroupKey]).
  final String key;

  /// The display name: the trimmed name of the latest member (by
  /// `window_start`, then ULID).
  final String name;

  /// The members, by `window_start`, then ULID.
  final List<ReportMemberLine> members;

  /// The members' events, added.
  final int events;

  /// The union of the members' leaves: a leaf learnt in two years counts
  /// once.
  final Set<LeafRef> leaves;

  /// `leaves.length`.
  int get distinctLeaves => leaves.length;

  @override
  bool operator ==(Object other) =>
      other is ReportGroup &&
      other.key == key &&
      other.name == name &&
      _listEquals(other.members, members);

  @override
  int get hashCode => Object.hash(key, name, Object.hashAll(members));

  @override
  String toString() => 'ReportGroup($key, ${members.length} members)';
}

/// The report projection of one curriculum (AD-48): the only input of
/// every report total, count and velocity.
final class ReportProjection {
  /// Creates the projection. Prefer [deriveReportProjection].
  ReportProjection({
    required this.curriculumId,
    required this.distinctLearnt,
    required this.totalEvents,
    required Map<String, ReportSourceTotals> sources,
    this.beforeTracking,
    List<ReportGroup> groups = const [],
  }) : sources = Map.unmodifiable(sources),
       groups = List.unmodifiable(groups);

  /// A curriculum with nothing to report: Home only, at zero.
  factory ReportProjection.empty(String curriculumId) => ReportProjection(
    curriculumId: curriculumId,
    distinctLearnt: 0,
    totalEvents: 0,
    sources: {
      LearningEvent.sourceMain: ReportSourceTotals.zero(
        LearningEvent.sourceMain,
        ReportSourceKind.main,
      ),
    },
  );

  /// The curriculum.
  final String curriculumId;

  /// Distinct leaves learnt: the engine learnt set's size (FR-14, FR-31).
  final int distinctLearnt;

  /// Total counted learning events, one per covered leaf (FR-30, FR-31).
  /// It keeps growing after the goal completes (FR-31).
  final int totalEvents;

  /// Per-source totals keyed by `source`: always Home (`main`), then every
  /// sub-track source. The Before-tracking bucket is [beforeTracking].
  final Map<String, ReportSourceTotals> sources;

  /// The Before-tracking bucket; null when there is none.
  final ReportSourceTotals? beforeTracking;

  /// The sub-track roll-up, by [ReportGroup.key]; empty with no
  /// sub-tracks.
  final List<ReportGroup> groups;

  /// The Home (`main`) totals.
  ReportSourceTotals get home => sources[LearningEvent.sourceMain]!;

  @override
  bool operator ==(Object other) =>
      other is ReportProjection &&
      other.curriculumId == curriculumId &&
      other.distinctLearnt == distinctLearnt &&
      other.totalEvents == totalEvents &&
      _mapEquals(other.sources, sources) &&
      other.beforeTracking == beforeTracking &&
      _listEquals(other.groups, groups);

  @override
  int get hashCode => Object.hash(
    curriculumId,
    distinctLearnt,
    totalEvents,
    Object.hashAllUnordered(sources.values),
    beforeTracking,
    Object.hashAll(groups),
  );

  @override
  String toString() =>
      'ReportProjection($curriculumId, distinct: $distinctLearnt, '
      'events: $totalEvents, sources: ${sources.length})';
}

final class _SourceAcc {
  int events = 0;
  final Set<LeafRef> leaves = {};
}

/// The report projection of [curriculumId].
///
/// [countedLearns] are the curriculum's counted `learn` events (stage 1);
/// [learntLeaves] is its learnt set (stage 2); [inScope] is the learner's
/// corpus. [subTracks] are the curriculum's `sub_tracks` docs, live and
/// tombstoned; [civilDayOf] is the AD-41 learner civil date of an instant.
/// Nothing here re-derives voids, locks or the learnt set.
///
/// Every sub-track is listed in [ReportProjection.sources] and the roll-up
/// (zero totals when it has no counted event), except one whose creation
/// was undone (`end_reason = undo`) and has no counted event.
ReportProjection deriveReportProjection({
  required String curriculumId,
  required List<LearningEvent> countedLearns,
  required Corpus corpus,
  required bool Function(LeafRef leaf) inScope,
  required Set<LeafRef> learntLeaves,
  required List<SubTrack> subTracks,
  required CivilDate Function(DateTime instantUtc) civilDayOf,
}) {
  final known = {for (final s in subTracks) s.id};
  final bySource = <String, _SourceAcc>{LearningEvent.sourceMain: _SourceAcc()};
  _SourceAcc? before;
  var total = 0;
  for (final e in countedLearns) {
    final leaves = [
      for (final leaf in coveredLeaves(e, corpus))
        if (inScope(leaf)) leaf,
    ];
    if (leaves.isEmpty) continue;
    final source = e.source!;
    final acc =
        e.dateState == DateState.beforeTracking &&
            source == LearningEvent.sourceMain
        ? (before ??= _SourceAcc())
        : bySource.putIfAbsent(source, _SourceAcc.new);
    acc.events += leaves.length;
    acc.leaves.addAll(leaves);
    total += leaves.length;
  }
  ReportSourceTotals totalsOf(String source, _SourceAcc acc) =>
      ReportSourceTotals(
        source: source,
        kind: source == LearningEvent.sourceMain
            ? ReportSourceKind.main
            : known.contains(source)
            ? ReportSourceKind.subTrack
            : ReportSourceKind.unknownSubTrack,
        events: acc.events,
        leaves: acc.leaves,
      );
  final listed = [
    for (final s in subTracks)
      if (s.endReason != SubTrackEndReason.undo || bySource.containsKey(s.id))
        s,
  ];
  for (final s in listed) {
    bySource.putIfAbsent(s.id, _SourceAcc.new);
  }
  final sourceIds = bySource.keys.toList()
    ..sort((a, b) {
      if (a == LearningEvent.sourceMain) return -1;
      if (b == LearningEvent.sourceMain) return 1;
      return a.compareTo(b);
    });
  final sources = {for (final s in sourceIds) s: totalsOf(s, bySource[s]!)};
  return ReportProjection(
    curriculumId: curriculumId,
    distinctLearnt: learntLeaves.length,
    totalEvents: total,
    sources: sources,
    groups: _groups(listed, sources, civilDayOf),
    beforeTracking: before == null
        ? null
        : ReportSourceTotals(
            source: reportBeforeTrackingKey,
            kind: ReportSourceKind.beforeTracking,
            events: before.events,
            leaves: before.leaves,
          ),
  );
}

/// The roll-up of [listed] sub-tracks by [reportGroupKey], in key order.
List<ReportGroup> _groups(
  List<SubTrack> listed,
  Map<String, ReportSourceTotals> sources,
  CivilDate Function(DateTime instantUtc) civilDayOf,
) {
  final byKey = <String, List<SubTrack>>{};
  for (final s in listed) {
    (byKey[reportGroupKey(s.name)] ??= []).add(s);
  }
  final keys = byKey.keys.toList()..sort();
  return [
    for (final key in keys) _group(key, byKey[key]!, sources, civilDayOf),
  ];
}

ReportGroup _group(
  String key,
  List<SubTrack> members,
  Map<String, ReportSourceTotals> sources,
  CivilDate Function(DateTime instantUtc) civilDayOf,
) {
  members.sort((a, b) {
    final byStart = a.windowStart.compareTo(b.windowStart);
    return byStart != 0 ? byStart : a.id.compareTo(b.id);
  });
  return ReportGroup(
    key: key,
    name: members.last.name.trim(),
    members: [
      for (final s in members)
        ReportMemberLine(
          subTrackId: s.id,
          name: s.name,
          type: s.type,
          academicYear: s.academicYear,
          windowStart: s.windowStart,
          windowEnd: s.windowEnd,
          label: s.type == SubTrackType.schoolYear && s.academicYear != null
              ? reportSchoolYearLabel(s.academicYear!)
              : reportWindowLabel(s.windowStart, s.windowEnd),
          endedAt: s.endedAt,
          endedOn: s.endedAt == null ? null : civilDayOf(s.endedAt!),
          endReason: s.endReason,
          totals: sources[s.id]!,
        ),
    ],
  );
}
