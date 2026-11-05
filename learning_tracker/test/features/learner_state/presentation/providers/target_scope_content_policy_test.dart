import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';

class _RawContentRepository implements ContentRepository {
  final items = [
    ContentItem(
      curriculumId: CurriculumId.mishnayos.storageKey,
      level1: 'Seder',
      level2: 'Masechta',
      displayNameHe: 'Masechta',
      displayNameEn: 'Masechta',
      sefariaRef: 'Masechta',
      sortOrder: 0,
      isLeaf: false,
    ),
    ContentItem(
      curriculumId: CurriculumId.mishnayos.storageKey,
      level1: 'Seder',
      level2: 'Masechta',
      level3: '1',
      displayNameHe: 'Visible',
      displayNameEn: 'Visible',
      sefariaRef: 'Visible leaf',
      sortOrder: 1,
      isLeaf: true,
    ),
    ContentItem(
      curriculumId: CurriculumId.mishnayos.storageKey,
      level1: 'Seder',
      level2: 'Masechta',
      level3: '2',
      displayNameHe: 'Hidden',
      displayNameEn: 'Hidden',
      sefariaRef: 'Hidden leaf',
      sortOrder: 2,
      isLeaf: true,
    ),
  ];

  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId id) async =>
      items;

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(CurriculumId id) async =>
      CurriculumHierarchyConfig(
        curriculumId: id.storageKey,
        levelLabels: const ['Seder', 'Masechta', 'Perek'],
        totalItems: 2,
      );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => items;

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => items;

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => items;

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => items.where((item) => item.sefariaRef == sefariaRef).firstOrNull;
}

void main() {
  test('each tutor roster target gets its own hidden-content corpus', () async {
    final childA = LearnerScope(
      ownerUid: 'parent-a',
      profileId: '01ARZ3NDEKTSV4RRFFQ69G5FAA',
    );
    final childB = LearnerScope(
      ownerUid: 'parent-b',
      profileId: '01ARZ3NDEKTSV4RRFFQ69G5FAB',
    );
    final container = ProviderContainer.test(
      overrides: [
        contentRepositoryProvider.overrideWithValue(_RawContentRepository()),
        hiddenContentRefsForScopeProvider(
          childA,
        ).overrideWith((ref) async => {'Hidden leaf'}),
        hiddenContentRefsForScopeProvider(
          childB,
        ).overrideWith((ref) async => {'Visible leaf'}),
      ],
    );
    addTearDown(container.dispose);

    final corporaA = await container.read(
      corporaForScopeProvider(childA).future,
    );
    final corporaB = await container.read(
      corporaForScopeProvider(childB).future,
    );
    final corpusA = corporaA[CurriculumId.mishnayos.storageKey]!;
    final corpusB = corporaB[CurriculumId.mishnayos.storageKey]!;

    expect(corpusA.nodeForRef('Visible leaf'), isNotNull);
    expect(corpusA.nodeForRef('Hidden leaf'), isNull);
    expect(corpusB.nodeForRef('Visible leaf'), isNull);
    expect(corpusB.nodeForRef('Hidden leaf'), isNotNull);
  });
}
