/// AUD-progress-01 regression guard for the composite synthetic-container
/// ledger filter.
@Tags(['story_i3'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_ledger_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

const _uid = 'items-composite-test-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

ContentItem _tanachLeaf(
  String ref, {
  required String sefer,
  required String perek,
  required String pasuk,
}) => ContentItem(
  curriculumId: CurriculumId.tanach.storageKey,
  level1: 'Torah',
  level2: sefer,
  level3: perek,
  level4: pasuk,
  displayNameHe: '',
  displayNameEn: '',
  sefariaRef: ref,
  sortOrder: 0,
  isLeaf: true,
);

void main() {
  test(
    'a stray tanach/level1/Torah row does not blanket-credit the whole Torah',
    () async {
      final firestore = createFakeFirestore(authenticatedUid: _uid);
      final repo = _MockContentRepository();
      final leaves = [
        _tanachLeaf('Genesis 1:1', sefer: 'Genesis', perek: '1', pasuk: '1'),
        _tanachLeaf('Genesis 1:2', sefer: 'Genesis', perek: '1', pasuk: '2'),
        _tanachLeaf('Genesis 2:1', sefer: 'Genesis', perek: '2', pasuk: '1'),
        _tanachLeaf('Exodus 1:1', sefer: 'Exodus', perek: '1', pasuk: '1'),
        _tanachLeaf('Exodus 1:2', sefer: 'Exodus', perek: '1', pasuk: '2'),
      ];
      when(
        () => repo.getContentForCurriculum(CurriculumId.tanach),
      ).thenAnswer((_) async => leaves);

      await seedLedgerEntry(
        firestore,
        uid: _uid,
        profileId: _profileId,
        ulid: '01ARZ3NDEKTSV4RRFFQ69G5FAX',
        curriculumId: CurriculumId.tanach,
        entryScope: 'level2',
        unitIdentifier: scopeUnitIdentifier(
          level: 2,
          level1: 'Torah',
          level2: 'Genesis',
        ),
        completedAt: DateTime.utc(2026, 1, 1),
      );
      await seedLedgerEntry(
        firestore,
        uid: _uid,
        profileId: _profileId,
        ulid: '01ARZ3NDEKTSV4RRFFQ69G5FAY',
        curriculumId: CurriculumId.tanach,
        entryScope: 'level1',
        unitIdentifier: 'Torah',
        completedAt: DateTime.utc(2026, 1, 1),
      );

      final ledgerRepository = FirestoreLearningLedgerRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      final ledger = await ledgerRepository.getLedgerForCurriculum(
        CurriculumId.tanach,
      );
      final summary = await computeLifetimeViewSummary(
        completions: const [],
        ledger: ledger,
        repo: repo,
        curriculum: CurriculumId.tanach,
      );

      expect(summary, isNotNull);
      expect(summary!.learnedLeafCount, 3);
      expect(summary.totalLeafCount, 5);
    },
  );
}
