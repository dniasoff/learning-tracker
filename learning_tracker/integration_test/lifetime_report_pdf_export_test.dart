// Story 5.4 (DNI-519) T7: the report PDF export on a device (AC-7, AC-8,
// AC-11).
//
// Runs the real export pipeline on the device: the bundled fonts from the
// asset bundle, the PDF builder on a background isolate, the temporary file
// store. Only the share sheet is recorded instead of opened, so the run is
// unattended; the sheet itself (and its dismissal and platform back) is
// checked by hand in the release device sweep (ruling B12), as are the
// named reference device's budgets.
//
// - AC-7: a multi-page report exports in under 3 s, and the frames drawn
//   while it is generated are recorded (`watchPerformance`, reported, not
//   gated in CI, B12).
// - AC-8: the shared file has the exact name and is a complete PDF; on an
//   iPad-sized window the share origin is the Export PDF button's bounds.
// - AC-11: the learner state is local (no network read), so the export
//   succeeds offline.
//
// Run: flutter test integration_test/lifetime_report_pdf_export_test.dart
// -d <device>
@Tags(['progress', 'lifetime', 'story_5_4', 'device'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_export_provider.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_report_screen.dart';
import 'package:learning_tracker/features/progress/presentation/services/lifetime_report_export_service.dart';

import '../test/helpers/learner_state/c0_fixtures.dart';
import '../test/helpers/progress/lifetime_report_fixtures.dart';
import '../test/helpers/pump_app.dart';

final class _RecordingSharer implements LifetimeReportPdfSharer {
  final shares = <({String fileName, Rect? origin, Uint8List bytes})>[];

  @override
  Future<LifetimeReportShareOutcome> share({
    required String path,
    required String fileName,
    Rect? origin,
    String? subject,
  }) async {
    shares.add((
      fileName: fileName,
      origin: origin,
      bytes: File(path).readAsBytesSync(),
    ));
    return LifetimeReportShareOutcome.dismissed;
  }
}

/// A large history: 40 School-years groups of four years each, so the
/// School years section runs over several pages (the 5.1 perf shape).
ReportProjection _largeReport() {
  final home = reportTotals(
    LearningEvent.sourceMain,
    events: 4000,
    distinct: 3000,
  );
  final sources = <String, ReportSourceTotals>{LearningEvent.sourceMain: home};
  final groups = <ReportGroup>[];
  for (var g = 0; g < 40; g++) {
    final members = <ReportMemberLine>[];
    for (var y = 0; y < 4; y++) {
      final id = '01J00000000000000000G${g.toString().padLeft(2, '0')}Y$y'
          .padRight(26, '0');
      final totals = reportTotals(id, events: 20 + y, distinct: 10 + y);
      sources[id] = totals;
      members.add(
        schoolYearLine(id, 2010 + y, totals, name: 'Group $g', ended: y < 3),
      );
    }
    groups.add(
      ReportGroup(key: 'group $g', name: 'Group $g', members: members),
    );
  }
  return ReportProjection(
    curriculumId: reportCurriculum,
    distinctLearnt: 3000 + 40 * 46,
    totalEvents: 4000 + 40 * 86,
    sources: sources,
    groups: groups,
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<_RecordingSharer> pumpReport(WidgetTester tester) async {
    final sharer = _RecordingSharer();
    await tester.pumpWidget(
      pumpApp(
        child: const LifetimeReportScreen(),
        overrides: [
          parentSessionProvider.overrideWith((ref) async => true),
          effectiveUseHebrewTermsProvider.overrideWithValue(false),
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          activeProfileProvider.overrideWith(
            (ref) async => LearnerProfileEntity(
              profileId: 'p1',
              displayName: 'Dovid',
              mode: ProfileMode.adult,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ),
          // AC-11: the complete learner state is local; nothing is read
          // from the network.
          learnerStateProvider.overrideWith(
            (ref, _) => Stream.value(reportState([_largeReport()])),
          ),
          lifetimeReportExportServiceProvider.overrideWith(
            (ref) => LifetimeReportExportService(
              isParentSession: () async => true,
              fonts: AssetLifetimeReportPdfFontSource(rootBundle),
              files: TemporaryReportPdfFileStore(),
              sharer: sharer,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return sharer;
  }

  final pill = find.byKey(const ValueKey('lifetimeReportExportPdf'));

  testWidgets('AC-7, AC-8, AC-11 a large report exports off the UI isolate '
      'within budget, as a complete, exactly named PDF', (tester) async {
    final sharer = await pumpReport(tester);
    final watch = Stopwatch()..start();
    await binding.watchPerformance(() async {
      await tester.tap(pill);
      // Frames keep coming while the PDF is generated.
      while (sharer.shares.isEmpty) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }, reportKey: 'lifetime_report_pdf_export');
    watch.stop();
    await tester.pumpAndSettle();

    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    final share = sharer.shares.single;
    expect(
      share.fileName,
      matches(
        RegExp(r'^learning-report-Dovid-mishnayos-\d{4}-\d{2}-\d{2}\.pdf$'),
      ),
    );
    expect(String.fromCharCodes(share.bytes.sublist(0, 5)), '%PDF-');
    expect(
      String.fromCharCodes(share.bytes.sublist(share.bytes.length - 6)),
      contains('%%EOF'),
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('AC-8 on an iPad-sized window the share sheet is anchored to '
      'the Export PDF button', (tester) async {
    tester.view.physicalSize = const Size(2048, 2732);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final sharer = await pumpReport(tester);
    final bounds = tester.getRect(pill);
    await tester.tap(pill);
    while (sharer.shares.isEmpty) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(sharer.shares.single.origin, bounds);
  });
}
