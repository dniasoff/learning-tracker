/// AUD-progress-01 regression guard.
///
/// [computeLifetimeViewSummary] used to reimplement the ledger-to-learned-refs
/// algorithm in a private `_learnedLeafRefs` function instead of delegating to
/// [LifetimeTreeBuilder.computeLearnedLeafRefs], and that copy never applied
/// the synthetic-container guard that [lifetimeDataProvider]
/// (`lifetime_knowledge_providers.dart`) applies before building its tree.
///
/// A composite curriculum (Tanach = Chumash + Nach) re-parents Chumash leaves
/// under a SYNTHETIC level1 container ('Torah') that exists in no real
/// curriculum. A stray `tanach/level1/'Torah'` ledger row — left over from a
/// since-fixed write-path bug, and never cleaned up on already-upgraded
/// devices because the v32 migration that deletes it only runs once — must be
/// dropped before computing learned refs, or it blanket-credits the entire
/// Torah from a single real per-book mark.
///
/// This test seeds exactly that scenario directly through
/// [computeLifetimeViewSummary] (the "All sources" tab's data path) and
/// asserts the learned count equals the single marked book's leaf count
/// (3), never the whole composite curriculum's leaf count (5).
@Tags(['story_i3'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

// Tanach leaf (Chumash item remapped under the synthetic 'Torah' container):
// level1='Torah', level2=sefer, level3=perek, level4=pasuk.
ContentItem _tanachTorahLeaf(
  String sefariaRef, {
  required String sefer,
  required String perek,
  required String pasuk,
  int sortOrder = 0,
}) => ContentItem(
  curriculumId: CurriculumId.tanach.storageKey,
  level1: 'Torah',
  level2: sefer,
  level3: perek,
  level4: pasuk,
  displayNameHe: '',
  displayNameEn: '',
  sefariaRef: sefariaRef,
  sortOrder: sortOrder,
  isLeaf: true,
);

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.tanach);
  });

  group('AUD-progress-01 — composite synthetic-container guard', () {
    late UserDatabase db;
    late _MockContentRepository repo;
    late int profileId;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      repo = _MockContentRepository();

      final now = DateTime.utc(2026, 5, 1);
      final profile = await db
          .into(db.learnerProfiles)
          .insertReturning(
            LearnerProfilesCompanion.insert(
              accountId: 1,
              displayName: 'Tester',
              mode: 'adult',
              createdAt: now,
              updatedAt: now,
            ),
          );
      profileId = profile.id;
    });

    tearDown(() async => db.close());

    test('a stray tanach/level1/Torah row does not blanket-credit the whole '
        'Torah when only Bereishis was genuinely marked', () async {
      // Two-book miniature Torah, matching
      // lifetime_tree_builder_composite_test.dart's fixture: Bereishis
      // (Genesis) has 3 leaves, Shemos (Exodus) has 2. Whole Torah = 5.
      final leaves = [
        _tanachTorahLeaf(
          'Genesis 1:1',
          sefer: 'Genesis',
          perek: '1',
          pasuk: '1',
        ),
        _tanachTorahLeaf(
          'Genesis 1:2',
          sefer: 'Genesis',
          perek: '1',
          pasuk: '2',
        ),
        _tanachTorahLeaf(
          'Genesis 2:1',
          sefer: 'Genesis',
          perek: '2',
          pasuk: '1',
        ),
        _tanachTorahLeaf('Exodus 1:1', sefer: 'Exodus', perek: '1', pasuk: '1'),
        _tanachTorahLeaf('Exodus 1:2', sefer: 'Exodus', perek: '1', pasuk: '2'),
      ];
      when(
        () => repo.getContentForCurriculum(CurriculumId.tanach),
      ).thenAnswer((_) async => leaves);

      // The genuine mark: Bereishis, recorded via the Tanach→Torah UI path
      // as a qualified level2 scope mark ('Torah|Genesis').
      await db.learningLedgerDao.insertEntry(
        LearningLedgerCompanion.insert(
          profileId: profileId,
          ulid: Value(newUlid()),
          curriculumId: CurriculumId.tanach.storageKey,
          entryScope: 'level2',
          unitIdentifier: scopeUnitIdentifier(
            level: 2,
            level1: 'Torah',
            level2: 'Genesis',
          ),
          unitDisplayNameHe: '',
          unitDisplayNameEn: '',
          trackType: 'personal',
          completedAt: DateTime.utc(2026, 1, 1),
          completionNumber: 1,
          markedBy: profileId,
        ),
      );

      // The stray row: a bare level1 mark against the SYNTHETIC 'Torah'
      // container — the exact leftover the v32 migration was meant to
      // clean up but, per the guard's own doc comment, cannot be relied on
      // for already-upgraded devices.
      await db.learningLedgerDao.insertEntry(
        LearningLedgerCompanion.insert(
          profileId: profileId,
          ulid: Value(newUlid()),
          curriculumId: CurriculumId.tanach.storageKey,
          entryScope: 'level1',
          unitIdentifier: 'Torah',
          unitDisplayNameHe: '',
          unitDisplayNameEn: '',
          trackType: 'personal',
          completedAt: DateTime.utc(2026, 1, 1),
          completionNumber: 1,
          markedBy: profileId,
        ),
      );

      final summary = await computeLifetimeViewSummary(
        db: db,
        repo: repo,
        curriculum: CurriculumId.tanach,
        profileId: profileId,
      );

      expect(summary, isNotNull);
      expect(
        summary!.learnedLeafCount,
        3,
        reason:
            'must credit exactly Bereishis (3 leaves) — the synthetic '
            'tanach/level1/Torah row must be dropped before computing '
            'learned refs, never the whole Torah (5 leaves)',
      );
      expect(summary.totalLeafCount, 5);
    });
  });
}
