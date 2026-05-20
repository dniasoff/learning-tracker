// Regression test for `ProgramLabelResolver`
// (`lib/features/scheduler/domain/labels/program_label_resolver.dart`).
//
// F4 (W7-D adversarial fix wave): the program-label resolver methods were
// moved out of `core/labels/DomainTermLabels` into a thin scheduler-side
// shim so `lib/core/` no longer imports `features/scheduler/` (Rule 1 /
// DNI-386). The toggle source-of-truth stays in `core/labels/` via
// `DomainTermLabels.isHebrew`; this shim only does feature-side
// type-aware field picking.
//
// The test exercises the resolver with the Hebrew Terms toggle both ON and
// OFF, through real `ProviderContainer` / `Consumer` wiring (no mirror —
// runs production code). The bottom group also covers the scheduler
// service wrapper functions (`learningProgramLabelText` /
// `calendarEntryLabelText` / `calendarEntryTodayRefText`) so a future
// regression that re-introduces a direct `useHebrewTermsProvider.watch`
// in scheduler service code would be caught.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/labels/program_label_resolver.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ── learningProgramLabel ────────────────────────────────────────────────
  //
  // The seed list and CalendarProgramRegistry both contain a "daf_yomi"
  // program with English "Daf Yomi" / Hebrew "דף יומי". The repo's
  // `getProgramByName` lookup is the production path that gives the
  // `LearningProgramData` instance we pass to the resolver method.

  group('ProgramLabelResolver.learningProgramLabel — toggle wiring', () {
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
                  rendered =
                      ProgramLabelResolver.of(ref).learningProgramLabel(program);
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
                    rendered = ProgramLabelResolver.of(
                      ref,
                    ).learningProgramLabel(program);
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
        // and the resolver must fall back to the program's English
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
                    rendered = ProgramLabelResolver.of(
                      ref,
                    ).learningProgramLabel(program);
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

  group('ProgramLabelResolver.calendarEntryLabel — toggle wiring', () {
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
                  rendered =
                      ProgramLabelResolver.of(ref).calendarEntryLabel(entry);
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
                  rendered =
                      ProgramLabelResolver.of(ref).calendarEntryLabel(entry);
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

  group('ProgramLabelResolver.calendarEntryTodayRef — toggle wiring', () {
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
                  rendered =
                      ProgramLabelResolver.of(ref).calendarEntryTodayRef(entry);
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
          // Empty by default — represents the case where the source didn't
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
                    rendered = ProgramLabelResolver.of(
                      ref,
                    ).calendarEntryTodayRef(entry);
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
      SharedPreferences.setMockInitialValues({
        'hebrew_terms_script_p0': false,
      });
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
                  rendered =
                      ProgramLabelResolver.of(ref).calendarEntryTodayRef(entry);
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
  // `learningProgramLabelText` / `calendarEntryLabelText` /
  // `calendarEntryTodayRefText` are the public call sites in scheduler
  // service code. Post-F4 these are thin wrappers around
  // [ProgramLabelResolver]. The wrapper-level coverage here guards against
  // regression — a future change that re-introduces a direct
  // `useHebrewTermsProvider.watch` in those services would silently keep
  // the resolver tests above passing but would fail here.

  group('scheduler service wrappers route through ProgramLabelResolver', () {
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
      SharedPreferences.setMockInitialValues({
        'hebrew_terms_script_p0': false,
      });
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
