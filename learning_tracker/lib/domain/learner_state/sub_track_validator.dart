/// AD-45 sub-track validation shared by the owner commands (Story 2.1 /
/// DNI-492) and mirrored, code for code, by `writeWithChangeLog`
/// (`functions/src/sub_track_limits.ts`).
///
/// Both implementations run the same fixture suite,
/// `test/fixtures/sub_track_limits/*.json`, and must agree on every case
/// (AD-45). Every check is a pure function of the sub-track values, so a
/// rejected command writes nothing.
///
/// - **Limits** apply per learner profile **and** curriculum. A sub-track
///   counts toward a limit only while it is not ended and its window has
///   not passed (`window_end` is null or `>= today`, inclusive, AD-41). That
///   is exactly "`onHome` or future-start" (AD-34 predicates).
///   - at most [kMaxOngoingSubTracks] counting `ongoing` sub-tracks;
///   - at most one counting `school_year` sub-track per `academic_year`;
///   - no two counting `school_year` windows overlapping (inclusive bounds:
///     windows that touch on one day overlap).
/// - **Only new violations reject a write.** A violation the stored row
///   already had before the change (e.g. an excess two offline devices
///   reconciled into, which the engine tolerates, AD-45) does not block an
///   unrelated edit of that row.
/// - **Calendar programs** (AD-45, NFR-20): a sub-track cannot be created on
///   a curriculum whose main track follows a calendar program, and a
///   calendar program cannot be set on a curriculum with a non-ended
///   sub-track (tombstone only; a live sub-track with a passed window still
///   blocks it).
/// - **Intent shape** (AC-5): no duplicate ground entry (same `ref`), every
///   ground node in the sub-track's own curriculum (Dart only: it needs the
///   ContentIndex corpus, which the server does not hold), `window_start`
///   not after `window_end`, and positive `rate_per_week` /
///   `weeks_per_year`.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// The AD-45 cap on counting ongoing sub-tracks per profile and curriculum.
const kMaxOngoingSubTracks = 5;

/// Every rule a sub-track write can violate. [code] is the stable wire code
/// shared with `functions/src/sub_track_limits.ts` and the fixtures.
enum SubTrackLimit {
  /// More than [kMaxOngoingSubTracks] counting ongoing sub-tracks.
  ongoingLimit('ongoing_limit'),

  /// A second counting school-year sub-track for one `academic_year`.
  schoolYearDuplicate('school_year_duplicate_academic_year'),

  /// Two counting school-year windows overlap.
  schoolYearOverlap('school_year_window_overlap'),

  /// A sub-track create on a calendar-program curriculum.
  calendarProgramCurriculum('calendar_program_curriculum'),

  /// A calendar program set on a curriculum with a non-ended sub-track.
  calendarProgramHasSubTracks('calendar_program_has_sub_tracks'),

  /// The same ground node entered twice.
  duplicateGround('duplicate_ground'),

  /// A ground node outside the sub-track's curriculum.
  crossCurriculumGround('cross_curriculum_ground'),

  /// `window_start` after `window_end`.
  windowReversed('window_reversed'),

  /// `rate_per_week` is zero or negative.
  nonPositiveRate('non_positive_rate'),

  /// `weeks_per_year` is zero or negative.
  nonPositiveWeeks('non_positive_weeks');

  const SubTrackLimit(this.code);

  /// The stable wire code.
  final String code;

  /// Wire code → value.
  static final Map<String, SubTrackLimit> byCode = {
    for (final l in values) l.code: l,
  };
}

/// One violated rule; [subject] names what it conflicts with (another
/// sub-track id, or a ground `ref`), when there is one.
final class SubTrackViolation {
  /// Creates a violation.
  const SubTrackViolation(this.limit, {this.subject});

  /// The violated rule.
  final SubTrackLimit limit;

  /// The conflicting sub-track id or ground ref, if any.
  final String? subject;

  @override
  bool operator ==(Object other) =>
      other is SubTrackViolation &&
      other.limit == limit &&
      other.subject == subject;

  @override
  int get hashCode => Object.hash(limit, subject);

  @override
  String toString() =>
      'SubTrackViolation(${limit.code}${subject == null ? '' : ', $subject'})';
}

/// Whether [track] counts toward the AD-45 limits on [today]: not ended and
/// its window not passed (null `window_end` = open; inclusive).
bool countsTowardSubTrackLimits(SubTrack track, CivilDate today) {
  if (track.isEnded) return false;
  final end = track.windowEnd;
  return end == null || end.compareTo(today) >= 0;
}

/// The AC-5 shape violations of [track]: duplicate ground, cross-curriculum
/// ground (only when [corpus] is given), reversed window and non-positive
/// rate or weeks.
List<SubTrackViolation> subTrackIntentViolations(
  SubTrack track, {
  Corpus? corpus,
}) {
  final out = <SubTrackViolation>[];
  final seen = <String>{};
  for (final node in track.ground) {
    if (!seen.add(node.ref)) {
      out.add(
        SubTrackViolation(SubTrackLimit.duplicateGround, subject: node.ref),
      );
    }
  }
  if (corpus != null) {
    for (final node in track.ground) {
      final found = corpus.curriculumId == track.curriculumId
          ? corpus.nodeForRef(node.ref)
          : null;
      if (found == null || found.level != node.level) {
        out.add(
          SubTrackViolation(
            SubTrackLimit.crossCurriculumGround,
            subject: node.ref,
          ),
        );
      }
    }
  }
  final end = track.windowEnd;
  if (end != null && track.windowStart.compareTo(end) > 0) {
    out.add(const SubTrackViolation(SubTrackLimit.windowReversed));
  }
  if (!(track.ratePerWeek > 0)) {
    out.add(const SubTrackViolation(SubTrackLimit.nonPositiveRate));
  }
  if (!(track.weeksPerYear > 0)) {
    out.add(const SubTrackViolation(SubTrackLimit.nonPositiveWeeks));
  }
  return out;
}

/// The AD-45 limit and calendar-program violations that writing [candidate]
/// would introduce.
///
/// [prior] is the stored row before the change (null on create). [siblings]
/// is every other sub-track of the learner profile (any curriculum, live
/// and ended; rows with [candidate]'s id are ignored). [calendarProgramId]
/// is the live `profile_programs/{curriculumId}.program_id` of the
/// candidate's curriculum, or null.
List<SubTrackViolation> subTrackLimitViolations({
  required SubTrack candidate,
  required SubTrack? prior,
  required Iterable<SubTrack> siblings,
  required CivilDate today,
  required String? calendarProgramId,
}) {
  final peers = [
    for (final s in siblings)
      if (s.id != candidate.id && s.curriculumId == candidate.curriculumId) s,
  ];
  final after = _limitViolations(candidate, peers, today);
  final before = prior == null || prior.curriculumId != candidate.curriculumId
      ? const <SubTrackViolation>{}
      : _limitViolations(prior, peers, today);
  return [
    if (prior == null && calendarProgramId != null)
      const SubTrackViolation(SubTrackLimit.calendarProgramCurriculum),
    for (final v in after)
      if (!before.contains(v)) v,
  ];
}

/// The violation of setting calendar program [programId] on [curriculumId]
/// while [subTracks] (the learner profile's sub-tracks, any curriculum)
/// hold a non-ended sub-track of that curriculum. Clearing the program
/// (null) is always allowed.
List<SubTrackViolation> calendarProgramSetViolations({
  required String curriculumId,
  required String? programId,
  required Iterable<SubTrack> subTracks,
}) {
  if (programId == null) return const [];
  return [
    for (final s in subTracks)
      if (s.curriculumId == curriculumId && !s.isEnded)
        SubTrackViolation(
          SubTrackLimit.calendarProgramHasSubTracks,
          subject: s.id,
        ),
  ];
}

/// The sorted, de-duplicated wire codes of [violations] (the fixture and
/// cross-language parity form).
List<String> subTrackViolationCodes(Iterable<SubTrackViolation> violations) =>
    ({for (final v in violations) v.limit.code}.toList()..sort());

Set<SubTrackViolation> _limitViolations(
  SubTrack track,
  List<SubTrack> peers,
  CivilDate today,
) {
  if (!countsTowardSubTrackLimits(track, today)) return const {};
  final counting = [
    for (final p in peers)
      if (countsTowardSubTrackLimits(p, today) && p.type == track.type) p,
  ];
  final out = <SubTrackViolation>{};
  switch (track.type) {
    case SubTrackType.ongoing:
      if (counting.length + 1 > kMaxOngoingSubTracks) {
        out.add(const SubTrackViolation(SubTrackLimit.ongoingLimit));
      }
    case SubTrackType.schoolYear:
      for (final p in counting) {
        if (p.academicYear == track.academicYear) {
          out.add(
            SubTrackViolation(SubTrackLimit.schoolYearDuplicate, subject: p.id),
          );
        }
        if (_overlaps(track, p)) {
          out.add(
            SubTrackViolation(SubTrackLimit.schoolYearOverlap, subject: p.id),
          );
        }
      }
  }
  return out;
}

/// Inclusive civil-date interval overlap; a null end is +∞.
bool _overlaps(SubTrack a, SubTrack b) {
  bool startsByEndOf(SubTrack x, SubTrack y) {
    final end = y.windowEnd;
    return end == null || x.windowStart.compareTo(end) <= 0;
  }

  return startsByEndOf(a, b) && startsByEndOf(b, a);
}
