import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/domain/models/calendar_position.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/progress/data/repositories/firestore_chart_data_repository_adapter.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/profile_program_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calendar_position_providers.g.dart';

/// Provides calendar-relative position for a program track.
///
/// Uses the enrolled program + selected starting anchor (today or offset) to
/// compute expected progress and compare against completed learn items.
///
/// AD-25: [curriculumId] IS the track — there is no separate per-device
/// track id to resolve any more.
@riverpod
Future<CalendarPosition> programCalendarPosition(
  Ref ref,
  CurriculumId curriculumId,
) async {
  // All ref reads MUST happen synchronously before the first await: this
  // provider is rebuilt rapidly on the dashboard, and a `ref.read`/`ref.watch`
  // after an async gap throws "Cannot use Ref after dispose" when the previous
  // build is still pending. Capture every dependency up-front.
  final calendarServiceFuture = ref.watch(
    calendarProgramServiceProvider.future,
  );
  final programRepository = ref.read(learningProgramRepositoryProvider);
  final clockUtc = ref.watch(clockProvider);
  final stageRepository = ref.watch(globalStageRepositoryProvider);
  final programRepo = FirestoreProfileProgramRepositoryAdapter(ref: ref);
  final chartData = FirestoreChartDataRepositoryAdapter(ref: ref);
  // Await after all synchronous ref reads are captured.
  final calendarService = await calendarServiceFuture;

  // 1. Resolve the track's enrolled program.
  final enrollment = await programRepo.getProgram(curriculumId);
  if (enrollment == null) {
    throw StateError(
      'Curriculum ${curriculumId.storageKey} has no program enrollment',
    );
  }

  final program = programRepository.getProgramById(enrollment.programId);
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

  // 2–3. Use the same local calendar day as the scheduler / add-track flow
  // (clock is UTC per P5; calendar_cycles keys are local YYYY-MM-DD).
  final todayLocal = LocalDayUtils.extractLocalDate(clockUtc);
  final startLocal = enrollment.trackingStartDate != null
      ? (enrollment.trackingStartDate!.isBefore(DateTime.utc(2020, 1, 1))
            ? todayLocal
            : LocalDayUtils.extractLocalDate(enrollment.trackingStartDate!))
      : (() {
          final rawRef = enrollment.trackingStartRef;
          if (rawRef == null || !rawRef.startsWith('offset:')) {
            return todayLocal;
          }
          final parsed = int.tryParse(rawRef.substring('offset:'.length));
          if (parsed == null) return todayLocal;
          return LocalDayUtils.extractLocalDate(
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

  // 4. Count unique first-stage completions (learn-stage progress).
  final stages = await stageRepository.getStagesForCurriculum(curriculumId);
  final firstStage = stages.isEmpty
      ? null
      : (stages.toList()..sort((a, b) => a.stageOrder.compareTo(b.stageOrder)))
            .first;
  final completions = await chartData.getCompletionsByTier(
    tier: CompletionTierFilter.trackAchievement,
    curriculumId: curriculumId,
  );
  final completedLearnItems = <String>{};
  for (final c in completions) {
    if (firstStage == null || c.stageId == firstStage.stageOrder) {
      completedLearnItems.add(c.sefariaRef);
    }
  }
  final completionCount = completedLearnItems.length;

  // 5. Compare expected vs actual since chosen start anchor.
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
