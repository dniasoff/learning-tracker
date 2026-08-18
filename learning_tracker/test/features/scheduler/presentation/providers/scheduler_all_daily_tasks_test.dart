/// Provider integration coverage for the real allDailyTasksProvider.
library;

import 'package:cloud_functions/cloud_functions.dart';
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
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

const _uid = 'scheduler-all-tasks-uid';
const _profileId = '01J9V8J5Q2K7M3N6P4R8T1WXYZ';

class _FirebaseApp extends Mock implements FirebaseApp {}

class _FirebaseAuth extends Mock implements FirebaseAuth {}

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

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
  bool seedStudyDays = false,
  int? reviewDay,
  List<int> reviewDays = const [],
  int paceValue = 1,
  bool includeGoal = true,
  Map<CurriculumId, DateTime>? activatedAt,
  Map<String, DateTime>? completions,
  Set<String> sentinelCompletions = const {},
  List<String> skippedRefs = const [],
  List<String> previouslySkippedRefs = const [],
}) async {
  final today = clock ?? DateTime.utc(2026, 5, 27);
  final dateString =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  SharedPreferences.setMockInitialValues({
    'skipped_tasks_date': dateString,
    'skipped_tasks_refs': skippedRefs,
    'skipped_tasks_previous_refs': previouslySkippedRefs,
  });
  final firestore = createFakeFirestore(authenticatedUid: _uid);
  for (final curriculum in curricula) {
    final trackStart = activatedAt?[curriculum] ?? today;
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: curriculum,
      activatedAt: trackStart,
    );
    if (includeGoal) {
      await seedGoal(
        firestore,
        uid: _uid,
        profileId: _profileId,
        curriculumId: curriculum,
        goalType: 'pace',
        paceValue: paceValue,
        pacePeriod: 'day',
        createdAt: today,
        updatedAt: today,
      );
    }
    await seedStageDefinitions(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: curriculum,
      stages: [
        StageDefinition(
          curriculumId: curriculum,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
          isDefault: true,
        ),
      ],
      updatedAt: today,
    );
    if (seedStudyDays) {
      final studyDays = FirestoreStudyDayConfigRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      await studyDays.initializeDefaults(curriculum);
      for (final day in {...reviewDays, if (reviewDay != null) reviewDay}) {
        await studyDays.setDayConfig(
          curriculumId: curriculum,
          dayOfWeek: day,
          dayType: DayType.review,
        );
      }
    }
  }

  for (final entry
      in completions?.entries ?? const <MapEntry<String, DateTime>>[]) {
    await seedCompletion(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.chumash,
      sefariaRef: entry.key,
      completedAt: sentinelCompletions.contains(entry.key)
          ? DateTime.fromMillisecondsSinceEpoch(
              SchedulerEngine.kBulkPriorSentinelMs,
            )
          : entry.value,
      source: sentinelCompletions.contains(entry.key)
          ? CompletionSource.bulkInTrack
          : CompletionSource.live,
    );
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
        (ref) => FirestoreCurriculumTrackRepositoryAdapter(
          ref: ref,
          functions: _MockFirebaseFunctions(),
        ),
      ),
      activeProfileIdProvider.overrideWith(_ProfileId.new),
      activeProfileDocIdProvider.overrideWith(_ProfileDocId.new),
      clockProvider.overrideWith((ref) => today),
      calendarProgramServiceProvider.overrideWith(
        (ref) async => CalendarProgramService(const _Calendar()),
      ),
      for (final curriculum in curricula)
        scopedCurriculumContentProvider(
          curriculum,
        ).overrideWith((ref) async => _content(curriculum, count: 12)),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real Firestore-backed provider graph projects an active track',
    () async {
      final container = await _container();
      addTearDown(container.dispose);
      final subscription = container.listen(
        allDailyTasksProvider,
        (_, __) {},
        fireImmediately: false,
      );
      addTearDown(subscription.close);

      final tasks = await container.read(allDailyTasksProvider.future);

      expect(tasks, hasLength(1));
      expect(tasks.single.contentItemSefariaRef, 'Genesis 1:1');
      expect(tasks.single.curriculumId, CurriculumId.chumash);
      expect(tasks.single.priority, DailyTaskPriority.newLearning);
      expect(tasks.single.isOverdue, isFalse);
    },
  );

  test(
    'empty active-curriculum set produces an empty real-provider result',
    () async {
      final container = await _container(curricula: const []);
      addTearDown(container.dispose);
      final subscription = container.listen(allDailyTasksProvider, (_, __) {});
      addTearDown(subscription.close);

      expect(await container.read(allDailyTasksProvider.future), isEmpty);
    },
  );

  test(
    'an active track anchored three days ago yields overdue then today work',
    () async {
      final now = DateTime.utc(2026, 5, 27);
      final container = await _container(
        clock: now,
        activatedAt: {
          CurriculumId.chumash: now.subtract(const Duration(days: 3)),
        },
      );
      addTearDown(container.dispose);
      final subscription = container.listen(allDailyTasksProvider, (_, __) {});
      addTearDown(subscription.close);

      final tasks = await container.read(allDailyTasksProvider.future);
      expect(tasks, hasLength(4));
      expect(tasks.take(3).every((task) => task.isOverdue), isTrue);
      expect(tasks.last.isOverdue, isFalse);
      expect(tasks.map((task) => task.contentItemSefariaRef), [
        'Genesis 1:1',
        'Genesis 1:2',
        'Genesis 1:3',
        'Genesis 1:4',
      ]);
    },
  );

  test('a genuine completion is filtered from the returned queue', () async {
    final now = DateTime.utc(2026, 5, 27);
    final container = await _container(
      clock: now,
      activatedAt: {
        CurriculumId.chumash: now.subtract(const Duration(days: 2)),
      },
      completions: {'Genesis 1:1': now.subtract(const Duration(days: 1))},
    );
    addTearDown(container.dispose);
    final subscription = container.listen(allDailyTasksProvider, (_, __) {});
    addTearDown(subscription.close);

    final tasks = await container.read(allDailyTasksProvider.future);
    expect(tasks.map((task) => task.contentItemSefariaRef), [
      'Genesis 1:2',
      'Genesis 1:3',
    ]);
  });

  test('sentinel completions do not ghost the active queue', () async {
    final now = DateTime.utc(2026, 5, 27);
    final refs = {for (var i = 1; i <= 6; i++) 'Genesis 1:$i': now};
    final container = await _container(
      clock: now,
      paceValue: 3,
      completions: refs,
      sentinelCompletions: refs.keys.toSet(),
    );
    addTearDown(container.dispose);
    final subscription = container.listen(allDailyTasksProvider, (_, __) {});
    addTearDown(subscription.close);

    final tasks = await container.read(allDailyTasksProvider.future);
    expect(tasks, isNotEmpty);
    expect(
      tasks.map((task) => task.contentItemSefariaRef),
      isNot(contains('Genesis 1:1')),
    );
    expect(
      tasks.map((task) => task.contentItemSefariaRef),
      isNot(contains('Genesis 1:6')),
    );
  });

  test('today-skipped refs are excluded at provider read time', () async {
    final container = await _container(
      paceValue: 3,
      skippedRefs: ['Genesis 1:1'],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(allDailyTasksProvider, (_, __) {});
    addTearDown(subscription.close);

    final tasks = await container.read(allDailyTasksProvider.future);
    expect(
      tasks.map((task) => task.contentItemSefariaRef),
      isNot(contains('Genesis 1:1')),
    );
    expect(tasks, hasLength(2));
  });

  test('yesterday-skipped refs receive the overdueChazara boost', () async {
    final container = await _container(
      paceValue: 3,
      previouslySkippedRefs: ['Genesis 1:2'],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(allDailyTasksProvider, (_, __) {});
    addTearDown(subscription.close);

    final tasks = await container.read(allDailyTasksProvider.future);
    final boosted = tasks.singleWhere(
      (task) => task.contentItemSefariaRef == 'Genesis 1:2',
    );
    expect(boosted.priority, DailyTaskPriority.overdueChazara);
    expect(boosted.reason, contains('previously skipped'));
  });

  test('an active track without a goal contributes no tasks', () async {
    final container = await _container(includeGoal: false);
    addTearDown(container.dispose);
    final subscription = container.listen(allDailyTasksProvider, (_, __) {});
    addTearDown(subscription.close);

    expect(await container.read(allDailyTasksProvider.future), isEmpty);
  });

  test('two active curricula remain isolated in the provider result', () async {
    final container = await _container(
      curricula: const [CurriculumId.chumash, CurriculumId.bavli],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(allDailyTasksProvider, (_, __) {});
    addTearDown(subscription.close);

    final tasks = await container.read(allDailyTasksProvider.future);
    final chumash = tasks
        .where((task) => task.curriculumId == CurriculumId.chumash)
        .toList();
    final bavli = tasks
        .where((task) => task.curriculumId == CurriculumId.bavli)
        .toList();
    expect(chumash, hasLength(1));
    expect(bavli, hasLength(1));
    expect(bavli.single.contentItemSefariaRef, 'bavli_ref_0');
  });

  test(
    'rest-day configuration preserves missed work and suppresses rest days',
    () async {
      final now = DateTime.utc(2026, 5, 27);
      final container = await _container(
        clock: now,
        activatedAt: {CurriculumId.chumash: DateTime.utc(2026, 5, 25)},
        seedStudyDays: true,
        paceValue: 2,
        reviewDays: const [2, 4, 5, 6, 7],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(allDailyTasksProvider, (_, __) {});
      addTearDown(subscription.close);

      final tasks = await container.read(allDailyTasksProvider.future);
      expect(tasks.where((task) => task.isOverdue), hasLength(2));
      expect(tasks.where((task) => !task.isOverdue), hasLength(2));
    },
  );
}
