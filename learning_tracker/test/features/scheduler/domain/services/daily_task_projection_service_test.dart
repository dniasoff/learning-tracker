/// Domain-layer projection branch tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/dashboard/data/repositories/firestore_study_day_reader_adapter.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_projection_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

class _StudyDays extends Mock implements FirestoreStudyDayReaderAdapter {}

class _Content implements SchedulerContentRepository {
  @override
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId id) async => [
    for (var i = 0; i < 20; i++)
      SchedulerContentItem(
        sefariaRef: '${id.storageKey}-$i',
        sortOrder: i,
        level1: 'Seder',
        level2: 'Masechta',
        level3: 'Perek 1',
        level4: 'Mishna $i',
      ),
  ];
}

class _Completions implements SchedulerCompletionRepository {
  final Map<CurriculumId, List<SchedulerCompletion>> byCurriculum = {};

  @override
  Future<List<SchedulerCompletion>> getCompletions(CurriculumId id) async =>
      byCurriculum[id] ?? const [];
}

class _Order implements SchedulerLearningOrderRepository {
  @override
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId id) async => const [];
}

class _Stages implements SchedulerStageRepository {
  @override
  Future<List<SchedulerStage>> getStages(CurriculumId id) async => const [
    SchedulerStage(id: -1, stageOrder: 1, stageName: 'Learn', delayDays: 0),
  ];
}

class _StageDefinitions implements StageDefinitionRepository {
  @override
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculumId,
  ) async => [
    StageDefinition(
      id: -1,
      curriculumId: curriculumId,
      stageOrder: 1,
      stageName: 'Learn',
      delayDays: 0,
      isDefault: true,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Only getStagesForCurriculum is used by this projection test double.',
  );
}

class _Goals implements GoalRepository {
  final Map<CurriculumId, GoalEntity> values;

  _Goals(this.values);

  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async => [
    if (values[curriculumId] case final goal?) goal,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Only getGoals is used by this projection test double.',
  );
}

class _Programs implements ProfileProgramRepository {
  final Map<CurriculumId, ProfileProgramEntity> values;

  _Programs(this.values);

  @override
  Future<ProfileProgramEntity?> getProgram(CurriculumId curriculumId) async =>
      values[curriculumId];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Only getProgram is used by this projection test double.',
  );
}

class _Calendar implements LocalCalendarEngine {
  _Calendar(this.programId);

  final String programId;

  @override
  Future<CalendarProgramEntry?> getEntry(String id, DateTime date) async {
    if (id != programId) return null;
    return CalendarProgramEntry(
      programId: id,
      displayNameEn: 'Test program',
      displayNameHe: '',
      todayRef: 'program-${date.day}',
      apiSource: 'test',
      date: DateTime.utc(date.year, date.month, date.day),
    );
  }

  @override
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String id,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (id != programId) return const [];
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final end = DateTime.utc(endDate.year, endDate.month, endDate.day);
    return [
      for (
        var date = start;
        !date.isAfter(end);
        date = date.add(const Duration(days: 1))
      )
        (await getEntry(id, date))!,
    ];
  }

  @override
  Future<List<CalendarProgramEntry>> getTodayPrograms([DateTime? date]) async =>
      const [];

  @override
  Future<CalendarProgramEntry?> getProgramForDate(
    String programKey,
    DateTime date,
  ) => getEntry(programKey, date);
}

GoalEntity _paceGoal(CurriculumId curriculum, DateTime now) => GoalEntity(
  curriculumId: curriculum,
  goalType: 'pace',
  paceValue: 1,
  pacePeriod: 'day',
  createdAt: now,
  updatedAt: now,
);

CurriculumTrackEntity _track(
  CurriculumId curriculum,
  DateTime activatedAt, {
  DateTime? lastReorderAt,
}) => CurriculumTrackEntity(
  curriculumId: curriculum,
  state: 'active',
  stateChangedAt: activatedAt,
  activatedAt: activatedAt,
  lastReorderAt: lastReorderAt,
);

ProfileProgramEntity _program(
  CurriculumId curriculum,
  int programId,
  DateTime anchor,
) => ProfileProgramEntity(
  curriculumId: curriculum,
  programId: programId,
  trackingStartDate: anchor,
  updatedAt: anchor,
);

Future<List<DailyTask>> _build({
  required DateTime now,
  required List<CurriculumId> activeCurricula,
  required List<CurriculumTrackEntity> activeTracks,
  required _Goals goals,
  required _Programs programs,
  required CalendarProgramService calendarService,
  _Completions? completions,
}) async {
  final completionRepo = completions ?? _Completions();
  final stages = _StageDefinitions();
  final reader = _StudyDays();
  when(
    () => reader.getConfigsForCurriculum(any()),
  ).thenAnswer((_) async => const []);
  final engine = SchedulerEngine(
    contentRepository: _Content(),
    completionRepository: completionRepo,
    stageRepository: _Stages(),
    learningOrderRepository: _Order(),
  );
  return buildProjectionTasks(
    trackLabelFor: (curriculum) => curriculum.storageKey,
    activeCurricula: activeCurricula,
    activeTracks: activeTracks,
    completionRepository: completionRepo,
    profileProgramRepository: programs,
    goalRepository: goals,
    studyDayReader: reader,
    stageRepository: stages,
    engine: engine,
    now: now,
    calendarService: calendarService,
    getScopedContent: (curriculum) async => [
      if (curriculum == CurriculumId.mishnayos)
        for (var i = 0; i < 20; i++)
          ContentItem(
            curriculumId: curriculum.storageKey,
            level1: 'Seder',
            level2: 'Masechta',
            level3: 'Perek 1',
            level4: 'Mishna $i',
            displayNameHe: 'משנה',
            displayNameEn: 'Mishna',
            sefariaRef: 'mishnayos-$i',
            sortOrder: i,
            isLeaf: true,
          ),
    ],
    programRepository: LearningProgramRepository.instance,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  test(
    'self-paced amnesty keeps only work on or after the reorder day',
    () async {
      final today = DateTime.utc(2026, 5, 27);
      final anchor = today.subtract(const Duration(days: 5));
      final tasks = await _build(
        now: today,
        activeCurricula: const [CurriculumId.mishnayos],
        activeTracks: [
          _track(
            CurriculumId.mishnayos,
            anchor,
            lastReorderAt: anchor.add(const Duration(days: 3, hours: 15)),
          ),
        ],
        goals: _Goals({
          CurriculumId.mishnayos: _paceGoal(CurriculumId.mishnayos, today),
        }),
        programs: _Programs({}),
        calendarService: CalendarProgramService(_Calendar('unused')),
      );

      expect(tasks.where((task) => task.isOverdue), hasLength(2));
      expect(tasks.where((task) => !task.isOverdue), hasLength(1));
      expect(
        tasks
            .where((task) => task.isOverdue)
            .every((task) => task.reason == 'Behind pace'),
        isTrue,
      );
      expect(tasks.where((task) => !task.isOverdue).single.reason, 'Due today');
    },
  );

  test(
    'one call routes enrolled and unenrolled curricula through their branches',
    () async {
      final today = DateTime.utc(2026, 5, 27);
      final program = LearningProgramRepository.instance
          .getAllPrograms()
          .firstWhere((candidate) => candidate.apiProgramKey == 'daf_yomi');
      final programCurriculum = CurriculumId.values.firstWhere(
        (curriculum) => curriculum.storageKey == program.curriculumType,
      );
      final programAnchor = today.subtract(const Duration(days: 2));
      final tasks = await _build(
        now: today,
        activeCurricula: [CurriculumId.mishnayos, programCurriculum],
        activeTracks: [
          _track(CurriculumId.mishnayos, today),
          _track(programCurriculum, programAnchor),
        ],
        goals: _Goals({
          CurriculumId.mishnayos: _paceGoal(CurriculumId.mishnayos, today),
        }),
        programs: _Programs({
          programCurriculum: _program(
            programCurriculum,
            program.id,
            programAnchor,
          ),
        }),
        calendarService: CalendarProgramService(
          _Calendar(program.apiProgramKey!),
        ),
      );

      final selfPaced = tasks
          .where((task) => task.curriculumId == CurriculumId.mishnayos)
          .toList();
      final programmed = tasks
          .where((task) => task.curriculumId == programCurriculum)
          .toList();
      expect(selfPaced, hasLength(1));
      expect(selfPaced.single.priority, DailyTaskPriority.newLearning);
      expect(programmed, hasLength(3));
      expect(
        programmed.where(
          (task) => task.priority == DailyTaskPriority.overdueProgram,
        ),
        hasLength(2),
      );
      expect(
        programmed
            .where((task) => task.priority == DailyTaskPriority.overdueProgram)
            .every(
              (task) => task.reason == 'Program day pending from previous days',
            ),
        isTrue,
      );
      expect(
        programmed.where(
          (task) => task.priority == DailyTaskPriority.todayProgram,
        ),
        hasLength(1),
      );
      expect(
        programmed
            .singleWhere(
              (task) => task.priority == DailyTaskPriority.todayProgram,
            )
            .reason,
        'Program assignment for today',
      );
    },
  );

  test(
    'back-dated program enrollment is protected by the anchor clamp',
    () async {
      final today = DateTime.utc(2026, 5, 27);
      final program = LearningProgramRepository.instance
          .getAllPrograms()
          .firstWhere((candidate) => candidate.apiProgramKey == 'daf_yomi');
      final programCurriculum = CurriculumId.values.firstWhere(
        (curriculum) => curriculum.storageKey == program.curriculumType,
      );
      final anchor = today.subtract(const Duration(days: 4));
      final tasks = await _build(
        now: today,
        activeCurricula: [programCurriculum],
        activeTracks: [_track(programCurriculum, today, lastReorderAt: today)],
        goals: _Goals({}),
        programs: _Programs({
          programCurriculum: _program(programCurriculum, program.id, anchor),
        }),
        calendarService: CalendarProgramService(
          _Calendar(program.apiProgramKey!),
        ),
      );

      expect(tasks.where((task) => task.isOverdue), hasLength(4));
      expect(tasks.where((task) => !task.isOverdue), hasLength(1));
    },
  );
}
