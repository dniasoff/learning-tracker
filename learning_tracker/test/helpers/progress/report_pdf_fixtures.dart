/// Fonts and helpers for the Story 5.4 (DNI-519) report PDF tests.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_builder.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_document.dart';

import 'pdf_text_extractor.dart';

/// The app's bundled faces, read from `assets/fonts/` (tests run from the
/// package root), exactly as the export loads them from the asset bundle.
LifetimeReportPdfFonts reportPdfFonts() {
  const paths = LifetimeReportPdfFonts.assetPaths;
  Uint8List read(String path) => File(path).readAsBytesSync();
  return LifetimeReportPdfFonts(
    latinRegular: read(paths.latinRegular),
    latinBold: read(paths.latinBold),
    hebrewRegular: read(paths.hebrewRegular),
    hebrewBold: read(paths.hebrewBold),
  );
}

/// Builds [document] uncompressed and reads it back.
Future<PdfTextDocument> renderReportPdf(
  LifetimeReportPdfDocument document,
) async => PdfTextDocument.parse(
  await buildLifetimeReportPdf(document, reportPdfFonts(), compress: false),
);

/// A one-section document holding [rows].
LifetimeReportPdfDocument reportPdfDocument({
  List<LifetimeReportPdfRow> rows = const [],
  List<LifetimeReportPdfSection>? sections,
  bool rtl = false,
  String title = 'Lifetime report',
  String learnerName = 'Dovid',
  String curriculumName = 'Mishnayos',
  String generatedOn = 'Generated on Oct 3, 2026',
}) => LifetimeReportPdfDocument(
  title: title,
  learnerName: learnerName,
  curriculumName: curriculumName,
  generatedOn: generatedOn,
  pageLabel: 'Page {page} of {total}',
  rtl: rtl,
  sections:
      sections ??
      [LifetimeReportPdfSection(key: 'rows', title: 'Rows', rows: rows)],
);
