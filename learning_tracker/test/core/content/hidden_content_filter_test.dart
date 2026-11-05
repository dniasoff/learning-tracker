import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/hidden_content.dart';

ContentItem item({
  required String ref,
  required bool leaf,
  String level1 = 'Seder',
  String? level2,
  String? level3,
}) => ContentItem(
  curriculumId: 'test',
  level1: level1,
  level2: level2,
  level3: level3,
  displayNameHe: ref,
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: 0,
  isLeaf: leaf,
);

void main() {
  test('nothing hidden is the default', () {
    final items = [
      item(ref: 'Seder', leaf: false),
      item(ref: 'Book', leaf: false, level2: 'Book'),
      item(ref: 'Book 1', leaf: true, level2: 'Book', level3: '1'),
    ];

    expect(HiddenContentFilter.visible(items, const {}), items);
  });

  test('hiding a container removes the container and every descendant', () {
    final items = [
      item(ref: 'Seder', leaf: false),
      item(ref: 'Visible Book', leaf: false, level2: 'Visible Book'),
      item(
        ref: 'Visible Book 1',
        leaf: true,
        level2: 'Visible Book',
        level3: '1',
      ),
      item(ref: 'Hidden Book', leaf: false, level2: 'Hidden Book'),
      item(
        ref: 'Hidden Book 1',
        leaf: true,
        level2: 'Hidden Book',
        level3: '1',
      ),
    ];

    expect(
      HiddenContentFilter.visible(items, {
        'Hidden Book',
      }).map((i) => i.sefariaRef),
      ['Seder', 'Visible Book', 'Visible Book 1'],
    );
  });

  test('hiding a leaf does not hide its siblings or ancestors', () {
    final items = [
      item(ref: 'Book', leaf: false, level2: 'Book'),
      item(ref: 'Book 1', leaf: true, level2: 'Book', level3: '1'),
      item(ref: 'Book 2', leaf: true, level2: 'Book', level3: '2'),
    ];

    expect(
      HiddenContentFilter.visible(items, {'Book 1'}).map((i) => i.sefariaRef),
      ['Book', 'Book 2'],
    );
  });

  test('switching profiles replaces the policy instead of leaking it', () {
    final items = [
      item(ref: 'Book', leaf: false, level2: 'Book'),
      item(ref: 'Book 1', leaf: true, level2: 'Book', level3: '1'),
      item(ref: 'Book 2', leaf: true, level2: 'Book', level3: '2'),
    ];

    final profileA = HiddenContentFilter.visible(items, {'Book 1'});
    final profileB = HiddenContentFilter.visible(items, {'Book 2'});

    expect(profileA.map((i) => i.sefariaRef), ['Book', 'Book 2']);
    expect(profileB.map((i) => i.sefariaRef), ['Book', 'Book 1']);
  });

  test('suggested preset contains the requested top-level refs', () {
    expect(
      suggestedHiddenContentRefs,
      containsAll(<String>[
        'Niddah',
        'Jerusalem Talmud Niddah',
        'Mishnah Niddah',
        'Mishneh Torah, Forbidden Intercourse',
        'Mishnah Zavim',
      ]),
    );
  });
}
