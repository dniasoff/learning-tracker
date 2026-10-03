// Story 5.4 (DNI-519): the report PDF builder lays out the document it is
// given, in embedded font subsets, with unpointed Hebrew in visual order,
// across pages without splitting a row (AC-3, AC-4, AC-7; AD-48).
//
// The PDF is written uncompressed and read back with the test extractor,
// which maps every drawn glyph run to Unicode through the embedded
// fonts' ToUnicode CMaps and places it on the page.
@Tags(['progress', 'lifetime', 'story_5_4'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_builder.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_document.dart';

import '../../../../helpers/progress/report_pdf_fixtures.dart';

/// Pointed and cantillated Hebrew: every kind of mark in U+0591–U+05C7.
const _pointed = 'בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים בֵּית־הַמִּקְדָּשׁ׃';

bool _isMark(int rune) => rune >= 0x0591 && rune <= 0x05C7;

void main() {
  group('stripHebrewMarks (AD-48)', () {
    test('removes every point and cantillation mark', () {
      final stripped = stripHebrewMarks(_pointed);
      expect(stripped.runes.where(_isMark), isEmpty);
      expect(stripped, 'בראשית ברא אלהים בית-המקדש:');
    });

    test('every code point in U+0591–U+05C7 is gone', () {
      final all = String.fromCharCodes([
        for (var r = 0x0591; r <= 0x05C7; r++) r,
      ]);
      expect(stripHebrewMarks('א$allב').runes.where(_isMark), isEmpty);
    });

    test('leaves unpointed Hebrew and Latin text unchanged', () {
      const plain = 'בית ספר · 210 mishnayos';
      expect(identical(stripHebrewMarks(plain), plain), isTrue);
    });
  });

  group('visualOrder (AC-4)', () {
    test('left-to-right line: the Hebrew run reverses, digits stay', () {
      expect(
        visualOrder(
          '${closeDirection('בית ספר', rtl: false)} · 210 mishnayos',
          rtl: false,
        ),
        'רפס תיב · 210 mishnayos',
      );
    });

    test('right-to-left line: the line reads from the right, digits stay '
        'left to right', () {
      expect(
        visualOrder('בית ספר · 210 משניות', rtl: true),
        'תוינשמ 210 · רפס תיב',
      );
    });

    test('a year range stays left to right in a right-to-left line', () {
      expect(
        visualOrder('${leftToRight('2024–25')} · הסתיים', rtl: true),
        'םייתסה · 2024–25',
      );
    });

    test('direction marks are never drawn', () {
      expect(
        visualOrder(closeDirection('Home', rtl: false), rtl: false),
        'Home',
      );
    });
  });

  group('AC-3 embedded font subsets', () {
    test('Inter and Noto Sans Hebrew are embedded as subsets; no standard '
        'font is used', () async {
      final pdf = await renderReportPdf(
        reportPdfDocument(
          rows: const [
            LifetimeReportPdfRow(
              'בית ספר · 210 mishnayos',
              style: LifetimeReportPdfRowStyle.heading,
            ),
            LifetimeReportPdfRow('בית ספר · 1,204 mishnayos'),
          ],
        ),
      );
      final fonts = {for (final f in pdf.fonts) f.baseFont: f};
      expect(
        fonts.keys,
        unorderedEquals([
          'Inter-Regular',
          'Inter-Bold',
          'NotoSansHebrew-Regular',
          'NotoSansHebrew-Bold',
        ]),
      );
      const paths = LifetimeReportPdfFonts.assetPaths;
      final sources = {
        'Inter-Regular': paths.latinRegular,
        'Inter-Bold': paths.latinBold,
        'NotoSansHebrew-Regular': paths.hebrewRegular,
        'NotoSansHebrew-Bold': paths.hebrewBold,
      };
      for (final MapEntry(:key, :value) in fonts.entries) {
        expect(value.subtype, '/Type0', reason: key);
        // Embedded, and smaller than the bundled file: a glyph subset.
        expect(value.embeddedLength, isNotNull, reason: key);
        expect(
          value.embeddedLength,
          lessThan(File(sources[key]!).lengthSync()),
          reason: key,
        );
      }
      // Every drawn run is set in one of the embedded faces.
      expect(
        pdf.lines.expand((l) => l.runs).map((r) => r.font).toSet(),
        everyElement(isIn(sources.keys)),
      );
    });
  });

  group('AC-4 Hebrew text', () {
    test('no point or cantillation code point reaches the PDF, from any '
        'field', () async {
      final pdf = await renderReportPdf(
        reportPdfDocument(
          title: _pointed,
          learnerName: _pointed,
          curriculumName: _pointed,
          generatedOn: _pointed,
          sections: const [
            LifetimeReportPdfSection(
              key: 'x',
              title: _pointed,
              rows: [LifetimeReportPdfRow(_pointed)],
              footnote: _pointed,
            ),
          ],
        ),
      );
      expect(pdf.text.runes.where(_isMark), isEmpty);
      // Drawn in visual order: "בית-המקדש" reads right to left.
      expect(pdf.text, contains('שדקמה-תיב'));
    });

    test('a mixed line is drawn in visual order with the digits left to '
        'right (English report)', () async {
      final pdf = await renderReportPdf(
        reportPdfDocument(
          rows: [
            LifetimeReportPdfRow(
              '${closeDirection('בית ספר', rtl: false)} · 210 mishnayos',
              style: LifetimeReportPdfRowStyle.heading,
            ),
          ],
        ),
      );
      final line = pdf.lines.firstWhere((l) => l.text.contains('210'));
      expect(line.text, 'רפס תיב · 210 mishnayos');
      // The number is one left-to-right run, left of the Latin unit.
      final digits = line.runs.firstWhere((r) => r.text.contains('210'));
      final unit = line.runs.firstWhere((r) => r.text == 'mishnayos');
      expect(digits.text, '210');
      expect(digits.x, lessThan(unit.x));
    });

    test('a Hebrew report is right aligned and reads from the right', () async {
      final pdf = await renderReportPdf(
        reportPdfDocument(
          rtl: true,
          rows: const [LifetimeReportPdfRow('בית ספר · 210 משניות')],
        ),
      );
      final line = pdf.lines.firstWhere((l) => l.text.contains('210'));
      expect(line.text, 'תוינשמ 210 · רפס תיב');
      final title = pdf.lines.firstWhere((l) => l.text == 'Rows');
      // Right aligned: the line ends near the right margin (595 - 40).
      final end = title.runs.last.x + title.runs.last.width;
      expect(end, closeTo(555.3, 1.5));
    });

    test('a long Hebrew line wraps with its logical start on the first '
        'line', () async {
      final words = [for (var i = 1; i <= 40; i++) 'מילה$i'];
      final pdf = await renderReportPdf(
        reportPdfDocument(
          rtl: true,
          rows: [LifetimeReportPdfRow(words.join(' '))],
        ),
      );
      final lines = pdf.lines.where((l) => l.text.contains('הלימ')).toList();
      expect(lines.length, greaterThan(1));
      // Visual order: the first word is the rightmost of the first line.
      expect(lines.first.text.endsWith(' 1הלימ'), isTrue);
      expect(lines.last.text, contains('40הלימ'));
    });
  });

  group('AC-7 pagination', () {
    LifetimeReportPdfDocument large() => reportPdfDocument(
      sections: [
        const LifetimeReportPdfSection(
          key: 'totals',
          rows: [
            LifetimeReportPdfRow(
              'Distinct · 1,204 Mishnayos',
              style: LifetimeReportPdfRowStyle.figure,
            ),
          ],
        ),
        LifetimeReportPdfSection(
          key: 'schoolYears',
          title: 'School years',
          rows: [
            for (var g = 0; g < 30; g++) ...[
              LifetimeReportPdfRow(
                'Group $g · ${g * 10} mishnayos',
                style: LifetimeReportPdfRowStyle.heading,
                keepWithNext: true,
              ),
              for (var y = 0; y < 4; y++)
                LifetimeReportPdfRow(
                  '${2000 + y}–${y + 1} · Ended · line $g-$y '
                  '${'of a row long enough to wrap ' * 4}tail-$g-$y',
                  indent: 1,
                ),
            ],
          ],
        ),
      ],
    );

    test('flows across pages with the section title repeated and page '
        'numbers on every page', () async {
      final pdf = await renderReportPdf(large());
      final pages = pdf.pages;
      expect(pages.length, greaterThan(2));
      for (final (i, page) in pages.indexed) {
        final texts = page.map((l) => l.text).toList();
        expect(texts.last, 'Page ${i + 1} of ${pages.length}');
        if (i > 0) {
          expect(texts.first, 'Lifetime report · Dovid · Mishnayos');
          expect(texts[1], 'School years');
        }
      }
    });

    test('no row is split across pages, and a group heading stays with its '
        'first line', () async {
      final pdf = await renderReportPdf(large());
      for (var g = 0; g < 30; g++) {
        for (var y = 0; y < 4; y++) {
          int pageOf(String text) =>
              pdf.pages.indexWhere((p) => p.any((l) => l.text.contains(text)));
          final head = pdf.lines.firstWhere(
            (l) => l.text.contains('line $g-$y '),
          );
          // The row wraps, and its last line is on the same page.
          expect(head.text, isNot(contains('tail-$g-$y')));
          expect(pageOf('tail-$g-$y'), pageOf('line $g-$y '), reason: '$g-$y');
        }
        final heading = pdf.pages.indexWhere(
          (p) => p.any((l) => l.text == 'Group $g · ${g * 10} mishnayos'),
        );
        final first = pdf.pages.indexWhere(
          (p) => p.any((l) => l.text.contains('line $g-0 ')),
        );
        expect(heading, first, reason: 'group $g');
      }
    });
  });
}
