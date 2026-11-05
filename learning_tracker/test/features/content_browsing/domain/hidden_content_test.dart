import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/hidden_content.dart';

ContentItem _item({
  required String ref,
  required String level1,
  String? level2,
  bool isLeaf = false,
}) => ContentItem(
  curriculumId: 'mishnayos',
  level1: level1,
  level2: level2,
  displayNameHe: ref,
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: 0,
  isLeaf: isLeaf,
);

void main() {
  test('hiding a container removes its descendants', () {
    final items = [
      _item(ref: 'Zeraim', level1: 'Zeraim'),
      _item(ref: 'Berakhot', level1: 'Zeraim', level2: 'Berakhot'),
      _item(
        ref: 'Berakhot 1:1',
        level1: 'Zeraim',
        level2: 'Berakhot',
        isLeaf: true,
      ),
      _item(ref: 'Shabbos', level1: 'Shabbos'),
    ];

    final visible = HiddenContentFilter.visible(items, {'Berakhot'});

    expect(visible.map((item) => item.sefariaRef), ['Zeraim', 'Shabbos']);
  });

  test('empty hidden refs preserve the original list', () {
    final items = [_item(ref: 'Zeraim', level1: 'Zeraim')];

    expect(identical(HiddenContentFilter.visible(items, {}), items), isTrue);
  });
}
