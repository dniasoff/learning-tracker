import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';

/// Builds the identifier-only payload from the canonical learner engine.
/// No account identifiers, free text, event times, points or settings are
/// included. The callable adds the server-owned display identity/timestamp.
Map<String, Object?> socialSummaryPayload(LearnerState state) {
  final active =
      state.curricula.entries
          .where(
            (entry) =>
                entry.value.evaluated &&
                CurriculumId.fromStorageKey(entry.key) != null,
          )
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
  final activeIds = active.map((entry) => entry.key).toSet();
  final streakRows = <Map<String, Object?>>[];
  final tracks = <Map<String, Object?>>[];
  for (final entry in active) {
    final streak = entry.value.streak;
    if (streak != null) {
      streakRows.add({
        'curriculum_id': entry.key,
        'current_days': streak.current,
        'best_days': streak.best,
      });
    }
    tracks.add({
      'curriculum_id': entry.key,
      'position_ref': entry.value.mainTrackPosition,
    });
  }

  final today = parseCivilDay(state.today);
  final weekStartDay = today.subtract(Duration(days: today.weekday % 7));
  final weekStart = formatCivilDay(weekStartDay);
  final weeklyCounts = <String, ({int limudim, int chazaros})>{
    for (final id in activeIds) id: (limudim: 0, chazaros: 0),
  };
  for (final event in state.countedLearns) {
    final curriculumId = event.curriculumId;
    final learnedOn = event.learnedOn;
    if (curriculumId == null ||
        learnedOn == null ||
        !activeIds.contains(curriculumId) ||
        learnedOn.compareTo(weekStart) < 0 ||
        learnedOn.compareTo(state.today) > 0) {
      continue;
    }
    final counts = weeklyCounts[curriculumId]!;
    weeklyCounts[curriculumId] = event.stage == null
        ? (limudim: counts.limudim + 1, chazaros: counts.chazaros)
        : (limudim: counts.limudim, chazaros: counts.chazaros + 1);
  }

  final siyumim = <Map<String, Object?>>[];
  for (final entry in state.curricula.entries) {
    if (CurriculumId.fromStorageKey(entry.key) == null) continue;
    for (final completed in entry.value.completedUnits) {
      siyumim.add({
        'curriculum_id': entry.key,
        'ref': completed.unit.ref,
        'level': completed.unit.level,
      });
    }
  }
  final boundedSiyumim = siyumim.length <= 100
      ? siyumim
      : siyumim.sublist(siyumim.length - 100);

  return {
    'streak': {'by_curriculum': streakRows},
    'current_tracks': tracks,
    'weekly_learning': {
      'week_start': weekStart,
      'by_curriculum': [
        for (final id in activeIds)
          {
            'curriculum_id': id,
            'limudim': weeklyCounts[id]!.limudim,
            'chazaros': weeklyCounts[id]!.chazaros,
          },
      ],
    },
    'siyumim': boundedSiyumim,
  };
}
