// AUD-core-content-01 regression test: AdjacentItems previously had no
// == /hashCode override (identity-only equality), so two structurally
// identical instances never compared equal. This locks in the @freezed
// value-equality behavior.

@Tags(['content'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

ContentItem _item(String ref) => ContentItem(
  curriculumId: 'bavli',
  level1: 'Berakhot',
  displayNameHe: '',
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: 0,
  isLeaf: true,
);

void main() {
  group('AdjacentItems equality', () {
    test('two instances built from the same prev/next are equal', () {
      final prev = _item('Berakhot 2a');
      final next = _item('Berakhot 2b');

      final a = AdjacentItems(prev: prev, next: next);
      final b = AdjacentItems(prev: prev, next: next);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('instances with a different next are not equal', () {
      final prev = _item('Berakhot 2a');

      final a = AdjacentItems(prev: prev, next: _item('Berakhot 2b'));
      final b = AdjacentItems(prev: prev, next: _item('Berakhot 3a'));

      expect(a, isNot(equals(b)));
    });

    test('two default (null, null) instances are equal', () {
      expect(const AdjacentItems(), equals(const AdjacentItems()));
    });
  });
}
