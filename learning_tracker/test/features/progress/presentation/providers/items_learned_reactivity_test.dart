/// ILP-01 regression guard for the real Firestore-backed providers.
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
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _ActiveProfile extends ActiveProfileId {
  @override
  String? build() => _profileId;
}

class _ContentRepository extends Fake implements ContentRepository {
  _ContentRepository(this._items);

  final Map<CurriculumId, List<ContentItem>> _items;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculum,
  ) async => _items[curriculum] ?? const [];
}

const _uid = 'items-learned-reactivity-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

ContentItem _leaf(CurriculumId curriculum, String ref) => ContentItem(
  curriculumId: curriculum.storageKey,
  sefariaRef: ref,
  displayNameEn: ref,
  displayNameHe: ref,
  level1: 'Zeraim',
  level2: 'Berakhot',
  level3: null,
  level4: null,
  isLeaf: true,
  sortOrder: 0,
);

void main() {
  Future<({FakeFirebaseFirestore firestore, ProviderContainer container})>
  setup(CurriculumId curriculum, ContentItem leaf) async {
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
        contentRepositoryProvider.overrideWithValue(
          _ContentRepository({
            curriculum: [leaf],
          }),
        ),
      ],
    );
    container.read(activeProfileDocIdProvider.notifier).set(_profileId);
    return (firestore: firestore, container: container);
  }

  Future<void> mark(
    FakeFirebaseFirestore firestore,
    CurriculumId curriculum,
    String ref,
  ) => seedCompletion(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: curriculum,
    sefariaRef: ref,
    source: CompletionSource.live,
    completedAt: DateTime.utc(2026, 5, 1, 10),
  );

  test('itemsLearnedDataProvider reacts to a completion commit', () async {
    final leaf = _leaf(CurriculumId.mishnayos, 'Mishnah Berakhot 1:1');
    final fixture = await setup(CurriculumId.mishnayos, leaf);
    addTearDown(fixture.container.dispose);
    final target = itemsLearnedDataProvider(CurriculumId.mishnayos);
    final sub = fixture.container.listen(target, (_, __) {});
    addTearDown(sub.close);

    expect(await fixture.container.read(target.future), isNull);
    await mark(fixture.firestore, CurriculumId.mishnayos, leaf.sefariaRef);
    fixture.container.read(completionCommittedProvider.notifier).increment();

    expect((await fixture.container.read(target.future))?.learnedLeafCount, 1);
  });

  test('lifetimeViewDataProvider reacts to a completion commit', () async {
    final leaf = _leaf(CurriculumId.chumash, 'Genesis 1:1');
    final fixture = await setup(CurriculumId.chumash, leaf);
    addTearDown(fixture.container.dispose);
    final target = lifetimeViewDataProvider(CurriculumId.chumash);
    final sub = fixture.container.listen(target, (_, __) {});
    addTearDown(sub.close);

    expect(await fixture.container.read(target.future), isNull);
    await mark(fixture.firestore, CurriculumId.chumash, leaf.sefariaRef);
    fixture.container.read(completionCommittedProvider.notifier).increment();

    expect((await fixture.container.read(target.future))?.learnedLeafCount, 1);
  });

  test('itemsLearnedSummariesProvider reacts to a completion commit', () async {
    final leaf = _leaf(CurriculumId.mishnayos, 'Mishnah Berakhot 1:1');
    final fixture = await setup(CurriculumId.mishnayos, leaf);
    addTearDown(fixture.container.dispose);
    final target = itemsLearnedSummariesProvider;
    final sub = fixture.container.listen(target, (_, __) {});
    addTearDown(sub.close);

    expect(await fixture.container.read(target.future), isEmpty);
    await mark(fixture.firestore, CurriculumId.mishnayos, leaf.sefariaRef);
    fixture.container.read(completionCommittedProvider.notifier).increment();

    expect(await fixture.container.read(target.future), hasLength(1));
  });
}
