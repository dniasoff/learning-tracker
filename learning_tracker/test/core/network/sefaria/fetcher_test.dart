import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/bavli_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/chumash_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/mishna_berurah_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/mishna_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/yerushalmi_fetcher.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
  });

  setUpAll(() {
    registerFallbackValue(FakeRequestOptions());
  });

  /// Load a JSON fixture file.
  dynamic loadFixture(String name) {
    final file = File('test/fixtures/sefaria/$name');
    return jsonDecode(file.readAsStringSync());
  }

  /// Set up a mock shape response for a given path.
  void mockShapeResponse(String path, dynamic data) {
    when(() => mockDio.get<dynamic>(path)).thenAnswer(
      (_) async => Response(
        data: data,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      ),
    );
  }

  /// Set up a mock text response for a given path.
  void mockTextResponse(String path, Map<String, dynamic> data) {
    when(() => mockDio.get<Map<String, dynamic>>(path)).thenAnswer(
      (_) async => Response(
        data: data,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      ),
    );
  }

  group('MishnaFetcher', () {
    late MishnaFetcher fetcher;

    setUp(() {
      fetcher = MishnaFetcher(dio: mockDio);
    });

    test('curriculumId uses CurriculumId.storageKey', () {
      expect(fetcher.curriculumId, CurriculumId.mishnayos.storageKey);
    });

    test(
      'fetchAllContent returns items with correct 4-level hierarchy',
      () async {
        mockShapeResponse(
          '/api/shape/Mishnah',
          loadFixture('mishnah_shape.json'),
        );

        final result = await fetcher.fetchAllContent();

        // Should have containers and leaves for 3 tractates across 2 sedarim.
        expect(result.items, isNotEmpty);
        expect(result.hierarchyConfig.levelLabels, [
          'Seder',
          'Masechta',
          'Perek',
          'Mishna',
        ]);

        // Count leaf items (actual mishnayot).
        final leaves = result.items.where((i) => i.isLeaf).toList();
        // Berakhot: 5+8+6+7+5+8+5+8+5 = 57
        // Peah: 6+8+8+11+8+11+8+9 = 69
        // Shabbat: 11+7+6+2+4+10+4+7+7+6+6+6+7+4+3+8+8+3+6+5+3+6+5+5 = 139
        expect(leaves.length, 57 + 69 + 139);
        expect(result.hierarchyConfig.totalItems, leaves.length);
      },
    );

    test('isLeaf is true only for leaf-level mishna items', () async {
      mockShapeResponse(
        '/api/shape/Mishnah',
        loadFixture('mishnah_shape.json'),
      );

      final result = await fetcher.fetchAllContent();

      // Seder containers have no level2.
      final sedarim = result.items
          .where((i) => i.level2 == null && !i.isLeaf)
          .toList();
      expect(sedarim, isNotEmpty);

      // Masechta containers have level2 but no level3.
      final masechtot = result.items
          .where((i) => i.level2 != null && i.level3 == null)
          .toList();
      expect(masechtot, isNotEmpty);
      for (final m in masechtot) {
        expect(m.isLeaf, false);
      }

      // Leaf items have level4.
      for (final leaf in result.items.where((i) => i.isLeaf)) {
        expect(leaf.level4, isNotNull);
      }
    });

    test('populates curriculum_hierarchy_config correctly', () async {
      mockShapeResponse(
        '/api/shape/Mishnah',
        loadFixture('mishnah_shape.json'),
      );

      final result = await fetcher.fetchAllContent();

      expect(result.hierarchyConfig.curriculumId, 'mishnayos');
      expect(result.hierarchyConfig.depth, 4);
      expect(result.hierarchyConfig.levelLabels, [
        'Seder',
        'Masechta',
        'Perek',
        'Mishna',
      ]);
    });

    test('fetchText returns both Hebrew and English text', () async {
      final textData =
          loadFixture('text_response.json') as Map<String, dynamic>;
      mockTextResponse(
        '/api/v3/texts/${Uri.encodeComponent('Mishnah Berakhot 1.1')}',
        textData,
      );

      final text = await fetcher.fetchText('Mishnah Berakhot 1.1');

      expect(text, contains('מֵאֵימָתַי'));
      expect(text, contains('From when may one recite'));
    });

    test('fetchText with lang=he returns only Hebrew', () async {
      final textData =
          loadFixture('text_response.json') as Map<String, dynamic>;
      mockTextResponse(
        '/api/v3/texts/${Uri.encodeComponent('Mishnah Berakhot 1.1')}',
        textData,
      );

      final text = await fetcher.fetchText('Mishnah Berakhot 1.1', lang: 'he');

      expect(text, contains('מֵאֵימָתַי'));
      expect(text, isNot(contains('From when')));
    });
  });

  group('BavliFetcher', () {
    late BavliFetcher fetcher;

    setUp(() {
      fetcher = BavliFetcher(dio: mockDio);
    });

    test('curriculumId uses CurriculumId.storageKey', () {
      expect(fetcher.curriculumId, CurriculumId.bavli.storageKey);
    });

    test('fetchAllContent parses masechta-daf-amud correctly', () async {
      mockShapeResponse('/api/shape/Bavli', loadFixture('bavli_shape.json'));

      final result = await fetcher.fetchAllContent();

      expect(result.items, isNotEmpty);
      expect(result.hierarchyConfig.levelLabels, ['Masechta', 'Daf', 'Amud']);

      // All leaves should have level3 (amud: 'a' or 'b').
      final leaves = result.items.where((i) => i.isLeaf).toList();
      for (final leaf in leaves) {
        expect(leaf.level3, anyOf('a', 'b'));
      }

      // Berakhot has 10 amudim in fixture = 10 leaf items.
      // Shabbat has 6 amudim in fixture = 6 leaf items.
      expect(leaves.length, 10 + 6);
    });

    test('isLeaf is true only on amud items', () async {
      mockShapeResponse('/api/shape/Bavli', loadFixture('bavli_shape.json'));

      final result = await fetcher.fetchAllContent();

      // Masechta containers.
      final masechtot = result.items.where((i) => i.level2 == null).toList();
      for (final m in masechtot) {
        expect(m.isLeaf, false);
      }

      // Daf containers.
      final dapim = result.items
          .where((i) => i.level2 != null && i.level3 == null)
          .toList();
      for (final d in dapim) {
        expect(d.isLeaf, false);
      }
    });
  });

  group('YerushalmiFetcher', () {
    late YerushalmiFetcher fetcher;

    setUp(() {
      fetcher = YerushalmiFetcher(dio: mockDio);
    });

    test('curriculumId uses CurriculumId.storageKey', () {
      expect(fetcher.curriculumId, CurriculumId.yerushalmi.storageKey);
    });

    test('fetchAllContent parses masechta-daf-halacha correctly', () async {
      mockShapeResponse(
        '/api/shape/Yerushalmi',
        loadFixture('yerushalmi_shape.json'),
      );

      final result = await fetcher.fetchAllContent();

      expect(result.items, isNotEmpty);
      expect(result.hierarchyConfig.levelLabels, [
        'Masechta',
        'Daf',
        'Halacha',
      ]);

      // Berakhot: 8+9+6+4+5+6+5+8+5 = 56 halachot.
      // Peah: 5+7+4+6+5+4+5+7 = 43 halachot.
      final leaves = result.items.where((i) => i.isLeaf).toList();
      expect(leaves.length, 56 + 43);
    });

    test('isLeaf is true only on halacha items', () async {
      mockShapeResponse(
        '/api/shape/Yerushalmi',
        loadFixture('yerushalmi_shape.json'),
      );

      final result = await fetcher.fetchAllContent();

      for (final item in result.items.where((i) => i.isLeaf)) {
        expect(item.level3, isNotNull);
      }

      for (final item in result.items.where((i) => !i.isLeaf)) {
        expect(item.level3, isNull);
      }
    });
  });

  group('MishnaBerurahFetcher', () {
    late MishnaBerurahFetcher fetcher;

    setUp(() {
      fetcher = MishnaBerurahFetcher(dio: mockDio);
    });

    test('curriculumId uses CurriculumId.storageKey', () {
      expect(fetcher.curriculumId, CurriculumId.mishnaBerurah.storageKey);
    });

    test('fetchAllContent parses siman-seif-seif_katan correctly', () async {
      // MB shape: 3 simanim with 20, 14, 31 seif katan.
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Mishnah Berurah')}',
        [loadFixture('mishna_berurah_shape.json')],
      );
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Shulchan Arukh, Orach Chayyim')}',
        [loadFixture('shulchan_aruch_oc_shape.json')],
      );

      final result = await fetcher.fetchAllContent();

      expect(result.items, isNotEmpty);
      expect(result.hierarchyConfig.levelLabels, [
        'Siman',
        'Seif',
        'Seif Katan',
      ]);

      // Total seif katan: 20 + 14 + 31 = 65.
      final leaves = result.items.where((i) => i.isLeaf).toList();
      expect(leaves.length, 65);
    });

    test('populates curriculum_hierarchy_config correctly', () async {
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Mishnah Berurah')}',
        [loadFixture('mishna_berurah_shape.json')],
      );
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Shulchan Arukh, Orach Chayyim')}',
        [loadFixture('shulchan_aruch_oc_shape.json')],
      );

      final result = await fetcher.fetchAllContent();

      expect(result.hierarchyConfig.curriculumId, 'mishna_berurah');
      expect(result.hierarchyConfig.depth, 3);
    });
  });

  group('ChumashFetcher', () {
    late ChumashFetcher fetcher;

    setUp(() {
      fetcher = ChumashFetcher(dio: mockDio);
    });

    test('curriculumId uses CurriculumId.storageKey', () {
      expect(fetcher.curriculumId, CurriculumId.chumash.storageKey);
    });

    test('fetchAllContent parses sefer-parsha-perek-pasuk correctly', () async {
      mockShapeResponse('/api/shape/Tanakh', loadFixture('tanakh_shape.json'));

      final result = await fetcher.fetchAllContent();

      expect(result.items, isNotEmpty);
      expect(result.hierarchyConfig.levelLabels, [
        'Sefer',
        'Parsha',
        'Perek',
        'Pasuk',
      ]);

      // Genesis: 31+25+24 = 80 verses (3 chapters in fixture).
      // Exodus: 22+25 = 47 verses (2 chapters in fixture).
      final leaves = result.items.where((i) => i.isLeaf).toList();
      expect(leaves.length, 80 + 47);
    });

    test('isLeaf is true only on pasuk items', () async {
      mockShapeResponse('/api/shape/Tanakh', loadFixture('tanakh_shape.json'));

      final result = await fetcher.fetchAllContent();

      for (final item in result.items.where((i) => i.isLeaf)) {
        expect(item.level4, isNotNull);
      }
    });

    test('populates curriculum_hierarchy_config correctly', () async {
      mockShapeResponse('/api/shape/Tanakh', loadFixture('tanakh_shape.json'));

      final result = await fetcher.fetchAllContent();

      expect(result.hierarchyConfig.curriculumId, 'chumash');
      expect(result.hierarchyConfig.depth, 4);
      expect(result.hierarchyConfig.totalItems, 127);
    });
  });

  group('Error handling', () {
    test(
      'API failure throws SefariaApiException, not unhandled exception',
      () async {
        final fetcher = MishnaFetcher(dio: mockDio);

        when(() => mockDio.get<dynamic>(any())).thenThrow(
          DioException(
            type: DioExceptionType.connectionTimeout,
            requestOptions: RequestOptions(path: '/api/shape/Mishnah'),
          ),
        );

        expect(
          () => fetcher.fetchAllContent(),
          throwsA(isA<SefariaApiException>()),
        );
      },
    );

    test('API 500 error throws SefariaApiException', () async {
      final fetcher = BavliFetcher(dio: mockDio);

      when(() => mockDio.get<dynamic>(any())).thenThrow(
        DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 500,
            requestOptions: RequestOptions(path: '/api/shape/Bavli'),
          ),
          requestOptions: RequestOptions(path: '/api/shape/Bavli'),
        ),
      );

      expect(
        () => fetcher.fetchAllContent(),
        throwsA(
          isA<SefariaApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });

    test('Network error throws SefariaApiException', () async {
      final fetcher = YerushalmiFetcher(dio: mockDio);

      when(() => mockDio.get<dynamic>(any())).thenThrow(
        DioException(
          type: DioExceptionType.connectionError,
          requestOptions: RequestOptions(path: '/api/shape/Yerushalmi'),
        ),
      );

      expect(
        () => fetcher.fetchAllContent(),
        throwsA(isA<SefariaApiException>()),
      );
    });

    test('fetchText API failure throws SefariaApiException', () async {
      final fetcher = MishnaFetcher(dio: mockDio);

      when(() => mockDio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          type: DioExceptionType.receiveTimeout,
          requestOptions: RequestOptions(path: '/api/v3/texts/test'),
        ),
      );

      expect(
        () => fetcher.fetchText('test'),
        throwsA(isA<SefariaApiException>()),
      );
    });
  });
}
