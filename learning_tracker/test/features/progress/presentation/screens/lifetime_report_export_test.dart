// Story 5.4 (DNI-519): the lifetime report's Export PDF pill, and the PDF
// it exports being the report on screen (AC-1, AC-2, AC-4–AC-6, AC-8–AC-10,
// AC-12).
//
// The export service runs with in-memory seams: the "renderer" records the
// document it is given, so a test can read what would be printed, and,
// where a test needs the real PDF, builds it with the real builder and
// reads it back.
@Tags(['progress', 'lifetime', 'story_5_4'])
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_builder.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_document.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_export_provider.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_report_screen.dart';
import 'package:learning_tracker/features/progress/presentation/services/lifetime_report_export_service.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/progress/lifetime_report_fixtures.dart';
import '../../../../helpers/progress/pace_report_fixtures.dart';
import '../../../../helpers/progress/report_pdf_fixtures.dart';
import '../../../../helpers/pump_app.dart';

final class _NoFonts implements LifetimeReportPdfFontSource {
  @override
  Future<LifetimeReportPdfFonts> load() async => LifetimeReportPdfFonts(
    latinRegular: Uint8List(0),
    latinBold: Uint8List(0),
    hebrewRegular: Uint8List(0),
    hebrewBold: Uint8List(0),
  );
}

final class _MemoryFiles implements LifetimeReportPdfFileStore {
  final files = <String, Uint8List>{};

  @override
  Future<void> delete(String path) async => files.remove(path);

  @override
  Future<String> write(String fileName, Uint8List bytes) async {
    files['/tmp/$fileName'] = bytes;
    return '/tmp/$fileName';
  }
}

/// The export seams of one test.
final class _Export {
  final documents = <LifetimeReportPdfDocument>[];
  final files = _MemoryFiles();
  final shares = <({String fileName, Rect? origin})>[];

  /// Completes each render; null renders at once.
  Completer<Uint8List>? gate;

  /// Throws from the renderer while set (AC-9).
  Exception? renderError;

  LifetimeReportExportService service(Ref ref) => LifetimeReportExportService(
    isParentSession: () async => ref.read(parentSessionProvider).value == true,
    fonts: _NoFonts(),
    files: files,
    sharer: _Sharer(this),
    render: (document, fonts) async {
      documents.add(document);
      if (renderError case final e?) throw e;
      if (gate case final g?) return g.future;
      return Uint8List.fromList('%PDF-'.codeUnits);
    },
  );
}

final class _Sharer implements LifetimeReportPdfSharer {
  _Sharer(this.export);

  final _Export export;

  @override
  Future<LifetimeReportShareOutcome> share({
    required String path,
    required String fileName,
    Rect? origin,
    String? subject,
  }) async {
    export.shares.add((fileName: fileName, origin: origin));
    return LifetimeReportShareOutcome.dismissed;
  }
}

List<Override> _overrides(
  _Export export, {
  LearnerState? state,
  Stream<LearnerState> Function()? states,
  bool parent = true,
  bool hebrewTerms = false,
}) => [
  parentSessionProvider.overrideWith((ref) async => parent),
  effectiveUseHebrewTermsProvider.overrideWithValue(hebrewTerms),
  activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
  activeProfileProvider.overrideWith(
    (ref) async => LearnerProfileEntity(
      profileId: 'p1',
      displayName: 'Dovid',
      mode: ProfileMode.child,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  ),
  learnerStateProvider.overrideWith(
    (ref, _) => states != null ? states() : Stream.value(state!),
  ),
  lifetimeReportExportServiceProvider.overrideWith(export.service),
];

Future<void> _pump(
  WidgetTester tester,
  _Export export, {
  LearnerState? state,
  Stream<LearnerState> Function()? states,
  bool parent = true,
  bool hebrewTerms = false,
  Size size = const Size(400, 900),
  Locale locale = const Locale('en'),
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    pumpApp(
      child: const LifetimeReportScreen(),
      overrides: _overrides(
        export,
        state: state,
        states: states,
        parent: parent,
        hebrewTerms: hebrewTerms,
      ),
      locale: locale,
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

final _pill = find.byKey(const ValueKey('lifetimeReportExportPdf'));

bool _enabled(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(_pill).onPressed != null;

Future<void> _tapExport(WidgetTester tester) async {
  await tester.tap(_pill);
  await tester.pumpAndSettle();
}

/// The document's section [key].
LifetimeReportPdfSection _section(LifetimeReportPdfDocument doc, String key) =>
    doc.sections.firstWhere((s) => s.key == key);

/// [text] without direction marks and embeddings (never drawn).
String _plain(String text) =>
    text.replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E]'), '');

/// Every number in [texts], in order of appearance.
List<String> _numbers(Iterable<String> texts) => [
  for (final t in texts)
    for (final m in RegExp(r'\d+(?:[.,]\d+)*').allMatches(t)) m.group(0)!,
];

/// Every string painted on screen.
Iterable<String> _painted(WidgetTester tester) => [
  for (final t in tester.widgetList<RichText>(find.byType(RichText)))
    t.text.toPlainText(),
];

/// Expands every School-years group on screen.
Future<void> _expandAll(WidgetTester tester, ReportProjection report) async {
  for (final group in report.groups) {
    final header = find.byKey(
      ValueKey('lifetimeReportGroupHeader-${group.key}'),
    );
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
  }
}

/// The report with a Hebrew-only group, a renamed group and a deleted year
/// (AC-5).
ReportProjection _namesReport() {
  final base = fullReport(deleted2025: true);
  final rebbe = base.groups.first;
  final school = base.groups.last;
  ReportMemberLine renamed(ReportMemberLine m, String name) => ReportMemberLine(
    subTrackId: m.subTrackId,
    name: name,
    type: m.type,
    academicYear: m.academicYear,
    windowStart: m.windowStart,
    windowEnd: m.windowEnd,
    label: m.label,
    endedAt: m.endedAt,
    endedOn: m.endedOn,
    endReason: m.endReason,
    totals: m.totals,
  );
  return ReportProjection(
    curriculumId: base.curriculumId,
    distinctLearnt: base.distinctLearnt,
    totalEvents: base.totalEvents,
    sources: base.sources,
    beforeTracking: base.beforeTracking,
    groups: [
      ReportGroup(
        key: 'רבי',
        name: 'רבי',
        members: [for (final m in rebbe.members) renamed(m, 'רבי')],
      ),
      // "School" was renamed "School (morning)" in its last year; the
      // engine groups the years under the current name.
      ReportGroup(
        key: 'school (morning)',
        name: 'School (morning)',
        members: [
          for (final m in school.members) renamed(m, 'School (morning)'),
        ],
      ),
    ],
  );
}

/// The ongoing Rebbe member line ("since Jan 2025 · In progress · …").
String get _rebbeLine =>
    '${reportWindowLabel('2025-01-05', null)} · In progress · 216 Mishnayos';

void main() {
  late _Export export;

  setUp(() => export = _Export());

  group('AC-1 the Export PDF pill', () {
    testWidgets('a primary pill, enabled on a complete report', (tester) async {
      await _pump(tester, export, state: reportState([fullReport()]));
      expect(_pill, findsOneWidget);
      expect(find.text('Export PDF'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_pill).style?.shape?.resolve({}),
        isA<StadiumBorder>(),
      );
      expect(_enabled(tester), isTrue);
    });

    testWidgets('stays enabled with no counted events and exports the zero '
        'report', (tester) async {
      await _pump(tester, export, state: reportState(const []));
      expect(_enabled(tester), isTrue);
      await _tapExport(tester);
      final doc = export.documents.single;
      expect(doc.sections.map((s) => s.key), ['totals']);
      expect(_section(doc, 'totals').rows.map((r) => r.text), [
        'Distinct · 0 Mishnayos',
        'Learning events · 0',
      ]);
    });
  });

  group('AC-10 inputs complete before export', () {
    testWidgets('disabled while the learner state is loading or paging', (
      tester,
    ) async {
      final states = StreamController<LearnerState>();
      addTearDown(states.close);
      await _pump(tester, export, states: () => states.stream, settle: false);
      await tester.pump();
      expect(_pill, findsOneWidget);
      expect(_enabled(tester), isFalse);
      await tester.tap(_pill, warnIfMissed: false);
      await tester.pump();
      expect(export.documents, isEmpty);

      states.add(reportState([fullReport()]));
      await tester.pumpAndSettle();
      expect(_enabled(tester), isTrue);
    });
  });

  group('AC-12 parent session only', () {
    testWidgets('no export entry point outside a parent session', (
      tester,
    ) async {
      await _pump(
        tester,
        export,
        state: reportState([fullReport()]),
        parent: false,
        settle: false,
      );
      await tester.pump();
      expect(_pill, findsNothing);
      expect(find.text('Export PDF'), findsNothing);
      // The screen leaves for Lifetime (DNI-517); this harness has no
      // router to take it there.
      tester.takeException();
    });

    testWidgets('a direct call is rejected outside a parent session', (
      tester,
    ) async {
      await _pump(
        tester,
        export,
        state: reportState([fullReport()]),
        parent: false,
        settle: false,
      );
      await tester.pump();
      tester.takeException();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LifetimeReportScreen)),
      );
      final result = await container
          .read(lifetimeReportExportProvider.notifier)
          .export(
            document: reportPdfDocument(),
            fileName: 'learning-report-x-y-2026-10-03.pdf',
          );
      expect(result, LifetimeReportExportResult.denied);
      expect(export.documents, isEmpty);
      expect(export.files.files, isEmpty);
    });
  });

  group('AC-2 the PDF is the report on screen', () {
    testWidgets('learner, curriculum, generated-on date and every section', (
      tester,
    ) async {
      await _pump(tester, export, state: reportState([fullReport()]));
      await _tapExport(tester);
      final doc = export.documents.single;
      expect(doc.title, 'Lifetime report');
      expect(doc.learnerName, 'Dovid');
      expect(doc.curriculumName, 'Mishnayos');
      // fakeLearnerStateNow's civil date (the learner's time zone).
      expect(doc.generatedOn, startsWith('Generated on '));
      expect(doc.sections.map((s) => s.key), [
        'totals',
        'bySource',
        'schoolYears',
      ]);
      // School years fully expanded: every group with every year line.
      expect(_section(doc, 'schoolYears').rows.map((r) => _plain(r.text)), [
        'Rebbe · ongoing · 216 Mishnayos',
        _rebbeLine,
        'School · 640 Mishnayos',
        '2024–25 · Ended · 210 Mishnayos',
        '2025–26 · Ended · 250 Mishnayos',
        '2026–27 · In progress · 180 Mishnayos',
      ]);
    });

    testWidgets('every number in the PDF is the number on screen', (
      tester,
    ) async {
      final report = fullReport();
      await _pump(tester, export, state: reportState([report]));
      await _expandAll(tester, report);
      final screen = _numbers(_painted(tester))..sort();

      await _tapExport(tester);
      final doc = export.documents.single;
      final pdf = (await tester.runAsync(() => renderReportPdf(doc)))!;
      final printed = _numbers(
        pdf.lines
            .map((l) => l.text)
            .where((t) => !t.startsWith('Generated on'))
            .where((t) => !t.startsWith('Page ')),
      )..sort();
      expect(printed, screen);
      expect(printed, containsAll(['1,204', '2,040', '640', '1,020']));
    });

    testWidgets('pace and on-track numbers match the screen too', (
      tester,
    ) async {
      final state = paceState([paceCurriculumState(paceReport())]);
      await _pump(tester, export, state: state);
      final screen = _numbers(_painted(tester));
      await _tapExport(tester);
      final doc = export.documents.single;
      expect(doc.sections.map((s) => s.key), [
        'totals',
        'onTrack',
        'pace',
        'bySource',
        'schoolYears',
      ]);
      expect(_section(doc, 'pace').footnote, isNotNull);
      final pdf = (await tester.runAsync(() => renderReportPdf(doc)))!;
      final pace = pdf.lines
          .map((l) => l.text)
          .skipWhile((t) => t != 'Goal status')
          .takeWhile((t) => t != 'By source');
      // Every pace and on-track figure the PDF prints is on screen.
      expect(screen, containsAll(_numbers(pace)));
      expect(_numbers(pace), containsAll(['9.6', '3']));
    });
  });

  group('AC-5 names and the Ended marker', () {
    testWidgets('Hebrew-only, renamed and deleted sub-tracks appear as on '
        'screen', (tester) async {
      final report = _namesReport();
      await _pump(tester, export, state: reportState([report]));
      await _expandAll(tester, report);
      final screen = _painted(tester).toList();

      await _tapExport(tester);
      final rows = _section(
        export.documents.single,
        'schoolYears',
      ).rows.map((r) => _plain(r.text)).toList();
      expect(rows, [
        'רבי · ongoing · 216 Mishnayos',
        _rebbeLine,
        'School (morning) · 640 Mishnayos',
        '2024–25 · Ended · 210 Mishnayos',
        '2025–26 · Ended · 250 Mishnayos',
        '2026–27 · In progress · 180 Mishnayos',
      ]);
      // The same group headers and Ended markers as the screen.
      expect(screen, contains('רבי · ongoing · 216 Mishnayos'));
      expect(screen, contains('School (morning) · 640 Mishnayos'));
      expect(screen.where((t) => t == 'Ended'), hasLength(2));
      expect(rows.where((r) => r.contains(' · Ended · ')), hasLength(2));
      // No old-name row.
      expect(rows.where((r) => r.startsWith('School ·')), isEmpty);
    });
  });

  group('AC-6 reduced reports', () {
    testWidgets('no sub-tracks: no School years section, no empty table', (
      tester,
    ) async {
      await _pump(tester, export, state: reportState([homeOnlyReport()]));
      await _tapExport(tester);
      final doc = export.documents.single;
      expect(doc.sections.map((s) => s.key), ['totals', 'bySource']);
      expect(find.text('School years'), findsNothing);
      expect(doc.sections.every((s) => s.rows.isNotEmpty), isTrue);
    });
  });

  group('AC-4 Hebrew terms (UX-DR-11)', () {
    testWidgets('setting off: transliterated units, as on screen', (
      tester,
    ) async {
      await _pump(tester, export, state: reportState([fullReport()]));
      await _tapExport(tester);
      final doc = export.documents.single;
      expect(doc.curriculumName, 'Mishnayos');
      expect(_section(doc, 'totals').rows.first.text, endsWith('Mishnayos'));
    });

    testWidgets('setting on: Hebrew units, as on screen', (tester) async {
      await _pump(
        tester,
        export,
        state: reportState([fullReport()]),
        hebrewTerms: true,
      );
      await _tapExport(tester);
      final doc = export.documents.single;
      expect(doc.curriculumName, 'משניות');
      expect(_section(doc, 'totals').rows.first.text, endsWith('משניות'));
      expect(find.bySemanticsLabel('Distinct · 1,204 משניות'), findsOneWidget);
    });

    testWidgets('a Hebrew UI exports a right-to-left document', (tester) async {
      await _pump(
        tester,
        export,
        state: reportState([fullReport()]),
        locale: const Locale('he'),
      );
      await _tapExport(tester);
      expect(export.documents.single.rtl, isTrue);
    });
  });

  group('AC-8 share', () {
    testWidgets('the file name and the share anchor (iPad)', (tester) async {
      await _pump(
        tester,
        export,
        state: reportState([fullReport()]),
        size: const Size(1024, 1366),
      );
      final bounds = tester.getRect(_pill);
      await _tapExport(tester);
      final share = export.shares.single;
      expect(
        share.fileName,
        matches(
          RegExp(r'^learning-report-Dovid-mishnayos-\d{4}-\d{2}-\d{2}\.pdf$'),
        ),
      );
      // The sheet is anchored to the Export PDF button itself.
      expect(share.origin, bounds);
    });

    testWidgets('dismissing the sheet returns to the report with no error', (
      tester,
    ) async {
      await _pump(tester, export, state: reportState([fullReport()]));
      await _tapExport(tester);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Lifetime report'), findsOneWidget);
      expect(_enabled(tester), isTrue);
    });
  });

  group('AC-7 busy', () {
    testWidgets('the pill shows progress and is disabled until the export '
        'ends', (tester) async {
      export.gate = Completer<Uint8List>();
      await _pump(tester, export, state: reportState([fullReport()]));
      await tester.tap(_pill);
      await tester.pump();
      await tester.pump();
      expect(find.text('Preparing PDF…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_enabled(tester), isFalse);
      await tester.tap(_pill, warnIfMissed: false);
      await tester.pump();
      expect(export.documents, hasLength(1));

      export.gate!.complete(Uint8List.fromList('%PDF-'.codeUnits));
      await tester.pumpAndSettle();
      expect(find.text('Export PDF'), findsOneWidget);
      expect(_enabled(tester), isTrue);
    });
  });

  group('AC-9 failure', () {
    testWidgets('a floating snackbar with Retry; the report stays; nothing '
        'is shared', (tester) async {
      export.renderError = Exception('layout');
      await _pump(tester, export, state: reportState([fullReport()]));
      await _tapExport(tester);

      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.behavior, SnackBarBehavior.floating);
      expect(
        find.text("Couldn't export the report — try again."),
        findsOneWidget,
      );
      expect(find.text('Lifetime report'), findsOneWidget);
      expect(find.text('Distinct'), findsOneWidget);
      expect(export.shares, isEmpty);
      expect(export.files.files, isEmpty);
      expect(_enabled(tester), isTrue);

      export.renderError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(export.documents, hasLength(2));
      expect(export.shares, hasLength(1));
    });
  });
}
