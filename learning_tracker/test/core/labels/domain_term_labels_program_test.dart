// Regression test for the program-label methods added to
// `lib/core/labels/domain_term_labels.dart`.
//
// W0.5-B refactor: scheduler service code (`learning_program_service.dart`,
// `calendar_program_service.dart`) no longer reads `useHebrewTermsProvider`
// directly. All program-label resolution must go through
// `domainTermLabels(ref).learningProgramLabel` /
// `.calendarEntryLabel` / `.calendarEntryTodayRef`. This test exercises
// those methods with the Hebrew Terms toggle both ON and OFF, through real
// `ProviderContainer` and `Consumer` wiring (no mirror — runs production
// code).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ── learningProgramLabel ────────────────────────────────────────────────
  //
  // The seed list and CalendarProgramRegistry both contain a "daf_yomi"
  // program with English "Daf Yomi" / Hebrew "דף יומי". The repo's
  // `getProgramByName` lookup is the production path that gives the
  // `LearningProgramData` instance we pass to the label method.

  group('domainTermLabels.learningProgramLabel — Hebrew toggle wiring', () {
    testWidgets('Hebrew ON → Hebrew name from CalendarProgramRegistry', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'hebrew_terms_script_p0': true});
      String? rendered;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final program = LearningProgramRepository.instance
                      .getProgramByName('daf_yomi')!;
                  rendered = domainTermLabels(ref).learningProgramLabel(
                    program,
                  );
                  return Text(rendered!);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rendered, 'דף יומי');
    });

    testWidgets(
      'Hebrew OFF → English LearningProgramData.displayName',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'hebrew_terms_script_p0': false,
        });
        String? rendered;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    final program = LearningProgramRepository.instance
                        .getProgramByName('daf_yomi')!;
                    rendered = domainTermLabels(ref).learningProgramLabel(
                      program,
                    );
                    return Text(rendered!);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(rendered, 'Daf Yomi');
      },
    );

    testWidgets(
      'Hebrew ON + unregistered program → falls back to English displayName',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'hebrew_terms_script_p0': true,
        });
        String? rendered;
        // Build a LearningProgramData whose `name` is NOT in
        // CalendarProgramRegistry — the registry lookup must return null
        // and the method must fall back to the program's English
        // displayName.
        const program = LearningProgramData(
          id: 999,
          name: 'fake_not_in_registry',
          displayName: 'Synthetic Program',
          description: '',
          curriculumType: 'bavli',
          isActive: true,
          hasTests: false,
          stagesConfig: '{}',
          testConfig: '{}',
          apiSource: null,
          apiProgramKey: null,
          isCalendarProgram: false,
        );
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    rendered = domainTermLabels(ref).learningProgramLabel(
                      program,
                    );
                    return Text(rendered!);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(rendered, 'Synthetic Program');
      },
    );
  });

  // ── calendarEntryLabel ──────────────────────────────────────────────────

  group('domainTermLabels.calendarEntryLabel — Hebrew toggle wiring', () {
    const entry = CalendarProgramEntry(
      programId: 'daf_yomi',
      displayNameEn: 'Daf Yomi',
      displayNameHe: 'דף יומי',
      todayRef: 'Hullin 7',
      todayRefHe: 'חולין ז',
      apiSource: 'local',
    );

    testWidgets('Hebrew ON → entry.displayNameHe', (tester) async {
      SharedPreferences.setMockInitialValues({'hebrew_terms_script_p0': true});
      String? rendered;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  rendered = domainTermLabels(ref).calendarEntryLabel(entry);
                  return Text(rendered!);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rendered, 'דף יומי');
    });

    testWidgets('Hebrew OFF → entry.displayNameEn', (tester) async {
      SharedPreferences.setMockInitialValues({'hebrew_terms_script_p0': false});
      String? rendered;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  rendered = domainTermLabels(ref).calendarEntryLabel(entry);
                  return Text(rendered!);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rendered, 'Daf Yomi');
    });
  });

  // ── calendarEntryTodayRef ───────────────────────────────────────────────

  group('domainTermLabels.calendarEntryTodayRef — Hebrew toggle wiring', () {
    testWidgets('Hebrew ON + non-empty todayRefHe → entry.todayRefHe', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'hebrew_terms_script_p0': true});
      const entry = CalendarProgramEntry(
        programId: 'daf_yomi',
        displayNameEn: 'Daf Yomi',
        displayNameHe: 'דף יומי',
        todayRef: 'Hullin 7',
        todayRefHe: 'חולין ז',
        apiSource: 'local',
      );
      String? rendered;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  rendered = domainTermLabels(ref).calendarEntryTodayRef(entry);
                  return Text(rendered!);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rendered, 'חולין ז');
    });

    testWidgets(
      'Hebrew ON + empty todayRefHe → falls back to entry.todayRef (English)',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'hebrew_terms_script_p0': true,
        });
        const entry = CalendarProgramEntry(
          programId: 'daf_yomi',
          displayNameEn: 'Daf Yomi',
          displayNameHe: 'דף יומי',
          todayRef: 'Hullin 7',
          // Empty by default — represents the case where the API didn't
          // supply a Hebrew ref form.
          apiSource: 'local',
        );
        String? rendered;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    rendered = domainTermLabels(ref).calendarEntryTodayRef(
                      entry,
                    );
                    return Text(rendered!);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(rendered, 'Hullin 7');
      },
    );

    testWidgets('Hebrew OFF → entry.todayRef (English)', (tester) async {
      SharedPreferences.setMockInitialValues({'hebrew_terms_script_p0': false});
      const entry = CalendarProgramEntry(
        programId: 'daf_yomi',
        displayNameEn: 'Daf Yomi',
        displayNameHe: 'דף יומי',
        todayRef: 'Hullin 7',
        todayRefHe: 'חולין ז',
        apiSource: 'local',
      );
      String? rendered;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  rendered = domainTermLabels(ref).calendarEntryTodayRef(entry);
                  return Text(rendered!);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rendered, 'Hullin 7');
    });
  });

  // ── End-to-end through the scheduler service wrapper functions ──────────
  //
  // The scheduler exports `learningProgramLabelText` /
  // `calendarEntryLabelText` / `calendarEntryTodayRefText` as the public
  // call sites. After the W0.5-B refactor these are thin wrappers around
  // the DomainTermLabels methods above. The wrapper-level coverage here
  // guards against regression — a future change that re-introduces a
  // direct `useHebrewTermsProvider.watch` here would silently keep the
  // tests above passing.

  group('scheduler service wrappers route through domainTermLabels', () {
    testWidgets('learningProgramLabelText Hebrew ON → Hebrew', (tester) async {
      SharedPreferences.setMockInitialValues({'hebrew_terms_script_p0': true});
      String? rendered;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final program = LearningProgramRepository.instance
                      .getProgramByName('daf_yomi')!;
                  rendered = learningProgramLabelText(ref, program: program);
                  return Text(rendered!);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rendered, 'דף יומי');
    });

    testWidgets('calendarEntryLabelText Hebrew OFF → English', (tester) async {
      SharedPreferences.setMockInitialValues({'hebrew_terms_script_p0': false});
      const entry = CalendarProgramEntry(
        programId: 'daf_yomi',
        displayNameEn: 'Daf Yomi',
        displayNameHe: 'דף יומי',
        todayRef: 'Hullin 7',
        todayRefHe: 'חולין ז',
        apiSource: 'local',
      );
      String? rendered;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  rendered = calendarEntryLabelText(ref, entry: entry);
                  return Text(rendered!);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rendered, 'Daf Yomi');
    });

    testWidgets('calendarEntryTodayRefText Hebrew ON → Hebrew ref', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'hebrew_terms_script_p0': true});
      const entry = CalendarProgramEntry(
        programId: 'daf_yomi',
        displayNameEn: 'Daf Yomi',
        displayNameHe: 'דף יומי',
        todayRef: 'Hullin 7',
        todayRefHe: 'חולין ז',
        apiSource: 'local',
      );
      String? rendered;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  rendered = calendarEntryTodayRefText(ref, entry: entry);
                  return Text(rendered!);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rendered, 'חולין ז');
    });
  });
}
