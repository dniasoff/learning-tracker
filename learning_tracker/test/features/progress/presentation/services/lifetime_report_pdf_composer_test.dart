// Story 5.4 (DNI-519; AD-48, CAP-12): the composer writes the screen's
// strings and numbers into the printable document, counting nothing.
@Tags(['progress', 'lifetime', 'story_5_4'])
library;

import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_document.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/providers/pace_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/services/lifetime_report_pdf_composer.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/progress/lifetime_report_fixtures.dart';
import '../../../../helpers/progress/pace_report_fixtures.dart';

LifetimeReportView _view(ReportProjection report, {String? key}) =>
    LifetimeReportView(
      curriculumId: key ?? report.curriculumId,
      curricula: [key ?? report.curriculumId],
      report: report,
    );

PaceReportView? _pace(LifetimeReportView view, {ProjectionStatus? status}) =>
    PaceReportView.of(
      view,
      paceCurriculumState(
        view.report,
        projection: paceProjection(status ?? ProjectionStatus.onTrack),
        subTracks: const {
          school2026: paceSchoolShortfall,
          rebbeId: paceRebbeNoShortfall,
        },
      ),
    );

LifetimeReportPdfDocument _compose(
  LifetimeReportView view, {
  PaceReportView? pace,
  String locale = 'en',
  bool useHebrewTerms = false,
  String learnerName = ' Dovid ',
}) => composeLifetimeReportPdf(
  view: view,
  pace: pace,
  l10n: lookupAppLocalizations(Locale(locale)),
  localeTag: locale,
  rtl: locale == 'he',
  useHebrewTerms: useHebrewTerms,
  variant: TransliterationVariant.ashkenazi,
  learnerName: learnerName,
  today: '2026-10-03',
);

LifetimeReportPdfSection _section(LifetimeReportPdfDocument d, String key) =>
    d.sections.singleWhere((s) => s.key == key);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('he');
  });

  group('header', () {
    test('carries the learner (trimmed), curriculum, date and page label', () {
      final doc = _compose(_view(fullReport()));
      expect(doc.title, 'Lifetime report');
      expect(doc.learnerName, 'Dovid');
      expect(doc.curriculumName, 'Mishnayos');
      expect(doc.generatedOn, 'Generated on Oct 3, 2026');
      expect(doc.pageLabel, 'Page {page} of {total}');
      expect(doc.rtl, isFalse);
    });

    test('an unknown curriculum key is named by its key', () {
      final doc = _compose(_view(fullReport(), key: 'zzz'));
      expect(doc.curriculumName, 'zzz');
    });

    test('a Hebrew UI sets the document right to left', () {
      expect(_compose(_view(fullReport()), locale: 'he').rtl, isTrue);
    });
  });

  group('sections', () {
    test('a learner with sub-tracks and no pace gets totals, By source '
        'and School years', () {
      final doc = _compose(_view(fullReport()));
      expect(doc.sections.map((s) => s.key), [
        'totals',
        'bySource',
        'schoolYears',
      ]);
    });

    test('the totals are the projection numbers, formatted', () {
      final totals = _section(_compose(_view(fullReport())), 'totals');
      expect(totals.title, isNull);
      expect(totals.rows.map((r) => r.text), [
        'Distinct · 1,204 Mishnayos',
        'Learning events · 2,040',
      ]);
      expect(
        totals.rows.map((r) => r.style),
        everyElement(LifetimeReportPdfRowStyle.figure),
      );
    });

    test('a learner with no counted event gets the zero totals only, even '
        'with a pace view', () {
      final empty = ReportProjection(
        curriculumId: reportCurriculum,
        distinctLearnt: 0,
        totalEvents: 0,
        sources: const {},
      );
      final view = _view(empty);
      final doc = _compose(view, pace: _pace(view));
      expect(doc.sections.map((s) => s.key), ['totals']);
      expect(_section(doc, 'totals').rows.first.text, 'Distinct · 0 Mishnayos');
    });

    test('a learner with no sub-tracks has no School years section', () {
      final doc = _compose(_view(homeOnlyReport()));
      expect(doc.sections.map((s) => s.key), ['totals', 'bySource']);
    });

    test('a singular count takes the singular unit', () {
      final one = ReportProjection(
        curriculumId: reportCurriculum,
        distinctLearnt: 1,
        totalEvents: 1,
        sources: {
          LearningEvent.sourceMain: reportTotals(
            LearningEvent.sourceMain,
            events: 1,
            distinct: 1,
          ),
        },
      );
      expect(
        _section(_compose(_view(one)), 'totals').rows.first.text,
        'Distinct · 1 Mishna',
      );
    });
  });

  group('By source and School years', () {
    test('By source: one heading and one counts row per source, in screen '
        'order, headings kept with their counts', () {
      final view = _view(fullReport());
      final by = _section(_compose(view), 'bySource');
      expect(by.title, 'By source');
      expect(by.rows, hasLength(view.sourceRows.length * 2));
      expect(by.rows.first.text, 'Home');
      expect(by.rows[1].text, '1,020 learning events · 700 Mishnayos');
      expect(by.rows.last.text, '40 learning events · 40 Mishnayos');
      expect(by.rows[by.rows.length - 2].text, 'Before tracking');
      for (var i = 0; i < by.rows.length; i += 2) {
        expect(by.rows[i].style, LifetimeReportPdfRowStyle.heading);
        expect(by.rows[i].keepWithNext, isTrue);
        expect(by.rows[i + 1].keepWithNext, isFalse);
      }
    });

    test('By source: a sub-track row carries its name and year range', () {
      final by = _section(_compose(_view(fullReport())), 'bySource');
      expect(by.rows.map((r) => r.text), contains(contains('2024–25')));
      expect(by.rows.any((r) => r.text.contains('Rebbe')), isTrue);
    });

    test('School years: groups expanded with member lines and Ended '
        'markers', () {
      final sy = _section(_compose(_view(fullReport())), 'schoolYears');
      expect(sy.title, 'School years');
      final texts = sy.rows.map((r) => r.text).toList();
      expect(
        texts.any((t) => t.contains('Rebbe') && t.contains('ongoing')),
        isTrue,
      );
      expect(
        texts.any((t) => t.endsWith('School\u200e · 640 Mishnayos')),
        isTrue,
      );
      expect(texts.where((t) => t.contains('Ended')), hasLength(2));
      expect(texts.where((t) => t.contains('In progress')), hasLength(2));
      final headings = sy.rows.where(
        (r) => r.style == LifetimeReportPdfRowStyle.heading,
      );
      expect(headings, hasLength(2));
      expect(headings.every((r) => r.indent == 0 && r.keepWithNext), isTrue);
      final members = sy.rows.where((r) => r.indent == 1);
      expect(members, hasLength(4));
    });

    test('a deleted sub-track year shows the same Ended marker', () {
      final sy = _section(
        _compose(_view(fullReport(deleted2025: true))),
        'schoolYears',
      );
      expect(sy.rows.where((r) => r.text.contains('Ended')), hasLength(2));
    });
  });

  group('pace', () {
    test('On-track block: status, projected finish, daily target and the '
        'shortfall as a warning', () {
      final view = _view(paceReport());
      final doc = _compose(view, pace: _pace(view));
      expect(doc.sections.map((s) => s.key), [
        'totals',
        'onTrack',
        'pace',
        'bySource',
        'schoolYears',
      ]);
      final on = _section(doc, 'onTrack');
      expect(on.title, 'Goal status');
      expect(on.rows[0].text, 'On track');
      expect(on.rows[0].style, LifetimeReportPdfRowStyle.heading);
      expect(on.rows[1].text, 'Projected finish: Mar 14, 2029');
      expect(on.rows[2].text, 'Daily target: 3 Mishnayos/day');
      final warning = on.rows.last;
      expect(warning.style, LifetimeReportPdfRowStyle.warning);
      expect(
        warning.text,
        contains('may not reach Berakhot 3 before June 2027'),
      );
      expect(warning.text, contains('12 Mishnayos'));
    });

    test('Per-source pace: blocks of heading, rate and trailing lines, '
        'kept together, with the footnote', () {
      final view = _view(paceReport(ended2025: true));
      final pace = _section(_compose(view, pace: _pace(view)), 'pace');
      expect(pace.title, 'Per-source pace');
      expect(pace.footnote, "Before-tracking learning isn't counted in pace.");
      final texts = pace.rows.map((r) => r.text).toList();
      expect(texts.first, 'Home');
      expect(
        texts[1],
        'Since tracking started · Mishnayos per week: 9.6 / week',
      );
      expect(texts[2], 'Last 28 days: 8 / week');
      expect(texts, contains('5 / week estimate'));
      expect(
        texts.any((t) => t.contains('2025–26') && t.endsWith('Ended')),
        isTrue,
      );
      // The last line of each block lets a page break follow; the rest do not.
      for (final row in pace.rows) {
        final heading = row.style == LifetimeReportPdfRowStyle.heading;
        if (heading) expect(row.keepWithNext, isTrue);
      }
      final breaks = pace.rows.where((r) => !r.keepWithNext).toList();
      expect(breaks, hasLength(4));
      expect(
        breaks.every((r) => r.style == LifetimeReportPdfRowStyle.detail),
        isTrue,
      );
    });

    test('a too-early projection prints no finish line', () {
      final view = _view(paceReport(status: ProjectionStatus.tooEarly));
      final on = _section(
        _compose(view, pace: _pace(view, status: ProjectionStatus.tooEarly)),
        'onTrack',
      );
      expect(
        on.rows.map((r) => r.text),
        isNot(contains(startsWith('Projected finish'))),
      );
    });
  });

  group('Hebrew', () {
    test('a Hebrew-named sub-track keeps its name in the School years '
        'line and the digits stay left to right', () {
      final school = reportTotals(school2026, events: 230, distinct: 210);
      final report = ReportProjection(
        curriculumId: reportCurriculum,
        distinctLearnt: 210,
        totalEvents: 230,
        sources: {
          LearningEvent.sourceMain: reportTotals(
            LearningEvent.sourceMain,
            events: 0,
            distinct: 0,
          ),
          school2026: school,
        },
        groups: [
          ReportGroup(
            key: 'בית ספר',
            name: 'בית ספר',
            members: [
              schoolYearLine(school2026, 2026, school, name: 'בית ספר'),
            ],
          ),
        ],
      );
      for (final locale in ['en', 'he']) {
        final sy = _section(
          _compose(_view(report), locale: locale),
          'schoolYears',
        );
        expect(sy.rows.first.text, contains('בית ספר'));
        expect(sy.rows.first.text, contains('210'));
      }
    });

    test('the Hebrew UI localizes the title and formats the date', () {
      final doc = _compose(_view(fullReport()), locale: 'he');
      expect(doc.title, lookupAppLocalizations(const Locale('he')).reportTitle);
      expect(doc.title, isNot('Lifetime report'));
    });

    test('Hebrew terms name the curriculum in Hebrew', () {
      final doc = _compose(_view(fullReport()), useHebrewTerms: true);
      expect(doc.curriculumName, isNot('Mishnayos'));
    });
  });
}
