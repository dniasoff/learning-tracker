/// PP-3 + PP-10 regression tests for LifetimeCurriculumMarkingScreen.
///
/// PP-3 root cause:
///   The picker header rendered "Selected: N • level {level}" where `_currentLevel`
///   returned `_currentDisplayItems.length` — a nonsense folder-size presented as
///   a hierarchy depth.  Additionally, after Save the session selection was NOT
///   cleared, leaving green checkmarks on already-persisted rows.
///
/// PP-10 root cause:
///   After "Select all in this list" checks all rows, the label stayed the same
///   and re-tapping was a no-op; `deselectAllInThisList` was wired in the ARB
///   but never used.
///
/// Fixes:
///   PP-3 — switched to `lifetimeMarkAsLearnedCount` (count only, no level);
///           `_markSelections` now calls `setState(() => _selections.clear())`
///           after a successful save.
///   PP-10 — added `_allCurrentSelected` getter; the button toggles between
///            `_markAllCurrentLevel` / `_deselectAllCurrentLevel` and renders
///            the matching l10n label.
///
/// Test strategy:
///   - Verify `lifetimeMarkAsLearnedCount` l10n key exists and does NOT include
///     a "level" token.
///   - Verify `deselectAllInThisList` l10n key is present and correctly wired.
///   - Pump a minimal `LifetimeCurriculumMarkingScreen` with all heavy providers
///     stubbed (empty ledger, no hierarchy content) and assert:
///       * the info line does NOT contain "level"
///       * "Select all in this list" button is shown by default
@Tags(['settings', 'lifetime_marking', 'pp3', 'pp10'])
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/screens/lifetime_marking_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

class _FakeActiveProfileId extends ActiveProfileId {
  @override
  int build() => 1;
}

// A UseHebrewTerms subclass that always returns false (English) without
// touching SharedPreferences.
class _FakeUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

Widget _buildScreen({required UserDatabase db, required String curriculumId}) {
  return ProviderScope(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWith(() => _FakeActiveProfileId()),
      // Return an empty ledger so the screen renders without real DB data.
      curriculumLedgerProvider.overrideWith(
        (ref, id) async => const <LearningLedgerData>[],
      ),
      // Avoid touching SharedPreferences.
      useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: LifetimeCurriculumMarkingScreen(curriculumId: curriculumId),
    ),
  );
}

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  late UserDatabase db;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ── PP-3: l10n key has no "level" token ─────────────────────────────────────

  testWidgets(
    'PP-3: lifetimeMarkAsLearnedCount(0) renders "Selected: 0" without "level"',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Scaffold(body: Text(l10n.lifetimeMarkAsLearnedCount(0)));
            },
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Selected: 0'),
        findsOneWidget,
        reason:
            'PP-3: lifetimeMarkAsLearnedCount(0) must render "Selected: 0" '
            'without any trailing "• level N" token',
      );
      expect(
        find.textContaining('level'),
        findsNothing,
        reason:
            'PP-3: the new l10n key must not include a "level" token — it '
            'must not leak the internal folder size',
      );
    },
  );

  testWidgets('PP-3: picker info line in screen does not contain "level"', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScreen(db: db, curriculumId: CurriculumId.mishnayos.storageKey),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The info box must show "Selected:" without any "level" text.
    expect(
      find.textContaining('Selected:'),
      findsAtLeastNWidgets(1),
      reason: 'PP-3: the selection count line must be rendered',
    );
    expect(
      find.textContaining('level'),
      findsNothing,
      reason:
          'PP-3: "level N" must not appear anywhere — it leaked the internal '
          'folder size as a fake hierarchy depth',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── PP-10: deselectAllInThisList l10n key is wired ──────────────────────────

  testWidgets(
    'PP-10: deselectAllInThisList l10n key renders "Deselect all in this list"',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Scaffold(body: Text(l10n.deselectAllInThisList));
            },
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Deselect all in this list'),
        findsOneWidget,
        reason:
            'PP-10: deselectAllInThisList l10n key must render correctly so '
            'the toggle button can display it when all items are selected',
      );
    },
  );

  testWidgets(
    'PP-10: "Select all in this list" button is shown in screen by default',
    (tester) async {
      await tester.pumpWidget(
        _buildScreen(db: db, curriculumId: CurriculumId.mishnayos.storageKey),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initially nothing is selected so "Select all" must be shown.
      expect(
        find.text('Select all in this list'),
        findsOneWidget,
        reason:
            'PP-10: "Select all in this list" must appear when no items are '
            'currently selected (not toggled to deselect mode)',
      );
      // "Deselect all" must NOT be shown yet.
      expect(
        find.text('Deselect all in this list'),
        findsNothing,
        reason:
            'PP-10: "Deselect all in this list" must only appear after all '
            'items in the list are selected',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
