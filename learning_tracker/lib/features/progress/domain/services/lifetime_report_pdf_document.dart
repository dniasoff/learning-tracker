/// The lifetime report as a printable document (Story 5.4, DNI-519; AD-48).
///
/// A [LifetimeReportPdfDocument] is the report screen's content reduced to
/// the strings it shows, already localized and formatted: the learner,
/// the curriculum, the generated-on date and one [LifetimeReportPdfSection]
/// per section the screen renders. It is built from the same report
/// projection as the screen (`LearnerState.report`, via the report and
/// pace views), so every number in it is the screen's number; the PDF
/// builder only lays it out and counts nothing.
///
/// It is plain immutable data (strings, ints and bools) so it can be sent
/// to the isolate that renders the PDF.
library;

/// How a row of the document is set.
enum LifetimeReportPdfRowStyle {
  /// A plain line.
  body,

  /// A headline figure ("Distinct · 1,204 Mishnayos").
  figure,

  /// A group or source heading ("School · 640 Mishnayos").
  heading,

  /// A secondary line under a heading (a year, a trailing pace).
  detail,

  /// A warning line (a shortfall, a calendar backlog).
  warning,
}

/// One line of a section. A row is never split across pages.
final class LifetimeReportPdfRow {
  /// Creates the row.
  const LifetimeReportPdfRow(
    this.text, {
    this.style = LifetimeReportPdfRowStyle.body,
    this.indent = 0,
    this.keepWithNext = false,
  });

  /// The text, in logical order.
  final String text;

  /// How the row is set.
  final LifetimeReportPdfRowStyle style;

  /// The nesting level (0 or 1): a School-year line under its group.
  final int indent;

  /// Whether a page break must not fall right after this row (a heading
  /// and its first line stay together).
  final bool keepWithNext;

  @override
  bool operator ==(Object other) =>
      other is LifetimeReportPdfRow &&
      other.text == text &&
      other.style == style &&
      other.indent == indent &&
      other.keepWithNext == keepWithNext;

  @override
  int get hashCode => Object.hash(text, style, indent, keepWithNext);

  @override
  String toString() => 'LifetimeReportPdfRow($text, ${style.name}, $indent)';
}

/// One report section: its title (repeated on every page it continues
/// onto), its rows and an optional footnote.
final class LifetimeReportPdfSection {
  /// Creates the section.
  const LifetimeReportPdfSection({
    required this.key,
    required this.rows,
    this.title,
    this.footnote,
  });

  /// A stable id ("totals", "onTrack", "pace", "bySource", "schoolYears").
  final String key;

  /// The section title; null for the headline totals.
  final String? title;

  /// The rows, in screen order.
  final List<LifetimeReportPdfRow> rows;

  /// A note printed after the rows (the before-tracking footnote).
  final String? footnote;

  @override
  String toString() => 'LifetimeReportPdfSection($key, ${rows.length} rows)';
}

/// The whole document.
final class LifetimeReportPdfDocument {
  /// Creates the document.
  const LifetimeReportPdfDocument({
    required this.title,
    required this.learnerName,
    required this.curriculumName,
    required this.generatedOn,
    required this.sections,
    required this.pageLabel,
    this.rtl = false,
  });

  /// The report title ("Lifetime report").
  final String title;

  /// The learner's display name.
  final String learnerName;

  /// The curriculum's display name, following the Hebrew-terms setting.
  final String curriculumName;

  /// The localized generated-on line ("Generated on Oct 3, 2026"), dated
  /// in the learner's time zone.
  final String generatedOn;

  /// The sections, in screen order.
  final List<LifetimeReportPdfSection> sections;

  /// The page-number label with `{page}` and `{total}` placeholders
  /// ("Page {page} of {total}").
  final String pageLabel;

  /// Whether the document reads right to left (a Hebrew UI).
  final bool rtl;

  /// Every string of the document, in reading order: what a reader of the
  /// PDF sees.
  Iterable<String> get strings sync* {
    yield title;
    yield learnerName;
    yield curriculumName;
    yield generatedOn;
    for (final section in sections) {
      if (section.title case final title?) yield title;
      for (final row in section.rows) {
        yield row.text;
      }
      if (section.footnote case final note?) yield note;
    }
  }
}
