/// F4 regression tests for the Firestore-backed curriculum pace provider.
@Tags(['progress', 'pace', 'f4_regression'])
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _ActiveProfile extends ActiveProfileId {
  @override
  String? build() => _profileId;
}

class _ContentRepository extends Fake implements ContentRepository {
  _ContentRepository(this._count);
  final int _count;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculum,
  ) async => List.generate(
    _count,
    (i) => ContentItem(
      curriculumId: curriculum.storageKey,
      sefariaRef: 'ref_$i',
      displayNameEn: 'Item $i',
      displayNameHe: 'פריט $i',
      level1: 'Seder',
      level2: 'Masechta',
      level3: null,
      level4: null,
      isLeaf: true,
      sortOrder: i,
    ),
  );
}

const _uid = 'pace-provider-test-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _curriculum = CurriculumId.mishnayos;
final _today = DateTime(2026, 5, 20);
final _sentinel = DateTime.utc(2000, 1, 1);

void main() {
  Future<({FakeFirebaseFirestore firestore, ProviderContainer container})>
  setup({required int leafCount, DateTime? trackActivatedAt}) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    if (trackActivatedAt != null) {
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _profileId,
        curriculumId: _curriculum,
        activatedAt: trackActivatedAt,
      );
    }
    final handles = AccountFirebaseHandles(
      app: _MockFirebaseApp(),
      firestore: firestore,
      auth: _MockFirebaseAuth(),
      uid: _uid,
    );
    final container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith((ref) async => handles),
        activeProfileIdProvider.overrideWith(() => _ActiveProfile()),
        contentRepositoryProvider.overrideWithValue(
          _ContentRepository(leafCount),
        ),
        clockProvider.overrideWith((ref) => _today),
        // curriculumPaceStatus watches curriculumTrackRepositoryAdapterProvider
        // to read the track's activatedAt. That adapter's constructor eagerly
        // resolves FirebaseFunctions.instance (for the unrelated
        // deleteCurriculumTrack Cloud Function wiring), which needs a real
        // Firebase app under `flutter test` — inject a mock instead, the same
        // pattern scheduler_all_daily_tasks_test.dart and the
        // parent-track-management screen tests already use.
        curriculumTrackRepositoryAdapterProvider.overrideWith(
          (ref) => FirestoreCurriculumTrackRepositoryAdapter(
            ref: ref,
            functions: _MockFirebaseFunctions(),
          ),
        ),
      ],
    );
    container.read(activeProfileDocIdProvider.notifier).set(_profileId);
    return (firestore: firestore, container: container);
  }

  Future<void> mark(
    FakeFirebaseFirestore firestore,
    String ref, {
    required DateTime at,
    CompletionSource source = CompletionSource.live,
    int stageId = 1,
  }) => seedCompletion(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: _curriculum,
    sefariaRef: ref,
    stageId: stageId,
    source: source,
    completedAt: at,
  );

  Future<void> goal(
    FakeFirebaseFirestore firestore, {
    required DateTime createdAt,
    required DateTime targetDate,
  }) => seedGoal(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: _curriculum,
    createdAt: createdAt,
    updatedAt: createdAt,
    targetDate: targetDate,
  );

  test('bulk baseline on day 1 does not create phantom ahead status', () async {
    final fixture = await setup(leafCount: 1336, trackActivatedAt: _today);
    addTearDown(fixture.container.dispose);
    for (var i = 0; i < 1336; i++) {
      await mark(
        fixture.firestore,
        'ref_$i',
        at: _sentinel,
        source: CompletionSource.bulkInTrack,
      );
    }
    await goal(
      fixture.firestore,
      createdAt: _today,
      targetDate: _today.add(const Duration(days: 365)),
    );
    final result = await fixture.container.read(
      curriculumPaceStatusProvider(_curriculum.storageKey).future,
    );
    expect(result, isNotNull);
    expect(result!.paceStatus, ProgressPaceStatus.graceWindow);
    expect(result.bulkBaseline, 1336);
    expect(result.liveProgress, 0);
    expect(result.paceVariance, 0.0);
    expect(result.paceStatus, isNot(ProgressPaceStatus.ahead));
  });

  test('30 days elapsed with 1000 bulk and 150 live is ahead', () async {
    final start = _today.subtract(const Duration(days: 30));
    final fixture = await setup(leafCount: 1336, trackActivatedAt: start);
    addTearDown(fixture.container.dispose);
    for (var i = 0; i < 1000; i++) {
      await mark(
        fixture.firestore,
        'bulk_$i',
        at: _sentinel,
        source: CompletionSource.bulkInTrack,
      );
    }
    for (var i = 0; i < 150; i++) {
      await mark(
        fixture.firestore,
        'live_$i',
        at: start.add(Duration(days: i % 30 + 1)),
      );
    }
    await goal(
      fixture.firestore,
      createdAt: start,
      targetDate: start.add(const Duration(days: 100)),
    );
    final result = await fixture.container.read(
      curriculumPaceStatusProvider(_curriculum.storageKey).future,
    );
    expect(result, isNotNull);
    expect(result!.liveProgress, 150);
    expect(result.bulkBaseline, 1000);
    expect(result.paceStatus, ProgressPaceStatus.ahead);
  });

  test('30 days elapsed with 1000 bulk and 10 live is behind', () async {
    final start = _today.subtract(const Duration(days: 30));
    final fixture = await setup(leafCount: 1336, trackActivatedAt: start);
    addTearDown(fixture.container.dispose);
    for (var i = 0; i < 1000; i++) {
      await mark(
        fixture.firestore,
        'bulk_$i',
        at: _sentinel,
        source: CompletionSource.bulkInTrack,
      );
    }
    for (var i = 0; i < 10; i++) {
      await mark(
        fixture.firestore,
        'live_$i',
        at: start.add(Duration(days: i + 1)),
      );
    }
    await goal(
      fixture.firestore,
      createdAt: start,
      targetDate: start.add(const Duration(days: 100)),
    );
    final result = await fixture.container.read(
      curriculumPaceStatusProvider(_curriculum.storageKey).future,
    );
    expect(result, isNotNull);
    expect(result!.liveProgress, 10);
    expect(result.bulkBaseline, 1000);
    expect(result.paceStatus, ProgressPaceStatus.behind);
  });

  test('no goal returns null', () async {
    final fixture = await setup(leafCount: 100, trackActivatedAt: null);
    addTearDown(fixture.container.dispose);
    expect(
      await fixture.container.read(
        curriculumPaceStatusProvider(_curriculum.storageKey).future,
      ),
      isNull,
    );
  });

  test('chazara stages count distinct refs, not raw rows', () async {
    final start = _today.subtract(const Duration(days: 50));
    final fixture = await setup(leafCount: 100, trackActivatedAt: start);
    addTearDown(fixture.container.dispose);
    for (var i = 0; i < 50; i++) {
      for (final stage in [1, 2, 3]) {
        await mark(
          fixture.firestore,
          'live_$i',
          stageId: stage,
          at: start.add(Duration(days: i + 1)),
        );
      }
    }
    await goal(
      fixture.firestore,
      createdAt: start,
      targetDate: start.add(const Duration(days: 100)),
    );
    final result = await fixture.container.read(
      curriculumPaceStatusProvider(_curriculum.storageKey).future,
    );
    expect(result, isNotNull);
    expect(result!.liveProgress, 50);
    expect(result.paceVariance, 0.0);
    expect(result.paceStatus, ProgressPaceStatus.onTrack);
    expect(result.paceStatus, isNot(ProgressPaceStatus.ahead));
  });

  test('bulk chazara stages count 40 distinct baseline refs', () async {
    final fixture = await setup(leafCount: 100, trackActivatedAt: _today);
    addTearDown(fixture.container.dispose);
    for (var i = 0; i < 40; i++) {
      for (final stage in [1, 2, 3]) {
        await mark(
          fixture.firestore,
          'bulk_$i',
          stageId: stage,
          at: _sentinel,
          source: CompletionSource.bulkInTrack,
        );
      }
    }
    await goal(
      fixture.firestore,
      createdAt: _today,
      targetDate: _today.add(const Duration(days: 100)),
    );
    final result = await fixture.container.read(
      curriculumPaceStatusProvider(_curriculum.storageKey).future,
    );
    expect(result, isNotNull);
    expect(result!.bulkBaseline, 40);
    expect(result.requiredVelocity, greaterThan(0.0));
  });
}
