import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final file = File('assets/content/hierarchy/mishna_berurah.json');

  test('Mishnah Berurah uses authoritative Orach Chaim hilchos ranges', () {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final items = (json['items'] as List).cast<Map<String, dynamic>>();
    final expected = <String, (int, int)>{
      'Morning conduct': (1, 7),
      'Tzitzis': (8, 24),
      'Tefillin': (25, 45),
      'Morning blessings': (46, 57),
      'Krias Shema': (58, 88),
      'Tefillah': (89, 127),
      'Birkat Kohanim and nefilat apayim': (128, 134),
      'Krias HaTorah': (135, 149),
      'Beis Haknesses': (150, 156),
      'Netilas Yadayim': (157, 165),
      'Bitzias HaPas': (166, 168),
      'Seudah': (169, 181),
      'Birkat Hamazon': (182, 201),
      'Fruit and fragrance blessings': (202, 217),
      'Other blessings': (218, 231),
      'Mincha': (232, 234),
      'Maariv': (235, 239),
      'Tznius': (240, 241),
      'Shabbos': (242, 344),
      'Eruvin': (345, 416),
      'Rosh Chodesh': (417, 428),
      'Pesach': (429, 494),
      'Yom Tov': (495, 529),
      'Chol HaMoed': (530, 548),
      "Tisha B'Av and other fasts": (549, 561),
      'Fast days': (562, 580),
      'Rosh Hashanah': (581, 603),
      'Yom Kippur': (604, 624),
      'Sukkah': (625, 644),
      'Lulav': (645, 669),
      'Chanukah': (670, 685),
      'Purim': (686, 697),
    };

    final leaves = items.where((item) => item['isLeaf'] == true).toList();
    expect(leaves, hasLength(17397));
    final root = items.singleWhere(
      (item) => item['sefariaRef'] == 'Mishnah Berurah',
    );
    expect(root['level1'], 'Mishnah Berurah');
    expect(root['level2'], isNull);
    expect(root['isLeaf'], isFalse);

    final sections = <String, List<int>>{};
    for (final item in items) {
      final section = item['level2'] as String?;
      final siman = int.tryParse(item['level3'] as String? ?? '');
      if (section != null && siman != null) {
        sections.putIfAbsent(section, () => []).add(siman);
      }
    }
    expect(sections.keys, containsAll(expected.keys));
    expect(sections, hasLength(expected.length));
    for (final entry in expected.entries) {
      expect(
        sections[entry.key]!.reduce((a, b) => a < b ? a : b),
        entry.value.$1,
      );
      expect(
        sections[entry.key]!.reduce((a, b) => a > b ? a : b),
        entry.value.$2,
      );
    }
  });

  test('regrouping preserves every leaf Sefaria ref', () {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final items = (json['items'] as List).cast<Map<String, dynamic>>();
    final leaves = items
        .where((item) => item['isLeaf'] == true)
        .map((item) => item['sefariaRef'] as String)
        .toSet();

    expect(leaves, hasLength(17397));
    expect(leaves, contains('Mishnah Berurah 1:1'));
    expect(leaves, contains('Mishnah Berurah 697:1'));
    expect(leaves.every((ref) => ref.startsWith('Mishnah Berurah ')), isTrue);
  });
}
