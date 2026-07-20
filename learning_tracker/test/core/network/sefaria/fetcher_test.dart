import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';

import 'package:mocktail/mocktail.dart';

// ignore: avoid_relative_lib_imports
import '../../../../tool/lib/sefaria/bavli_fetcher.dart';
// ignore: avoid_relative_lib_imports
import '../../../../tool/lib/sefaria/chumash_fetcher.dart';
// ignore: avoid_relative_lib_imports
import '../../../../tool/lib/sefaria/mishna_berurah_fetcher.dart';
// ignore: avoid_relative_lib_imports
import '../../../../tool/lib/sefaria/mishna_fetcher.dart';
// ignore: avoid_relative_lib_imports
import '../../../../tool/lib/sefaria/mussar_fetcher.dart';
// ignore: avoid_relative_lib_imports
import '../../../../tool/lib/sefaria/nach_fetcher.dart';
// ignore: avoid_relative_lib_imports
import '../../../../tool/lib/sefaria/yerushalmi_fetcher.dart';

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

    test('seder containers use the canonical Hebrew seder names', () async {
      // Pins the exact Hebrew value produced by the seder-name lookup
      // (AUD-guardrails-30: shared with BavliFetcher via
      // SefariaFetcherBase.sederHebrewName). Regression guard for the
      // hoist out of a private per-fetcher table.
      mockShapeResponse(
        '/api/shape/Mishnah',
        loadFixture('mishnah_shape.json'),
      );

      final result = await fetcher.fetchAllContent();

      final sedarim = {
        for (final item in result.items.where(
          (i) => i.level2 == null && !i.isLeaf,
        ))
          item.level1: item.displayNameHe,
      };

      expect(sedarim['Seder Zeraim'], 'סדר זרעים');
      expect(sedarim['Seder Moed'], 'סדר מועד');
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
      expect(result.hierarchyConfig.levelLabels, [
        'Seder',
        'Masechta',
        'Daf',
        'Amud',
      ]);

      // All leaves should have level4 (amud: 'a' or 'b').
      final leaves = result.items.where((i) => i.isLeaf).toList();
      for (final leaf in leaves) {
        expect(leaf.level4, anyOf('a', 'b'));
      }

      // Berakhot has 10 amudim in fixture = 10 leaf items.
      // Shabbat has 6 amudim in fixture = 6 leaf items.
      expect(leaves.length, 10 + 6);
    });

    test('isLeaf is true only on amud items', () async {
      mockShapeResponse('/api/shape/Bavli', loadFixture('bavli_shape.json'));

      final result = await fetcher.fetchAllContent();

      // Seder containers (level2 == null).
      final sedarim = result.items
          .where((i) => i.level2 == null && !i.isLeaf)
          .toList();
      for (final s in sedarim) {
        expect(s.isLeaf, false);
      }

      // Masechta containers (level2 set, level3 == null).
      final masechtot = result.items
          .where((i) => i.level2 != null && i.level3 == null)
          .toList();
      for (final m in masechtot) {
        expect(m.isLeaf, false);
      }

      // Daf containers (level3 set, level4 == null).
      final dapim = result.items
          .where((i) => i.level3 != null && i.level4 == null)
          .toList();
      for (final d in dapim) {
        expect(d.isLeaf, false);
      }
    });

    test('seder containers use the canonical Hebrew seder names', () async {
      // Pins the exact Hebrew value produced by the seder-name lookup
      // (AUD-guardrails-30: shared with MishnaFetcher via
      // SefariaFetcherBase.sederHebrewName). Regression guard for the
      // hoist out of a private per-fetcher table.
      mockShapeResponse('/api/shape/Bavli', loadFixture('bavli_shape.json'));

      final result = await fetcher.fetchAllContent();

      final sedarim = {
        for (final item in result.items.where(
          (i) => i.level2 == null && !i.isLeaf,
        ))
          item.level1: item.displayNameHe,
      };

      expect(sedarim['Seder Zeraim'], 'סדר זרעים');
      expect(sedarim['Seder Moed'], 'סדר מועד');
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

  group('SefariaFetcherBase - fetchText edge cases', () {
    late MishnaFetcher fetcher;

    setUp(() {
      fetcher = MishnaFetcher(dio: mockDio);
    });

    test('fetchText strips HTML tags from text', () async {
      mockTextResponse(
        '/api/v3/texts/${Uri.encodeComponent('Mishnah Berakhot 1.1')}',
        {
          'versions': [
            {
              'text': '<b>Bold</b> and <i>italic</i> text',
              'language': 'en',
              'actualLanguage': 'en',
            },
            {
              'text': '<span class="segment">מֵאֵימָתַי</span>',
              'language': 'he',
              'actualLanguage': 'he',
            },
          ],
        },
      );

      final text = await fetcher.fetchText('Mishnah Berakhot 1.1');

      expect(text, contains('Bold and italic text'));
      expect(text, isNot(contains('<b>')));
      expect(text, isNot(contains('<span')));
      expect(text, contains('מֵאֵימָתַי'));
    });

    test('fetchText handles nested list text fields', () async {
      mockTextResponse(
        '/api/v3/texts/${Uri.encodeComponent('Mishnah Berakhot 1.1')}',
        {
          'versions': [
            {
              'text': ['First sentence.', 'Second sentence.'],
              'language': 'en',
              'actualLanguage': 'en',
            },
          ],
        },
      );

      final text = await fetcher.fetchText('Mishnah Berakhot 1.1', lang: 'en');

      expect(text, contains('First sentence.'));
      expect(text, contains('Second sentence.'));
    });

    test('fetchText returns empty string when no versions present', () async {
      mockTextResponse(
        '/api/v3/texts/${Uri.encodeComponent('Mishnah Berakhot 1.1')}',
        {'versions': <dynamic>[]},
      );

      final text = await fetcher.fetchText('Mishnah Berakhot 1.1');

      expect(text, isEmpty);
    });

    test('fetchText with lang=en returns only English', () async {
      final textData =
          loadFixture('text_response.json') as Map<String, dynamic>;
      mockTextResponse(
        '/api/v3/texts/${Uri.encodeComponent('Mishnah Berakhot 1.1')}',
        textData,
      );

      final text = await fetcher.fetchText('Mishnah Berakhot 1.1', lang: 'en');

      expect(text, contains('From when may one recite'));
      expect(text, isNot(contains('מֵאֵימָתַי')));
    });

    test('fetchText throws on null response data', () async {
      when(() => mockDio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: null,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/api/v3/texts/test'),
        ),
      );

      expect(
        () => fetcher.fetchText('test'),
        throwsA(isA<SefariaApiException>()),
      );
    });
  });

  group('SefariaFetcherBase - fetchBookShape', () {
    late MishnaBerurahFetcher fetcher;

    setUp(() {
      fetcher = MishnaBerurahFetcher(dio: mockDio);
    });

    test('fetchBookShape extracts map from list wrapper', () async {
      // Sefaria returns book shape as a list containing one map.
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Mishnah Berurah')}',
        [
          {
            'title': 'Mishnah Berurah',
            'chapters': [5, 10],
          },
        ],
      );

      final shape = await fetcher.fetchBookShape('Mishnah Berurah');

      expect(shape['title'], 'Mishnah Berurah');
      expect(shape['chapters'], [5, 10]);
    });

    test('fetchBookShape handles direct map response', () async {
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Mishnah Berurah')}',
        {
          'title': 'Mishnah Berurah',
          'chapters': [5, 10],
        },
      );

      final shape = await fetcher.fetchBookShape('Mishnah Berurah');

      expect(shape['title'], 'Mishnah Berurah');
    });

    test('fetchBookShape throws on unexpected format', () async {
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Mishnah Berurah')}',
        'unexpected string',
      );

      expect(
        () => fetcher.fetchBookShape('Mishnah Berurah'),
        throwsA(isA<SefariaApiException>()),
      );
    });
  });

  group('NachFetcher', () {
    late NachFetcher fetcher;

    setUp(() {
      fetcher = NachFetcher(dio: mockDio);
    });

    test('curriculumId uses CurriculumId.storageKey', () {
      expect(fetcher.curriculumId, CurriculumId.nach.storageKey);
    });

    test('fetchAllContent parses sefer-perek-pasuk correctly', () async {
      // nach_shape.json has Joshua (3 chapters: 18,24,17) and Judges (2 chapters: 36,23)
      // but also Torah books may be in Tanakh shape — Nach filters them out.
      // Our fixture only has Nach books (no Torah).
      mockShapeResponse('/api/shape/Tanakh', loadFixture('nach_shape.json'));

      final result = await fetcher.fetchAllContent();

      expect(result.items, isNotEmpty);
      expect(result.hierarchyConfig.levelLabels, ['Sefer', 'Perek', 'Pasuk']);

      // Joshua: 18+24+17 = 59 verses, Judges: 36+23 = 59 verses → 118 total
      final leaves = result.items.where((i) => i.isLeaf).toList();
      expect(leaves.length, 118);
    });

    test('isLeaf is true only on pasuk items', () async {
      mockShapeResponse('/api/shape/Tanakh', loadFixture('nach_shape.json'));

      final result = await fetcher.fetchAllContent();

      for (final item in result.items.where((i) => i.isLeaf)) {
        expect(item.level3, isNotNull);
      }
    });

    test('populates curriculum_hierarchy_config correctly', () async {
      mockShapeResponse('/api/shape/Tanakh', loadFixture('nach_shape.json'));

      final result = await fetcher.fetchAllContent();

      expect(result.hierarchyConfig.curriculumId, 'nach');
      expect(result.hierarchyConfig.depth, 3);
      expect(result.hierarchyConfig.totalItems, 118);
    });

    test('excludes Torah books from Tanakh shape', () async {
      // Use the tanakh_shape.json which has Torah books (Genesis, Exodus)
      mockShapeResponse('/api/shape/Tanakh', loadFixture('tanakh_shape.json'));

      final result = await fetcher.fetchAllContent();

      // Torah books should be filtered out — no items expected
      expect(result.items, isEmpty);
      expect(result.hierarchyConfig.totalItems, 0);
    });
  });

  group('MussarFetcher', () {
    late MussarFetcher fetcher;

    setUp(() {
      fetcher = MussarFetcher(dio: mockDio);
    });

    test('curriculumId uses CurriculumId.storageKey', () {
      expect(fetcher.curriculumId, CurriculumId.mussar.storageKey);
    });

    test('fetchAllContent parses sefer-section correctly', () async {
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Mesillat Yesharim')}',
        [loadFixture('mussar_shape_mesillat_yesharim.json')],
      );
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Orchot Tzaddikim')}',
        [loadFixture('mussar_shape_orchot_tzaddikim.json')],
      );
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Chovot HaLevavot')}',
        [loadFixture('mussar_shape_chovot_halevavot.json')],
      );

      final result = await fetcher.fetchAllContent();

      expect(result.items, isNotEmpty);
      expect(result.hierarchyConfig.levelLabels, ['Sefer', 'Section']);

      // MY: 3 chapters, OT: 2 chapters, CHL: 3 chapters → 8 total leaves
      final leaves = result.items.where((i) => i.isLeaf).toList();
      expect(leaves.length, 8);
    });

    test('isLeaf is true only on section items', () async {
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Mesillat Yesharim')}',
        [loadFixture('mussar_shape_mesillat_yesharim.json')],
      );
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Orchot Tzaddikim')}',
        [loadFixture('mussar_shape_orchot_tzaddikim.json')],
      );
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Chovot HaLevavot')}',
        [loadFixture('mussar_shape_chovot_halevavot.json')],
      );

      final result = await fetcher.fetchAllContent();

      for (final item in result.items.where((i) => i.isLeaf)) {
        expect(item.level2, isNotNull);
      }

      // Sefer containers should not be leaves
      final containers = result.items.where((i) => !i.isLeaf).toList();
      expect(containers.length, 3); // 3 sefarim
      for (final c in containers) {
        expect(c.level2, isNull);
      }
    });

    test('populates curriculum_hierarchy_config correctly', () async {
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Mesillat Yesharim')}',
        [loadFixture('mussar_shape_mesillat_yesharim.json')],
      );
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Orchot Tzaddikim')}',
        [loadFixture('mussar_shape_orchot_tzaddikim.json')],
      );
      mockShapeResponse(
        '/api/shape/${Uri.encodeComponent('Chovot HaLevavot')}',
        [loadFixture('mussar_shape_chovot_halevavot.json')],
      );

      final result = await fetcher.fetchAllContent();

      expect(result.hierarchyConfig.curriculumId, 'mussar');
      expect(result.hierarchyConfig.depth, 2);
      expect(result.hierarchyConfig.totalItems, 8);
    });
  });

  group('All fetchers cover all 7 curricula', () {
    test('each CurriculumId has a corresponding fetcher', () {
      final fetchers = {
        CurriculumId.mishnayos: MishnaFetcher(dio: mockDio),
        CurriculumId.bavli: BavliFetcher(dio: mockDio),
        CurriculumId.yerushalmi: YerushalmiFetcher(dio: mockDio),
        CurriculumId.mishnaBerurah: MishnaBerurahFetcher(dio: mockDio),
        CurriculumId.chumash: ChumashFetcher(dio: mockDio),
        CurriculumId.nach: NachFetcher(dio: mockDio),
        CurriculumId.mussar: MussarFetcher(dio: mockDio),
      };

      // All 7 curricula with dedicated fetchers.
      expect(fetchers.length, 7);

      // Each fetcher's curriculumId matches its CurriculumId.storageKey.
      for (final entry in fetchers.entries) {
        expect(
          entry.value.curriculumId,
          entry.key.storageKey,
          reason: '${entry.key} fetcher should use ${entry.key.storageKey}',
        );
      }
    });
  });

  group('Seed script JSON schema compatibility', () {
    test(
      'fetcher output contains all fields required by seed script schema',
      () async {
        // Use MishnaFetcher as representative; all fetchers produce ContentItems.
        mockShapeResponse(
          '/api/shape/Mishnah',
          loadFixture('mishnah_shape.json'),
        );

        final result = await MishnaFetcher(dio: mockDio).fetchAllContent();

        // Verify hierarchyConfig has fields that _validateSchema checks.
        expect(result.hierarchyConfig.curriculumId, isNotEmpty);
        expect(result.hierarchyConfig.levelLabels, isNotEmpty);
        expect(result.hierarchyConfig.depth, greaterThan(0));
        expect(result.hierarchyConfig.totalItems, greaterThan(0));

        // Verify items have all required fields that _validateSchema checks.
        final firstLeaf = result.items.firstWhere((i) => i.isLeaf);
        expect(firstLeaf.curriculumId, isNotEmpty);
        expect(firstLeaf.level1, isNotEmpty);
        expect(firstLeaf.displayNameHe, isNotEmpty);
        expect(firstLeaf.displayNameEn, isNotEmpty);
        expect(firstLeaf.sefariaRef, isNotEmpty);
        expect(firstLeaf.sortOrder, greaterThanOrEqualTo(0));
        expect(firstLeaf.isLeaf, isTrue);
      },
    );
  });
}
