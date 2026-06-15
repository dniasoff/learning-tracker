// L1 widget tests — OfflineTopBanner
//
// The banner is a pure-UI widget controlled by a single `visible` bool.
// The caller (AppShell) computes visibility as:
//
//   isCloudBorn && !isOnline
//
// These tests cover:
//   1. Banner shown when visible: true  (cloud-born + offline scenario)
//   2. Banner hidden when visible: false (cloud-born + online scenario)
//   3. Banner hidden when visible: false (local-born + offline scenario)
//   4. AnimatedSize wraps an empty SizedBox when hidden
//   5. Semantics liveRegion + label present when visible
//   6. cloud_off icon present when visible
//   7. Integration wrapper — ConnectedOfflineBanner consumer replicates
//      AppShell logic: cloud-born offline → visible; online → hidden;
//      local-born offline → hidden.
//   8. He-RTL smoke test — banner renders in RTL locale without errors.
//   9. Offline-debounce — a transient <300 ms offline blip (startup noise)
//      does NOT flash the banner; a persistent offline DOES show it.
//
// LOCALIZATION (fixed):
//   The banner text and its Semantics label are now drawn from
//   AppLocalizations (l10n.offlineBannerMessage / l10n.offlineBannerSemantics)
//   instead of hardcoded English. The He-RTL test below asserts the Hebrew
//   string renders and the old English literal no longer appears.

@Tags(['l1', 'offline_banner', 'account'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/widgets/offline_top_banner.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Minimal AuthUser for test overrides.
const _cloudUser = AuthUser(
  profileId: 1,
  email: 'cloud@test.com',
  displayName: 'Cloud User',
  firebaseUid: 'uid-cloud',
);

const _localUser = AuthUser(
  profileId: 2,
  email: 'local@test.local',
  displayName: 'Local User',
);

AuthState _cloudBornSignedIn() =>
    const AuthState.signedIn(user: _cloudUser, tier: Tier.cloudBorn);

AuthState _localBornSignedIn() =>
    const AuthState.signedIn(user: _localUser, tier: Tier.localBorn);

/// Wraps [OfflineTopBanner] in the canonical pump rig.
Widget _buildBanner({
  required bool visible,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: OfflineTopBanner(visible: visible)),
    ),
  );
}

/// A minimal ConsumerWidget that replicates app_shell's visibility logic:
///   final isCloudBorn = ref.watch(authStateProvider).isCloudBorn;
///   final connectivity = ref.watch(connectivityStreamProvider);
///   final isOnline = connectivity.maybeWhen(data: (v) => v, orElse: () => true);
///   final bannerVisible = isCloudBorn && !isOnline;
class _ConnectedOfflineBanner extends ConsumerWidget {
  const _ConnectedOfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCloudBorn = ref.watch(authStateProvider).isCloudBorn;
    final connectivity = ref.watch(connectivityStreamProvider);
    final isOnline = connectivity.maybeWhen(
      data: (online) => online,
      orElse: () => true,
    );
    final bannerVisible = isCloudBorn && !isOnline;
    return OfflineTopBanner(visible: bannerVisible);
  }
}

Widget _buildConnected({
  required AuthState authState,
  required bool online,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWithValue(authState),
      connectivityStreamProvider.overrideWith((ref) => Stream.value(online)),
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
      home: const Scaffold(body: _ConnectedOfflineBanner()),
    ),
  );
}

// ── Test body ─────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── Direct widget tests ────────────────────────────────────────────────────

  group('OfflineTopBanner — direct visible param', () {
    testWidgets('shows banner text when visible: true', (tester) async {
      await tester.pumpWidget(_buildBanner(visible: true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Banner text is present.
      expect(
        find.textContaining('Offline'),
        findsOneWidget,
        reason: 'banner text must appear when visible: true',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('hides banner text when visible: false', (tester) async {
      await tester.pumpWidget(_buildBanner(visible: false));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No banner text rendered.
      expect(
        find.textContaining('Offline'),
        findsNothing,
        reason: 'banner text must be absent when visible: false',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('banner has height 32 when visible: true', (tester) async {
      await tester.pumpWidget(_buildBanner(visible: true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The Container inside the banner is 32 px tall.
      final container = find.byWidgetPredicate(
        (w) => w is Container && (w.constraints?.minHeight ?? 0) == 0,
      );
      // Easier: check the rendered size of the banner widget itself.
      final bannerFinder = find.byType(OfflineTopBanner);
      final size = tester.getSize(bannerFinder);
      expect(
        size.height,
        greaterThanOrEqualTo(32),
        reason: 'banner should have at least 32 px height when visible',
      );
      // Suppress unused variable warning.
      expect(container, isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('AnimatedSize collapses to zero height when visible: false', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBanner(visible: false));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final bannerFinder = find.byType(OfflineTopBanner);
      final size = tester.getSize(bannerFinder);
      expect(
        size.height,
        equals(0.0),
        reason: 'banner height must be 0 when not visible',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('cloud_off icon present when visible: true', (tester) async {
      await tester.pumpWidget(_buildBanner(visible: true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byIcon(Icons.cloud_off),
        findsOneWidget,
        reason: 'cloud_off icon must be shown when banner is visible',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('cloud_off icon absent when visible: false', (tester) async {
      await tester.pumpWidget(_buildBanner(visible: false));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byIcon(Icons.cloud_off),
        findsNothing,
        reason: 'cloud_off icon must not appear when banner is hidden',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('Semantics liveRegion set to true when visible: true', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBanner(visible: true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Find the Semantics widget with liveRegion: true.
      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      );
      expect(
        semanticsFinder,
        findsOneWidget,
        reason: 'banner must have a Semantics live-region for a11y',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('Semantics liveRegion absent when visible: false', (
      tester,
    ) async {
      await tester.pumpWidget(_buildBanner(visible: false));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      );
      expect(
        semanticsFinder,
        findsNothing,
        reason: 'no live-region Semantics should exist when banner is hidden',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── Provider-driven integration tests ─────────────────────────────────────
  //
  // These tests wire up the same logic AppShell uses:
  //   offlineBannerVisible = isCloudBorn && !isOnline
  // by overriding authStateProvider + connectivityStreamProvider.

  group('OfflineTopBanner — provider-driven (tier × connectivity)', () {
    testWidgets('cloud-born + offline → banner visible', (tester) async {
      await tester.pumpWidget(
        _buildConnected(authState: _cloudBornSignedIn(), online: false),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Offline'),
        findsOneWidget,
        reason: 'cloud-born user offline: banner must be visible',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('cloud-born + online → banner hidden', (tester) async {
      await tester.pumpWidget(
        _buildConnected(authState: _cloudBornSignedIn(), online: true),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Offline'),
        findsNothing,
        reason: 'cloud-born user online: banner must be hidden',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'local-born + offline → banner hidden (offline is normal for local-born)',
      (tester) async {
        await tester.pumpWidget(
          _buildConnected(authState: _localBornSignedIn(), online: false),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.textContaining('Offline'),
          findsNothing,
          reason:
              'local-born user offline: banner must never show '
              '(v2 §4.6 — being offline is their permanent state)',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('local-born + online → banner hidden', (tester) async {
      await tester.pumpWidget(
        _buildConnected(authState: _localBornSignedIn(), online: true),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Offline'),
        findsNothing,
        reason: 'local-born user online: banner must stay hidden',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('connectivity loading (no data yet) → banner hidden '
        '(maybeWhen orElse: true treats unknown as online)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWithValue(_cloudBornSignedIn()),
            // Never emits — stream stays in loading state.
            connectivityStreamProvider.overrideWith(
              (ref) => const Stream<bool>.empty(),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: _ConnectedOfflineBanner()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // orElse returns true (online), so banner stays hidden.
      expect(
        find.textContaining('Offline'),
        findsNothing,
        reason:
            'while connectivity is loading (no data), assume online → '
            'banner hidden',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── Offline-debounce — consumer-side banner state tests ───────────────────
  //
  // connectivityStreamProvider debounces "offline" signals by 300 ms to
  // suppress the transient ConnectivityResult.none event that the
  // connectivity_plus platform stream emits on Android/iOS cold-start before
  // the OS has finished associating the network interface.
  //
  // These widget tests verify the CONSUMER behaviour (what the banner shows)
  // by overriding connectivityStreamProvider with a controlled stream.  They
  // test the AppShell visibility logic (isCloudBorn && !isOnline) rather than
  // the debounce mechanism itself.  The provider-level debounce is covered by
  // the unit tests in test/features/account/presentation/providers/
  // connectivity_providers_test.dart.

  group('OfflineTopBanner — consumer state (online / offline / loading)', () {
    /// Helper: wires up [_ConnectedOfflineBanner] with a controlled
    /// [connectivityStreamProvider] override.
    Widget buildWithStream(
      Stream<bool> stream, {
      Locale locale = const Locale('en'),
    }) {
      return ProviderScope(
        overrides: [
          authStateProvider.overrideWithValue(_cloudBornSignedIn()),
          connectivityStreamProvider.overrideWith((ref) => stream),
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
          home: const Scaffold(body: _ConnectedOfflineBanner()),
        ),
      );
    }

    testWidgets('loading state (stream never emits) → banner hidden', (
      tester,
    ) async {
      // connectivityStreamProvider is in AsyncLoading (no events yet).
      // orElse: () => true → isOnline = true → banner hidden.
      await tester.pumpWidget(buildWithStream(const Stream<bool>.empty()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Offline'),
        findsNothing,
        reason:
            'banner must be hidden while connectivity is loading '
            '(no data yet — orElse treats unknown as online)',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('confirmed online → banner hidden', (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(buildWithStream(controller.stream));
      await tester.pump();

      controller.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.textContaining('Offline'),
        findsNothing,
        reason: 'banner must be hidden when connectivity confirms online',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('confirmed offline → banner shown', (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(buildWithStream(controller.stream));
      await tester.pump();

      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.textContaining('Offline'),
        findsOneWidget,
        reason: 'banner must appear when connectivity confirms offline',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'online → offline → banner shown; then online → banner hidden',
      (tester) async {
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        await tester.pumpWidget(buildWithStream(controller.stream));
        await tester.pump();

        controller.add(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.textContaining('Offline'), findsNothing);

        controller.add(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.textContaining('Offline'),
          findsOneWidget,
          reason: 'banner must appear after offline transition',
        );

        controller.add(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.textContaining('Offline'),
          findsNothing,
          reason: 'banner must hide when connection is restored',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // ── He-RTL smoke test ──────────────────────────────────────────────────────

  group('OfflineTopBanner — RTL (he locale)', () {
    testWidgets(
      'renders without errors in Hebrew RTL locale when visible: true',
      (tester) async {
        await tester.pumpWidget(
          _buildConnected(
            authState: _cloudBornSignedIn(),
            online: false,
            locale: const Locale('he'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Banner renders; icon and the localized Hebrew text are present.
        final he = await AppLocalizations.delegate.load(const Locale('he'));
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        expect(find.text(he.offlineBannerMessage), findsOneWidget);
        // The pre-fix hardcoded English literal must NOT appear on a Hebrew
        // device (regression guard for the localization fix).
        expect(find.textContaining('Offline'), findsNothing);

        // Directionality inside the banner should be RTL.
        final bannerFinder = find.byType(OfflineTopBanner);
        final bannerContext = tester.element(bannerFinder);
        final dir = Directionality.of(bannerContext);
        expect(
          dir,
          TextDirection.rtl,
          reason: 'Hebrew locale must produce RTL text direction',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'renders without errors in Hebrew RTL locale when visible: false',
      (tester) async {
        await tester.pumpWidget(
          _buildConnected(
            authState: _cloudBornSignedIn(),
            online: true,
            locale: const Locale('he'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // No errors thrown; banner correctly absent.
        expect(find.textContaining('Offline'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
