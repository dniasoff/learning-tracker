import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/data/mock_program_cycles.dart';
import 'package:learning_tracker/features/dashboard/domain/models/calendar_position.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'program_calendar_providers.g.dart';

/// Provides CalendarPosition for a program track.
///
/// Mock implementation: computes plausible position from track creation date
/// and completion count. Will be replaced by real calendar computation.
///
/// Interface contract (stable):
///   Input: trackId (int)
///   Output: AsyncValue<CalendarPosition>
@riverpod
Future<CalendarPosition> programCalendarPosition(Ref ref, int trackId) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  // 1. Look up the track
  final track = await (db.select(
    db.curriculumTracks,
  )..where((t) => t.id.equals(trackId))).getSingleOrNull();
  if (track == null) throw StateError('Track $trackId not found');

  // 2. Get mock cycle data for this curriculum
  final cycleData =
      mockProgramCycles[track.curriculumId] ?? defaultProgramCycleData;

  // 3. Compute position from days since track creation
  final now = DateTime.now().toUtc();
  final daysSinceCreation = now.difference(track.activatedAt).inDays;
  final currentDay = daysSinceCreation.clamp(1, cycleData.totalDays);

  // 4. Get completion count for delta computation
  final completionCount = await db.completionDao.getAggregateCountByTrack(
    trackId,
    profileId,
  );
  final delta = completionCount - currentDay;

  // 5. Derive status from delta
  final status = delta > 0
      ? CalendarStatus.ahead
      : delta == 0
      ? CalendarStatus.caughtUp
      : CalendarStatus.behind;

  return CalendarPosition(
    currentDay: currentDay,
    totalDays: cycleData.totalDays,
    todayRef: cycleData.sampleTodayRef,
    todayDisplayHe: cycleData.sampleTodayDisplayHe,
    delta: delta,
    status: status,
  );
}
