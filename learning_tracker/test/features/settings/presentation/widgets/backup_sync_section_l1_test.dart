// L1 behaviour tests for BackupSyncSection (DNI-188).
//
// Covers:
//   1. Cloud-born + SyncStatusSynced  → "Last synced Xm ago" subtitle.
//   2. Cloud-born + SyncStatusLocalOnly (transitional) → "Connecting…" subtitle.
//   3. Cloud-born + SyncStatusSyncing  → l10n "Syncing..." subtitle.
//   4. Cloud-born + SyncStatusPending  → "N changes pending" subtitle.
//   5. Cloud-born + SyncStatusOffline (no pending) → "Offline" subtitle.
//   6. Cloud-born + SyncStatusOffline (with pending) → "N changes pending".
//   7. Cloud-born + SyncStatusError    → sync error + tap-to-retry subtitle;
//      tapping retries via syncOrchestratorProvider.retryPull().
//   8. Cloud-born + SyncStatusDegraded → "Sync paused" subtitle.
//   9. Local-born user → "LOCAL ONLY" copy; Upgrade button present.
//  10. Local-born user + heroLayout → hero layout with Upgrade button.
//  11. Cloud-born user (non-local) local-only path → no Upgrade button.
//  12. Local-born, heroLayout=false → compact layout with Upgrade button.
//  13. Tapping Upgrade button calls context.pushRoute(UpgradeToCloudRoute).
//  14. RTL (he) smoke — widget renders without overflow.
//
// Hardcoded English strings (product-level, not l10n):
//   • "Backup & Sync" heading
//   • "Connecting…" (cloud-born transitional)
//   • "Offline" (zero-pending offline state)
//   • "LOCAL ONLY" (within upgrade-to-cloud copy)
//   • Degraded "Sync paused…" message
//
// These are flagged below as // HARDCODED.

@Tags(['l1', 'settings', 'backup_sync'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart';
import 'package:learning_tracker/core/sync/sync_identity_status.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/backup_sync_section.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

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

/// Pump harness for [BackupSyncSection].
///
/// [syncStatus]  — the [SyncStatus] surfaced by [syncStatusProvider].
/// [authState]   — the [AuthState] surfaced by [authStateProvider].
/// [orchestrator] — optional mock [SyncOrchestrator] (required for error tap tests).
/// [heroLayout]  — mirrors [BackupSyncSection.parentSettingsHeroLayout].
/// [locale]      — defaults to English; pass `const Locale('he')` for RTL smoke.
Widget _buildHarness({
  required SyncStatus syncStatus,
  required AuthState authState,
  SyncOrchestrator? orchestrator,
  bool heroLayout = false,
  Locale locale = const Locale('en'),
  // Defaults to matched so the degraded card does not transitively touch
  // FirebaseAuth via the real syncIdentityStatusProvider (which reads
  // authRepositoryProvider). Pass a mismatched value to exercise the re-auth
  // banner branch.
  SyncIdentityStatus identityStatus = const SyncIdentityStatus.matched(),
}) {
  final mockRouter = _MockStackRouter();
  when(() => mockRouter.push(any())).thenAnswer((_) async => null);
  when(() => mockRouter.navigate(any())).thenAnswer((_) async {});
  when(() => mockRouter.canPop()).thenReturn(false);

  return ProviderScope(
    overrides: [
      authStateProvider.overrideWithValue(authState),
      syncStatusProvider.overrideWith((_) => syncStatus),
      syncIdentityStatusProvider.overrideWithValue(identityStatus),
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
      final now = DateTime.now();
      final lastSynced = now.subtract(const Duration(minutes: 5));
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
      final now = DateTime.now();
      final lastSynced = now.subtract(const Duration(seconds: 30));
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

  group('BackupSyncSection — cloud-born pending', () {
    testWidgets('shows l10n backupPendingChanges subtitle', (tester) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: const SyncStatus.pending(pendingChanges: 3),
          authState: _kCloudUser,
        ),
      );

      // l10n: "3 changes pending"
      expect(find.textContaining('3 changes pending'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('BackupSyncSection — cloud-born offline', () {
    testWidgets('zero-pending offline shows "Offline"', (tester) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: const SyncStatus.offline(pendingChanges: 0),
          authState: _kCloudUser,
        ),
      );

      // HARDCODED: "Offline"
      expect(find.text('Offline'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('offline with pending shows l10n changes pending', (
      tester,
    ) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: const SyncStatus.offline(pendingChanges: 7),
          authState: _kCloudUser,
        ),
      );

      // l10n: "7 changes pending"
      expect(find.textContaining('7 changes pending'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('BackupSyncSection — cloud-born error', () {
    testWidgets('shows error message and tap-to-retry copy', (tester) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: SyncStatus.error(
            message: 'timeout',
            failedAt: DateTime.now(),
          ),
          authState: _kCloudUser,
        ),
      );

      // l10n: "Sync error: timeout"
      expect(find.textContaining('Sync error'), findsOneWidget);
      // l10n: "Tap to retry"
      expect(find.textContaining('Tap to retry'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('tapping error card calls orchestrator.retryPull()', (
      tester,
    ) async {
      final mockOrch = _MockSyncOrchestrator();
      when(() => mockOrch.retryPull()).thenAnswer((_) async {});

      await _pump(
        tester,
        _buildHarness(
          syncStatus: SyncStatus.error(
            message: 'network',
            failedAt: DateTime.now(),
          ),
          authState: _kCloudUser,
          orchestrator: mockOrch,
        ),
      );

      // Tap the InkWell wrapping the error card
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      verify(() => mockOrch.retryPull()).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('BackupSyncSection — cloud-born degraded', () {
    testWidgets('shows "Sync paused" with pending count', (tester) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: const SyncStatus.degraded(
            pendingChanges: 4,
            reason: 'Permission denied',
          ),
          authState: _kCloudUser,
        ),
      );

      // HARDCODED: "Sync paused — 4 queued. Permission denied"
      expect(find.textContaining('Sync paused'), findsOneWidget);
      expect(find.textContaining('4 queued'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('degraded with zero pending shows "Sync paused. reason"', (
      tester,
    ) async {
      await _pump(
        tester,
        _buildHarness(
          syncStatus: const SyncStatus.degraded(
            pendingChanges: 0,
            reason: 'quota exhausted',
          ),
          authState: _kCloudUser,
        ),
      );

      expect(find.textContaining('Sync paused'), findsOneWidget);
      expect(find.textContaining('quota exhausted'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'identity mismatch → re-auth banner with "Sign in to back up" button '
      'that routes to SignInRoute',
      (tester) async {
        final mockRouter = _MockStackRouter();
        when(() => mockRouter.push(any())).thenAnswer((_) async => null);
        when(() => mockRouter.navigate(any())).thenAnswer((_) async {});
        when(() => mockRouter.canPop()).thenReturn(false);

        await _pump(
          tester,
          ProviderScope(
            overrides: [
              authStateProvider.overrideWithValue(_kCloudUser),
              syncStatusProvider.overrideWith(
                (_) => const SyncStatus.degraded(
                  pendingChanges: 5,
                  reason:
                      'Signed in as familyniasoff@gmail.com — sign in as '
                      'dniasoff@gmail.com to back up this account.',
                ),
              ),
              syncIdentityStatusProvider.overrideWithValue(
                const SyncIdentityStatus.mismatched(
                  activeAccountEmail: 'dniasoff@gmail.com',
                  signedInEmail: 'familyniasoff@gmail.com',
                ),
              ),
            ],
            child: MaterialApp(
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
                child: const Scaffold(body: BackupSyncSection()),
              ),
            ),
          ),
        );

        // The actionable account name + the re-auth button are shown.
        expect(find.textContaining('dniasoff@gmail.com'), findsOneWidget);
        expect(find.text('Sign in to back up'), findsOneWidget);

        await tester.tap(find.text('Sign in to back up'));
        await tester.pump();

        // Routes to the sign-in screen so the user can authenticate as the
        // active account.
        final pushed = verify(() => mockRouter.push(captureAny())).captured;
        expect(pushed.single.runtimeType.toString(), 'SignInRoute');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
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
  // The subtitles for "Connecting…", "Offline", and "Sync paused…" were
  // hard-coded English literals. These tests assert that the Hebrew locale
  // shows the localized Hebrew text instead of the English literal.  They
  // were RED before the fix (hard-coded literals survive a locale change and
  // always show English) and GREEN after (l10n keys resolved to Hebrew).
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
            syncStatus: const SyncStatus.offline(pendingChanges: 0),
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

    testWidgets(
      'degraded subtitle is localized in he locale (not hard-coded English)',
      (tester) async {
        await _pump(
          tester,
          _buildHarness(
            syncStatus: const SyncStatus.degraded(
              pendingChanges: 2,
              reason: 'test reason',
            ),
            authState: _kCloudUser,
            locale: const Locale('he'),
          ),
        );

        // Hard-coded 'Sync paused' must NOT appear in Hebrew locale.
        expect(find.textContaining('Sync paused'), findsNothing);
        // The localized Hebrew text must appear instead.
        expect(find.textContaining('סנכרון מושהה'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
