/// Regression test — a contiguous overdue self-paced sequence must have NO
/// gaps in the generated daily-task queue.
///
/// Repro for the on-device sweep finding: the Learn-tab queue showed
/// Pasuk 7, 8, then 10, 11, 12 — omitting Pasuk 9 — even though everything
/// was overdue and nothing was completed. A contiguous overdue run must
/// surface every ref between the first and last with no missing item.
///
/// This drives the REAL allDailyTasksProvider via a ProviderContainer with an
/// in-memory DB so the schedule → project → task-assembly pipeline is
/// exercised end-to-end.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';

class _NoopCalendarEngine implements LocalCalendarEngine {
  const _NoopCalendarEngine();
  @override
  Future<CalendarProgramEntry?> getEntry(
    String programId,
    DateTime date,
  ) async => null;
  @override
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String programId,
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

class _ProfileId1 extends ActiveProfileId {
  @override
  int build() => 1;
}

const _profileId = 1;

/// Chumash-shaped leaf items: Bereishis (Genesis) chapter 1, pasukim 1..[count].
/// Mirrors the real on-device data shape: Sefer|Perek|Pasuk (3 levels) with a
/// canonical "Genesis 1:N" sefariaRef and a strictly increasing sortOrder.
List<ContentItem> _genesisCh1(int count) => List.generate(
  count,
  (i) => ContentItem(
    curriculumId: CurriculumId.chumash.storageKey,
    level1: 'Bereishis',
    level2: 'Perek 1',
    level3: 'Pasuk ${i + 1}',
    displayNameHe: 'פסוק ${i + 1}',
    displayNameEn: 'Pasuk ${i + 1}',
    sefariaRef: 'Genesis 1:${i + 1}',
    sortOrder: i,
    isLeaf: true,
  ),
);

Future<int> _seedSelfPacedTrack(
  UserDatabase db, {
  required DateTime activatedAt,
}) async {
  const curriculum = CurriculumId.chumash;
  final trackId = await db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: _profileId,
          curriculumId: curriculum.storageKey,
          state: const Value('active'),
          stateChangedAt: activatedAt,
          activatedAt: activatedAt,
        ),
      );

  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: _profileId,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
        ),
      );

  final now = DateTimeFactory.nowUtc();
  await db.goalDao.upsertGoalByTrack(
    profileId: _profileId,
    trackId: trackId,
    curriculumId: curriculum.storageKey,
    description: 'Test goal',
    targetPercent: 100.0,
    targetDate: null,
    goalType: 'pace',
    paceValue: 1,
    pacePeriod: 'day',
    createdAt: now,
    updatedAt: now,
  );

  for (var d = 1; d <= 7; d++) {
    await db.studyDayConfigDao.upsertDayConfig(
      profileId: _profileId,
      curriculumId: curriculum.storageKey,
      trackId: trackId,
      dayOfWeek: d,
      dayType: 'study',
    );
  }
  return trackId;
}

ProviderContainer _container(UserDatabase db, {required DateTime clock}) {
  const curriculum = CurriculumId.chumash;
  final today =
      '${clock.year}-${clock.month.toString().padLeft(2, '0')}-${clock.day.toString().padLeft(2, '0')}';
  SharedPreferences.setMockInitialValues({
    'skipped_tasks_date': today,
    'skipped_tasks_refs': <String>[],
    'skipped_tasks_previous_refs': <String>[],
  });

  final items = _genesisCh1(12);

  return ProviderContainer(
    retry: (_, __) => null,
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWith(_ProfileId1.new),
      clockProvider.overrideWith((ref) => clock),
      calendarProgramServiceProvider.overrideWith(
        (ref) =>
            Future.value(CalendarProgramService(const _NoopCalendarEngine())),
      ),
      globalStageRepositoryProvider.overrideWith((ref) {
        return StageDefinitionRepositoryImpl(
          stageDao: db.stageDao,
          completionDao: db.completionDao,
          pushStageDefinitions: null,
        );
      }),
      scopedCurriculumContentProvider(
        curriculum,
      ).overrideWith((ref) => Future.value(items)),
      for (final c in CurriculumId.values)
        if (c != curriculum)
          scopedCurriculumContentProvider(
            c,
          ).overrideWith((ref) => Future.value(const <ContentItem>[])),
    ],
  );
}

int _verseOf(String ref) =>
    int.parse(RegExp(r'(\d+)$').firstMatch(ref)!.group(1)!);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('contiguous overdue run (Pasuk 1..N) has NO gap (regression: 8 → 10 '
      'skipped Pasuk 9)', () async {
    // Anchor 6 study days ago, pace=1/day, nothing completed.
    // Expected schedule: day0..day5 = Pasuk 1..6 (overdue), today = Pasuk 7.
    final today = DateTime.utc(2026, 5, 27);
    final anchor = today.subtract(const Duration(days: 6));

    await _seedSelfPacedTrack(db, activatedAt: anchor);

    final c = _container(db, clock: today);
    addTearDown(c.dispose);
    c.listen<Set<String>>(skippedTasksProvider, (_, __) {});
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final tasks = await c.read(allDailyTasksProvider.future);

    final verses = tasks.map((t) => _verseOf(t.contentItemSefariaRef)).toList()
      ..sort();
    // Seven contiguous days (6 overdue + today) with pace=1 → Pasuk 1..7.
    expect(
      verses,
      [1, 2, 3, 4, 5, 6, 7],
      reason:
          'A contiguous overdue run must surface every pasuk with no gap; '
          'got $verses',
    );

    // Explicit no-gap invariant across whatever range is produced.
    for (var i = 1; i < verses.length; i++) {
      expect(
        verses[i] - verses[i - 1],
        1,
        reason: 'Gap between Pasuk ${verses[i - 1]} and ${verses[i]}: $verses',
      );
    }
  });
}
