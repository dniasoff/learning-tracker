// L1 behaviour tests for BackupSyncSection (DNI-188).
//
// Story 1.5 / AD-11 (owner-ratified, 2026-08-02): SyncStatus collapsed from
// 7 cases to synced | syncing | offline (+ localOnly). The differentiated
// SyncStatusError (appCheck/permissionDenied/timeout, tap-to-retry) and
// SyncStatusDegraded (stuck-outbox / identity-mismatch re-auth banner) cards
// this file used to cover no longer exist — see backup_sync_section.dart's
// class-level doc comment for the AD-30/Phase 3 replacement plan. Their
// coverage groups (formerly #4, #6, #7, #8) were removed below rather than
// adapted, since the UI they exercised was deleted, not changed.
//
// Covers:
//   1. Cloud-born + SyncStatusSynced  → "Last synced Xm ago" subtitle.
//   2. Cloud-born + SyncStatusLocalOnly (transitional) → "Connecting…" subtitle.
//   3. Cloud-born + SyncStatusSyncing  → l10n "Syncing..." subtitle.
//   4. Cloud-born + SyncStatusOffline  → "Offline" subtitle (no pendingChanges
//      variant — the state carries no count at all now).
//   5. Local-born user → "LOCAL ONLY" copy; Upgrade button present.
//   6. Local-born user + heroLayout → hero layout with Upgrade button.
//   7. Cloud-born user (non-local) local-only path → no Upgrade button.
//   8. Local-born, heroLayout=false → compact layout with Upgrade button.
//   9. Tapping Upgrade button calls context.pushRoute(UpgradeToCloudRoute).
//  10. RTL (he) smoke — widget renders without overflow.
//
// Hardcoded English strings (product-level, not l10n):
//   • "Backup & Sync" heading
//   • "Connecting…" (cloud-born transitional)
//   • "Offline" (offline state)
//   • "LOCAL ONLY" (within upgrade-to-cloud copy)
//
// These are flagged below as // HARDCODED.

@Tags(['l1', 'settings', 'backup_sync'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/backup_sync_section.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_clock.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _kCloudUser = AuthState.signedIn(
  user: AuthUser(
    profileId: 1,
    email: 'cloud@test.com',
    displayName: 'Cloud User',
    firebaseUid: 'uid-cloud',
  ),
  tier: Tier.cloudBorn,
);

const _kLocalUser = AuthState.signedIn(
  user: AuthUser(
    profileId: 2,
    email: 'local@test.com',
    displayName: 'Local User',
  ),
  tier: Tier.localBorn,
);

// AUD-t-settings-10: fixed instant for the relative-time ("just now"/"Xm
// ago") assertions below. `_formatTimeAgo` reads
// `DateTimeFactory.nowLocal()`, which is gated by the global
// `currentLocalDayClock` (installed via `useLocalDayClock`), not by
// `localDayClockProvider` — so each relative-time test must call
// `useLocalDayClock(FakeLocalDayClock(_kFixedNow))` and derive
// `lastSyncedAt` from this same instant, never from a bare
// `DateTime.now()` wall-clock read (TQ-6).
final _kFixedNow = DateTime(2026, 6, 15, 10);

/// Pump harness for [BackupSyncSection].
///
/// [syncStatus]  — the [SyncStatus] surfaced by [syncStatusProvider].
/// [authState]   — the [AuthState] surfaced by [authStateProvider].
/// [orchestrator] — optional mock [SyncOrchestrator] (required for cold-launch
///   pull-trigger tests).
/// [heroLayout]  — mirrors [BackupSyncSection.parentSettingsHeroLayout].
/// [locale]      — defaults to English; pass `const Locale('he')` for RTL smoke.
Widget _buildHarness({
  required SyncStatus syncStatus,
  required AuthState authState,
  SyncOrchestrator? orchestrator,
  bool heroLayout = false,
  Locale locale = const Locale('en'),
}) {
  final mockRouter = _MockStackRouter();
  when(() => mockRouter.push(any())).thenAnswer((_) async => null);
  when(() => mockRouter.navigate(any())).thenAnswer((_) async {});
  when(() => mockRouter.canPop()).thenReturn(false);

  return ProviderScope(
    overrides: [
      authStateProvider.overrideWithValue(authState),
      syncStatusProvider.overrideWith((_) => syncStatus),
      if (orchestrator != null)
        syncOrchestratorProvider.overrideWith((_) => orchestrator),
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
        child: Scaffold(
          body: BackupSyncSection(parentSettingsHeroLayout: heroLayout),
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // flutter_test_config.dart already sets GoogleFonts.config.allowRuntimeFetching = false.

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  tearDown(() async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      // nothing to close — no DB in these tests
    });
  });

  group('BackupSyncSection — cloud-born synced', () {
    testWidgets('shows "Backup & Sync" heading and last-synced subtitle', (
      tester,
    ) async {
      installFakeClock(_kFixedNow);
      final lastSynced = _kFixedNow.subtract(const Duration(minutes: 5));
      await _pump(
        tester,
        _buildHarness(
          syncStatus: SyncStatus.synced(lastSyncedAt: lastSynced),
          authState: _kCloudUser,
        ),
      );

      // HARDCODED: heading text
      expect(find.text('Backup & Sync'), findsAtLeastNWidgets(1));
      // l10n: "Last synced 5m ago"
      expect(find.textContaining('5m ago'), findsOneWidget);
      expect(find.textContaining('Last synced'), findsOneWidget);

      // Teardown
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('shows "just now" when sync was under 1 minute ago', (
      tester,
    ) async {
      installFakeClock(_kFixedNow);
      final lastSynced = _kFixedNow.subtract(const Duration(seconds: 30));
      await _pump(
        tester,
        _buildHarness(
          syncStatus: SyncStatus.synced(lastSyncedAt: lastSynced),
          authState: _kCloudUser,
        ),
      );

      expect(find.textContaining('just now'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // RED→GREEN [P2]: the relative-time strings ('just now', 'Xm ago', 'Xh ago',
    // 'Xd ago') were hardcoded English. Under a Hebrew UI they must render the
    // localized Hebrew form, never the English literal.
    testWidgets(
      'he locale: minutes-ago relative time is localized (no English)',
      (tester) async {
        installFakeClock(_kFixedNow);
        final lastSynced = _kFixedNow.subtract(const Duration(minutes: 5));
        await _pump(
          tester,
          _buildHarness(
            syncStatus: SyncStatus.synced(lastSyncedAt: lastSynced),
            authState: _kCloudUser,
            locale: const Locale('he'),
          ),
        );

        expect(
          find.textContaining('m ago'),
          findsNothing,
          reason: 'Hardcoded English relative-time must not leak into he UI',
        );
        // Localized Hebrew minutes-ago form (backupTimeAgoMinutes → "לפני 5 דק'").
        expect(find.textContaining('דק'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('he locale: "just now" is localized (no English literal)', (
      tester,
    ) async {
      installFakeClock(_kFixedNow);
      final lastSynced = _kFixedNow.subtract(const Duration(seconds: 30));
      await _pump(
        tester,
        _buildHarness(
          syncStatus: SyncStatus.synced(lastSyncedAt: lastSynced),
          authState: _kCloudUser,
          locale: const Locale('he'),
        ),
      );

      expect(
        find.textContaining('just now'),
        findsNothing,
        reason: 'Hardcoded English "just now" must not leak into he UI',
      );
      // Localized Hebrew "just now" (backupTimeAgoJustNow → "ממש עכשיו").
      expect(find.textContaining('עכשיו'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group(
    'BackupSyncSection — cloud-born + connecting (transitional LocalOnly)',
    () {
      testWidgets(
        'cloud-born user with SyncStatusLocalOnly sees Connecting not upgrade prompt',
        (tester) async {
          await _pump(
            tester,
            _buildHarness(
              syncStatus: const SyncStatus.localOnly(),
              authState: _kCloudUser,
            ),
          );

          // HARDCODED: "Connecting…" subtitle
          expect(find.textContaining('Connecting'), findsOneWidget);
          // Must NOT show the upgrade CTA
          expect(find.text('Upgrade to Cloud'), findsNothing);
          // Must NOT show LOCAL ONLY copy
          expect(find.textContaining('LOCAL ONLY'), findsNothing);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(Duration.zero);
        },
      );
    },
  );

  group('BackupSyncSection — cloud-born syncing', () {
    testWidgets('shows l10n backupSyncing subtitle', (tester) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: SyncStatus.syncing(startedAt: DateTime.now()),
          authState: _kCloudUser,
        ),
      );

      // l10n: "Syncing..."
      expect(find.textContaining('Syncing'), findsOneWidget);
      expect(find.text('Upgrade to Cloud'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('BackupSyncSection — cloud-born offline', () {
    testWidgets('shows "Offline"', (tester) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: const SyncStatus.offline(),
          authState: _kCloudUser,
        ),
      );

      // HARDCODED: "Offline"
      expect(find.text('Offline'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('BackupSyncSection — local-born user', () {
    testWidgets(
      'compact layout: shows LOCAL ONLY copy and Upgrade button (local-born)',
      (tester) async {
        await _pump(
          tester,
          _buildHarness(
            syncStatus: const SyncStatus.localOnly(),
            authState: _kLocalUser,
            heroLayout: false,
          ),
        );

        // HARDCODED: "LOCAL ONLY"
        expect(find.textContaining('LOCAL ONLY'), findsAtLeastNWidgets(1));
        // l10n: backupUpgradeToCloud or upgradeToCloudButton
        expect(
          find.textContaining('Upgrade to Cloud'),
          findsAtLeastNWidgets(1),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'hero layout: shows LOCAL ONLY copy and Upgrade button (local-born)',
      (tester) async {
        await _pump(
          tester,
          _buildHarness(
            syncStatus: const SyncStatus.localOnly(),
            authState: _kLocalUser,
            heroLayout: true,
          ),
        );

        expect(find.textContaining('LOCAL ONLY'), findsAtLeastNWidgets(1));
        // In hero layout the button text is l10n backupUpgradeToCloud
        expect(
          find.textContaining('Upgrade to Cloud'),
          findsAtLeastNWidgets(1),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('tapping Upgrade button calls pushRoute(UpgradeToCloudRoute)', (
      tester,
    ) async {
      final mockRouter = _MockStackRouter();
      when(() => mockRouter.push(any())).thenAnswer((_) async => null);
      when(() => mockRouter.navigate(any())).thenAnswer((_) async {});
      when(() => mockRouter.canPop()).thenReturn(false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWithValue(_kLocalUser),
            syncStatusProvider.overrideWith(
              (_) => const SyncStatus.localOnly(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
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
              child: const Scaffold(
                body: BackupSyncSection(parentSettingsHeroLayout: false),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Find the FilledButton that contains "Upgrade to Cloud"
      final upgradeButton = find.widgetWithText(
        FilledButton,
        'Upgrade to Cloud',
      );
      expect(upgradeButton, findsAtLeastNWidgets(1));
      await tester.tap(upgradeButton.first);
      await tester.pump();

      verify(() => mockRouter.push(any())).called(greaterThanOrEqualTo(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('BackupSyncSection — cold-launch pull trigger (BUG 2)', () {
    testWidgets(
      'cloud-born + localOnly on mount kicks orchestrator.pullOnLaunch() so '
      'the status resolves without a background→foreground cycle',
      (tester) async {
        final mockOrch = _MockSyncOrchestrator();
        when(
          () => mockOrch.currentStatus,
        ).thenReturn(const SyncStatus.localOnly());
        when(
          () => mockOrch.statusStream,
        ).thenAnswer((_) => const Stream.empty());
        when(() => mockOrch.pullOnLaunch()).thenAnswer((_) async {});

        await _pump(
          tester,
          _buildHarness(
            syncStatus: const SyncStatus.localOnly(),
            authState: _kCloudUser,
            orchestrator: mockOrch,
          ),
        );

        // The mount-time post-frame callback must have triggered a cold-start
        // pull (once-per-launch guard makes a duplicate call cheap/no-op).
        verify(() => mockOrch.pullOnLaunch()).called(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'cloud-born already synced on mount does NOT kick another pull',
      (tester) async {
        final synced = SyncStatus.synced(lastSyncedAt: DateTime.now());
        final mockOrch = _MockSyncOrchestrator();
        when(() => mockOrch.currentStatus).thenReturn(synced);
        when(
          () => mockOrch.statusStream,
        ).thenAnswer((_) => const Stream.empty());
        when(() => mockOrch.pullOnLaunch()).thenAnswer((_) async {});

        await _pump(
          tester,
          _buildHarness(
            syncStatus: synced,
            authState: _kCloudUser,
            orchestrator: mockOrch,
          ),
        );

        verifyNever(() => mockOrch.pullOnLaunch());

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('local-born on mount does NOT kick a pull', (tester) async {
      final mockOrch = _MockSyncOrchestrator();
      when(
        () => mockOrch.currentStatus,
      ).thenReturn(const SyncStatus.localOnly());
      when(() => mockOrch.statusStream).thenAnswer((_) => const Stream.empty());
      when(() => mockOrch.pullOnLaunch()).thenAnswer((_) async {});

      await _pump(
        tester,
        _buildHarness(
          syncStatus: const SyncStatus.localOnly(),
          authState: _kLocalUser,
          orchestrator: mockOrch,
        ),
      );

      verifyNever(() => mockOrch.pullOnLaunch());

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('BackupSyncSection — cloud-born without Upgrade CTA', () {
    testWidgets(
      'signed-in cloud-born user on SyncStatusLocalOnly has no Upgrade button',
      (tester) async {
        // cloud-born user briefly sees localOnly while orchestrator boots
        await _pump(
          tester,
          _buildHarness(
            syncStatus: const SyncStatus.localOnly(),
            authState: _kCloudUser,
          ),
        );

        expect(find.text('Upgrade to Cloud'), findsNothing);
        expect(find.textContaining('Connecting'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('cloud-born user on SyncStatusSynced has no Upgrade button', (
      tester,
    ) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: SyncStatus.synced(
            lastSyncedAt: DateTime.now().subtract(const Duration(minutes: 2)),
          ),
          authState: _kCloudUser,
        ),
      );

      expect(find.text('Upgrade to Cloud'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('BackupSyncSection — RTL smoke (he)', () {
    testWidgets('Hebrew locale renders without overflow or crash', (
      tester,
    ) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: SyncStatus.synced(
            lastSyncedAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
          authState: _kCloudUser,
          locale: const Locale('he'),
        ),
      );

      // Just verify the widget renders without throwing
      expect(find.byType(BackupSyncSection), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'Hebrew locale local-born renders local-only card without overflow',
      (tester) async {
        await _pump(
          tester,
          _buildHarness(
            syncStatus: const SyncStatus.localOnly(),
            authState: _kLocalUser,
            locale: const Locale('he'),
          ),
        );

        expect(find.byType(BackupSyncSection), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // SYNC-BACKUP-07: he-RTL i18n regression tests.
  //
  // The subtitles for "Connecting…" and "Offline" were hard-coded English
  // literals. These tests assert that the Hebrew locale shows the localized
  // Hebrew text instead of the English literal. They were RED before the fix
  // (hard-coded literals survive a locale change and always show English) and
  // GREEN after (l10n keys resolved to Hebrew).
  group('BackupSyncSection — SYNC-BACKUP-07 he-RTL i18n regression', () {
    testWidgets(
      'connecting subtitle is localized in he locale (not hard-coded English)',
      (tester) async {
        await _pump(
          tester,
          _buildHarness(
            syncStatus: const SyncStatus.localOnly(),
            authState: _kCloudUser,
            locale: const Locale('he'),
          ),
        );

        // Hard-coded 'Connecting…' must NOT appear in Hebrew locale.
        expect(find.text('Connecting…'), findsNothing);
        expect(find.text('Connecting...'), findsNothing);
        // The localized Hebrew text must appear instead.
        expect(find.textContaining('מתחבר'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'offline subtitle is localized in he locale (not hard-coded English)',
      (tester) async {
        await _pump(
          tester,
          _buildHarness(
            syncStatus: const SyncStatus.offline(),
            authState: _kCloudUser,
            locale: const Locale('he'),
          ),
        );

        // Hard-coded 'Offline' must NOT appear in Hebrew locale.
        expect(find.text('Offline'), findsNothing);
        // The localized Hebrew text must appear instead.
        expect(find.textContaining('לא מקוון'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
