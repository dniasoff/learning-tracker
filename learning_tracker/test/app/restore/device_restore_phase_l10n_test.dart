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

import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/restore/device_restore_screen.dart';
import 'package:learning_tracker/app/restore/restore_providers.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_phase.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _MockRestoreGuard extends Mock implements RestoreGuard {
  @override
  void markRestoreComplete() {}
}

class _StubAppRouter extends Mock implements AppRouter {
  _StubAppRouter({required this.restoreGuard});

  @override
  final RestoreGuard restoreGuard;
}

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}

// ── Helpers ────────────────────────────────────────────────────────────────────

_MockStackRouter _makeRouter() {
  final r = _MockStackRouter();
  when(() => r.replaceAll(any())).thenAnswer((_) async => []);
  when(() => r.push(any())).thenAnswer((_) async => null);
  return r;
}

_StubAppRouter _makeAppRouter() =>
    _StubAppRouter(restoreGuard: _MockRestoreGuard());

Widget _buildHarness({
  required RestoreStatus fixedStatus,
  required _MockStackRouter mockRouter,
  required _StubAppRouter stubAppRouter,
  required UserDatabase db,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      restoreStatusProvider.overrideWithValue(fixedStatus),
      deviceRestoreServiceProvider.overrideWithValue(null),
      routerProvider.overrideWithValue(stubAppRouter),
      userDatabaseProvider.overrideWithValue(db),
      currentAccountIdProvider.overrideWithValue(1),
      selectedProfileIdProvider.overrideWith(
        () => _FixedSelectedProfileId(null),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: mockRouter,
        stateHash: 0,
        child: const DeviceRestoreScreen(),
      ),
    ),
  );
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(const AppShellRoute());
    registerFallbackValue(<PageRouteInfo>[const AppShellRoute()]);
    registerFallbackValue(const ProfilePickerRoute());
  });

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
            _buildHarness(
              fixedStatus: const RestoreStatus.restoring(
                phase: RestorePhase.pullingData,
                completedSteps: 0,
                totalSteps: 3,
              ),
              mockRouter: _makeRouter(),
              stubAppRouter: _makeAppRouter(),
              db: db,
              locale: const Locale('en'),
            ),
          );
          await tester.pump();

          // In EN locale the l10n value IS 'Restoring your data...' so the text
          // must still be present (no regression for existing English users).
          expect(find.text('Restoring your data...'), findsOneWidget);

          await _tearDown(tester);
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
            _buildHarness(
              fixedStatus: const RestoreStatus.restoring(
                phase: RestorePhase.pullingData,
                completedSteps: 0,
                totalSteps: 3,
              ),
              mockRouter: _makeRouter(),
              stubAppRouter: _makeAppRouter(),
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

          await _tearDown(tester);
        },
      );

      testWidgets(
        'he locale: RestorePhase.loadingCurricula renders Hebrew translation '
        '(SYNC-RESTORE-PHASE-02)',
        (tester) async {
          final db = UserDatabase(NativeDatabase.memory());
          addTearDown(db.close);

          await tester.pumpWidget(
            _buildHarness(
              fixedStatus: const RestoreStatus.restoring(
                phase: RestorePhase.loadingCurricula,
                completedSteps: 1,
                totalSteps: 3,
              ),
              mockRouter: _makeRouter(),
              stubAppRouter: _makeAppRouter(),
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

          await _tearDown(tester);
        },
      );

      testWidgets(
        'he locale: RestorePhase.importingContent renders Hebrew translation '
        '(SYNC-RESTORE-PHASE-03)',
        (tester) async {
          final db = UserDatabase(NativeDatabase.memory());
          addTearDown(db.close);

          await tester.pumpWidget(
            _buildHarness(
              fixedStatus: const RestoreStatus.restoring(
                phase: RestorePhase.importingContent,
                completedSteps: 2,
                totalSteps: 3,
              ),
              mockRouter: _makeRouter(),
              stubAppRouter: _makeAppRouter(),
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

          await _tearDown(tester);
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
