import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';

class _CompositeRepository extends ContentRepositoryImpl {
  _CompositeRepository(this._assets);

  final Map<String, String> _assets;

  @override
  Future<String> loadRawContentJson(String key) async => _assets[key]!;
}

Map<String, dynamic> _asset(
  String curriculumId,
  List<Map<String, dynamic>> items,
) => {
  'hierarchyConfig': {
    'curriculumId': curriculumId,
    'levelLabels': const ['Section', 'Sefer', 'Perek', 'Pasuk'],
    'totalItems': items.where((item) => item['isLeaf'] == true).length,
  },
  'items': items,
};

Map<String, dynamic> _item({
  required String curriculumId,
  required String ref,
  required String level1,
  String? level2,
  String? level3,
  String? level4,
  required int sortOrder,
  required bool isLeaf,
}) => {
  'curriculumId': curriculumId,
  'level1': level1,
  'level2': level2,
  'level3': level3,
  'level4': level4,
  'displayNameHe': ref,
  'displayNameEn': ref,
  'sefariaRef': ref,
  'sortOrder': sortOrder,
  'isLeaf': isLeaf,
};

void main() {
  test('Tanach keeps source trees ordered and progress-addressable', () async {
    final chumash = [
      _item(
        curriculumId: 'chumash',
        ref: 'Genesis',
        level1: 'Genesis',
        sortOrder: 0,
        isLeaf: false,
      ),
      _item(
        curriculumId: 'chumash',
        ref: 'Genesis 1',
        level1: 'Genesis',
        level2: '1',
        sortOrder: 1,
        isLeaf: false,
      ),
      _item(
        curriculumId: 'chumash',
        ref: 'Genesis 1:1',
        level1: 'Genesis',
        level2: '1',
        level3: '1',
        sortOrder: 2,
        isLeaf: true,
      ),
      _item(
        curriculumId: 'chumash',
        ref: 'Genesis 1:2',
        level1: 'Genesis',
        level2: '1',
        level3: '2',
        sortOrder: 3,
        isLeaf: true,
      ),
    ];
    final nach = [
      _item(
        curriculumId: 'nach',
        ref: 'Prophets',
        level1: 'Prophets',
        sortOrder: 0,
        isLeaf: false,
      ),
      _item(
        curriculumId: 'nach',
        ref: 'Joshua',
        level1: 'Prophets',
        level2: 'Joshua',
        sortOrder: 1,
        isLeaf: false,
      ),
      _item(
        curriculumId: 'nach',
        ref: 'Joshua 1',
        level1: 'Prophets',
        level2: 'Joshua',
        level3: '1',
        sortOrder: 2,
        isLeaf: false,
      ),
      _item(
        curriculumId: 'nach',
        ref: 'Joshua 1:1',
        level1: 'Prophets',
        level2: 'Joshua',
        level3: '1',
        level4: '1',
        sortOrder: 3,
        isLeaf: true,
      ),
      _item(
        curriculumId: 'nach',
        ref: 'Joshua 1:2',
        level1: 'Prophets',
        level2: 'Joshua',
        level3: '1',
        level4: '2',
        sortOrder: 4,
        isLeaf: true,
      ),
    ];
    final repo = _CompositeRepository({
      'chumash': jsonEncode(_asset('chumash', chumash)),
      'nach': jsonEncode(_asset('nach', nach)),
    });

    final tanach = await repo.getContentForCurriculum(CurriculumId.tanach);
    expect(tanach.map((item) => item.sefariaRef).toList(), [
      'Torah',
      'Genesis',
      'Genesis 1',
      'Genesis 1:1',
      'Genesis 1:2',
      'Prophets',
      'Joshua',
      'Joshua 1',
      'Joshua 1:1',
      'Joshua 1:2',
    ]);

    final corpus = corpusOf(CurriculumId.tanach, tanach);
    final prophets = corpus.nodeForRef('Prophets');
    expect(prophets, isNotNull);
    expect(corpus.leavesUnder(prophets!), ['Joshua 1:1', 'Joshua 1:2']);
  });
}
