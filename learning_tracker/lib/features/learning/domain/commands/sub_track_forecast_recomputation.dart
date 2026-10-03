/// History-backed SM-5 comparison for explicitly closed sub-track windows.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_capacity.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';

/// Recomputes the capacity at creation and distinct in-window leaves.
SubTrackForecastComparison? recomputeSubTrackForecast({
  required SubTrack track,
  required Iterable<ChangeLogEntry> history,
  required Iterable<LearningEvent> events,
}) {
  final creation = history
      .where(
        (entry) =>
            entry.entity == GovernedEntity.subTrack &&
            entry.entityId == track.id &&
            entry.before.values.every((value) => value == null),
      )
      .firstOrNull;
  if (creation == null) return null;

  final creationFields = <String, Object?>{};
  for (final change in creation.after.entries) {
    final key = ChangedFieldKey.tryParse(change.key);
    if (key != null &&
        key.collection == 'sub_tracks' &&
        key.docId == track.id) {
      creationFields[key.field] = change.value;
    }
  }
  creationFields[SubTrack.kLastChangeId] = creation.id;
  final SubTrack snapshot;
  try {
    snapshot = SubTrack.fromStorage(track.id, creationFields);
  } on Object {
    return null;
  }

  final end =
      snapshot.windowEnd ??
      formatCivilDay(
        parseCivilDay(
          snapshot.windowStart,
        ).add(const Duration(days: ongoingWindowLengthDays - 1)),
      );
  final forecast = subTrackCapacity(
    snapshot,
    today: snapshot.windowStart,
    targetDate: end,
  );
  final voided = <String>{
    for (final event in events)
      if (event.isVoid) event.targetId!,
  };
  final actualRefs = <String>{};
  for (final event in events) {
    if (event.isVoid ||
        voided.contains(event.id) ||
        event.curriculumId != snapshot.curriculumId ||
        event.source != snapshot.id ||
        event.level != null) {
      continue;
    }
    final learnedOn = event.learnedOn;
    if (learnedOn != null &&
        learnedOn.compareTo(snapshot.windowStart) >= 0 &&
        learnedOn.compareTo(end) <= 0) {
      actualRefs.add(event.ref!);
    }
  }
  final days = civilDays(snapshot.windowStart, end);
  return SubTrackForecastComparison(
    forecast: forecast,
    actual: actualRefs.length,
    windowWeeks: (days / 7).ceil(),
  );
}
