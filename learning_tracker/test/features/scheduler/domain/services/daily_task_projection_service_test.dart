/// The planner on LearnerState (DNI-477 AC-1, AC-2; AD-49).
///
/// The planner lays out the engine's numbers and never computes one:
/// main-track tasks come from `schedulableRefs` (position / current unit)
/// up to `dailyTarget`, else `paceRate`, else nothing; calendar programs
/// from `programAssignments(date) ∪ programBacklog(date)`; reviews from
/// `reviewsDue(date)` with their stage order and due date. Every state
/// here is a [FakeCurriculumState] (the C0 contract), so each case pins
/// what the planner does with a given engine output.
///
/// R15 disposition of the retired planner tests: the self-paced accrual
/// ("Behind pace" overdue from `selfPacedSchedule`), the reorder amnesty
/// and the program anchor clamp are deleted with their code (AD-49 retires
/// planner quantities and planner amnesty); calendar overdue/today routing
/// is the "calendar program" group below; the golden parity of the
/// no-sub-track learner is `legacy_planner_golden_parity_test.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_projection_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';

const _c = CurriculumId.mishnayos;
const _today = '2026-09-07'; // a Monday

// The engine fixture corpus: Berakhot (1:1, 1:2, 1:3, 2:1, 2:2), Peah
// (1:1, 1:2), Shabbat (1:1, 1:2).
const _b11 = 'Mishnah Berakhot 1:1';
const _b13 = 'Mishnah Berakhot 1:3';
const _b21 = 'Mishnah Berakhot 2:1';
const _b22 = 'Mishnah Berakhot 2:2';
const _p11 = 'Mishnah Peah 1:1';
const _p12 = 'Mishnah Peah 1:2';
const _s11 = 'Mishnah Shabbat 1:1';
const _s12 = 'Mishnah Shabbat 1:2';

final Corpus _corpus = mishnayosCorpus();

const _stages = {1: 'Learn', 2: 'Chazara A', 3: 'Chazara B'};

CurriculumTaskPresentation _presentation({
  bool studyDay = true,
  Map<String, ProgramDayLabel>? labels,
  Map<int, String> stages = _stages,
}) => CurriculumTaskPresentation(
  trackLabel: 'Mishnayos',
  stageNames: stages,
  studyDay: studyDay,
  programDayLabels: labels,
);

CurriculumTasks _plan(
  CurriculumState state, {
  CurriculumTaskPresentation? presentation,
  String date = _today,
}) => planCurriculumTasks(
  curriculum: _c,
  state: state,
  corpus: _corpus,
  date: date,
  presentation: presentation ?? _presentation(),
);

List<String> _refs(List<DailyTask> tasks) =>
    tasks.map((t) => t.contentItemSefariaRef).toList();

/// A Berakhot learner with the rest of the corpus schedulable.
FakeCurriculumState _midBerakhot({
  int? dailyTarget,
  double? paceRate,
  List<String> schedulable = const [_b21, _b22, _p11, _p12, _s11, _s12],
  Map<String, List<ReviewDue>> reviews = const {},
}) => FakeCurriculumState(
  curriculumId: _c.storageKey,
  currentUnit: berakhot,
  mainTrackPosition: schedulable.isEmpty ? null : schedulable.first,
  schedulableRefs: schedulable,
  mainTrackRemaining: schedulable.length,
  dailyTarget: dailyTarget,
  paceRate: paceRate,
  reviews: reviews,
);

void main() {
  group('AC-1: the quantity is the engine\'s', () {
    test('a deadline lays out dailyTarget leaves, even with a pace', () {
      final tasks = _plan(_midBerakhot(dailyTarget: 1, paceRate: 2));
      expect(_refs(tasks.learning), [_b21]);
    });

    test('a pace alone lays out paceRate leaves (whole leaves, rounded '
        'up)', () {
      expect(_refs(_plan(_midBerakhot(paceRate: 2)).learning), [_b21, _b22]);
      expect(_refs(_plan(_midBerakhot(paceRate: 1.2)).learning), [_b21, _b22]);
    });

    test('no deadline and no pace: no new learning; reviews still show', () {
      final tasks = _plan(
        _midBerakhot(
          reviews: {
            _today: [const ReviewDue(_b11, 2, dueFrom: _today)],
          },
        ),
      );
      expect(tasks.learning, isEmpty);
      expect(_refs(tasks.reviews), [_b11]);
    });

    test('a zero dailyTarget is not replaced by the pace', () {
      expect(
        _plan(_midBerakhot(dailyTarget: 0, paceRate: 3)).learning,
        isEmpty,
      );
    });

    test('new learning is the learn stage, due today', () {
      final task = _plan(_midBerakhot(dailyTarget: 1)).learning.single;
      expect(
        task,
        const DailyTask(
          curriculumId: _c,
          contentItemSefariaRef: _b21,
          stageOrder: 1,
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
          reason: 'Due today',
          stageName: 'Learn',
          trackLabel: 'Mishnayos',
          estimatedEffortMinutes: 5,
        ),
      );
    });

    test('only schedulableRefs are laid out: a learnt or sub-track-held '
        'leaf never re-enters', () {
      // Berakhot 1:x is learnt, Peah is held by a sub-track: neither is in
      // the engine's schedulableRefs.
      final tasks = _plan(
        _midBerakhot(dailyTarget: 9, schedulable: const [_b21, _b22, _s11]),
      );
      expect(_refs(tasks.learning), [_b21, _b22, _s11]);
    });

    test('a review-only day shows no new learning but keeps reviews', () {
      final tasks = _plan(
        _midBerakhot(
          dailyTarget: 2,
          reviews: {
            _today: [const ReviewDue(_b11, 2, dueFrom: _today)],
          },
        ),
        presentation: _presentation(studyDay: false),
      );
      expect(tasks.learning, isEmpty);
      expect(tasks.reviews, hasLength(1));
    });

    test('nothing schedulable, nothing due: an empty plan', () {
      final tasks = _plan(
        FakeCurriculumState(curriculumId: _c.storageKey, dailyTarget: 3),
      );
      expect(tasks.learning, isEmpty);
      expect(tasks.reviews, isEmpty);
    });

    test('a curriculum the engine did not evaluate, or with no stages, has '
        'no tasks', () {
      expect(
        _plan(
          FakeCurriculumState(
            curriculumId: _c.storageKey,
            evaluated: false,
            schedulableRefs: const [_b21],
            dailyTarget: 1,
          ),
        ).learning,
        isEmpty,
      );
      expect(
        _plan(
          _midBerakhot(dailyTarget: 1),
          presentation: _presentation(stages: const {}),
        ).learning,
        isEmpty,
      );
    });
  });

  group('AC-2: FR-12a, one masechta at a time', () {
    test('mid-masechta: the batch stays in the current unit', () {
      expect(_refs(_plan(_midBerakhot(dailyTarget: 2)).learning), [_b21, _b22]);
    });

    test('the day the masechta finishes, the next one begins — and only '
        'that one', () {
      expect(_refs(_plan(_midBerakhot(dailyTarget: 3)).learning), [
        _b21,
        _b22,
        _p11,
      ]);
      // Room for more than the next masechta still stops at it.
      expect(_refs(_plan(_midBerakhot(dailyTarget: 6)).learning), [
        _b21,
        _b22,
        _p11,
        _p12,
      ]);
    });

    test('an interleaved order still finishes the current unit first', () {
      final tasks = _plan(
        _midBerakhot(
          dailyTarget: 2,
          schedulable: const [_p11, _b21, _p12, _b22],
        ),
      );
      expect(_refs(tasks.learning), [_b21, _b22]);
    });

    test('without a current unit the position\'s unit is used', () {
      final state = FakeCurriculumState(
        curriculumId: _c.storageKey,
        mainTrackPosition: _p11,
        schedulableRefs: const [_p11, _p12, _s11],
        paceRate: 3,
      );
      expect(_refs(_plan(state).learning), [_p11, _p12, _s11]);
    });

    test('mainTrackBatch with a zero quantity or no corpus', () {
      final mainTrack = _midBerakhot(dailyTarget: 2).mainTrackAtStartOf(_today);
      expect(
        mainTrackBatch(mainTrack: mainTrack, corpus: _corpus, quantity: 0),
        isEmpty,
      );
      expect(mainTrackBatch(mainTrack: mainTrack, corpus: null, quantity: 3), [
        _b21,
        _b22,
        _p11,
      ]);
    });
  });

  group('AC-2: the day\'s batch is anchored at the start of the day — it '
      'shrinks as it is learnt and never refills', () {
    /// A Berakhot learner who had [_b21] onward schedulable at the start of
    /// [_today] and has since learnt [learntToday] of it.
    FakeCurriculumState afterLearning(
      List<String> learntToday, {
      int? dailyTarget,
      double? paceRate,
    }) {
      const atStart = [_b21, _b22, _p11, _p12, _s11, _s12];
      final live = [
        for (final leaf in atStart)
          if (!learntToday.contains(leaf)) leaf,
      ];
      final peahNow = !live.contains(_b21) && !live.contains(_b22);
      return FakeCurriculumState(
        curriculumId: _c.storageKey,
        learntLeaves: learntToday.toSet(),
        currentUnit: peahNow ? peah : berakhot,
        mainTrackPosition: live.first,
        schedulableRefs: live,
        mainTrackRemaining: live.length,
        dailyTarget: dailyTarget,
        paceRate: paceRate,
        dayStarts: {
          _today: MainTrackDayStart(
            schedulableRefs: atStart,
            currentUnit: berakhot,
            position: _b21,
          ),
        },
      );
    }

    test('learning part of the batch shows only the rest of it', () {
      expect(_refs(_plan(afterLearning(const [_b21], paceRate: 2)).learning), [
        _b22,
      ]);
    });

    test('learning the whole batch leaves no new learning that day', () {
      expect(
        _plan(afterLearning(const [_b21, _b22], paceRate: 2)).learning,
        isEmpty,
      );
      // A deadline's target is the engine's start-of-day one; it lays out
      // no further leaves either.
      expect(
        _plan(afterLearning(const [_b21, _b22, _p11], dailyTarget: 3)).learning,
        isEmpty,
      );
    });

    test('learning ahead of the batch also finishes the day', () {
      expect(
        _plan(
          afterLearning(const [_b21, _b22, _p11, _p12], paceRate: 2),
        ).learning,
        isEmpty,
      );
    });

    test('FR-12a transition day: once the finishing masechta is learnt, '
        'only the batch\'s part of the next one remains', () {
      // Start of day: [b21, b22, p11]. Berakhot is now learnt and Peah is
      // the live current unit; Peah 1:2 does not slide in.
      expect(
        _refs(
          _plan(afterLearning(const [_b21, _b22], dailyTarget: 3)).learning,
        ),
        [_p11],
      );
    });

    test('a later date (erev planned list) lays out the live main track', () {
      expect(
        _refs(
          _plan(
            afterLearning(const [_b21], paceRate: 2),
            date: '2026-09-08',
          ).learning,
        ),
        [_b22, _p11],
      );
    });
  });

  group('AC-1: calendar program = assignments ∪ backlog', () {
    const label = (he: 'ברכות א', en: 'Berakhot 1');

    FakeCurriculumState calendarState() => FakeCurriculumState(
      curriculumId: _c.storageKey,
      learntLeaves: const {_b13},
      // A main track and a target exist too; a calendar program ignores
      // them.
      schedulableRefs: const [_s11, _s12],
      mainTrackPosition: _s11,
      dailyTarget: 4,
      backlog: {
        _today: const [_b11, _b21],
      },
      assignments: {
        _today: const [_b21, _b13, _b22],
      },
    );

    test('backlog days are overdue, today\'s day is today, deduplicated by '
        'leaf and less what is learnt', () {
      final tasks = _plan(
        calendarState(),
        presentation: _presentation(labels: {_b11: label}),
      );
      expect(
        [
          for (final t in tasks.learning)
            (t.contentItemSefariaRef, t.priority, t.isOverdue, t.reason),
        ],
        [
          (
            _b11,
            DailyTaskPriority.overdueProgram,
            true,
            'Program day pending from previous days',
          ),
          (
            _b21,
            DailyTaskPriority.overdueProgram,
            true,
            'Program day pending from previous days',
          ),
          (
            _b22,
            DailyTaskPriority.todayProgram,
            false,
            'Program assignment for today',
          ),
        ],
      );
      expect(tasks.learning.first.unitDisplayHe, label.he);
      expect(tasks.learning.first.unitDisplayEn, label.en);
      expect(tasks.learning.last.unitDisplayEn, isNull);
    });

    test('calendar days show on a review-only day too', () {
      final tasks = _plan(
        calendarState(),
        presentation: _presentation(labels: const {}, studyDay: false),
      );
      expect(tasks.learning, hasLength(3));
    });

    test('an empty union is an empty plan, never the main track', () {
      final tasks = _plan(
        FakeCurriculumState(
          curriculumId: _c.storageKey,
          schedulableRefs: const [_s11],
          dailyTarget: 1,
        ),
        presentation: _presentation(labels: const {}),
      );
      expect(tasks.learning, isEmpty);
    });
  });

  group('AC-1: chazara from reviewsDue(date)', () {
    test('stage order and due date come from the engine', () {
      final tasks = _plan(
        _midBerakhot(
          reviews: {
            _today: [
              const ReviewDue(_b11, 2, dueFrom: '2026-09-03'),
              const ReviewDue(_b13, 3, dueFrom: _today),
              const ReviewDue(_b21, 2, dueFrom: '2026-09-06'),
            ],
          },
        ),
      );
      expect(
        [
          for (final t in tasks.reviews)
            (
              t.contentItemSefariaRef,
              t.stageOrder,
              t.stageName,
              t.priority,
              t.isOverdue,
              t.reason,
              t.estimatedEffortMinutes,
            ),
        ],
        [
          (
            _b11,
            2,
            'Chazara A',
            DailyTaskPriority.overdueChazara,
            true,
            'Chazara A overdue by 4 day(s)',
            3,
          ),
          (
            _b21,
            2,
            'Chazara A',
            DailyTaskPriority.overdueChazara,
            true,
            'Chazara A overdue by 1 day(s)',
            3,
          ),
          (
            _b13,
            3,
            'Chazara B',
            DailyTaskPriority.scheduledChazara,
            false,
            'Chazara B due today',
            3,
          ),
        ],
      );
    });

    test('a review done on the date is not a task', () {
      final tasks = _plan(
        _midBerakhot(
          reviews: {
            _today: [
              const ReviewDue(_b11, 2, dueFrom: _today, completedOn: _today),
            ],
          },
        ),
      );
      expect(tasks.reviews, isEmpty);
    });

    test('every due review shows: the planner caps nothing', () {
      final due = [
        for (var i = 0; i < 25; i++)
          ReviewDue('Mishnah Berakhot 9:$i', 2, dueFrom: '2026-09-01'),
      ];
      expect(
        _plan(_midBerakhot(reviews: {_today: due})).reviews,
        hasLength(25),
      );
    });

    test('a review at a stage the presentation does not name keeps the '
        'engine\'s stage order', () {
      final task = _plan(
        _midBerakhot(
          reviews: {
            _today: [const ReviewDue(_b11, 7, dueFrom: _today)],
          },
        ),
      ).reviews.single;
      expect(task.stageOrder, 7);
      expect(task.stageName, '');
    });

    test('a later date reads the engine at that date (erev planned list)', () {
      final state = _midBerakhot(
        dailyTarget: 1,
        reviews: {
          '2026-09-09': [const ReviewDue(_b11, 2, dueFrom: '2026-09-09')],
        },
      );
      expect(_plan(state).reviews, isEmpty);
      final later = _plan(state, date: '2026-09-09');
      expect(_refs(later.reviews), [_b11]);
      expect(_refs(later.learning), [_b21]);
    });
  });

  group('buildPlannedTasks', () {
    test('plans only tracked, evaluated curricula, in order', () async {
      final state = fakeLearnerState(
        curricula: {
          _c.storageKey: _midBerakhot(dailyTarget: 1),
          CurriculumId.bavli.storageKey: FakeCurriculumState(
            curriculumId: CurriculumId.bavli.storageKey,
            schedulableRefs: const ['Berakhot 2a'],
            dailyTarget: 1,
          ),
          CurriculumId.chumash.storageKey: FakeCurriculumState(
            curriculumId: CurriculumId.chumash.storageKey,
            evaluated: false,
          ),
        },
      );
      final tasks = await buildPlannedTasks(
        state: state,
        corpora: {_c.storageKey: _corpus},
        date: _today,
        activeCurricula: const [
          CurriculumId.chumash,
          _c,
          CurriculumId.bavli,
          CurriculumId.tanach,
        ],
        activeTracks: [
          for (final c in [_c, CurriculumId.chumash, CurriculumId.tanach])
            CurriculumTrackEntity(
              curriculumId: c,
              state: 'active',
              activatedAt: DateTime.utc(2026),
            ),
        ],
        presentationFor: (_) async => _presentation(),
      );
      expect(_refs(tasks.learning), [_b21]);
    });
  });

  group('loadCurriculumTaskPresentation', () {
    Future<CurriculumTaskPresentation> load({
      List<StudyDayConfigEntry> configs = const [],
      ProfileProgramEntity? program,
      String date = _today,
    }) => loadCurriculumTaskPresentation(
      curriculum: _c,
      date: date,
      trackLabel: 'Mishnayos',
      stageRepository: _StageDefinitions(),
      studyDayConfigs: (_) async => configs,
      profileProgramRepository: _Programs(program),
      programRepository: LearningProgramRepository.instance,
      calendarService: CalendarProgramService(_Calendar()),
      getScopedContent: (_) async => const <ContentItem>[],
    );

    test('stage names by stage order', () async {
      expect((await load()).stageNames, {1: 'Learn', 2: 'Chazara A'});
    });

    test('no study-day config: every day is a study day', () async {
      expect((await load()).studyDay, isTrue);
    });

    test('the date\'s weekday decides the study day', () async {
      final configs = [
        const StudyDayConfigEntry(dayOfWeek: 1, dayType: DayType.review),
        const StudyDayConfigEntry(dayOfWeek: 2, dayType: DayType.study),
      ];
      expect((await load(configs: configs)).studyDay, isFalse); // Monday
      expect(
        (await load(configs: configs, date: '2026-09-08')).studyDay, // Tue
        isTrue,
      );
    });

    test('no calendar enrollment: not a calendar program', () async {
      expect((await load()).programDayLabels, isNull);
    });

    test(
      'a calendar enrollment labels each assigned leaf with its day',
      () async {
        final dafYomi = LearningProgramRepository.instance
            .getAllPrograms()
            .firstWhere((p) => p.apiProgramKey == 'daf_yomi');
        final labels = (await load(
          program: ProfileProgramEntity(
            curriculumId: _c,
            programId: dafYomi.id,
            trackingStartDate: DateTime(2026, 9, 6),
          ),
        )).programDayLabels;
        expect(labels, {
          'Day 6': (he: 'יום ו', en: 'Day 6'),
          'Day 7': (he: 'יום ז', en: 'Day 7'),
        });
      },
    );

    test('a calendar enrollment starting later labels nothing yet', () async {
      final dafYomi = LearningProgramRepository.instance
          .getAllPrograms()
          .firstWhere((p) => p.apiProgramKey == 'daf_yomi');
      final labels = (await load(
        program: ProfileProgramEntity(
          curriculumId: _c,
          programId: dafYomi.id,
          trackingStartDate: DateTime(2026, 9, 10),
        ),
      )).programDayLabels;
      expect(labels, isEmpty);
    });
  });
}

class _StageDefinitions implements StageDefinitionRepository {
  @override
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculumId,
  ) async => [
    for (final (order, name) in [(1, 'Learn'), (2, 'Chazara A')])
      StageDefinition(
        curriculumId: curriculumId,
        stageOrder: order,
        stageName: name,
        delayDays: order - 1,
        isDefault: true,
      ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Only getStagesForCurriculum is used.');
}

class _Programs implements ProfileProgramRepository {
  _Programs(this.program);

  final ProfileProgramEntity? program;

  @override
  Future<ProfileProgramEntity?> getProgram(CurriculumId curriculumId) async =>
      program;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Only getProgram is used.');
}

/// A calendar whose day `d` assigns `Day d` (Hebrew label `יום` + letter).
class _Calendar implements LocalCalendarEngine {
  static const _letters = ['', 'א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט'];

  CalendarProgramEntry _entry(String id, DateTime date) => CalendarProgramEntry(
    programId: id,
    displayNameEn: 'Test program',
    displayNameHe: '',
    todayRef: 'Day ${date.day}',
    todayRefHe: 'יום ${_letters[date.day % 10]}',
    apiSource: 'test',
    date: DateTime.utc(date.year, date.month, date.day),
  );

  @override
  Future<CalendarProgramEntry?> getEntry(String id, DateTime date) async =>
      _entry(id, date);

  @override
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String id,
    DateTime startDate,
    DateTime endDate,
  ) async => [
    for (
      var date = DateTime.utc(startDate.year, startDate.month, startDate.day);
      !date.isAfter(DateTime.utc(endDate.year, endDate.month, endDate.day));
      date = date.add(const Duration(days: 1))
    )
      _entry(id, date),
  ];

  @override
  Future<List<CalendarProgramEntry>> getTodayPrograms([DateTime? date]) async =>
      const [];

  @override
  Future<CalendarProgramEntry?> getProgramForDate(
    String programKey,
    DateTime date,
  ) => getEntry(programKey, date);
}
