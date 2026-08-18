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
// AUD-scheduler-05: the label-selection methods (learningProgramLabel /
// calendarEntryLabel / calendarEntryTodayRef) only branch on
// `DomainTermLabels.isHebrew` — they need no `WidgetRef`/`Ref` at all. Most
// cases below construct `ProgramLabelResolver` directly from a
// `DomainTermLabels` value via a plain `test()`, no `pumpWidget` required.
// Only the `.of(ref)` **wiring** itself — reading the live Hebrew Terms
// toggle through a real `ProviderScope` — still needs a widget/provider
// test; that coverage lives in the bottom group, which also covers the
// scheduler service wrapper functions (`learningProgramLabelText` /
// `calendarEntryLabelText` / `calendarEntryTodayRefText`) so a future
// regression that re-introduces a direct `useHebrewTermsProvider.watch` in
// scheduler service code would be caught.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
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

  group('ProgramLabelResolver.learningProgramLabel — label selection', () {
    test('Hebrew ON → Hebrew name from CalendarProgramRegistry', () {
      final program = LearningProgramRepository.instance.getProgramByName(
        'daf_yomi',
      )!;
      const resolver = ProgramLabelResolver(DomainTermLabels(true));

      expect(resolver.learningProgramLabel(program), 'דף יומי');
    });

    test('Hebrew OFF → English LearningProgramData.displayName', () {
      final program = LearningProgramRepository.instance.getProgramByName(
        'daf_yomi',
      )!;
      const resolver = ProgramLabelResolver(DomainTermLabels(false));

      expect(resolver.learningProgramLabel(program), 'Daf Yomi');
    });

    test(
      'Hebrew ON + unregistered program → falls back to English displayName',
      () {
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
        const resolver = ProgramLabelResolver(DomainTermLabels(true));

        expect(resolver.learningProgramLabel(program), 'Synthetic Program');
      },
    );
  });

  // ── calendarEntryLabel ──────────────────────────────────────────────────

  group('ProgramLabelResolver.calendarEntryLabel — label selection', () {
    const entry = CalendarProgramEntry(
      programId: 'daf_yomi',
      displayNameEn: 'Daf Yomi',
      displayNameHe: 'דף יומי',
      todayRef: 'Hullin 7',
      todayRefHe: 'חולין ז',
      apiSource: 'local',
    );

    test('Hebrew ON → entry.displayNameHe', () {
      const resolver = ProgramLabelResolver(DomainTermLabels(true));

      expect(resolver.calendarEntryLabel(entry), 'דף יומי');
    });

    test('Hebrew OFF → entry.displayNameEn', () {
      const resolver = ProgramLabelResolver(DomainTermLabels(false));

      expect(resolver.calendarEntryLabel(entry), 'Daf Yomi');
    });
  });

  // ── calendarEntryTodayRef ───────────────────────────────────────────────

  group('ProgramLabelResolver.calendarEntryTodayRef — label selection', () {
    test('Hebrew ON + non-empty todayRefHe → entry.todayRefHe', () {
      const entry = CalendarProgramEntry(
        programId: 'daf_yomi',
        displayNameEn: 'Daf Yomi',
        displayNameHe: 'דף יומי',
        todayRef: 'Hullin 7',
        todayRefHe: 'חולין ז',
        apiSource: 'local',
      );
      const resolver = ProgramLabelResolver(DomainTermLabels(true));

      expect(resolver.calendarEntryTodayRef(entry), 'חולין ז');
    });

    test(
      'Hebrew ON + empty todayRefHe → falls back to entry.todayRef (English)',
      () {
        const entry = CalendarProgramEntry(
          programId: 'daf_yomi',
          displayNameEn: 'Daf Yomi',
          displayNameHe: 'דף יומי',
          todayRef: 'Hullin 7',
          // Empty by default — represents the case where the source didn't
          // supply a Hebrew ref form.
          apiSource: 'local',
        );
        const resolver = ProgramLabelResolver(DomainTermLabels(true));

        expect(resolver.calendarEntryTodayRef(entry), 'Hullin 7');
      },
    );

    test('Hebrew OFF → entry.todayRef (English)', () {
      const entry = CalendarProgramEntry(
        programId: 'daf_yomi',
        displayNameEn: 'Daf Yomi',
        displayNameHe: 'דף יומי',
        todayRef: 'Hullin 7',
        todayRefHe: 'חולין ז',
        apiSource: 'local',
      );
      const resolver = ProgramLabelResolver(DomainTermLabels(false));

      expect(resolver.calendarEntryTodayRef(entry), 'Hullin 7');
    });
  });

  // ── End-to-end through the scheduler service wrapper functions ──────────
  //
  // `learningProgramLabelText` / `calendarEntryLabelText` /
  // `calendarEntryTodayRefText` are the public call sites in scheduler
  // service code. Post-F4 these are thin wrappers around
  // [ProgramLabelResolver]. Unlike the groups above, these genuinely need a
  // widget/provider test: they read the Hebrew Terms toggle through
  // `ProgramLabelResolver.of(ref)` → `domainTermLabels(ref)` →
  // `useHebrewTermsProvider`, which only exists inside a live
  // `ProviderScope`. The wrapper-level coverage here guards against
  // regression — a future change that re-introduces a direct
  // `useHebrewTermsProvider.watch` in those services would silently keep
  // the resolver tests above passing but would fail here.

  group('scheduler service wrappers route through ProgramLabelResolver', () {
    testWidgets('learningProgramLabelText Hebrew ON → Hebrew', (tester) async {
      SharedPreferences.setMockInitialValues({
        ProfileScopedPreferenceKeys.hebrewTermsScript(
          kNoProfilePreferenceSentinel,
        ): true,
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
        ProfileScopedPreferenceKeys.hebrewTermsScript(
          kNoProfilePreferenceSentinel,
        ): false,
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
      SharedPreferences.setMockInitialValues({
        ProfileScopedPreferenceKeys.hebrewTermsScript(
          kNoProfilePreferenceSentinel,
        ): true,
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
