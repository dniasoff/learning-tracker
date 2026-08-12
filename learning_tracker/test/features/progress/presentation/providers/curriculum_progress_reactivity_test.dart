/// CP-02 regression guard — curriculumProgressProvider must re-execute when
/// completionCommittedProvider ticks.
///
/// Before the fix, curriculumProgress never watched completionCommittedProvider,
/// so the "Breakdown by Level" cards in CurriculumProgressScreen stayed stale
/// after a completion until the user navigated away and back (auto-dispose) or
/// performed pull-to-refresh. After the fix a tick on completionCommittedProvider
/// causes the provider to re-execute with the new DB state.
///
/// AUD-t-progress-05: rewritten to drive the REAL curriculumProgressProvider
/// over an in-memory Drift DB and fake content/stage repositories, instead of
/// overriding the provider under test with a hand-written stub that merely
/// re-asserted the fix's own `ref.watch(completionCommittedProvider)` line. A
/// regression that drops that watch call now shows up as a stale
/// `completedAllStages` count on the REAL provider, not a call-count on a
/// stand-in that could drift from production behaviour undetected.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _curriculumKey = 'mishnayos';
const _curriculum = CurriculumId.mishnayos;
const _learnStageId = 1;

// ---------------------------------------------------------------------------
// Test doubles — mirrors the fixture shape already proven in
// curriculum_progress_screen_test.dart, so this reactivity guard exercises
// the same real-provider wiring the screen tests use.
// ---------------------------------------------------------------------------

class _FakeContentRepository implements ContentRepository {
  _FakeContentRepository(this._items);

  final List<ContentItem> _items;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async {
    if (curriculumId != _curriculum) return const [];
    return _items;
  }

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async {
    return CurriculumHierarchyConfig(
      curriculumId: curriculumId.storageKey,
      levelLabels: const ['Seder', 'Masechta', 'Perek', 'Mishna'],
      totalItems: _items.where((i) => i.isLeaf).length,
    );
  }

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => const [];

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => _items;

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => const [];

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => null;
}

/// Minimal stage repository — `curriculumProgress` only reads
/// [getStagesForCurriculum].
class _FakeStageDefinitionRepository extends Fake
    implements StageDefinitionRepository {
  _FakeStageDefinitionRepository(this._stages);

  final List<domain_stage.StageDefinition> _stages;

  @override
  Future<List<domain_stage.StageDefinition>> getStagesForCurriculum(
    CurriculumId c,
  ) async => _stages;
}

class _ProfileIdOverride extends ActiveProfileId {
  @override
  String? build() => _profileId;
}

ContentItem _leaf(String ref, {int sortOrder = 0}) => ContentItem(
  curriculumId: _curriculumKey,
  sefariaRef: ref,
  displayNameEn: ref,
  displayNameHe: ref,
  level1: 'Zeraim',
  level2: 'Berakhot',
  level3: null,
  level4: null,
  isLeaf: true,
  sortOrder: sortOrder,
);

void main() {
  group(
    'CP-02: curriculumProgressProvider reacts to completionCommittedProvider',
    () {
      test(
        'curriculumProgressProvider re-executes after a '
        'completionCommittedProvider tick and reflects the new completion',
        () async {
          final firestore = createFakeFirestore(
            authenticatedUid: 'curriculum-progress-reactivity-user',
          );
          // The initial empty completion read is an achievement-shaped
          // Firestore read. The adapter's hydration guard verifies the
          // profile document before it will report a truthful zero; omitting
          // this seed makes Riverpod retry the failed FutureProvider forever.
          await seedProfile(
            firestore,
            uid: 'curriculum-progress-reactivity-user',
            profileId: _profileId,
          );
          final handles = AccountFirebaseHandles(
            app: _MockFirebaseApp(),
            firestore: firestore,
            auth: _MockFirebaseAuth(),
            uid: 'curriculum-progress-reactivity-user',
          );

          final leaf = _leaf('Mishnah Berakhot 1:1');
          final repo = _FakeContentRepository([leaf]);
          final stageRepo = _FakeStageDefinitionRepository([
            const domain_stage.StageDefinition(
              id: _learnStageId,
              curriculumId: _curriculum,
              stageOrder: 1,
              stageName: 'Learned',
              delayDays: 0,
              isDefault: true,
            ),
          ]);

          final container = ProviderContainer(
            overrides: [
              activeAccountFirebaseProvider.overrideWith(
                (ref) async => handles,
              ),
              contentRepositoryProvider.overrideWithValue(repo),
              activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
              stageDefinitionRepositoryProvider.overrideWith(
                (ref, c) => stageRepo,
              ),
            ],
          );
          container.read(activeProfileDocIdProvider.notifier).set(_profileId);
          addTearDown(container.dispose);

          // Keep the provider alive across the DB mutation + tick — mirrors
          // the mounted CurriculumProgressScreen. Without an active listener
          // the autoDispose family would tear down between the two reads,
          // which would mask a missing completionCommittedProvider watch.
          final sub = container.listen(
            curriculumProgressProvider(_curriculumKey),
            (_, __) {},
          );
          addTearDown(sub.close);

          final before = await container.read(
            curriculumProgressProvider(_curriculumKey).future,
          );
          expect(
            before.overallStats.completedAllStages,
            0,
            reason: 'no completion seeded yet',
          );

          // A completion lands directly in the DB (mirrors the write path
          // elsewhere in the app) and the commit signal ticks.
          await seedCompletion(
            firestore,
            uid: 'curriculum-progress-reactivity-user',
            profileId: _profileId,
            curriculumId: _curriculum,
            sefariaRef: leaf.sefariaRef,
            stageId: _learnStageId,
            source: CompletionSource.live,
            completedAt: DateTime.utc(2026, 5, 1, 10),
          );
          container.read(completionCommittedProvider.notifier).increment();

          final after = await container.read(
            curriculumProgressProvider(_curriculumKey).future,
          );
          expect(
            after.overallStats.completedAllStages,
            1,
            reason:
                'CP-02: after completionCommittedProvider tick, '
                'curriculumProgressProvider must re-execute so Breakdown by '
                'Level updates without pull-to-refresh',
          );
        },
      );
    },
  );
}
