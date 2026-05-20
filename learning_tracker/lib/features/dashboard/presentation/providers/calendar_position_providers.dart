import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/domain/models/calendar_position.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_registry.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_position_providers.g.dart';

/// Provides calendar-relative position for a program track.
///
/// Uses the enrolled program + selected starting anchor (today or offset) to
/// compute expected progress and compare against completed learn items.
@riverpod
Future<CalendarPosition> programCalendarPosition(Ref ref, int trackId) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final calendarService = ref.watch(calendarProgramServiceProvider);

  // 1. Look up the track
  final track = await (db.select(
    db.curriculumTracks,
  )..where((t) => t.id.equals(trackId))).getSingleOrNull();
  if (track == null) throw StateError('Track $trackId not found');

  // 2. Resolve the track's enrolled program
  final enrollment = await db.profileProgramDao
      .getProgramForProfileAndCurriculum(profileId, track.curriculumId);
  if (enrollment == null) {
    throw StateError('Track $trackId has no program enrollment');
  }

  final program = ref
      .read(learningProgramRepositoryProvider)
      .getProgramById(enrollment.programId);
  if (program == null) {
    throw StateError('Program ${enrollment.programId} not found');
  }

  final apiKey = program.apiProgramKey;
  if (apiKey == null || apiKey.isEmpty) {
    throw StateError('Program ${program.name} has no calendar API key');
  }

  final programKey =
      CalendarProgramRegistry.byId(apiKey)?.id ??
      CalendarProgramRegistry.byApiKey(apiKey)?.id ??
      CalendarProgramRegistry.byHebcalCategory(apiKey)?.id;
  if (programKey == null) {
    throw StateError(
      'Unable to resolve calendar key for program ${program.name}',
    );
  }

  // 3–4. Use the same local calendar day as the scheduler / add-track flow
  // (clock is UTC per P5; calendar_cycles keys are local YYYY-MM-DD).
  final clockUtc = ref.watch(clockProvider);
  final todayLocal = DateUtils.extractLocalDate(clockUtc);
  final startLocal = enrollment.trackingStartDate != null
      ? (enrollment.trackingStartDate!.isBefore(DateTime.utc(2020, 1, 1))
            ? todayLocal
            : DateUtils.extractLocalDate(enrollment.trackingStartDate!))
      : (() {
          final rawRef = enrollment.trackingStartRef;
          if (rawRef == null || !rawRef.startsWith('offset:'))
            return todayLocal;
          final parsed = int.tryParse(rawRef.substring('offset:'.length));
          if (parsed == null) return todayLocal;
          return DateUtils.extractLocalDate(
            clockUtc.add(Duration(days: parsed.clamp(-30, 30))),
          );
        })();

  // Today's program row + cycle length from local calendar DB.
  final todayEntry = await calendarService.getEntry(programKey, todayLocal);
  final cycleEntries = await calendarService.getEntriesForRange(
    programKey,
    DateTime(2024, 1, 1),
    DateTime(2032, 12, 31),
  );
  final totalDays = cycleEntries.isNotEmpty ? cycleEntries.length : 1;

  // 5. Count unique first-stage completions (learn-stage progress).
  final stageRepository = ref.watch(globalStageRepositoryProvider);
  final stages = await stageRepository.getStagesByTrack(trackId);
  final firstStage = stages.isEmpty
      ? null
      : (stages.toList()..sort((a, b) => a.stageOrder.compareTo(b.stageOrder)))
            .first;
  final completions = await db.completionDao.getCompletionsByTrackAndProfile(
    trackId,
    profileId,
  );
  final completedLearnItems = <String>{};
  for (final c in completions) {
    if (firstStage == null ||
        c.stageId == firstStage.id ||
        c.stageId == firstStage.stageOrder) {
      completedLearnItems.add(c.sefariaRef);
    }
  }
  final completionCount = completedLearnItems.length;

  // 6. Compare expected vs actual since chosen start anchor.
  final elapsedDays = todayLocal.difference(startLocal).inDays;
  final expectedCount = elapsedDays >= 0 ? elapsedDays + 1 : 0;
  final delta = completionCount - expectedCount;
  final status = delta > 0
      ? CalendarStatus.ahead
      : delta == 0
      ? CalendarStatus.caughtUp
      : CalendarStatus.behind;
  final currentDay = (expectedCount + delta).clamp(1, totalDays);

  return CalendarPosition(
    currentDay: currentDay,
    totalDays: totalDays,
    todayRef: todayEntry?.todayRef ?? '',
    todayDisplayHe: todayEntry?.todayRef ?? '',
    delta: delta,
    status: status,
  );
}
