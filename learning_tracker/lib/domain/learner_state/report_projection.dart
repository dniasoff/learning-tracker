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
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    identical(a, b) || (a.length == b.length && a.containsAll(b));

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
  }) : sources = Map.unmodifiable(sources);

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

  /// The Home (`main`) totals.
  ReportSourceTotals get home => sources[LearningEvent.sourceMain]!;

  @override
  bool operator ==(Object other) =>
      other is ReportProjection &&
      other.curriculumId == curriculumId &&
      other.distinctLearnt == distinctLearnt &&
      other.totalEvents == totalEvents &&
      _mapEquals(other.sources, sources) &&
      other.beforeTracking == beforeTracking;

  @override
  int get hashCode => Object.hash(
    curriculumId,
    distinctLearnt,
    totalEvents,
    Object.hashAllUnordered(sources.values),
    beforeTracking,
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
/// tombstoned. Nothing here re-derives voids, locks or the learnt set.
ReportProjection deriveReportProjection({
  required String curriculumId,
  required List<LearningEvent> countedLearns,
  required Corpus corpus,
  required bool Function(LeafRef leaf) inScope,
  required Set<LeafRef> learntLeaves,
  required List<SubTrack> subTracks,
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
  final sourceIds = bySource.keys.toList()
    ..sort((a, b) {
      if (a == LearningEvent.sourceMain) return -1;
      if (b == LearningEvent.sourceMain) return 1;
      return a.compareTo(b);
    });
  return ReportProjection(
    curriculumId: curriculumId,
    distinctLearnt: learntLeaves.length,
    totalEvents: total,
    sources: {for (final s in sourceIds) s: totalsOf(s, bySource[s]!)},
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
