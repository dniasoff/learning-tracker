/// Tests for MasechtaOrderingPolicy (originally landed under W4.15).
///
/// All tests are pure — no DB, no Flutter, no Riverpod.
///
/// AG-5: mirrors
/// `lib/features/tracks/track_order/domain/services/masechta_ordering_policy.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/services/masechta_ordering_policy.dart';

// ── Helpers ─────────────────────────────────────────────────────────────────

ContentItem _item({
  required String sefariaRef,
  required String level1,
  String? level2,
  String? level3,
  String? level4,
  bool isLeaf = false,
  int sortOrder = 0,
  String he = '',
  String en = '',
}) {
  return ContentItem(
    curriculumId: 'bavli',
    sefariaRef: sefariaRef,
    level1: level1,
    level2: level2,
    level3: level3,
    level4: level4,
    isLeaf: isLeaf,
    sortOrder: sortOrder,
    displayNameHe: he.isEmpty ? sefariaRef : he,
    displayNameEn: en.isEmpty ? sefariaRef : en,
  );
}

void main() {
  // ── MasechtaOrderingPolicy ────────────────────────────────────────────────
  group('MasechtaOrderingPolicy', () {
    const policy = MasechtaOrderingPolicy();

    // Minimal content fixture:
    //  Seder Zeraim (L1 container)
    //    └── Berakhot (L2 container)  sortOrder=0
    //    └── Peah    (L2 container)   sortOrder=1
    //  Seder Moed (L1 container)
    //    └── Shabbat (L2 container)   sortOrder=0
    //    └── Eruvin  (L2 container)   sortOrder=1

    final zeraim = _item(
      sefariaRef: 'Seder Zeraim',
      level1: 'Seder Zeraim',
      sortOrder: 0,
    );
    final moed = _item(
      sefariaRef: 'Seder Moed',
      level1: 'Seder Moed',
      sortOrder: 1,
    );
    final berakhot = _item(
      sefariaRef: 'Berakhot',
      level1: 'Seder Zeraim',
      level2: 'Berakhot',
      sortOrder: 0,
      he: 'ברכות',
      en: 'Berakhot',
    );
    final peah = _item(
      sefariaRef: 'Peah',
      level1: 'Seder Zeraim',
      level2: 'Peah',
      sortOrder: 1,
      he: 'פאה',
      en: 'Peah',
    );
    final shabbat = _item(
      sefariaRef: 'Shabbat',
      level1: 'Seder Moed',
      level2: 'Shabbat',
      sortOrder: 0,
      he: 'שבת',
      en: 'Shabbat',
    );
    final eruvin = _item(
      sefariaRef: 'Eruvin',
      level1: 'Seder Moed',
      level2: 'Eruvin',
      sortOrder: 1,
      he: 'עירובין',
      en: 'Eruvin',
    );
    // A leaf item that should be excluded from the masechtos index.
    final daf = _item(
      sefariaRef: 'Berakhot 2a',
      level1: 'Seder Zeraim',
      level2: 'Berakhot',
      level3: 'Chapter 1',
      isLeaf: true,
      sortOrder: 0,
    );

    final allItems = [zeraim, moed, berakhot, peah, shabbat, eruvin, daf];

    final sedarimIndex = {
      'Seder Zeraim': (he: 'זרעים', en: 'Zeraim', sortOrder: 0),
      'Seder Moed': (he: 'מועד', en: 'Moed', sortOrder: 1),
    };

    test('excludes leaf items from the masechtos index', () {
      final index = policy.buildIndex(
        allItems: allItems,
        sedarimIndex: sedarimIndex,
        savedSederOrder: [],
      );
      expect(
        index.containsKey('Berakhot 2a'),
        isFalse,
        reason: 'Leaf items must not appear in masechtos index',
      );
    });

    test('excludes L1 containers from masechtos index', () {
      final index = policy.buildIndex(
        allItems: allItems,
        sedarimIndex: sedarimIndex,
        savedSederOrder: [],
      );
      expect(index.containsKey('Seder Zeraim'), isFalse);
      expect(index.containsKey('Seder Moed'), isFalse);
    });

    test('includes all L2 containers', () {
      final index = policy.buildIndex(
        allItems: allItems,
        sedarimIndex: sedarimIndex,
        savedSederOrder: [],
      );
      expect(index.containsKey('Berakhot'), isTrue);
      expect(index.containsKey('Peah'), isTrue);
      expect(index.containsKey('Shabbat'), isTrue);
      expect(index.containsKey('Eruvin'), isTrue);
      expect(index.length, 4);
    });

    test('canonical sort: Zeraim before Moed (no saved seder order)', () {
      final index = policy.buildIndex(
        allItems: allItems,
        sedarimIndex: sedarimIndex,
        savedSederOrder: [],
      );
      // Zeraim has lower canonical sortOrder → its masechtos come first.
      expect(
        index['Berakhot']!.sortOrder,
        lessThan(index['Shabbat']!.sortOrder),
      );
      expect(index['Peah']!.sortOrder, lessThan(index['Shabbat']!.sortOrder));
    });

    test('user seder order: Moed first → its masechtos sort first', () {
      final index = policy.buildIndex(
        allItems: allItems,
        sedarimIndex: sedarimIndex,
        savedSederOrder: ['Seder Moed', 'Seder Zeraim'],
      );
      // Moed is first in saved order → Shabbat/Eruvin sort before Berakhot/Peah.
      expect(
        index['Shabbat']!.sortOrder,
        lessThan(index['Berakhot']!.sortOrder),
      );
      expect(
        index['Eruvin']!.sortOrder,
        lessThan(index['Berakhot']!.sortOrder),
      );
    });

    test('within-seder order preserved: Berakhot before Peah', () {
      final index = policy.buildIndex(
        allItems: allItems,
        sedarimIndex: sedarimIndex,
        savedSederOrder: [],
      );
      // Both are in Zeraim; canonical sortOrder: Berakhot=0, Peah=1.
      expect(index['Berakhot']!.sortOrder, lessThan(index['Peah']!.sortOrder));
    });

    test('display names preserved in index', () {
      final index = policy.buildIndex(
        allItems: allItems,
        sedarimIndex: sedarimIndex,
        savedSederOrder: [],
      );
      expect(index['Berakhot']!.he, 'ברכות');
      expect(index['Berakhot']!.en, 'Berakhot');
    });

    test('empty items → empty index', () {
      final index = policy.buildIndex(
        allItems: [],
        sedarimIndex: sedarimIndex,
        savedSederOrder: [],
      );
      expect(index, isEmpty);
    });

    test('sortOrder values are 0-based integers', () {
      final index = policy.buildIndex(
        allItems: allItems,
        sedarimIndex: sedarimIndex,
        savedSederOrder: [],
      );
      final sortOrders = index.values.map((e) => e.sortOrder).toList()..sort();
      // Should be [0, 1, 2, 3] — contiguous 0-based.
      expect(sortOrders, [0, 1, 2, 3]);
    });
  });
}
