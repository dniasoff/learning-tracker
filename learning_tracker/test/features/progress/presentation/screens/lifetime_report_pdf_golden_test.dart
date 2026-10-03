// Story 5.4 (DNI-519) AC-4: the mixed Hebrew/Latin School-years line of
// the exported report ("בית ספר · 210 mishnayos") is drawn in the right
// glyph order, with the digits kept left to right, in an English and in a
// Hebrew report.
//
// The golden is the PDF's drawn glyph order: the extractor places every
// glyph run the PDF paints and reads them left to right, exactly as a
// viewer shows them. ([ASSUMPTION] A rasterized image golden needs a PDF
// rasterizer (pdfium via `printing`), which `flutter test` on the Linux CI
// host does not have; the image check is part of the release device sweep,
// ruling B12.)
@Tags(['progress', 'lifetime', 'story_5_4'])
library;

import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/services/lifetime_report_pdf_composer.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/progress/lifetime_report_fixtures.dart';
import '../../../../helpers/progress/pdf_text_extractor.dart';
import '../../../../helpers/progress/report_pdf_fixtures.dart';

/// One "בית ספר" year of 210 distinct leaves, plus Home.
LifetimeReportView _view() {
  final home = reportTotals(LearningEvent.sourceMain, events: 30, distinct: 25);
  final school = reportTotals(school2026, events: 230, distinct: 210);
  return LifetimeReportView(
    curriculumId: reportCurriculum,
    curricula: const [reportCurriculum],
    report: ReportProjection(
      curriculumId: reportCurriculum,
      distinctLearnt: 235,
      totalEvents: 260,
      sources: {LearningEvent.sourceMain: home, school2026: school},
      groups: [
        ReportGroup(
          key: 'בית ספר',
          name: 'בית ספר',
          members: [schoolYearLine(school2026, 2026, school, name: 'בית ספר')],
        ),
      ],
    ),
  );
}

Future<PdfTextLine> _mixedLine(String locale) async {
  final doc = composeLifetimeReportPdf(
    view: _view(),
    pace: null,
    l10n: lookupAppLocalizations(Locale(locale)),
    localeTag: locale,
    rtl: locale == 'he',
    useHebrewTerms: false,
    variant: TransliterationVariant.ashkenazi,
    learnerName: 'Dovid',
    today: '2026-10-03',
  );
  final pdf = await renderReportPdf(doc);
  return pdf.lines.firstWhere(
    (l) => l.text.contains('210') && l.text.contains('רפס'),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('he');
  });

  test('English report: the Hebrew name reads right to left, then the '
      'count left to right', () async {
    final line = await _mixedLine('en');
    expect(line.text, 'רפס תיב · 210 Mishnayos');
    final digits = line.runs.singleWhere((r) => r.text.contains('210'));
    expect(digits.text, '210');
    // Glyph order on the page: ר … ב, then ·, then 210, then the unit.
    final xs = [
      for (final glyph in ['ר', 'ב', '210', 'Mishnayos'])
        line.runs.firstWhere((r) => r.text.contains(glyph)).x,
    ];
    expect(xs, orderedEquals([...xs]..sort()));
  });

  test('Hebrew report: the line reads from the right; the count stays left '
      'to right', () async {
    final line = await _mixedLine('he');
    expect(line.text, 'Mishnayos 210 · רפס תיב');
    final digits = line.runs.singleWhere((r) => r.text.contains('210'));
    expect(digits.text, '210');
    // Right aligned: the name's first letter (ב) is the rightmost glyph.
    expect(line.runs.last.text, 'ב');
  });
}
