/// PP-4 regression guard — Lifetime Knowledge counts only review events as
/// chazaros.
@Tags(['unit', 'progress', 'lifetime', 'pp4'])
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
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _ActiveProfile extends ActiveProfileId {
  @override
  String? build() => _profileId;
}

class _EmptyContentRepository extends Fake implements ContentRepository {
  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculum,
  ) async => const [];
}

const _uid = 'pp4-lifetime-test-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

void main() {
  Future<({FakeFirebaseFirestore firestore, ProviderContainer container})>
  setup() async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
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
        contentRepositoryProvider.overrideWithValue(_EmptyContentRepository()),
      ],
    );
    container.read(activeProfileDocIdProvider.notifier).set(_profileId);
    return (firestore: firestore, container: container);
  }

  Future<void> insert(
    FakeFirebaseFirestore firestore, {
    required String ref,
    required int stageId,
  }) async {
    await seedCompletion(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
      sefariaRef: ref,
      stageId: stageId,
      completedAt: DateTime.utc(2026, 6, 15),
    );
  }

  test('reports 2 chazaros for 5 limud + 2 review events, not 7', () async {
    final fixture = await setup();
    addTearDown(fixture.container.dispose);
    for (var i = 0; i < 5; i++) {
      await insert(fixture.firestore, ref: 'Berakhot.1.$i', stageId: 1);
    }
    await insert(fixture.firestore, ref: 'Berakhot.1.review1', stageId: 2);
    await insert(fixture.firestore, ref: 'Berakhot.1.review2', stageId: 2);

    final counters = await fixture.container.read(
      lifetimeHeaderCountersProvider.future,
    );
    expect(counters.totalChazaros, 2);
  });

  test('a user with only limud completions has zero chazaros', () async {
    final fixture = await setup();
    addTearDown(fixture.container.dispose);
    for (var i = 0; i < 3; i++) {
      await insert(fixture.firestore, ref: 'Berakhot.1.$i', stageId: 1);
    }

    final counters = await fixture.container.read(
      lifetimeHeaderCountersProvider.future,
    );
    expect(counters.totalChazaros, 0);
  });
}
