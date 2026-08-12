/// Run-8 P2 regression guard for bulk-mark rollups in the Firestore progress
/// and Lifetime Knowledge surfaces.
@Tags(['progress'])
library;

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
import 'package:learning_tracker/features/progress/data/repositories/firestore_chart_data_repository_adapter.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/firestore_fake.dart';
import '../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _ContentRepository extends Fake implements ContentRepository {
  _ContentRepository(this._leaves);

  final List<ContentItem> _leaves;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculum,
  ) async {
    return curriculum == CurriculumId.mishnayos ? _leaves : const [];
  }
}

class _ActiveProfile extends ActiveProfileId {
  @override
  String? build() => _profileId;
}

const _uid = 'bulk-rollup-test-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _curriculum = CurriculumId.mishnayos;

ContentItem _leaf(String ref, {int sort = 0}) => ContentItem(
  curriculumId: _curriculum.storageKey,
  level1: 'Seder A',
  level2: 'Masechta A',
  level3: 'Perek 1',
  level4: ref,
  displayNameHe: '',
  displayNameEn: '',
  sefariaRef: ref,
  sortOrder: sort,
  isLeaf: true,
);

void main() {
  late FakeFirebaseFirestore firestore;
  late AccountFirebaseHandles handles;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    handles = AccountFirebaseHandles(
      app: _MockFirebaseApp(),
      firestore: firestore,
      auth: _MockFirebaseAuth(),
      uid: _uid,
    );
  });

  Future<void> seedBulk(String ref) => seedCompletion(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: _curriculum,
    sefariaRef: ref,
    source: CompletionSource.bulkInTrack,
    completedAt: DateTime.utc(2000, 1, 1),
  );

  ProviderContainer containerFor(ContentRepository content) {
    final container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith((ref) async => handles),
        activeProfileIdProvider.overrideWith(() => _ActiveProfile()),
        contentRepositoryProvider.overrideWithValue(content),
      ],
    );
    container.read(activeProfileDocIdProvider.notifier).set(_profileId);
    return container;
  }

  group('Recent Activity — All-time feed includes bulk marks', () {
    test(
      'three bulk-marked mishnayot roll up into the All-time limud total',
      () async {
        // At UTC+3, the local midnight corresponding to the UTC all-time
        // floor is three hours before the raw UTC floor. This is the exact
        // _effectiveStartDate boundary that used to drop sentinel bulk rows.
        final effectiveStartDateAtUtcPlus3 = DateTime.utc(
          2000,
          1,
          1,
        ).subtract(const Duration(hours: 3));
        expect(
          effectiveStartDateAtUtcPlus3.isBefore(kChartAllTimeFloor),
          isTrue,
          reason: 'UTC+3 local midnight must precede the raw UTC floor',
        );
        await seedBulk('m1');
        await seedBulk('m2');
        await seedBulk('m3');

        final container = containerFor(_ContentRepository([]));
        addTearDown(container.dispose);
        final adapterProvider = Provider<FirestoreChartDataRepositoryAdapter>(
          (ref) => FirestoreChartDataRepositoryAdapter(ref: ref),
        );
        final service = ChartDataService(
          repository: container.read(adapterProvider),
        );
        final feed = await service.getDailyLimudimAndChazaros(
          startDate: kChartAllTimeFloor,
          endDate: DateTime(2026, 3, 15),
        );

        final aggregateLimud = feed.fold<int>(0, (s, d) => s + d.limudCount);
        expect(aggregateLimud, 3);
      },
    );

    test('cumulative All-time feed also reflects the bulk marks', () async {
      await seedBulk('m1');
      await seedBulk('m2');

      final container = containerFor(_ContentRepository([]));
      addTearDown(container.dispose);
      final adapterProvider = Provider<FirestoreChartDataRepositoryAdapter>(
        (ref) => FirestoreChartDataRepositoryAdapter(ref: ref),
      );
      final service = ChartDataService(
        repository: container.read(adapterProvider),
      );
      final points = await service.getCumulativeProgressLive(
        startDate: kChartAllTimeFloor,
        endDate: DateTime(2026, 3, 15),
      );

      expect(points, isNotEmpty);
      expect(points.last.total, 2);
    });
  });

  group('Lifetime Knowledge header rolls up bulk marks (== body)', () {
    test(
      'header itemsLearned equals the per-curriculum body learned count',
      () async {
        await seedBulk('Berakhot 1:1');
        final content = _ContentRepository([
          _leaf('Berakhot 1:1'),
          _leaf('Berakhot 1:2', sort: 1),
        ]);
        final container = containerFor(content);
        addTearDown(container.dispose);

        final body = await container.read(
          lifetimeViewDataProvider(_curriculum).future,
        );
        final header = await container.read(
          lifetimeHeaderCountersProvider.future,
        );

        expect(body?.learnedLeafCount, 1);
        expect(header.itemsLearned, body?.learnedLeafCount);
      },
    );
  });
}
