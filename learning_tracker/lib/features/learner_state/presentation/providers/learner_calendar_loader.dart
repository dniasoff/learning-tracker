/// Loads the AD-35 `calendars` engine input: for every calendar program a
/// learner follows, `program_id → [(civilDate, node)]`, read from
/// `CalendarProgramService` and passed to the engine as data (DNI-474).
///
/// The calendar itself is the existing local calendar engine; this file only
/// maps its day entries onto ContentIndex nodes of the learner's corpus.
library;

import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/calendar_plan.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/sefaria_ref_matcher.dart';

/// How far past today the calendar is loaded, so the planner's upcoming
/// days (erev lists for locked days) have their assignments.
const learnerCalendarHorizon = Duration(days: 14);

/// Reads one program's day entries in `[start, end]` (UTC midnights).
typedef CalendarEntriesForRange =
    Future<List<CalendarProgramEntry>> Function(
      String programId,
      DateTime start,
      DateTime end,
    );

/// Reads a curriculum's ContentIndex items.
typedef CurriculumItems =
    Future<List<ContentItem>> Function(String curriculumId);

/// The `calendars` input for [intent] at [nowUtc].
///
/// * Only curricula that follow a calendar program
///   ([followsCalendarProgram]) are loaded, from their
///   `tracking_start_date` (today when it is missing; the engine reports
///   that as a validation error) through today + [horizon].
/// * Each day's calendar ref is resolved to ContentIndex leaves with the
///   scheduler's calendar matcher ([resolveProgramTodayRefs]) and then to
///   the corpus nodes the engine expands; refs the corpus does not know are
///   dropped. Day order and node order follow the calendar.
/// * Two curricula following the same program share one entry list.
Future<Map<String, List<CalendarAssignment>>> loadLearnerCalendars({
  required LearnerIntent intent,
  required LearnerSettingsHistory settingsHistory,
  required DateTime nowUtc,
  required Map<String, Corpus> corpora,
  required CalendarEntriesForRange entriesForRange,
  required CurriculumItems itemsFor,
  Duration horizon = learnerCalendarHorizon,
}) async {
  final today = civilDate(nowUtc, settingsHistory);
  final out = <String, List<CalendarAssignment>>{};
  for (final MapEntry(key: curriculumId, value: track)
      in intent.mainTracks.entries) {
    if (!followsCalendarProgram(track)) continue;
    final programId = track.program!.programId!;
    if (out.containsKey(programId)) continue;
    final corpus = corpora[curriculumId];
    if (corpus == null) continue;
    final start = _utcMidnight(track.program!.trackingStartDate ?? today);
    final end = _utcMidnight(today).add(horizon);
    if (start.isAfter(end)) {
      out[programId] = const [];
      continue;
    }
    final entries = await entriesForRange(programId, start, end);
    final items = await itemsFor(curriculumId);
    final assignments = <CalendarAssignment>[];
    for (final entry in entries) {
      final date = entry.date;
      if (date == null) continue;
      final day = _civil(date);
      final refs = resolveProgramTodayRefs(entry.todayRef, items).toList();
      for (final ref in refs) {
        final node = corpus.nodeForRef(ref);
        if (node != null) assignments.add(CalendarAssignment(day, node));
      }
    }
    out[programId] = List.unmodifiable(assignments);
  }
  return out;
}

DateTime _utcMidnight(CivilDate day) {
  final parts = day.split('-');
  return DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

CivilDate _civil(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
