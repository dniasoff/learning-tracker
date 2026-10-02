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
/// * **Velocity** (evaluated curricula only; FR-32): per source, the
///   distinct leaves whose first counted non-chazara `dated`/`catch_up`
///   event *from that source* falls on a `learned_on` day (gap G-1), over
///   the source's span since tracking and over the AD-35 trailing window
///   ([ReportVelocity]). The all-sources figure is AD-35's own "newly
///   learnt overall" rule, so its trailing figure is the dashboard
///   projection's velocity exactly. Per-source rates may add up to more
///   than it: a leaf one source learns after another counts for both
///   sources but once overall.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/projection.dart';
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

/// One velocity figure: [leaves] newly learnt over the inclusive civil
/// days [from]–[through] ([days] days, at least one).
final class ReportVelocityFigure {
  /// Creates the figure.
  const ReportVelocityFigure({
    required this.from,
    required this.through,
    required this.days,
    required this.leaves,
  });

  /// First day of the span.
  final CivilDate from;

  /// Last day of the span.
  final CivilDate through;

  /// Inclusive civil days in the span.
  final int days;

  /// Leaves newly learnt in the span.
  final int leaves;

  /// `leaves ÷ days`, unrounded; for the all-sources trailing figure this
  /// is `Projection.velocityPerDay`.
  double get leavesPerDay => leaves / days;

  /// Leaves per week, to one decimal place.
  double get leavesPerWeek => (leaves * 70 / days).round() / 10;

  @override
  bool operator ==(Object other) =>
      other is ReportVelocityFigure &&
      other.from == from &&
      other.through == through &&
      other.days == days &&
      other.leaves == leaves;

  @override
  int get hashCode => Object.hash(from, through, days, leaves);

  @override
  String toString() =>
      'ReportVelocityFigure($from..$through, $leaves / $days days)';
}

/// The velocity of one source (or of all sources) (FR-32, AD-35).
final class ReportVelocity {
  /// Creates the velocity.
  const ReportVelocity({this.sinceTracking, this.trailing});

  /// From tracking start (or the sub-track's later `window_start`) through
  /// today (or the sub-track's end day); null with no tracking start or an
  /// empty span.
  final ReportVelocityFigure? sinceTracking;

  /// The AD-35 window over the same span: the trailing 28 days, or all of
  /// it with 14–27 days; null under 14 days ("Too early to tell").
  final ReportVelocityFigure? trailing;

  /// Whether the trailing figure is too early to tell.
  bool get tooEarly => trailing == null;

  @override
  bool operator ==(Object other) =>
      other is ReportVelocity &&
      other.sinceTracking == sinceTracking &&
      other.trailing == trailing;

  @override
  int get hashCode => Object.hash(sinceTracking, trailing);

  @override
  String toString() => 'ReportVelocity($sinceTracking, $trailing)';
}

/// What the engine already derived for the velocity of an evaluated
/// curriculum; [deriveReportProjection] takes none for a curriculum that
/// is not evaluated (no velocity, no on-track status).
final class ReportVelocityBasis {
  /// Creates the basis.
  const ReportVelocityBasis({
    required this.newlyLearnt,
    required this.trackingStart,
    required this.today,
    required this.firstStage,
    this.projection,
    this.calendarProgram = false,
  });

  /// AD-35 `newlyLearntOn`: the day each leaf was newly learnt overall.
  final Map<LeafRef, CivilDate> newlyLearnt;

  /// `trackedHistoryStart`: `tracking_start_date`, else the earliest
  /// `learned_on`; null with neither.
  final CivilDate? trackingStart;

  /// The projection day (`projectionDay`: today, held at a lock's start
  /// during a lock).
  final CivilDate today;

  /// The first review stage order (chazara is a later stage).
  final int? firstStage;

  /// The engine's projection, for the FR-18/FR-21 on-track status.
  final Projection? projection;

  /// Whether the engine planned the curriculum from a calendar program
  /// ([ReportProjection.calendarProgram]).
  final bool calendarProgram;
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
    this.velocity,
  }) : leaves = Set.unmodifiable(leaves);

  /// No events from [source].
  ReportSourceTotals.zero(this.source, this.kind)
    : events = 0,
      leaves = const {},
      velocity = null;

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

  /// The source's velocity; null for the Before-tracking bucket (FR-32)
  /// and in a curriculum that is not evaluated.
  final ReportVelocity? velocity;

  @override
  bool operator ==(Object other) =>
      other is ReportSourceTotals &&
      other.source == source &&
      other.kind == kind &&
      other.events == events &&
      _setEquals(other.leaves, leaves) &&
      other.velocity == velocity;

  @override
  int get hashCode => Object.hash(
    source,
    kind,
    events,
    Object.hashAllUnordered(leaves),
    velocity,
  );

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
    this.ratePerWeek,
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

  /// The stored `rate_per_week`: the parent's estimate, in the
  /// curriculum's leaves per week (PRD deviation #12). A report shows it
  /// beside the measured velocity and never computes with it (FR-32).
  final double? ratePerWeek;

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
      other.ratePerWeek == ratePerWeek &&
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
    ratePerWeek,
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
    this.allSources,
    this.projectionStatus,
    this.calendarProgram = false,
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

  /// The all-sources velocity: AD-35 "newly learnt overall"; its
  /// trailing figure equals the dashboard projection's velocity. Null when
  /// the curriculum is not evaluated.
  final ReportVelocity? allSources;

  /// The FR-18/FR-21 on-track status the engine's projection computed;
  /// null when the curriculum is not evaluated.
  final ProjectionStatus? projectionStatus;

  /// Whether the curriculum's main track follows a calendar program
  /// (AD-33, AD-35): its on-track status is the engine's calendar
  /// shortfall (assigned through today minus learnt), not the deadline
  /// projection, and it has no sub-tracks (PRD deviation #12). False when
  /// the curriculum is not evaluated.
  final bool calendarProgram;

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
      _listEquals(other.groups, groups) &&
      other.allSources == allSources &&
      other.projectionStatus == projectionStatus &&
      other.calendarProgram == calendarProgram;

  @override
  int get hashCode => Object.hash(
    curriculumId,
    distinctLearnt,
    totalEvents,
    Object.hashAllUnordered(sources.values),
    beforeTracking,
    Object.hashAll(groups),
    allSources,
    projectionStatus,
    calendarProgram,
  );

  @override
  String toString() =>
      'ReportProjection($curriculumId, distinct: $distinctLearnt, '
      'events: $totalEvents, sources: ${sources.length})';
}

final class _SourceAcc {
  int events = 0;
  final Set<LeafRef> leaves = {};

  /// The earliest velocity day of each leaf from this source.
  final Map<LeafRef, CivilDate> firstDay = {};
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
  ReportVelocityBasis? velocity,
}) {
  final known = {for (final s in subTracks) s.id: s};
  final knownBeforeTracking = <LeafRef>{};
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
    if (velocity == null) continue;
    if (e.dateState == DateState.beforeTracking) {
      knownBeforeTracking.addAll(leaves);
    } else if (isVelocityEvent(e, velocity.firstStage)) {
      final day = e.learnedOn!;
      for (final leaf in leaves) {
        final current = acc.firstDay[leaf];
        if (current == null || day.compareTo(current) < 0) {
          acc.firstDay[leaf] = day;
        }
      }
    }
  }
  // As AD-35: a leaf known before tracking is never newly learnt.
  for (final acc in bySource.values) {
    acc.firstDay.removeWhere((leaf, _) => knownBeforeTracking.contains(leaf));
  }
  ReportSourceTotals totalsOf(String source, _SourceAcc acc) {
    final track = known[source];
    return ReportSourceTotals(
      source: source,
      kind: source == LearningEvent.sourceMain
          ? ReportSourceKind.main
          : track != null
          ? ReportSourceKind.subTrack
          : ReportSourceKind.unknownSubTrack,
      events: acc.events,
      leaves: acc.leaves,
      velocity: velocity == null
          ? null
          : _sourceVelocity(acc.firstDay, velocity, track, civilDayOf),
    );
  }

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
    allSources: velocity == null
        ? null
        : _velocity(
            velocity.newlyLearnt,
            velocity.trackingStart,
            velocity.today,
          ),
    projectionStatus: velocity?.projection?.status,
    calendarProgram: velocity?.calendarProgram ?? false,
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
          ratePerWeek: s.ratePerWeek,
          totals: sources[s.id]!,
        ),
    ],
  );
}

/// The velocity of one source from its first-learnt days [firstDay].
///
/// Its span runs from the curriculum's tracking start, or a sub-track's
/// `window_start` when later, through today, or through the civil day of
/// `ended_at` for an ended or deleted sub-track when earlier (AD-41).
ReportVelocity _sourceVelocity(
  Map<LeafRef, CivilDate> firstDay,
  ReportVelocityBasis basis,
  SubTrack? track,
  CivilDate Function(DateTime instantUtc) civilDayOf,
) {
  var start = basis.trackingStart;
  var end = basis.today;
  if (track != null) {
    if (start == null || track.windowStart.compareTo(start) > 0) {
      start = track.windowStart;
    }
    final endedAt = track.endedAt;
    if (endedAt != null) {
      final endedOn = civilDayOf(endedAt);
      if (endedOn.compareTo(end) < 0) end = endedOn;
    }
  }
  return _velocity(firstDay, start, end);
}

/// Since-tracking and AD-35 trailing figures of [firstDay] over the
/// inclusive span [start]–[end].
ReportVelocity _velocity(
  Map<LeafRef, CivilDate> firstDay,
  CivilDate? start,
  CivilDate end,
) {
  if (start == null) return const ReportVelocity();
  ReportVelocityFigure figure(CivilDate from, int days) {
    var leaves = 0;
    for (final day in firstDay.values) {
      if (day.compareTo(from) >= 0 && day.compareTo(end) <= 0) leaves++;
    }
    return ReportVelocityFigure(
      from: from,
      through: end,
      days: days,
      leaves: leaves,
    );
  }

  final span = civilDaySpan(start, end);
  final window = velocityWindow(historyStart: start, through: end);
  return ReportVelocity(
    sinceTracking: span == 0 ? null : figure(start, span),
    trailing: window == null ? null : figure(window.from, window.days),
  );
}
