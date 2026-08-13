import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';

import '../../../../fixtures/content_fixtures.dart';
import '../../../../helpers/firestore_fixtures.dart';

/// Composite-curriculum (Tanach = Chumash + Nach) lifetime-credit invariant.
///
/// Tanach is assembled at runtime: each Chumash book is re-parented under a
/// SYNTHETIC level1 section container 'Torah' (level1='Torah', level2=<sefer>,
/// …), while the underlying `sefariaRef` is preserved unchanged.
///
/// Invariant under test (P0 data-correctness): marking exactly one Torah book
/// (Bereishis) must credit EXACTLY that book's leaves in Tanach — equal to the
/// standalone Chumash credit — and never the whole Torah.

// Standalone Chumash leaf: level1 = sefer, level2 = perek, level3 = pasuk.
ContentItem _chumashLeaf(
  String sefariaRef, {
  required String sefer,
  required String perek,
  required String pasuk,
  int sortOrder = 0,
}) => ContentItemFixtures.leaf(
  curriculumId: 'chumash',
  level1: sefer,
  level2: perek,
  level3: pasuk,
  sefariaRef: sefariaRef,
  sortOrder: sortOrder,
);

// Tanach leaf (Chumash item remapped): level1 = 'Torah', level2 = sefer,
// level3 = perek, level4 = pasuk. sefariaRef identical to the Chumash leaf.
ContentItem _tanachTorahLeaf(
  String sefariaRef, {
  required String sefer,
  required String perek,
  required String pasuk,
  int sortOrder = 0,
}) => ContentItemFixtures.leaf(
  curriculumId: 'tanach',
  level1: 'Torah',
  level2: sefer,
  level3: perek,
  level4: pasuk,
  sefariaRef: sefariaRef,
  sortOrder: sortOrder,
);

const _uid = 'lifetime-tree-composite-test-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _ledgerUlid = '01ARZ3NDEKTSV4RRFFQ69G5FB1';

Future<LearningLedgerEntry> _ledger({
  required CurriculumId curriculumId,
  required String entryScope,
  required String unitIdentifier,
}) async {
  final firestore = FakeFirebaseFirestore();
  await seedLedgerEntry(
    firestore,
    uid: _uid,
    profileId: _profileId,
    ulid: _ledgerUlid,
    curriculumId: curriculumId,
    entryScope: entryScope,
    unitIdentifier: unitIdentifier,
    isManual: true,
  );
  final snapshot = await firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('learning_ledger')
      .doc(_ledgerUlid)
      .get();
  final data = snapshot.data()!;
  final completedAt = data['completed_at'];
  if (completedAt is Timestamp) {
    data['completed_at'] = completedAt.toDate().toUtc();
  }
  return learningLedgerEntryFromFirestore(data);
}

void main() {
  const builder = LifetimeTreeBuilder();

  // Two-book miniature Torah. Bereishis (Genesis) has 3 leaves; Shemos
  // (Exodus) has 2. "Whole Torah" = 5 leaves.
  final chumashLeaves = [
    _chumashLeaf('Genesis 1:1', sefer: 'Genesis', perek: '1', pasuk: '1'),
    _chumashLeaf('Genesis 1:2', sefer: 'Genesis', perek: '1', pasuk: '2'),
    _chumashLeaf('Genesis 2:1', sefer: 'Genesis', perek: '2', pasuk: '1'),
    _chumashLeaf('Exodus 1:1', sefer: 'Exodus', perek: '1', pasuk: '1'),
    _chumashLeaf('Exodus 1:2', sefer: 'Exodus', perek: '1', pasuk: '2'),
  ];
  final tanachLeaves = [
    _tanachTorahLeaf('Genesis 1:1', sefer: 'Genesis', perek: '1', pasuk: '1'),
    _tanachTorahLeaf('Genesis 1:2', sefer: 'Genesis', perek: '1', pasuk: '2'),
    _tanachTorahLeaf('Genesis 2:1', sefer: 'Genesis', perek: '2', pasuk: '1'),
    _tanachTorahLeaf('Exodus 1:1', sefer: 'Exodus', perek: '1', pasuk: '1'),
    _tanachTorahLeaf('Exodus 1:2', sefer: 'Exodus', perek: '1', pasuk: '2'),
  ];

  group('composite credit invariant — mark one book (Bereishis)', () {
    test(
      'standalone Chumash: level1 sefer mark credits exactly that book',
      () async {
        // In standalone Chumash, Bereishis is level1 → bare unitIdentifier.
        final chumashLearned = builder.computeLearnedLeafRefs(
          leaves: chumashLeaves,
          completedRefs: const {},
          ledgerEntries: [
            await _ledger(
              curriculumId: CurriculumId.chumash,
              entryScope: 'level1',
              unitIdentifier: 'Genesis',
            ),
          ],
        );
        expect(chumashLearned, {'Genesis 1:1', 'Genesis 1:2', 'Genesis 2:1'});
      },
    );

    test(
      'Tanach credits the SAME leaves via the unioned subset (Chumash) ledger '
      '— equals the standalone Chumash total, NOT the whole Torah',
      () async {
        // Models the provider fix: compute the subset (Chumash) learned refs
        // from the subset ledger, then union those canonical sefariaRefs into
        // the composite's completedRefs. Tanach's own ledger is empty.
        final chumashLearned = builder.computeLearnedLeafRefs(
          leaves: chumashLeaves,
          completedRefs: const {},
          ledgerEntries: [
            await _ledger(
              curriculumId: CurriculumId.chumash,
              entryScope: 'level1',
              unitIdentifier: 'Genesis',
            ),
          ],
        );

        final tanachLearned = builder.computeLearnedLeafRefs(
          leaves: tanachLeaves,
          // Subset-derived canonical refs unioned in (provider Fix A).
          completedRefs: chumashLearned,
          ledgerEntries: const [],
        );

        // Exactly Bereishis — equal to the standalone Chumash credit.
        expect(tanachLearned, {'Genesis 1:1', 'Genesis 1:2', 'Genesis 2:1'});
        expect(tanachLearned.length, chumashLearned.length);
        // Crucially NOT the whole Torah (5 leaves).
        expect(tanachLearned.contains('Exodus 1:1'), isFalse);
        expect(tanachLearned.contains('Exodus 1:2'), isFalse);
      },
    );

    test('marking Bereishis under Tanach→Torah (qualified level2) credits only '
        'that book — matches the standalone Chumash total', () async {
      // Tanach UI path: drill into Torah, check Bereishis → qualified level2
      // mark 'Torah|Genesis'.
      final markId = scopeUnitIdentifier(
        level: 2,
        level1: 'Torah',
        level2: 'Genesis',
      );
      final tanachLearned = builder.computeLearnedLeafRefs(
        leaves: tanachLeaves,
        completedRefs: const {},
        ledgerEntries: [
          await _ledger(
            curriculumId: CurriculumId.tanach,
            entryScope: 'level2',
            unitIdentifier: markId,
          ),
        ],
      );
      expect(tanachLearned, {'Genesis 1:1', 'Genesis 1:2', 'Genesis 2:1'});
      expect(tanachLearned.contains('Exodus 1:1'), isFalse);
    });
  });

  group('synthetic-container over-credit (the bug the migration removes)', () {
    test(
      'a tanach/level1/Torah blanket mark over-credits the ENTIRE Torah',
      () async {
        // This is the spurious row: marking the synthetic 'Torah' container
        // credits every leaf beneath it (whole Torah) from what the user
        // intended as a single-book mark. The v32 migration deletes such rows;
        // the write-path guard prevents creating new ones.
        final overCredited = builder.computeLearnedLeafRefs(
          leaves: tanachLeaves,
          completedRefs: const {},
          ledgerEntries: [
            await _ledger(
              curriculumId: CurriculumId.tanach,
              entryScope: 'level1',
              unitIdentifier: 'Torah',
            ),
          ],
        );
        // Demonstrates the over-credit: all 5 leaves, not just Bereishis's 3.
        expect(overCredited.length, tanachLeaves.length);
      },
    );
  });
}
