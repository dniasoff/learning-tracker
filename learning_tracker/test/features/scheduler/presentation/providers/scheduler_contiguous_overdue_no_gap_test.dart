/// Regression coverage for a contiguous overdue self-paced sequence.
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
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

const _uid = 'scheduler-contiguous-uid';
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

List<ContentItem> _content() => [
  for (var i = 1; i <= 12; i++)
    ContentItem(
      curriculumId: CurriculumId.chumash.storageKey,
      level1: 'Bereishis',
      level2: 'Perek 1',
      level3: 'Pasuk $i',
      level4: null,
      displayNameHe: 'פסוק $i',
      displayNameEn: 'Pasuk $i',
      sefariaRef: 'Genesis 1:$i',
      sortOrder: i,
      isLeaf: true,
    ),
];

Future<ProviderContainer> _container(DateTime now) async {
  SharedPreferences.setMockInitialValues({});
  final firestore = createFakeFirestore(authenticatedUid: _uid);
  final anchor = now.subtract(const Duration(days: 6));
  await seedTrack(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: CurriculumId.chumash,
    activatedAt: anchor,
  );
  await seedGoal(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: CurriculumId.chumash,
    goalType: 'pace',
    paceValue: 1,
    pacePeriod: 'day',
    createdAt: now,
    updatedAt: now,
  );
  await seedStageDefinitions(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: CurriculumId.chumash,
    stages: [
      const StageDefinition(
        curriculumId: CurriculumId.chumash,
        stageOrder: 1,
        stageName: 'Learn',
        delayDays: 0,
        isDefault: true,
      ),
    ],
    updatedAt: now,
  );

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
      activeProfileIdProvider.overrideWith(_ProfileId.new),
      activeProfileDocIdProvider.overrideWith(_ProfileDocId.new),
      clockProvider.overrideWith((ref) => now),
      calendarProgramServiceProvider.overrideWith(
        (ref) async => CalendarProgramService(const _Calendar()),
      ),
      scopedCurriculumContentProvider(
        CurriculumId.chumash,
      ).overrideWith((ref) async => _content()),
    ],
  );
}

int _verseOf(String ref) =>
    int.parse(RegExp(r'(\d+)$').firstMatch(ref)!.group(1)!);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('provider queue preserves every contiguous overdue ref', () async {
    final today = DateTime.utc(2026, 5, 27);
    final container = await _container(today);
    addTearDown(container.dispose);
    final subscription = container.listen(allDailyTasksProvider, (_, __) {});
    addTearDown(subscription.close);

    final tasks = await container.read(allDailyTasksProvider.future);
    final verses = tasks.map((t) => _verseOf(t.contentItemSefariaRef)).toList()
      ..sort();

    expect(verses, [1, 2, 3, 4, 5, 6, 7]);
    expect(tasks.where((task) => task.isOverdue), hasLength(6));
    expect(tasks.where((task) => !task.isOverdue), hasLength(1));
    for (var i = 1; i < verses.length; i++) {
      expect(verses[i] - verses[i - 1], 1);
    }
  });
}
