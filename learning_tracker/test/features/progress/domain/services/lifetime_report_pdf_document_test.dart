// Story 5.4 (DNI-519; AD-48): the printable report document is plain
// immutable data; its `strings` getter is what a reader of the PDF sees,
// in reading order.
@Tags(['progress', 'lifetime', 'story_5_4'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_document.dart';

void main() {
  group('LifetimeReportPdfRow', () {
    test('defaults to an unindented body row that may break after', () {
      const row = LifetimeReportPdfRow('Hello');
      expect(row.style, LifetimeReportPdfRowStyle.body);
      expect(row.indent, 0);
      expect(row.keepWithNext, isFalse);
    });

    test('equality and hashCode cover every field', () {
      const a = LifetimeReportPdfRow(
        'x',
        style: LifetimeReportPdfRowStyle.heading,
        indent: 1,
        keepWithNext: true,
      );
      const same = LifetimeReportPdfRow(
        'x',
        style: LifetimeReportPdfRowStyle.heading,
        indent: 1,
        keepWithNext: true,
      );
      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(const LifetimeReportPdfRow('y')));
      expect(
        const LifetimeReportPdfRow('x'),
        isNot(
          const LifetimeReportPdfRow(
            'x',
            style: LifetimeReportPdfRowStyle.warning,
          ),
        ),
      );
      expect(
        const LifetimeReportPdfRow('x'),
        isNot(const LifetimeReportPdfRow('x', indent: 1)),
      );
      expect(
        const LifetimeReportPdfRow('x'),
        isNot(const LifetimeReportPdfRow('x', keepWithNext: true)),
      );
    });

    test('toString names the text, style and indent', () {
      expect(
        const LifetimeReportPdfRow(
          'Total',
          style: LifetimeReportPdfRowStyle.figure,
          indent: 1,
        ).toString(),
        'LifetimeReportPdfRow(Total, figure, 1)',
      );
    });
  });

  group('LifetimeReportPdfSection', () {
    test('title and footnote are optional', () {
      const section = LifetimeReportPdfSection(key: 'totals', rows: []);
      expect(section.title, isNull);
      expect(section.footnote, isNull);
      expect(section.toString(), 'LifetimeReportPdfSection(totals, 0 rows)');
    });
  });

  group('LifetimeReportPdfDocument', () {
    const document = LifetimeReportPdfDocument(
      title: 'Lifetime report',
      learnerName: 'Dovid',
      curriculumName: 'Mishnayos',
      generatedOn: 'Generated on Oct 3, 2026',
      pageLabel: 'Page {page} of {total}',
      sections: [
        LifetimeReportPdfSection(
          key: 'totals',
          rows: [LifetimeReportPdfRow('Distinct · 5 Mishnayos')],
        ),
        LifetimeReportPdfSection(
          key: 'pace',
          title: 'Pace',
          rows: [
            LifetimeReportPdfRow('Home'),
            LifetimeReportPdfRow('2 per week'),
          ],
          footnote: 'Before tracking is excluded',
        ),
      ],
    );

    test('is left to right unless told otherwise', () {
      expect(document.rtl, isFalse);
    });

    test('strings lists header, then each section title, rows and '
        'footnote in reading order, skipping absent titles/notes', () {
      expect(document.strings.toList(), [
        'Lifetime report',
        'Dovid',
        'Mishnayos',
        'Generated on Oct 3, 2026',
        'Distinct · 5 Mishnayos',
        'Pace',
        'Home',
        '2 per week',
        'Before tracking is excluded',
      ]);
    });

    test('a document with no sections yields only the header', () {
      const empty = LifetimeReportPdfDocument(
        title: 't',
        learnerName: 'l',
        curriculumName: 'c',
        generatedOn: 'g',
        pageLabel: 'p',
        sections: [],
      );
      expect(empty.strings.toList(), ['t', 'l', 'c', 'g']);
    });
  });
}
