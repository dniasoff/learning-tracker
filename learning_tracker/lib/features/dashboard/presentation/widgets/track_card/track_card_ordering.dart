import 'package:learning_tracker/features/dashboard/domain/models/track_progress.dart';

/// Sort track cards by urgency for dashboard display.
///
/// Group 1: Tracks with tasks today (descending by count)
/// Group 2: Tracks with overdue items
/// Group 3: Remaining tracks
/// Within each group: stable sort by trackId (creation order proxy)
List<TrackProgress> sortTrackCards(List<TrackProgress> tracks) {
  final withTasks = <TrackProgress>[];
  final withOverdue = <TrackProgress>[];
  final rest = <TrackProgress>[];

  for (final t in tracks) {
    if (t.tasksToday > 0) {
      withTasks.add(t);
    } else if (_hasOverdue(t)) {
      withOverdue.add(t);
    } else {
      rest.add(t);
    }
  }

  withTasks.sort((a, b) => b.tasksToday.compareTo(a.tasksToday));

  return [...withTasks, ...withOverdue, ...rest];
}

bool _hasOverdue(TrackProgress t) {
  if (t.chazaraStatus != null && t.chazaraStatus!.overdue > 0) return true;
  if (t.paceStatus != null && t.paceStatus!.daysDelta < 0) return true;
  if (t.calendarPos != null && t.calendarPos!.delta < 0) return true;
  return false;
}
