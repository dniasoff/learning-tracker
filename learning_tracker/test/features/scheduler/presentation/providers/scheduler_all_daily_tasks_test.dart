/// Provider integration coverage for the real allDailyTasksProvider and
/// plannedTasksForDateProvider (DNI-477 T2): the task list is the planner's
/// layout of the live LearnerState, with the Firestore-backed presentation
/// inputs (tracks, stages, study days) read through the real graph.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';
import '../../../../helpers/firestore_governed_writer.dart';
import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';

const _uid = 'scheduler-all-tasks-uid';
const _profileId = '01J9V8J5Q2K7M3N6P4R8T1WXYZ';

class _FirebaseApp extends Mock implements FirebaseApp {}

class _FirebaseAuth extends Mock implements FirebaseAuth {}

class _ProfileId extends ActiveProfileId {
  @override
  String? build() => _profileId;
}

class _ProfileDocId extends ActiveProfileDocId {
  @override
  String? build() => _profileId;
}

class _Calendar implements LocalCalendarEngine {
  const _Calendar();

  @override
  Future<CalendarProgramEntry?> getEntry(String id, DateTime date) async =>
      null;

  @override
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String id,
    DateTime startDate,
    DateTime endDate,
  ) async => const [];

  @override
  Future<List<CalendarProgramEntry>> getTodayPrograms([DateTime? date]) async =>
      const [];

  @override
  Future<CalendarProgramEntry?> getProgramForDate(
    String programKey,
    DateTime date,
  ) async => null;
}

List<ContentItem> _content(CurriculumId curriculum, {int count = 3}) => [
  for (var i = 1; i <= count; i++)
    ContentItem(
      curriculumId: curriculum.storageKey,
      level1: curriculum == CurriculumId.chumash ? 'Bereishis' : 'Seder',
      level2: 'Perek 1',
      level3: 'Pasuk $i',
      level4: null,
      displayNameHe: 'פסוק $i',
      displayNameEn: 'Pasuk $i',
      sefariaRef: curriculum == CurriculumId.chumash
          ? 'Genesis 1:$i'
          : '${curriculum.storageKey}_ref_${i - 1}',
      sortOrder: i,
      isLeaf: true,
    ),
];

Future<ProviderContainer> _container({
  DateTime? clock,
  List<CurriculumId> curricula = const [CurriculumId.chumash],
  Map<CurriculumId, CurriculumState> states = const {},
  bool learnerActive = true,
  List<int> reviewDays = const [],
  List<String> skippedRefs = const [],
  List<String> previouslySkippedRefs = const [],
}) async {
  final today = clock ?? DateTime.utc(2026, 5, 27, 12);
  final dateString =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  SharedPreferences.setMockInitialValues({
    'skipped_tasks_date': dateString,
    'skipped_tasks_refs': skippedRefs,
    'skipped_tasks_previous_refs': previouslySkippedRefs,
  });
  final firestore = createFakeFirestore(authenticatedUid: _uid);
  for (final curriculum in curricula) {
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: curriculum,
      activatedAt: today,
    );
    await seedStageDefinitions(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: curriculum,
      stages: [
        for (final (order, name) in [(1, 'Learn'), (2, 'Chazara')])
          StageDefinition(
            curriculumId: curriculum,
            stageOrder: order,
            stageName: name,
            delayDays: order - 1,
            isDefault: true,
          ),
      ],
      updatedAt: today,
    );
    if (reviewDays.isNotEmpty) {
      final studyDays = FirestoreStudyDayConfigRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
        writer: FirestoreGovernedWriter(
          firestore,
          uid: _uid,
          profileId: _profileId,
        ),
      );
      await studyDays.initializeDefaults(curriculum);
      for (final day in reviewDays) {
        await studyDays.setDayConfig(
          curriculumId: curriculum,
          dayOfWeek: day,
          dayType: DayType.review,
        );
      }
    }
  }

  final handles = AccountFirebaseHandles(
    app: _FirebaseApp(),
    firestore: firestore,
    auth: _FirebaseAuth(),
    uid: _uid,
  );
  return ProviderContainer(
    retry: (_, __) => null,
    overrides: [
      activeAccountFirebaseProvider.overrideWith((ref) async => handles),
      curriculumTrackRepositoryAdapterProvider.overrideWith(
        (ref) => FirestoreCurriculumTrackRepositoryAdapter(ref: ref),
      ),
      activeProfileIdProvider.overrideWith(_ProfileId.new),
      activeProfileDocIdProvider.overrideWith(_ProfileDocId.new),
      clockProvider.overrideWith((ref) => today),
      calendarProgramServiceProvider.overrideWith(
        (ref) async => CalendarProgramService(const _Calendar()),
      ),
      corporaProvider.overrideWith((ref) async => const {}),
      ...learnerStateOverrides(
        scope: learnerActive ? c0Scope() : null,
        state: fakeLearnerState(
          curricula: {
            for (final MapEntry(:key, :value) in states.entries)
              key.storageKey: value,
          },
        ),
      ),
      for (final curriculum in curricula)
        scopedCurriculumContentProvider(
          curriculum,
        ).overrideWith((ref) async => _content(curriculum, count: 12)),
    ],
  );
}

/// A main track with [refs] schedulable at [dailyTarget] per day.
FakeCurriculumState _main(
  CurriculumId curriculum,
  List<String> refs, {
  int? dailyTarget = 1,
  Map<String, List<ReviewDue>> reviews = const {},
}) => FakeCurriculumState(
  curriculumId: curriculum.storageKey,
  schedulableRefs: refs,
  mainTrackPosition: refs.isEmpty ? null : refs.first,
  mainTrackRemaining: refs.length,
  dailyTarget: dailyTarget,
  reviews: reviews,
);

const _genesis = ['Genesis 1:1', 'Genesis 1:2', 'Genesis 1:3', 'Genesis 1:4'];

Future<List<DailyTask>> _tasks(ProviderContainer container) async {
  final subscription = container.listen(allDailyTasksProvider, (_, __) {});
  addTearDown(subscription.close);
  return container.read(allDailyTasksProvider.future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the real provider graph lays out the engine\'s main track', () async {
    final container = await _container(
      states: {CurriculumId.chumash: _main(CurriculumId.chumash, _genesis)},
    );
    addTearDown(container.dispose);

    final tasks = await _tasks(container);

    expect(tasks, hasLength(1));
    expect(tasks.single.contentItemSefariaRef, 'Genesis 1:1');
    expect(tasks.single.curriculumId, CurriculumId.chumash);
    expect(tasks.single.priority, DailyTaskPriority.newLearning);
    expect(tasks.single.stageName, 'Learn');
    expect(tasks.single.isOverdue, isFalse);
  });

  test('empty active-curriculum set produces an empty result', () async {
    final container = await _container(curricula: const []);
    addTearDown(container.dispose);

    expect(await _tasks(container), isEmpty);
  });

  test('chazara is reviewsDue(today), sorted ahead of new learning', () async {
    final container = await _container(
      states: {
        CurriculumId.chumash: _main(
          CurriculumId.chumash,
          _genesis.skip(2).toList(),
          reviews: {
            '2026-05-27': [
              const ReviewDue('Genesis 1:2', 2, dueFrom: '2026-05-27'),
              const ReviewDue('Genesis 1:1', 2, dueFrom: '2026-05-25'),
            ],
          },
        ),
      },
    );
    addTearDown(container.dispose);

    final tasks = await _tasks(container);
    expect(
      [for (final t in tasks) (t.contentItemSefariaRef, t.priority, t.reason)],
      [
        (
          'Genesis 1:1',
          DailyTaskPriority.overdueChazara,
          'Chazara overdue by 2 day(s)',
        ),
        (
          'Genesis 1:2',
          DailyTaskPriority.scheduledChazara,
          'Chazara due today',
        ),
        ('Genesis 1:3', DailyTaskPriority.newLearning, 'Due today'),
      ],
    );
  });

  test('today-skipped refs are excluded at provider read time', () async {
    final container = await _container(
      states: {
        CurriculumId.chumash: _main(
          CurriculumId.chumash,
          _genesis,
          dailyTarget: 3,
        ),
      },
      skippedRefs: ['Genesis 1:1'],
    );
    addTearDown(container.dispose);

    final tasks = await _tasks(container);
    expect(
      tasks.map((task) => task.contentItemSefariaRef),
      isNot(contains('Genesis 1:1')),
    );
    expect(tasks, hasLength(2));
  });

  test('yesterday-skipped refs receive the overdueChazara boost', () async {
    final container = await _container(
      states: {
        CurriculumId.chumash: _main(
          CurriculumId.chumash,
          _genesis,
          dailyTarget: 3,
        ),
      },
      previouslySkippedRefs: ['Genesis 1:2'],
    );
    addTearDown(container.dispose);

    final tasks = await _tasks(container);
    final boosted = tasks.singleWhere(
      (task) => task.contentItemSefariaRef == 'Genesis 1:2',
    );
    expect(boosted.priority, DailyTaskPriority.overdueChazara);
    expect(boosted.reason, contains('previously skipped'));
  });

  test('an active track with no deadline and no pace contributes no new '
      'learning', () async {
    final container = await _container(
      states: {
        CurriculumId.chumash: _main(
          CurriculumId.chumash,
          _genesis,
          dailyTarget: null,
        ),
      },
    );
    addTearDown(container.dispose);

    expect(await _tasks(container), isEmpty);
  });

  test('two active curricula remain isolated in the provider result', () async {
    final container = await _container(
      curricula: const [CurriculumId.chumash, CurriculumId.bavli],
      states: {
        CurriculumId.chumash: _main(CurriculumId.chumash, _genesis),
        CurriculumId.bavli: _main(CurriculumId.bavli, const ['bavli_ref_0']),
      },
    );
    addTearDown(container.dispose);

    final tasks = await _tasks(container);
    expect(
      tasks.where((task) => task.curriculumId == CurriculumId.chumash),
      hasLength(1),
    );
    expect(
      tasks
          .singleWhere((task) => task.curriculumId == CurriculumId.bavli)
          .contentItemSefariaRef,
      'bavli_ref_0',
    );
  });

  test('a review-only day (study-day config) shows reviews, no new '
      'learning', () async {
    // 2026-05-27 is a Wednesday (ISO 3).
    final container = await _container(
      states: {
        CurriculumId.chumash: _main(
          CurriculumId.chumash,
          _genesis.skip(1).toList(),
          reviews: {
            '2026-05-27': [
              const ReviewDue('Genesis 1:1', 2, dueFrom: '2026-05-27'),
            ],
          },
        ),
      },
      reviewDays: const [3],
    );
    addTearDown(container.dispose);

    final tasks = await _tasks(container);
    expect(tasks.map((t) => t.contentItemSefariaRef), ['Genesis 1:1']);
    expect(tasks.single.priority, DailyTaskPriority.scheduledChazara);
  });

  test('a later date is planned live over the current state (erev planned '
      'list)', () async {
    final container = await _container(
      states: {
        CurriculumId.chumash: _main(
          CurriculumId.chumash,
          _genesis.skip(1).toList(),
          reviews: {
            '2026-05-29': [
              const ReviewDue('Genesis 1:1', 2, dueFrom: '2026-05-29'),
            ],
          },
        ),
      },
    );
    addTearDown(container.dispose);
    final provider = plannedTasksForDateProvider('2026-05-29');
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);

    final tasks = await container.read(provider.future);
    expect(tasks.map((t) => (t.contentItemSefariaRef, t.stageOrder)), [
      ('Genesis 1:2', 1),
      ('Genesis 1:1', 2),
    ]);
  });

  test('no active learner is an error, not an empty plan', () async {
    final container = await _container(learnerActive: false);
    addTearDown(container.dispose);
    final subscription = container.listen(allDailyTasksProvider, (_, __) {});
    addTearDown(subscription.close);

    await expectLater(
      container.read(allDailyTasksProvider.future),
      throwsA(isA<SchedulerNoActiveProfileException>()),
    );
  });
}
