// Story 5.2 (DNI-517) AC-4, AC-12: disclosure semantics and keyboard,
// RTL mirroring, Hebrew at 200% text, touch targets, and the mobile /
// tablet goldens (light, dark, English, Hebrew) for screen #14.
@Tags(['progress', 'lifetime', 'a11y', 'rtl', 'golden', 'story_5_2'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart'
    show TransliterationVariant;
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_report_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_report_sections.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/golden_runner.dart';
import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/progress/lifetime_report_fixtures.dart';

/// A sub-track name with nikud, to catch clipped Hebrew marks.
const _pointedName = 'תַּלְמוּד תּוֹרָה';
const _pointedId = '01J00000000000000000PNTD00';

/// The full report plus a pointed-Hebrew ongoing track.
ReportProjection _hebrewReport() {
  final base = fullReport();
  final pointed = reportTotals(_pointedId, events: 12, distinct: 9);
  return ReportProjection(
    curriculumId: base.curriculumId,
    distinctLearnt: base.distinctLearnt,
    totalEvents: base.totalEvents + 12,
    sources: {...base.sources, _pointedId: pointed},
    beforeTracking: base.beforeTracking,
    groups: [
      ...base.groups,
      ReportGroup(
        key: _pointedName,
        name: _pointedName,
        members: [ongoingLine(_pointedId, pointed, name: _pointedName)],
      ),
    ],
  );
}

List<Override> _overrides(LearnerState state, {required bool hebrewTerms}) => [
  parentSessionProvider.overrideWith((ref) async => true),
  effectiveUseHebrewTermsProvider.overrideWithValue(hebrewTerms),
  // The curriculum switcher's labels read the transliteration preference;
  // pin it so no test depends on SharedPreferences having been mocked by an
  // earlier test (randomized ordering).
  currentTransliterationVariantProvider.overrideWithValue(
    TransliterationVariant.ashkenazi,
  ),
  activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
  learnerStateProvider.overrideWith((ref, _) => Stream.value(state)),
];

Widget _app({
  required LearnerState state,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) => ProviderScope(
  overrides: _overrides(state, hebrewTerms: locale.languageCode == 'he'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    theme: AppTheme.themeFor(brightness: brightness),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const LifetimeReportScreen(curriculumId: reportCurriculum),
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  LearnerState? state,
  Locale locale = const Locale('en'),
  double textScale = 1,
  Size size = const Size(400, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _app(
      state: state ?? reportState([fullReport()]),
      locale: locale,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _header(String key) =>
    find.byKey(ValueKey('lifetimeReportGroupHeader-$key'));

SemanticsData _semantics(WidgetTester tester, String key) =>
    tester.getSemantics(_header(key)).getSemanticsData();

void main() {
  group('AC-4 disclosure semantics and keyboard (UX-DR-157)', () {
    testWidgets('a group header is a button announcing its expanded state', (
      tester,
    ) async {
      await _pump(tester);
      await tester.ensureVisible(_header('school'));
      await tester.pumpAndSettle();

      var data = _semantics(tester, 'school');
      expect(data.label, 'School · 640 Mishnayos');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isExpanded.toBoolOrNull(), isFalse);
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(_header('school'));
      await tester.pumpAndSettle();
      data = _semantics(tester, 'school');
      expect(data.flagsCollection.isExpanded.toBoolOrNull(), isTrue);
    });

    testWidgets('the semantics tap action expands and collapses', (
      tester,
    ) async {
      await _pump(tester);
      await tester.ensureVisible(_header('school'));
      await tester.pumpAndSettle();
      final header = find.semantics.byLabel('School · 640 Mishnayos');
      tester.semantics.tap(header);
      await tester.pumpAndSettle();
      expect(find.text('2024–25'), findsNWidgets(2));
      tester.semantics.tap(header);
      await tester.pumpAndSettle();
      expect(find.text('2024–25'), findsOneWidget);
    });

    testWidgets('keyboard focus and Enter or Space toggle the group', (
      tester,
    ) async {
      await _pump(tester);
      await tester.ensureVisible(_header('school'));
      await tester.pumpAndSettle();
      final focus = Focus.of(
        tester.element(
          find
              .descendant(of: _header('school'), matching: find.byType(Row))
              .first,
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('lifetimeReportLine-$school2026')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('lifetimeReportLine-$school2026')),
        findsNothing,
      );
    });
  });

  group('AC-12 RTL, large text and touch targets', () {
    testWidgets('Hebrew mirrors chips and line insets', (tester) async {
      await _pump(tester, locale: const Locale('he'));
      expect(
        Directionality.of(tester.element(find.byType(LifetimeReportTotals))),
        TextDirection.rtl,
      );
      // The Home chip's icon sits at the start: on the right in RTL.
      final home = find.byKey(
        const ValueKey('lifetimeReportSource-${LearningEvent.sourceMain}'),
      );
      final chip = find.descendant(
        of: home,
        matching: find.byType(ReportSourceChip),
      );
      final icon = tester.getRect(
        find.descendant(of: chip, matching: find.byType(Icon)),
      );
      final label = tester.getRect(
        find.descendant(of: chip, matching: find.text('בית')),
      );
      expect(icon.left, greaterThan(label.right - 1));

      // The expand chevron is at the end: on the left in RTL.
      await tester.ensureVisible(_header('school'));
      await tester.pumpAndSettle();
      final header = tester.getRect(_header('school'));
      final chevron = tester.getRect(
        find.descendant(
          of: _header('school'),
          matching: find.byIcon(Icons.expand_more),
        ),
      );
      expect(chevron.center.dx, lessThan(header.center.dx));
    });

    testWidgets('Hebrew at 200% text: no overflow, no clipped marks, '
        'stacked totals', (tester) async {
      await _pump(
        tester,
        state: reportState([_hebrewReport()]),
        locale: const Locale('he'),
        textScale: 2,
        size: const Size(360, 800),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(_header(_pointedName));
      await tester.pumpAndSettle();
      await tester.tap(_header(_pointedName));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining(_pointedName), findsWidgets);

      for (final paragraph in tester.renderObjectList<RenderParagraph>(
        find.descendant(
          of: find.byKey(const ValueKey('lifetimeReportScroll')),
          matching: find.byType(RichText),
        ),
      )) {
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.overflow, isNot(TextOverflow.ellipsis));
      }

      final distinct = tester.getRect(
        find.byKey(const ValueKey('lifetimeReportDistinct')),
      );
      final events = tester.getRect(
        find.byKey(const ValueKey('lifetimeReportEvents')),
      );
      expect(events.top, greaterThanOrEqualTo(distinct.bottom));
    });

    testWidgets('every interactive target is at least 48×48 dp', (
      tester,
    ) async {
      await _pump(
        tester,
        state: reportState([
          fullReport(),
          homeOnlyReport(curriculumId: reportRetiredCurriculum),
        ]),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  });

  // AC-12 goldens: mockup #14 phone and tablet compositions, light/dark,
  // English/Hebrew.
  for (final (name, size) in [
    ('lifetime_report_mobile', const Size(400, 1000)),
    ('lifetime_report_tablet', const Size(1024, 800)),
  ]) {
    goldenTest(
      name,
      surfaceSize: size,
      builder: (locale, brightness) => _app(
        state: reportState([fullReport()]),
        locale: locale,
        brightness: brightness,
      ),
    );
  }
}
