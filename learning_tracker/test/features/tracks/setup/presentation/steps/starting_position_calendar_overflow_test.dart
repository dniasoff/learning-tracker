/// Regression test for R1 finding (4):
/// StartingPositionCalendarMode used Column + Spacer() inside a Scaffold body
/// with no scroll wrapper. At large OS text scales ("BOTTOM OVERFLOWED BY 59
/// PIXELS") the column overflowed. Fix: wrap the body in SingleChildScrollView
/// and replace the Spacer with a fixed SizedBox so the layout degrades
/// gracefully instead of overflowing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_starting_position_calendar.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/drift_memory.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockCalendarProgramService extends Mock
    implements CalendarProgramService {}

// ── Stubs ──────────────────────────────────────────────────────────────────────

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

// ── Helpers ────────────────────────────────────────────────────────────────────

const _kDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

LearningProgramData _dafYomiProgram() => const LearningProgramData(
  id: 1,
  name: 'Daf Yomi',
  displayName: 'Daf Yomi',
  description: 'Test program',
  curriculumType: 'bavli',
  isActive: true,
  hasTests: false,
  stagesConfig: '',
  testConfig: '',
  apiSource: 'local',
  apiProgramKey: 'daf_yomi',
  isCalendarProgram: true,
);

Widget _buildApp({
  required _MockCalendarProgramService calendarSvc,
  Size? viewportSize,
}) {
  final db = inMemoryDb();
  return ProviderScope(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      calendarProgramServiceProvider.overrideWithValue(calendarSvc),
      useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
      syncWriteFacadeProvider.overrideWithValue(null),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: _kDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        GoogleFonts.config.allowRuntimeFetching = false;
        if (viewportSize != null) {
          return MediaQuery(
            data: MediaQueryData(
              size: viewportSize,
              // Large text scale to simulate large-font user preference.
              textScaler: const TextScaler.linear(2.0),
            ),
            child: child!,
          );
        }
        return child!;
      },
      home: Scaffold(
        body: StartingPositionCalendarMode(
          selectedProgram: _dafYomiProgram(),
          onComplete: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('R1-(4) StartingPositionCalendarMode — no overflow at large text', () {
    testWidgets(
      'body is wrapped in SingleChildScrollView (prevents overflow at 2x text)',
      (tester) async {
        final calendarSvc = _MockCalendarProgramService();
        when(
          () => calendarSvc.getEntry(any(), any()),
        ).thenAnswer((_) async => null);

        // Mount in a narrow constrained viewport with 2× text scale to reproduce
        // the "BOTTOM OVERFLOWED BY 59 PIXELS" condition.
        await tester.pumpWidget(
          _buildApp(
            calendarSvc: calendarSvc,
            viewportSize: const Size(375, 500),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // R1-(4): the root layout widget inside the Scaffold body must be a
        // SingleChildScrollView so the column can scroll at large text sizes.
        expect(
          find.descendant(
            of: find.byType(StartingPositionCalendarMode),
            matching: find.byType(SingleChildScrollView),
          ),
          findsOneWidget,
          reason:
              'R1-(4): StartingPositionCalendarMode must wrap its body in '
              'SingleChildScrollView to prevent overflow at large text sizes.',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'no Spacer() in the widget tree (Spacer breaks inside scroll views)',
      (tester) async {
        final calendarSvc = _MockCalendarProgramService();
        when(
          () => calendarSvc.getEntry(any(), any()),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(_buildApp(calendarSvc: calendarSvc));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Spacer() must NOT be present — it causes overflow inside a scroll view.
        expect(
          find.descendant(
            of: find.byType(StartingPositionCalendarMode),
            matching: find.byType(Spacer),
          ),
          findsNothing,
          reason:
              'R1-(4): Spacer() must be removed from StartingPositionCalendarMode; '
              'it causes RenderFlex overflow when wrapped in SingleChildScrollView.',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
