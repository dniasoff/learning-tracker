// Tests for TextContent/TextSegment — the domain models moved out of
// text_cache_repository.dart (AUD-content_browsing-04). Covers the
// TextContent.single factory and the hebrewText/englishText join-and-filter
// getters, which carry real behavior (not plain field holders).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/content_browsing/domain/entities/text_content.dart';

void main() {
  group('TextSegment', () {
    test('stores all provided fields, including number', () {
      final segment = TextSegment(
        sefariaRef: 'Genesis 1:5',
        hebrewText: 'בְּרֵאשִׁית',
        englishText: 'In the beginning',
        number: 5,
      );

      expect(segment.sefariaRef, 'Genesis 1:5');
      expect(segment.hebrewText, 'בְּרֵאשִׁית');
      expect(segment.englishText, 'In the beginning');
      expect(segment.number, 5);
    });

    test('number defaults to null when not provided', () {
      final segment = TextSegment(
        sefariaRef: 'Berakhot 2a',
        hebrewText: 'הֵבֵאשִׁית',
        englishText: 'text',
      );

      expect(segment.number, isNull);
    });
  });

  group('TextContent.single', () {
    test('creates a single-segment TextContent from flat hebrew/english', () {
      final content = TextContent.single(
        sefariaRef: 'Berakhot 2a',
        hebrewText: 'טקסט עברי',
        englishText: 'English text',
      );

      expect(content.sefariaRef, 'Berakhot 2a');
      expect(content.segments, hasLength(1));
      expect(content.segments.single.sefariaRef, 'Berakhot 2a');
      expect(content.segments.single.hebrewText, 'טקסט עברי');
      expect(content.segments.single.englishText, 'English text');
      expect(content.segments.single.number, isNull);
    });
  });

  group('TextContent.hebrewText', () {
    test('joins multiple segments with a newline', () {
      final content = TextContent(
        sefariaRef: 'Pirkei Avot 1',
        segments: [
          TextSegment(
            sefariaRef: 'Pirkei Avot 1:1',
            hebrewText: 'משה קיבל תורה',
            englishText: 'Moses received',
            number: 1,
          ),
          TextSegment(
            sefariaRef: 'Pirkei Avot 1:2',
            hebrewText: 'שמעון הצדיק',
            englishText: 'Shimon HaTzadik',
            number: 2,
          ),
        ],
      );

      expect(content.hebrewText, 'משה קיבל תורה\nשמעון הצדיק');
    });

    test('filters out segments with empty hebrewText', () {
      final content = TextContent(
        sefariaRef: 'Pirkei Avot 1',
        segments: [
          TextSegment(
            sefariaRef: 'Pirkei Avot 1:1',
            hebrewText: 'משה קיבל תורה',
            englishText: 'Moses received',
          ),
          TextSegment(
            sefariaRef: 'Pirkei Avot 1:2',
            hebrewText: '',
            englishText: 'no hebrew here',
          ),
        ],
      );

      expect(content.hebrewText, 'משה קיבל תורה');
    });

    test('returns an empty string when every segment has empty hebrewText', () {
      final content = TextContent(
        sefariaRef: 'ref',
        segments: [
          TextSegment(sefariaRef: 'ref:1', hebrewText: '', englishText: 'a'),
          TextSegment(sefariaRef: 'ref:2', hebrewText: '', englishText: 'b'),
        ],
      );

      expect(content.hebrewText, '');
    });
  });

  group('TextContent.englishText', () {
    test('joins multiple segments with a newline', () {
      final content = TextContent(
        sefariaRef: 'Pirkei Avot 1',
        segments: [
          TextSegment(
            sefariaRef: 'Pirkei Avot 1:1',
            hebrewText: 'א',
            englishText: 'Moses received',
          ),
          TextSegment(
            sefariaRef: 'Pirkei Avot 1:2',
            hebrewText: 'ב',
            englishText: 'Shimon HaTzadik',
          ),
        ],
      );

      expect(content.englishText, 'Moses received\nShimon HaTzadik');
    });

    test('filters out segments with empty englishText', () {
      final content = TextContent(
        sefariaRef: 'Pirkei Avot 1',
        segments: [
          TextSegment(
            sefariaRef: 'Pirkei Avot 1:1',
            hebrewText: 'א',
            englishText: 'Moses received',
          ),
          TextSegment(
            sefariaRef: 'Pirkei Avot 1:2',
            hebrewText: 'ב',
            englishText: '',
          ),
        ],
      );

      expect(content.englishText, 'Moses received');
    });
  });
}
