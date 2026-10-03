/// Lays the lifetime report out as a PDF (Story 5.4, DNI-519; AD-48,
/// CAP-12).
///
/// [buildLifetimeReportPdf] turns a [LifetimeReportPdfDocument] (the
/// screen's strings, built from the same `LearnerState` report projection)
/// into PDF bytes with the `pdf` package. It reads nothing and counts
/// nothing: every figure is already in the document. It is a pure
/// top-level function over sendable data, so the export runs it on a
/// background isolate (AC-7).
///
/// Text rules (AD-48):
///
/// * Fonts are the app's bundled faces, embedded as subsets: Inter for
///   Latin text and digits, Noto Sans Hebrew for Hebrew, each with its
///   bold weight ([LifetimeReportPdfFonts]). No text falls back to a
///   standard PDF font (AC-3).
/// * The `pdf` package has no GSUB/GPOS shaping, so every Hebrew point and
///   cantillation mark, U+0591–U+05C7, is removed first
///   ([stripHebrewMarks], AC-4).
/// * `pdf` only reorders bidirectional text inside a right-to-left
///   paragraph, and only within one font run. So each paragraph is broken
///   into lines here (measured with the embedded fonts), and each line is
///   reordered to visual order with the Unicode bidi algorithm before it
///   is drawn left to right: a Hebrew run reads right to left and digits
///   stay left to right in either document direction (AC-4).
///
/// Layout: every row is one table row, which `pdf` never splits across a
/// page; a section's title row repeats at the top of every page the
/// section continues onto, and every page carries "Page n of N" (AC-7).
library;

import 'dart:typed_data';

import 'package:bidi/bidi.dart' as bidi;
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_document.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The first Hebrew point or cantillation code point AD-48 strips.
const int hebrewMarksFirst = 0x0591;

/// The last Hebrew point or cantillation code point AD-48 strips.
const int hebrewMarksLast = 0x05C7;

/// The Hebrew maqaf (U+05BE): a word-joining hyphen inside the stripped
/// range. It becomes a hyphen-minus so joined words stay joined.
const int _maqaf = 0x05BE;

/// Sof pasuq (U+05C3): a verse-ending colon inside the stripped range. It
/// becomes a colon.
const int _sofPasuq = 0x05C3;

/// [text] without any code point in U+0591–U+05C7 (AD-48): points (nikud)
/// and cantillation marks (te'amim) are removed; the maqaf and sof pasuq
/// punctuation in that range become "-" and ":" so the words around them
/// keep their meaning.
String stripHebrewMarks(String text) {
  var found = false;
  for (final rune in text.runes) {
    if (rune >= hebrewMarksFirst && rune <= hebrewMarksLast) {
      found = true;
      break;
    }
  }
  if (!found) return text;
  final out = StringBuffer();
  for (final rune in text.runes) {
    if (rune < hebrewMarksFirst || rune > hebrewMarksLast) {
      out.writeCharCode(rune);
    } else if (rune == _maqaf) {
      out.write('-');
    } else if (rune == _sofPasuq) {
      out.write(':');
    }
  }
  return out.toString();
}

/// Whether [rune] is a right-to-left letter (Hebrew block or Hebrew
/// presentation forms).
bool _isRtlRune(int rune) =>
    (rune >= 0x0590 && rune <= 0x05FF) || (rune >= 0xFB1D && rune <= 0xFB4F);

/// Left-to-right mark: forces a left-to-right paragraph.
const int _lrm = 0x200E;

/// Right-to-left mark: forces a right-to-left paragraph.
const int _rlm = 0x200F;

/// The directional marks and embedding controls the bidi algorithm
/// consumes; never drawn.
final RegExp _directionMarks = RegExp('[\u200E\u200F\u202A-\u202E]');

/// [line] (one line, logical order) in visual left-to-right order, for a
/// paragraph whose base direction is right to left when [rtl] (the Unicode
/// bidi algorithm, with the base direction forced rather than guessed from
/// the first letter).
///
/// A line with no right-to-left letter in a left-to-right paragraph is
/// returned unchanged.
String visualOrder(String line, {required bool rtl}) {
  if (line.isEmpty) return line;
  if (!rtl && !line.runes.any(_isRtlRune)) {
    return line.replaceAll(_directionMarks, '');
  }
  final marked = String.fromCharCode(rtl ? _rlm : _lrm) + line;
  final out = StringBuffer();
  for (final paragraph in bidi.BidiString.fromLogical(marked).paragraphs) {
    final visual = paragraph.bidiText;
    final end = paragraph.separator == visual.lastOrNull
        ? visual.length - 1
        : visual.length;
    out.write(String.fromCharCodes(visual, 0, end));
  }
  return out.toString();
}

/// [text] (a name the learner typed, in any script) closed with the
/// document direction's mark, so a Hebrew name in a left-to-right line (or
/// a Latin one in a right-to-left line) never pulls the figures after it
/// into its own direction: "בית ספר · 210 mishnayos" keeps the name first
/// and "210" after it.
String closeDirection(String text, {required bool rtl}) =>
    '$text${String.fromCharCode(rtl ? _rlm : _lrm)}';

/// [text] embedded left to right in any paragraph: a year or date range
/// ("2024–25") reads left to right in a Hebrew report too, as on screen.
String leftToRight(String text) => '\u202A$text\u202C';

/// The font files the PDF embeds: the app's bundled Latin and Hebrew
/// faces (`assets/fonts/`), regular and bold. Plain bytes, so they can be
/// sent to the rendering isolate.
final class LifetimeReportPdfFonts {
  /// Creates the font set.
  const LifetimeReportPdfFonts({
    required this.latinRegular,
    required this.latinBold,
    required this.hebrewRegular,
    required this.hebrewBold,
  });

  /// The Latin regular face (Inter Regular).
  final Uint8List latinRegular;

  /// The Latin bold face (Inter Bold).
  final Uint8List latinBold;

  /// The Hebrew regular face (Noto Sans Hebrew Regular).
  final Uint8List hebrewRegular;

  /// The Hebrew bold face (Noto Sans Hebrew Bold).
  final Uint8List hebrewBold;

  /// The asset paths of the four faces, in constructor order.
  ///
  /// The bundled Inter files are named one weight off their contents
  /// (`Inter-Regular.ttf` holds Inter Light, `Inter-Bold.ttf` Inter
  /// SemiBold); the faces are picked by what the files hold, Inter Regular
  /// (400) and Inter Bold (700). The font-inspection test pins the
  /// embedded PostScript names, so a later rename fails it loudly.
  static const assetPaths = (
    latinRegular: 'assets/fonts/Inter-Medium.ttf',
    latinBold: 'assets/fonts/Inter-ExtraBold.ttf',
    hebrewRegular: 'assets/fonts/NotoSansHebrew-Regular.ttf',
    hebrewBold: 'assets/fonts/NotoSansHebrew-Bold.ttf',
  );
}

/// The page size: A4 with 40 pt margins.
final PdfPageFormat _pageFormat = PdfPageFormat.a4.copyWith(
  marginLeft: 40,
  marginRight: 40,
  marginTop: 40,
  marginBottom: 40,
);

const PdfColor _ink = PdfColor.fromInt(0xFF1B2A3A);
const PdfColor _ink2 = PdfColor.fromInt(0xFF4A5868);
const PdfColor _outline = PdfColor.fromInt(0xFFD9DEE5);
const PdfColor _warning = PdfColor.fromInt(0xFF8A5300);

/// Indent of a nested row (a School-year line under its group), in pt.
const double _indentStep = 18;

/// The lifetime report [document] as PDF bytes, set in [fonts].
///
/// [compress] false writes uncompressed streams (tests read the text
/// back). Throws when the layout cannot be produced (for example a font
/// that does not parse); the caller treats any throw as a failed export.
Future<Uint8List> buildLifetimeReportPdf(
  LifetimeReportPdfDocument document,
  LifetimeReportPdfFonts fonts, {
  bool compress = true,
}) async {
  final faces = _Faces(
    latin: pw.Font.ttf(ByteData.sublistView(fonts.latinRegular)),
    latinBold: pw.Font.ttf(ByteData.sublistView(fonts.latinBold)),
    hebrew: pw.Font.ttf(ByteData.sublistView(fonts.hebrewRegular)),
    hebrewBold: pw.Font.ttf(ByteData.sublistView(fonts.hebrewBold)),
  );
  final rtl = document.rtl;
  String clean(String s) => stripHebrewMarks(s);

  final pdf = pw.Document(
    compress: compress,
    title: clean('${document.title} · ${document.learnerName}'),
    subject: clean(document.curriculumName),
    creator: 'Learning Tracker',
    theme: pw.ThemeData.withFont(
      base: faces.latin,
      bold: faces.latinBold,
      fontFallback: [faces.hebrew],
    ),
  );

  pw.Widget text(
    String value,
    _Style style, {
    double indent = 0,
    pw.EdgeInsets padding = pw.EdgeInsets.zero,
  }) => pw.Padding(
    padding:
        padding +
        (rtl
            ? pw.EdgeInsets.only(right: indent)
            : pw.EdgeInsets.only(left: indent)),
    child: _BidiParagraph(
      text: clean(value),
      style: style.textStyle(faces),
      faces: faces,
      bold: style.bold,
      rtl: rtl,
    ),
  );

  pw.TableRow row(List<pw.Widget> lines, {bool repeat = false}) => pw.TableRow(
    repeat: repeat,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: lines,
      ),
    ],
  );

  pw.Widget rowWidget(LifetimeReportPdfRow r) => text(
    r.text,
    _Style.of(r.style),
    indent: r.indent * _indentStep,
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
  );

  pw.Widget section(LifetimeReportPdfSection s) {
    final rows = <pw.TableRow>[
      if (s.title case final title?)
        row([
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
            margin: const pw.EdgeInsets.only(bottom: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _outline)),
            ),
            child: text(title, _Style.sectionTitle),
          ),
        ], repeat: true),
    ];
    // A row marked keep-with-next shares one table row with the next, so
    // a page break never falls between a heading and its first line.
    final pending = <pw.Widget>[];
    for (final r in s.rows) {
      pending.add(rowWidget(r));
      if (r.keepWithNext) continue;
      rows.add(row([...pending]));
      pending.clear();
    }
    if (pending.isNotEmpty) rows.add(row([...pending]));
    if (s.footnote case final note?) {
      rows.add(
        row([
          text(note, _Style.detail, padding: const pw.EdgeInsets.only(top: 6)),
        ]),
      );
    }
    return pw.Table(
      columnWidths: const {0: pw.FlexColumnWidth()},
      children: rows,
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: _pageFormat,
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      maxPages: 500,
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              child: text(
                '${document.title} · ${document.learnerName} · '
                '${document.curriculumName}',
                _Style.detail,
              ),
            ),
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        alignment: pw.Alignment.center,
        child: pw.Text(
          clean(
            document.pageLabel
                .replaceAll('{page}', '${context.pageNumber}')
                .replaceAll('{total}', '${context.pagesCount}'),
          ),
          style: _Style.detail.textStyle(faces),
          textDirection: pw.TextDirection.ltr,
        ),
      ),
      build: (context) => [
        text(document.title, _Style.title),
        pw.SizedBox(height: 4),
        text(document.learnerName, _Style.heading),
        text(document.curriculumName, _Style.body),
        text(document.generatedOn, _Style.detail),
        pw.SizedBox(height: 14),
        for (final (i, s) in document.sections.indexed) ...[
          if (i > 0) pw.SizedBox(height: 14),
          section(s),
        ],
      ],
    ),
  );
  return pdf.save();
}

/// The four embedded faces.
final class _Faces {
  const _Faces({
    required this.latin,
    required this.latinBold,
    required this.hebrew,
    required this.hebrewBold,
  });

  final pw.Font latin;
  final pw.Font latinBold;
  final pw.Font hebrew;
  final pw.Font hebrewBold;
}

/// A text style of the report.
enum _Style {
  title(20, bold: true),
  sectionTitle(13, bold: true),
  heading(11.5, bold: true),
  figure(13, bold: true),
  body(10.5),
  detail(9.5, color: _ink2),
  warning(10.5, color: _warning);

  const _Style(this.size, {this.bold = false, this.color = _ink});

  final double size;
  final bool bold;
  final PdfColor color;

  static _Style of(LifetimeReportPdfRowStyle style) => switch (style) {
    LifetimeReportPdfRowStyle.body => body,
    LifetimeReportPdfRowStyle.figure => figure,
    LifetimeReportPdfRowStyle.heading => heading,
    LifetimeReportPdfRowStyle.detail => detail,
    LifetimeReportPdfRowStyle.warning => warning,
  };

  pw.TextStyle textStyle(_Faces faces) => pw.TextStyle(
    font: bold ? faces.latinBold : faces.latin,
    fontBold: faces.latinBold,
    fontNormal: faces.latin,
    fontFallback: [if (bold) faces.hebrewBold else faces.hebrew],
    fontSize: size,
    color: color,
    lineSpacing: 2,
  );
}

/// A paragraph broken into lines by the embedded fonts' metrics, each line
/// drawn in visual order, aligned to the document's start edge.
class _BidiParagraph extends pw.StatelessWidget {
  _BidiParagraph({
    required this.text,
    required this.style,
    required this.faces,
    required this.bold,
    required this.rtl,
  });

  final String text;
  final pw.TextStyle style;
  final _Faces faces;
  final bool bold;
  final bool rtl;

  @override
  pw.Widget build(pw.Context context) => pw.LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints?.maxWidth ?? double.infinity;
      final lines = _breakLines(context, width);
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            pw.Align(
              alignment: rtl
                  ? pw.Alignment.centerRight
                  : pw.Alignment.centerLeft,
              child: pw.Text(
                visualOrder(line, rtl: rtl),
                style: style,
                textDirection: pw.TextDirection.ltr,
                textAlign: rtl ? pw.TextAlign.right : pw.TextAlign.left,
              ),
            ),
        ],
      );
    },
  );

  /// [text] split into logical lines no wider than [width].
  List<String> _breakLines(pw.Context context, double width) {
    if (!width.isFinite) return [text];
    final latin = (bold ? faces.latinBold : faces.latin).getFont(context);
    final hebrew = (bold ? faces.hebrewBold : faces.hebrew).getFont(context);
    final size = style.fontSize ?? 10;
    double measure(String s) {
      var em = 0.0;
      for (final rune in s.runes) {
        final font = latin.isRuneSupported(rune) ? latin : hebrew;
        em += font.stringMetrics(String.fromCharCode(rune)).advanceWidth;
      }
      return em * size;
    }

    // A little slack, so a line measured to fit is not wrapped again.
    final limit = width * 0.98;
    final space = measure(' ');
    final lines = <String>[];
    var current = StringBuffer();
    var currentWidth = 0.0;
    for (final word in text.split(' ')) {
      final w = measure(word);
      if (current.isEmpty) {
        current.write(word);
        currentWidth = w;
      } else if (currentWidth + space + w <= limit) {
        current
          ..write(' ')
          ..write(word);
        currentWidth += space + w;
      } else {
        lines.add(current.toString());
        current = StringBuffer(word);
        currentWidth = w;
      }
    }
    lines.add(current.toString());
    return lines;
  }
}
