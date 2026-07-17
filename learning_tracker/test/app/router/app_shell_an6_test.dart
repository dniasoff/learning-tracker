// Regression test for AN-6:
// Bottom-nav "DASHBOARD" label truncates to "DASHBOA…" at font_scale 1.3.
//
// Root cause: _ShellNavItem applied horizontal padding to its pill container
// (padding: horizontal: 6, margin: horizontal: 4) which squeezed the label.
// Fix: reduced to padding: horizontal: 4, margin: horizontal: 2.
//
// AUD-t-cross-40: the original version of this test defined
// `_ShellNavItemReplica`, a hand-copied literal duplicate of the real
// (private) `_ShellNavItem` in app_shell.dart, and pumped that instead. The
// only thing keeping the replica's dimensions in sync with the real widget
// was a code comment — an edit to the real `_ShellNavItem` could silently
// reintroduce AN-6 while this test stayed green.
//
// Fix for THIS finding: pump the REAL `AppShellScreen` through the same
// router/provider harness `test/core/navigation/app_shell_test.dart` already
// uses for other AppShell scenarios (real `AppRouter` + guards + a seeded
// in-memory profile), at a narrow device width and 1.3x text scale, and
// assert the real "DASHBOARD" label's `RenderParagraph` never truncates.
//
// The device width is DERIVED, not a hand-picked literal: `flutter test`'s
// headless text renderer has no real font loaded (GoogleFonts fetching is
// disabled in tests — see setUpAll below), so the glyph metrics it produces
// do not match the shipped PlusJakartaSans typeface on a real device. A
// hardcoded "375" would either never overflow under this fallback metric
// (giving the same false confidence this finding exists to fix) or overflow
// regardless of the fix.
//
// AUD-t-cross-40 (second pass): the FIRST rewrite of this test (which added
// the real-widget import) still derived its target device width from a
// standalone `TextPainter` built with a bare `TextStyle` — not from the
// widget tree itself. That TextPainter measured "DASHBOARD" at ~108.8px,
// but the REAL `RenderParagraph` the widget actually lays out measures only
// ~72.7px in this same test binding/style/scale (the ambient `Directionality`
// / theme text style resolution the live widget goes through does not
// exactly match a freestanding TextPainter). Sizing the device from the
// inflated estimate made the "narrow" width wide enough that even the
// PRE-FIX chrome (margin h:4 / padding h:6) never actually overflowed —
// reverting the AN-6 fix left this test green. Proven by: temporarily
// reverting `_ShellNavItem`'s padding/margin to the pre-fix values did NOT
// turn the old version of this test red.
//
// Fix for THIS pass: measure the label from the REAL, live `RenderParagraph`
// instead of a freestanding TextPainter. The test first pumps the actual
// widget tree at a generously wide device width (1200px — wide enough that
// no plausible chrome could clip a 4-9 character label), reads the "DASHBOARD"
// `RenderParagraph`'s actual laid-out width off that live tree, then RESIZES
// (not rebuilds) the same mounted tree down to a derived narrow width so the
// FIXED per-item chrome (margin: horizontal 2, padding: horizontal 4) leaves
// just enough content width to fit that measured label with a small safety
// margin — the same margin the PRE-FIX chrome (margin: horizontal 4, padding:
// horizontal 6) falls short by, so the two dimensions bracket the pass/fail
// boundary symmetrically. Verified red-first: temporarily reverting
// `_ShellNavItem`'s fixed padding/margin back to the pre-fix values turns
// this test red (see commit message for the captured failure output);
// restoring the fix turns it green again.

@Tags(['account', 'app_shell', 'an6'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/app_shell.dart' show AppShellScreen;
import 'package:learning_tracker/app/router/guards/auth_guard.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

class MockPinService extends Mock implements PinService {}

/// Pins the active profile id deterministically so the shell resolves the
/// seeded profile (id 1) and stays on the Dashboard tab.
class _FixedActiveProfileId extends ActiveProfileId {
  @override
  int build() => 1;
}

Future<AppRouter> _createAuthenticatedRouter() async {
  final mockPinService = MockPinService();
  when(() => mockPinService.hasParentPin()).thenAnswer((_) async => false);

  final testDb = createTestDatabase();
  // ProfileGuard validates the selected profile id exists in the current DB
  // before short-circuiting, so the guard DB must hold a profile whose id
  // matches getSelectedProfileId() → 1.
  await seedProfileWithIds(testDb, profileId: 1, accountId: 1);
  final restoreGuard = RestoreGuard(
    getDatabase: () => testDb,
    hasCloudAccount: () => false,
  );
  restoreGuard.markRestoreComplete();

  return AppRouter(
    authGuard: AuthGuard(),
    restoreGuard: restoreGuard,
    profileGuard: ProfileGuard(
      getDatabase: () => testDb,
      getSelectedProfileId: () => 1,
      setSelectedProfileId: (_) {},
      getAccountId: () => 1,
      isTutoredSession: () => false,
    ),
    childModeGuard: ChildModeGuard(
      getDatabase: () => testDb,
      getSelectedProfileId: () => 1,
    ),
    pinGuard: PinGuard(
      pinService: mockPinService,
      promptForPin: () async => false,
      getScope: () => const PinScope.parent(1),
    ),
  );
}

const _authOverride = AuthState.signedIn(
  user: AuthUser(profileId: 1, email: 'test@test.com', displayName: 'Test'),
  tier: Tier.localBorn,
);

/// A single own adult profile so AppShell sees a non-empty profile list and
/// does NOT trigger the profile-less → Settings-tab jump — it stays on the
/// Dashboard tab, which is what this shell-navigation test exercises.
final _seededProfiles = [
  ProfileModel(
    id: 1,
    accountId: 1,
    displayName: 'Test',
    mode: 'adult',
    avatarIndex: 0,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  ),
];

/// Pump enough frames for navigation and async providers to resolve,
/// without using pumpAndSettle (which hangs on stream providers).
Future<void> _pumpDashboard(WidgetTester tester) async {
  await tester.pump(); // initial frame
  await tester.pump(const Duration(milliseconds: 500)); // async resolution
  await tester.pump(); // rebuild
}

/// Force-disposes the widget tree and drains Drift's zero-duration cleanup
/// timers so the test framework's `_verifyInvariants` sees no pending timers.
Future<void> _cleanUpWidgets(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// Wraps the router in a MaterialApp configured with the same localization
/// delegates as production main.dart, forcing [textScale] on top of the
/// ambient MediaQuery — matching AN-6's "font_scale 1.3" repro condition.
MaterialApp _wrapAppAtTextScale(
  RouterConfig<Object> routerConfig, {
  required double textScale,
}) {
  return MaterialApp.router(
    routerConfig: routerConfig,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(textScaler: TextScaler.linear(textScale)),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

/// Locates the "DASHBOARD" label's [RenderParagraph] and asserts it did not
/// visually truncate — i.e. Flutter's `TextOverflow.ellipsis` clipping never
/// engaged. This checks `didExceedMaxLines`, NOT `Text.data` (which
/// `TextOverflow.ellipsis` never mutates), so it actually detects the AN-6
/// truncation instead of an assertion that can never fail.
void _expectDashboardLabelNotTruncated(WidgetTester tester) {
  final textFinder = find.text('DASHBOARD');
  expect(
    textFinder,
    findsOneWidget,
    reason: 'DASHBOARD text widget must be present',
  );
  final paragraph = tester.renderObject<RenderParagraph>(textFinder);
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason: 'AN-6: DASHBOARD label must not be truncated with ellipsis',
  );
}

/// Derives a simulated device width that brackets the AN-6 pass/fail
/// boundary in THIS test environment's font metrics (see file header for
/// why a hardcoded width would not work, and why [labelWidth] MUST come from
/// the real, live `RenderParagraph` rather than a freestanding `TextPainter`
/// estimate). Sizes the device so the FIXED per-item chrome
/// ([fixedItemChromeWidth]) clears [labelWidth] by a safety margin equal to
/// half the gap between [preFixItemChromeWidth] and [fixedItemChromeWidth] —
/// the same margin by which the PRE-FIX chrome falls short, so the two
/// dimensions land symmetrically on either side of the truncation boundary.
double _deriveNarrowShellWidth({
  required double labelWidth,
  required double fixedItemChromeWidth,
  required double preFixItemChromeWidth,
  required int tabCount,
  required double outerHorizontalPadding,
}) {
  final chromeSwing = preFixItemChromeWidth - fixedItemChromeWidth;
  final safetyMargin = chromeSwing / 2;
  final requiredItemWidth = labelWidth + safetyMargin + fixedItemChromeWidth;
  return requiredItemWidth * tabCount + outerHorizontalPadding;
}

void main() {
  late UserDatabase db;

  setUpAll(() {
    // Prevent google_fonts from making real HTTP requests in tests.
    // Without this, font-loading futures cause 10-minute test timeouts.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Suppress Drift "multiple database" warning in tests where router
    // helpers and setUp each create their own in-memory database.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    // Suppress google_fonts "font not found in assets" errors — PlusJakartaSans
    // is not bundled in test assets, but navigation tests don't need real fonts.
    final savedOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exception.toString();
      if (msg.contains('GoogleFonts') || msg.contains('google_fonts')) return;
      savedOnError?.call(details);
    };

    // Mock path_provider so driftDatabase can resolve in the auth guard
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getTemporaryDirectory' ||
                methodCall.method == 'getApplicationDocumentsDirectory' ||
                methodCall.method == 'getApplicationSupportDirectory') {
              return '/tmp/flutter_test';
            }
            return null;
          },
        );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('AN-6 regression — DASHBOARD label truncation at font_scale 1.3', () {
    testWidgets(
      'DASHBOARD label fits inside the real AppShell nav item at font_scale '
      '1.3 on a narrow simulated device width (AN-6 fixed)',
      (tester) async {
        // Start at a generously wide device width — wide enough that no
        // plausible chrome (pre- or post-fix) could clip a short all-caps
        // label — so the FIRST measurement below reflects the label's true
        // unclipped size, not a truncated one.
        const wideWidth = 1200.0;
        tester.view.physicalSize = const Size(wideWidth, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = await _createAuthenticatedRouter();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              userDatabaseProvider.overrideWithValue(db),
              authStateProvider.overrideWithValue(_authOverride),
              profileListStreamProvider.overrideWith(
                (ref) => Stream.value(_seededProfiles),
              ),
              activeProfileIdProvider.overrideWith(_FixedActiveProfileId.new),
              dashboardActiveCurriculaStreamProvider.overrideWith(
                (ref) => Stream.value(<CurriculumId>[]),
              ),
              dashboardStreakProvider.overrideWith(
                (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
              ),
              dashboardStreakRecoveryProvider.overrideWith(
                (ref) => Future.value(
                  const StreakRecoveryInfo(
                    wasRecovered: false,
                    currentStreak: 0,
                  ),
                ),
              ),
            ],
            child: _wrapAppAtTextScale(
              router.config(
                deepLinkBuilder: (_) => const DeepLink.path('/dashboard'),
              ),
              textScale: 1.3,
            ),
          ),
        );
        await _pumpDashboard(tester);

        // Sanity: the REAL AppShellScreen (imported from app_shell.dart, not
        // a replica) rendered — not some fallback/redirect.
        expect(find.byType(AppShellScreen), findsOneWidget);
        expect(find.text('DASHBOARD'), findsOneWidget);
        expect(find.text('LEARN'), findsOneWidget);
        expect(find.text('PROGRESS'), findsOneWidget);
        expect(find.text('SETTINGS'), findsOneWidget);

        // Measure the REAL, live "DASHBOARD" RenderParagraph — not a
        // freestanding TextPainter (see file header for why that diverged
        // from the widget's actual rendered size and made the old version of
        // this test unable to catch the AN-6 regression).
        final labelWidth = tester
            .renderObject<RenderParagraph>(find.text('DASHBOARD'))
            .size
            .width;

        // See the file header for why this width is derived from a real
        // text measurement instead of a hardcoded literal like "375".
        final deviceWidth = _deriveNarrowShellWidth(
          labelWidth: labelWidth,
          // Fix: _ShellNavItem's pill uses
          // margin: horizontal 2, padding: horizontal 4 (app_shell.dart).
          fixedItemChromeWidth: 2 * 2 + 4 * 2,
          // Pre-fix: margin: horizontal 4, padding: horizontal 6.
          preFixItemChromeWidth: 4 * 2 + 6 * 2,
          tabCount: 4,
          // bottomNavigationBuilder's outer
          // Padding(EdgeInsets.fromLTRB(12, 10, 12, 10)).
          outerHorizontalPadding: 12 * 2,
        );

        // Resize (not rebuild) the SAME mounted widget/provider tree down to
        // the derived narrow width and relayout, so both measurements come
        // from identical widget/provider state — only the device width
        // changes.
        tester.view.physicalSize = Size(deviceWidth, 800);
        await tester.pump();

        _expectDashboardLabelNotTruncated(tester);

        expect(
          tester.takeException(),
          isNull,
          reason: 'AppShell bottom nav must not overflow at 1.3x font scale',
        );

        await _cleanUpWidgets(tester);
      },
    );
  });
}
