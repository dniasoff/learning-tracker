// Regression test: DeviceRestoreScreen must display localized phase labels
// when the locale is Hebrew (he), not raw English text.
//
// Bug: DeviceRestoreService used to emit hard-coded English strings as the
// `phase` field of RestoreStatus.restoring (e.g. 'Restoring your data...',
// 'Loading curricula...', 'Importing content...'), matched by string
// equality on the screen. The screen rendered `Text(phase)` directly so
// Hebrew users always saw English during restore, and any drift between the
// service's literal and the screen's match arm silently fell back to raw
// English (AUD-app-02, EH-5/EH-6).
//
// Fix: `phase` is now the closed [RestorePhase] enum (see
// lib/features/sync/domain/models/restore_phase.dart), and
// DeviceRestoreScreen._localizePhase is an EXHAUSTIVE switch (no wildcard
// arm) mapping each value to an l10n key — an unmapped RestorePhase value
// is a compile error, not a silent English fallback.
//
// RED before fix: find.text(<he_translation>) findsNothing (screen shows English).
// GREEN after fix: find.text(<he_translation>) findsOneWidget.
@Tags(['l1', 'restore', 'l10n'])
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_phase.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';

import 'restore_test_harness.dart';

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(registerRestoreRouteFallbacks);

  group(
    'DeviceRestoreScreen — restoring phase labels must be localized (loop-iter2, AUD-app-02)',
    () {
      // ── English baseline ───────────────────────────────────────────────────────
      // Ensures RestorePhase.pullingData maps to the correct EN l10n value.

      testWidgets(
        'en locale: RestorePhase.pullingData maps to l10n.deviceRestorePhaseRestoring',
        (tester) async {
          final db = UserDatabase(NativeDatabase.memory());
          addTearDown(db.close);

          await tester.pumpWidget(
            buildRestoreHarness(
              fixedStatus: const RestoreStatus.restoring(
                phase: RestorePhase.pullingData,
                completedSteps: 0,
                totalSteps: 3,
              ),
              mockRouter: makeMockRouter(),
              stubAppRouter: makeStubAppRouter(),
              db: db,
              locale: const Locale('en'),
            ),
          );
          await tester.pump();

          // In EN locale the l10n value IS 'Restoring your data...' so the text
          // must still be present (no regression for existing English users).
          expect(find.text('Restoring your data...'), findsOneWidget);

          await tearDownRestoreHarness(tester);
        },
      );

      // ── Hebrew localization ────────────────────────────────────────────────────
      // Core defect: Hebrew users must see Hebrew text, not the English sentinel.

      testWidgets(
        'he locale: RestorePhase.pullingData renders Hebrew translation, '
        'not the raw English string (SYNC-RESTORE-PHASE-01)',
        (tester) async {
          final db = UserDatabase(NativeDatabase.memory());
          addTearDown(db.close);

          await tester.pumpWidget(
            buildRestoreHarness(
              fixedStatus: const RestoreStatus.restoring(
                phase: RestorePhase.pullingData,
                completedSteps: 0,
                totalSteps: 3,
              ),
              mockRouter: makeMockRouter(),
              stubAppRouter: makeStubAppRouter(),
              db: db,
              locale: const Locale('he'),
            ),
          );
          await tester.pump();

          // The raw English sentinel must NOT appear in Hebrew locale.
          expect(
            find.text('Restoring your data...'),
            findsNothing,
            reason:
                'Hebrew users must not see the hard-coded English phase string; '
                'it must be replaced by l10n.deviceRestorePhaseRestoring',
          );
          // The Hebrew l10n translation must be rendered instead.
          expect(
            find.text('מחזיר את הנתונים שלך...'),
            findsOneWidget,
            reason:
                'DeviceRestoreScreen must map RestorePhase.pullingData to '
                'l10n.deviceRestorePhaseRestoring for he locale',
          );

          await tearDownRestoreHarness(tester);
        },
      );

      testWidgets(
        'he locale: RestorePhase.loadingCurricula renders Hebrew translation '
        '(SYNC-RESTORE-PHASE-02)',
        (tester) async {
          final db = UserDatabase(NativeDatabase.memory());
          addTearDown(db.close);

          await tester.pumpWidget(
            buildRestoreHarness(
              fixedStatus: const RestoreStatus.restoring(
                phase: RestorePhase.loadingCurricula,
                completedSteps: 1,
                totalSteps: 3,
              ),
              mockRouter: makeMockRouter(),
              stubAppRouter: makeStubAppRouter(),
              db: db,
              locale: const Locale('he'),
            ),
          );
          await tester.pump();

          expect(
            find.text('Loading curricula...'),
            findsNothing,
            reason:
                'Hebrew users must not see the hard-coded English phase string',
          );
          expect(
            find.text('טוען תוכניות לימוד...'),
            findsOneWidget,
            reason:
                'DeviceRestoreScreen must map RestorePhase.loadingCurricula to '
                'l10n.deviceRestorePhaseLoadingCurricula for he locale',
          );

          await tearDownRestoreHarness(tester);
        },
      );

      testWidgets(
        'he locale: RestorePhase.importingContent renders Hebrew translation '
        '(SYNC-RESTORE-PHASE-03)',
        (tester) async {
          final db = UserDatabase(NativeDatabase.memory());
          addTearDown(db.close);

          await tester.pumpWidget(
            buildRestoreHarness(
              fixedStatus: const RestoreStatus.restoring(
                phase: RestorePhase.importingContent,
                completedSteps: 2,
                totalSteps: 3,
              ),
              mockRouter: makeMockRouter(),
              stubAppRouter: makeStubAppRouter(),
              db: db,
              locale: const Locale('he'),
            ),
          );
          await tester.pump();

          expect(
            find.text('Importing content...'),
            findsNothing,
            reason:
                'Hebrew users must not see the hard-coded English phase string',
          );
          expect(
            find.text('מייבא תוכן...'),
            findsOneWidget,
            reason:
                'DeviceRestoreScreen must map RestorePhase.importingContent to '
                'l10n.deviceRestorePhaseImportingContent for he locale',
          );

          await tearDownRestoreHarness(tester);
        },
      );

      // NOTE (AUD-app-02, test-file-not-deleted / single-case removal): the
      // former "unknown phase sentinel falls back to raw string" test is
      // removed, not weakened — it exercised a `phase: 'Some unexpected
      // phase'` String value that RestorePhase (a closed enum) can no longer
      // construct. DeviceRestoreScreen._localizePhase is now an EXHAUSTIVE
      // switch over RestorePhase with no wildcard arm (EH-6): the silent
      // "fall back to raw text" behaviour this test asserted has been
      // deleted from the production code, not merely from the test, and any
      // future RestorePhase value with no matching l10n arm is instead a
      // **compile error** at the switch in device_restore_screen.dart.
    },
  );
}
