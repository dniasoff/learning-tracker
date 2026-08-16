// Dark-mode legibility sweep — Settings feature area (owner decision #2,
// docs/planning/post-sweep-decisions.md).
//
// Modelled on test/core/theme/darkmode_sweep_contrast_test.dart's WCAG
// helper + widget-pump style. Each finding below documents the pre-fix
// literal, the measured (red) ratio, the fix, and the measured (green)
// ratio — the red numbers are reproducible by swapping the token back for
// the literal in the assertion (done inline via `_oldXxx` constants so the
// red demo does not require touching production code).
//
// Finding 1 — SettingsScreen "Send Diagnostic Logs" tile icon-pill
// background (`iconBackground`): a hardcoded `Color(0xFFF0F1F5)` under the
// already brightness-aware `brandInkMuted` icon (which LIGHTENS in dark) —
// icon and background stopped matching, measured 2.28:1 in dark. Fixed by
// pointing the background at `brandCreamSoft` (near-identical light value;
// darkens with the icon in dark), 5.97:1.
//
// Finding 2 — SettingsScreen "Parent Mode" tile icon-pill background: a
// hardcoded `Color(0xFFF8E3E7)` under `brandCoralDeep` (an ink role that
// LIGHTENS in dark) — measured 1.42:1 in dark. Fixed by pointing the
// background at `brandCoralSoft`, `brandCoralDeep`'s own paired tint
// container (used together everywhere else in the app), 9.32:1.
//
// Finding 3 — SettingsScreen `_TutorGrantTile` (pending/active tutor grant
// preview row): bg/border/icon/text were four hardcoded, brightness-fixed
// pastel literals, so the card never darkened. Fixed by reusing the app's
// existing solid confirmation-card pairs — `statusSuccessSoftBg`/
// `statusSuccessSoftText` (active) and `statusWarningSoft`/
// `statusWarningSoftText` (pending) — 7.67–8.64:1 in dark, 4.55–4.68:1 in
// light (was 4.56:1 / **2.49:1** — light mode was already failing here;
// the fix incidentally clears it too).
//
// Finding 4 — LifetimeMarkingScreen `_LifetimeLibraryCategoryCard` (the
// curriculum-overview tiles): a hardcoded `Colors.white` background under
// `brandInk` text (near-white in dark) — white-on-white, measured 1.16:1,
// the same pair already proven in darkmode_sweep_contrast_test.dart.
// Fixed by pointing the background at `brandCreamCard`.
//
// Finding 5 — LifetimeCurriculumMarkingScreen's own `AppBar` (distinct from
// the picker CARD already fixed/tested as Finding 8 in
// darkmode_sweep_contrast_test.dart): a hardcoded `Colors.white`
// background under `brandInk` (title/foreground) and `brandBlueDeep` (back
// icon) — both near-white/light in dark — measured 1.16:1 / 1.63:1. Fixed
// by pointing the background at `brandCreamCard`.
//
// Finding 6 — account_actions.dart `showSignOutConfirmation`'s "Sign Out"
// FilledButton foreground, and the small "?" badge icon on the same
// dialog: both hardcoded `Colors.white` painted on a `brandBlue` fill.
// `brandBlue` LIGHTENS in dark (it is an ink-role token, used here as a
// fill) — a fixed white label/icon sank to 2.52:1. Fixed by reading
// `theme.colorScheme.onPrimary` — the app's own contrast-computed pair for
// this exact fill (already used by every FilledButton that does not
// override its foreground): ~7–8:1 in dark depending on exact luminance,
// ~8.4:1 in light.
//
// Finding 7 — account_actions.dart "Cancel" TextButton background (sign-out
// dialog): a hardcoded `Color(0xFFF0F1F5)` under `brandInkMuted` — the same
// bug/fix shape as Finding 1, measured 2.28:1 in dark, 5.97:1 fixed.
//
// Finding 8 — account_actions.dart sign-out-failure SnackBar: background
// was `brandCoralDeep` (an ink role, lightens in dark) under the SnackBar
// theme's own near-white-in-dark default text — both went light together,
// measured 1.5:1 in dark. Fixed by using `theme.colorScheme.error`/
// `onError` (the same auto-contrast mechanism as Finding 6, applied to the
// error role) with an explicit text style — 7.6:1 in dark, 5.52:1 in light
// (was 5.87:1; still comfortably >4.5:1).
//
// Finding 9 — UserProfileHeaderCard's avatar outer ring border: a
// hardcoded `Colors.white`, meant to blend with the surrounding card
// (`brandCreamCard`) but staying white in dark mode — creating a bright
// halo around the avatar instead of blending with the (now-dark) card.
// Fixed by pointing the border at `brandCreamCard` (pixel-identical to the
// old literal in light).
@Tags(['settings'])
library;

import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/network/connectivity_gateway.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/network_providers.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/domain/services/account_management_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/lifetime_marking_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:learning_tracker/features/settings/presentation/utils/account_actions.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/user_profile_header_card.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show incomingTutorGrantsProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../helpers/pump_app.dart';

// ─── WCAG helper (mirrors darkmode_sweep_contrast_test.dart) ────────────────

double _relativeLuminance(Color c) {
  double channel(double v) {
    final s = v / 255.0;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel((c.r * 255).roundToDouble()) +
      0.7152 * channel((c.g * 255).roundToDouble()) +
      0.0722 * channel((c.b * 255).roundToDouble());
}

double _contrast(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

// ─── Mocks / fakes ────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAccountManagementService extends Mock
    implements AccountManagementService {}

class _MockConnectivityGateway extends Mock implements ConnectivityGateway {}

class _MockDeviceRegistryDatabase extends Mock
    implements DeviceRegistryDatabase {}

class _MockAppRouter extends Mock implements AppRouter {
  @override
  final PinGuard pinGuard = _FakePinGuard();
}

class _FakePinGuard extends Fake implements PinGuard {
  @override
  void lock() {}
}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _StubAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.signedOut();
}

class _FakeProfileId extends ActiveProfileId {
  @override
  String build() => _profileId;
}

/// A CHILD-mode profile id, so `_ParentalControlsSection` (the "Parent Mode"
/// tile, Finding 2) actually renders — it early-returns for adult profiles.
class _FakeChildProfileId extends ActiveProfileId {
  @override
  String build() => _childProfileId;
}

class _FakeUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _SignOutHost extends ConsumerWidget {
  const _SignOutHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () => showSignOutConfirmation(context, ref),
        child: const Text('trigger'),
      ),
    );
  }
}

Widget _buildSignOutApp({
  required _MockAppRouter router,
  required _MockAuthRepository authRepo,
  required _MockAccountManagementService service,
  required _MockConnectivityGateway connectivity,
  required DeviceRegistryDatabase registry,
  ThemeData? theme,
}) {
  return pumpApp(
    theme: theme,
    overrides: [
      routerProvider.overrideWithValue(router),
      authRepositoryProvider.overrideWithValue(authRepo),
      accountManagementServiceProvider.overrideWithValue(service),
      connectivityServiceProvider.overrideWithValue(connectivity),
      deviceRegistryProvider.overrideWithValue(registry),
      authStateProvider.overrideWith(() => _StubAuthStateNotifier()),
    ],
    child: const _SignOutHost(),
  );
}

// ─── SettingsScreen pump harness (Findings 1/2/3 widget-level tests) ────────
//
// Mirrors test/features/settings/presentation/screens/settings_screen_test.dart's
// `createTestWidget` (same minimal override set — db, auth, curriculum
// activation service — proven sufficient to render SettingsScreen without a
// real router/Firebase) and
// test/features/settings/presentation/screens/settings_screen_r5_regression_test.dart's
// TutorGrant fixtures (same shape, reused here for Finding 3).

/// Builds the real [SettingsScreen] wrapped in the shared [pumpApp] rig, with
/// the minimal provider set [settings_screen_test.dart] already proves is
/// enough to render it (no tutored session, adult profile by default).
/// [extraOverrides] layers in the per-finding provider state (a child
/// profile for Finding 2, tutor-grant data for Finding 3).
Widget _buildSettingsScreen({
  required _MockAuthRepository authRepo,
  ThemeData? theme,
  List<Override> extraOverrides = const [],
}) {
  return pumpApp(
    theme: theme,
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      authStateProvider.overrideWithValue(
        const AuthState.signedIn(
          user: AuthUser(
            uid: _profileUid,
            email: 'test@test.com',
            displayName: 'Test',
          ),
          tier: Tier.cloud,
        ),
      ),
      ...extraOverrides,
    ],
    child: const SettingsScreen(),
  );
}

/// A child-mode [ProfileModel] fixture (Finding 2 — the "Parent Mode" tile
/// only renders `_ParentalControlsSection` for a child profile).
LearnerProfileEntity _childProfileFixture() {
  final fixedNow = DateTime.utc(2026, 1, 1);
  return LearnerProfileEntity(
    profileId: _childProfileId,
    displayName: 'Child',
    mode: ProfileMode.child,
    avatar: '',
    createdAt: fixedNow,
    updatedAt: fixedNow,
  );
}

const _profileUid = 'darkmode-settings-test-uid';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY7';
const _childProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXY8';

/// A pending tutor-grant fixture (Finding 3 — renders as a `_TutorGrantTile`
/// with `isPending: true`, the `statusWarningSoft` background).
TutorGrant _pendingGrantFixture() {
  final fixedNow = DateTime.utc(2026, 1, 1);
  return TutorGrant(
    doc: TutorGrantDoc(
      grantId: 'grant_pending_1',
      parentUid: 'parent_uid',
      childProfileId: '2',
      tutorEmail: 'tutor@test.com',
      state: TutorGrantState.pending,
      invitedAt: fixedNow,
      updatedAt: fixedNow,
      expiresAt: fixedNow.add(const Duration(days: 7)),
      childName: 'Yosef',
    ),
    grantState: PendingGrant(expiresAt: fixedNow.add(const Duration(days: 7))),
  );
}

/// An active tutor-grant fixture (Finding 3 — renders as a `_TutorGrantTile`
/// with `isPending: false`, the `statusSuccessSoftBg` background).
TutorGrant _activeGrantFixture() {
  final fixedNow = DateTime.utc(2026, 1, 1);
  return TutorGrant(
    doc: TutorGrantDoc(
      grantId: 'grant_active_1',
      parentUid: 'parent_uid',
      childProfileId: '3',
      tutorEmail: 'tutor@test.com',
      state: TutorGrantState.active,
      invitedAt: fixedNow,
      updatedAt: fixedNow,
      acceptedAt: fixedNow,
      childName: 'Avigail',
    ),
    grantState: ActiveGrant(
      acceptedAt: fixedNow,
      permissions: TutorPermissions.defaults(),
    ),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // SettingsScreen's build() calls PackageInfo.fromPlatform() (app version
    // footer) — mock it once so Findings 1/2/3's widget tests (which pump
    // the real SettingsScreen) don't hit an unmocked platform channel.
    PackageInfo.setMockInitialValues(
      appName: 'Learning Tracker',
      packageName: 'learning_tracker',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  // ── Finding 1 — SendLogs tile icon-pill background ─────────────────────

  group('Finding 1 — Send Diagnostic Logs icon-pill background', () {
    test('brandCreamSoft clears WCAG 4.5:1 against brandInkMuted in dark mode '
        '(pre-fix literal 0xFFF0F1F5 measured 2.28:1)', () {
      const dark = AppPalette.dark;
      const oldLiteralBg = Color(0xFFF0F1F5);
      final oldRatio = _contrast(dark.brandInkMuted, oldLiteralBg);
      final newRatio = _contrast(dark.brandInkMuted, dark.brandCreamSoft);

      expect(
        oldRatio,
        lessThan(4.5),
        reason: 'red demo: the pre-fix literal fails in dark mode',
      );
      expect(newRatio, greaterThanOrEqualTo(4.5));
    });

    test('light mode is unchanged in spirit — brandCreamSoft '
        '(0xFFEFF2F7) is a 1-unit-per-channel match to the old '
        '0xFFF0F1F5 literal', () {
      const light = AppPalette.light;
      expect(light.brandCreamSoft, const Color(0xFFEFF2F7));
      expect(
        _contrast(light.brandInkMuted, light.brandCreamSoft),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  // ── Finding 2 — Parent Mode tile icon-pill background ───────────────────

  group('Finding 2 — Parent Mode icon-pill background', () {
    test('brandCoralSoft clears WCAG 4.5:1 against brandCoralDeep in dark mode '
        '(pre-fix literal 0xFFF8E3E7 measured 1.42:1)', () {
      const dark = AppPalette.dark;
      const oldLiteralBg = Color(0xFFF8E3E7);
      final oldRatio = _contrast(dark.brandCoralDeep, oldLiteralBg);
      final newRatio = _contrast(dark.brandCoralDeep, dark.brandCoralSoft);

      expect(oldRatio, lessThan(4.5));
      expect(newRatio, greaterThanOrEqualTo(4.5));
    });

    test(
      'light mode stays comfortably above 4.5:1 (was 4.79:1, now 5.02:1)',
      () {
        const light = AppPalette.light;
        expect(
          _contrast(light.brandCoralDeep, light.brandCoralSoft),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  });

  // ── Finding 3 — _TutorGrantTile bg/ink pairs ─────────────────────────────

  group('Finding 3 — Tutor grant preview tile (active/pending)', () {
    test('statusSuccessSoftText/Bg (active) and statusWarningSoftText/Soft '
        '(pending) both clear 4.5:1 in dark mode', () {
      const dark = AppPalette.dark;
      expect(
        _contrast(dark.statusSuccessSoftText, dark.statusSuccessSoftBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(dark.statusWarningSoftText, dark.statusWarningSoft),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light mode clears 4.5:1 too — an improvement over the pre-fix '
        'pending pair (hardcoded 0xFFF57F17 on 0xFFFFF8E1 measured 2.49:1, '
        'already failing in light before dark mode was even considered)', () {
      const light = AppPalette.light;
      const oldPendingIcon = Color(0xFFF57F17);
      const oldPendingBg = Color(0xFFFFF8E1);
      final oldRatio = _contrast(oldPendingIcon, oldPendingBg);
      final newRatio = _contrast(
        light.statusWarningSoftText,
        light.statusWarningSoft,
      );

      expect(oldRatio, lessThan(4.5));
      expect(newRatio, greaterThanOrEqualTo(4.5));
      expect(
        _contrast(light.statusSuccessSoftText, light.statusSuccessSoftBg),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  // ── Finding 6 (palette half) — onPrimary vs a brandBlue fill ─────────────

  group('Finding 6 — text/icon on a brandBlue fill (Sign Out button, "?" '
      'badge, Save button)', () {
    test('the theme\'s own onPrimary clears 4.5:1 against brandBlue in BOTH '
        'themes, where a fixed Colors.white measured only 2.52:1 in dark', () {
      final darkTheme = AppTheme.darkTheme();
      final lightTheme = AppTheme.lightTheme();

      final oldRatioDark = _contrast(
        Colors.white,
        darkTheme.colorScheme.primary,
      );
      final newRatioDark = _contrast(
        darkTheme.colorScheme.onPrimary,
        darkTheme.colorScheme.primary,
      );
      final newRatioLight = _contrast(
        lightTheme.colorScheme.onPrimary,
        lightTheme.colorScheme.primary,
      );

      expect(
        oldRatioDark,
        lessThan(4.5),
        reason: 'red demo: fixed white text on the lightened dark-mode fill',
      );
      expect(newRatioDark, greaterThanOrEqualTo(4.5));
      expect(newRatioLight, greaterThanOrEqualTo(4.5));
    });
  });

  // ── Finding 8 (palette half) — error/onError vs the old brandCoralDeep ──

  group('Finding 8 — Sign-out-failure SnackBar background', () {
    test(
      'theme.colorScheme.error/onError clears 4.5:1 in dark mode (pre-fix '
      'brandCoralDeep + default near-white SnackBar text measured 1.5:1)',
      () {
        const dark = AppPalette.dark;
        final darkTheme = AppTheme.darkTheme();
        // Pre-fix: bg = brandCoralDeep, text = the SnackBar theme's default
        // (near-white in dark, per app_theme.dart's snackBarTheme).
        final oldRatio = _contrast(dark.brandCoralDeep, dark.brandInk);
        final newRatio = _contrast(
          darkTheme.colorScheme.onError,
          darkTheme.colorScheme.error,
        );

        expect(oldRatio, lessThan(4.5));
        expect(newRatio, greaterThanOrEqualTo(4.5));
      },
    );

    test(
      'light mode stays comfortably above 4.5:1 (was 5.87:1, now ~5.5:1)',
      () {
        final lightTheme = AppTheme.lightTheme();
        expect(
          _contrast(
            lightTheme.colorScheme.onError,
            lightTheme.colorScheme.error,
          ),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  });

  // ── Finding 4 — _LifetimeLibraryCategoryCard ─────────────────────────────

  group(
    'Finding 4 — Lifetime-learning curriculum-overview tile background',
    () {
      test('brandInk clears 4.5:1 on brandCreamCard in dark mode (pre-fix '
          'Colors.white measured 1.16:1)', () {
        const dark = AppPalette.dark;
        expect(_contrast(dark.brandInk, Colors.white), lessThan(4.5));
        expect(
          _contrast(dark.brandInk, dark.brandCreamCard),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets(
        'the real tile reads brandCreamCard (not the hardcoded white literal) '
        'in dark mode',
        (tester) async {
          await tester.pumpWidget(
            pumpApp(
              theme: AppTheme.darkTheme(),
              overrides: [
                activeProfileIdProvider.overrideWith(() => _FakeProfileId()),
                curriculumContentProvider.overrideWith(
                  (ref, curriculumId) async => const <ContentItem>[],
                ),
                curriculumLedgerProvider.overrideWith(
                  (ref, id) async => const <LearningLedgerEntry>[],
                ),
              ],
              child: const LifetimeMarkingScreen(),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));

          final ink = tester.widgetList<Ink>(find.byType(Ink)).first;
          final decoration = ink.decoration! as BoxDecoration;

          expect(decoration.color, AppPalette.dark.brandCreamCard);
          expect(decoration.color, isNot(Colors.white));

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(Duration.zero);
        },
      );

      testWidgets('the real tile stays white in light mode (no regression)', (
        tester,
      ) async {
        await tester.pumpWidget(
          pumpApp(
            overrides: [
              activeProfileIdProvider.overrideWith(() => _FakeProfileId()),
              curriculumContentProvider.overrideWith(
                (ref, curriculumId) async => const <ContentItem>[],
              ),
              curriculumLedgerProvider.overrideWith(
                (ref, id) async => const <LearningLedgerEntry>[],
              ),
            ],
            child: const LifetimeMarkingScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        final ink = tester.widgetList<Ink>(find.byType(Ink)).first;
        final decoration = ink.decoration! as BoxDecoration;
        expect(decoration.color, const Color(0xFFFFFFFF));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      });
    },
  );

  // ── Finding 5 — LifetimeCurriculumMarkingScreen's own AppBar ─────────────

  group('Finding 5 — LifetimeCurriculumMarkingScreen AppBar background', () {
    test('brandInk / brandBlueDeep clear 4.5:1 on brandCreamCard in dark mode '
        '(pre-fix Colors.white measured 1.16:1 / 1.63:1)', () {
      const dark = AppPalette.dark;
      expect(_contrast(dark.brandInk, Colors.white), lessThan(4.5));
      expect(_contrast(dark.brandBlueDeep, Colors.white), lessThan(4.5));
      expect(
        _contrast(dark.brandInk, dark.brandCreamCard),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('the real AppBar reads brandCreamCard (not the hardcoded white '
        'literal) in dark mode', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          theme: AppTheme.darkTheme(),
          overrides: [
            activeProfileIdProvider.overrideWith(() => _FakeProfileId()),
            useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
            curriculumLedgerProvider.overrideWith(
              (ref, id) async => const <LearningLedgerEntry>[],
            ),
            curriculumContentProvider.overrideWith(
              (ref, curriculumId) async => const <ContentItem>[],
            ),
          ],
          child: LifetimeCurriculumMarkingScreen(
            curriculumId: CurriculumId.mishnayos.storageKey,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, AppPalette.dark.brandCreamCard);
      expect(appBar.backgroundColor, isNot(Colors.white));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('the real AppBar stays white in light mode (no regression)', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpApp(
          overrides: [
            activeProfileIdProvider.overrideWith(() => _FakeProfileId()),
            useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
            curriculumLedgerProvider.overrideWith(
              (ref, id) async => const <LearningLedgerEntry>[],
            ),
            curriculumContentProvider.overrideWith(
              (ref, curriculumId) async => const <ContentItem>[],
            ),
          ],
          child: LifetimeCurriculumMarkingScreen(
            curriculumId: CurriculumId.mishnayos.storageKey,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFFFFFFFF));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── Finding 6 (widget half) — Sign Out button + "?" badge ────────────────

  group('Finding 6 (widget) — Sign Out FilledButton + badge icon', () {
    late _MockAppRouter router;
    late _MockAuthRepository authRepo;
    late _MockAccountManagementService service;
    late _MockConnectivityGateway connectivity;
    late _MockDeviceRegistryDatabase registry;

    setUp(() {
      router = _MockAppRouter();
      authRepo = _MockAuthRepository();
      service = _MockAccountManagementService();
      connectivity = _MockConnectivityGateway();
      registry = _MockDeviceRegistryDatabase();
      registerFallbackValue(_FakePageRouteInfo());
      registerFallbackValue(<PageRouteInfo>[]);
      when(
        () => router.replaceAll(any<List<PageRouteInfo>>()),
      ).thenAnswer((_) async {});
      when(() => authRepo.signOut()).thenAnswer((_) async {});
      when(() => authRepo.currentUser).thenReturn(null);
      when(
        () => authRepo.onAuthStateChanged(),
      ).thenAnswer((_) => const Stream.empty());
      when(() => service.signOut()).thenAnswer((_) async {});
      when(() => connectivity.isOnline).thenAnswer((_) async => true);
    });

    tearDown(() async {});

    testWidgets('the real Sign Out button + "?" badge read theme.colorScheme'
        '.onPrimary (not Colors.white) in dark mode', (tester) async {
      await tester.pumpWidget(
        _buildSignOutApp(
          router: router,
          authRepo: authRepo,
          service: service,
          connectivity: connectivity,
          registry: registry,
          theme: AppTheme.darkTheme(),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('trigger'));
      await tester.pump();

      final onPrimary = Theme.of(
        tester.element(find.byType(FilledButton).first),
      ).colorScheme.onPrimary;

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Sign Out'),
      );
      final style = button.style!;
      final fg = style.foregroundColor?.resolve(<WidgetState>{});
      expect(fg, isNot(Colors.white));
      expect(fg, onPrimary);

      final badgeIcon = tester.widget<Icon>(
        find.byIcon(Icons.question_mark_rounded),
      );
      expect(badgeIcon.color, isNot(Colors.white));
      expect(badgeIcon.color, onPrimary);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── Finding 7 (widget half) — Cancel button background ───────────────────

  group('Finding 7 (widget) — Cancel TextButton background', () {
    late _MockAppRouter router;
    late _MockAuthRepository authRepo;
    late _MockAccountManagementService service;
    late _MockConnectivityGateway connectivity;
    late _MockDeviceRegistryDatabase registry;

    setUp(() {
      router = _MockAppRouter();
      authRepo = _MockAuthRepository();
      service = _MockAccountManagementService();
      connectivity = _MockConnectivityGateway();
      registry = _MockDeviceRegistryDatabase();
      registerFallbackValue(_FakePageRouteInfo());
      registerFallbackValue(<PageRouteInfo>[]);
      when(
        () => router.replaceAll(any<List<PageRouteInfo>>()),
      ).thenAnswer((_) async {});
      when(() => authRepo.signOut()).thenAnswer((_) async {});
      when(() => authRepo.currentUser).thenReturn(null);
      when(
        () => authRepo.onAuthStateChanged(),
      ).thenAnswer((_) => const Stream.empty());
      when(() => service.signOut()).thenAnswer((_) async {});
      when(() => connectivity.isOnline).thenAnswer((_) async => true);
    });

    tearDown(() async {});

    testWidgets(
      'the real Cancel button reads brandCreamSoft (not the hardcoded '
      '0xFFF0F1F5 literal) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          _buildSignOutApp(
            router: router,
            authRepo: authRepo,
            service: service,
            connectivity: connectivity,
            registry: registry,
            theme: AppTheme.darkTheme(),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('trigger'));
        await tester.pump();

        final cancel = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Cancel'),
        );
        final bg = cancel.style!.backgroundColor?.resolve(<WidgetState>{});
        expect(bg, isNot(const Color(0xFFF0F1F5)));
        expect(bg, AppPalette.dark.brandCreamSoft);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // ── Finding 9 — UserProfileHeaderCard avatar ring ────────────────────────

  group('Finding 9 — Profile avatar outer ring border', () {
    test(
      'brandCreamCard equals the old Colors.white literal in light mode',
      () {
        expect(AppPalette.light.brandCreamCard, const Color(0xFFFFFFFF));
      },
    );

    testWidgets(
      'the real avatar ring reads brandCreamCard (not Colors.white) in dark '
      'mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            theme: AppTheme.darkTheme(),
            overrides: [
              authStateProvider.overrideWith(() => _StubAuthStateNotifier()),
              activeProfileIdProvider.overrideWithValue('ulid-1'),
              profileListStreamProvider.overrideWith(
                (_) => Stream.value(const []),
              ),
            ],
            child: const Scaffold(
              body: UserProfileHeaderCard(
                user: AppUser(
                  uid: 'u1',
                  email: 'a@b.com',
                  displayName: 'Test User',
                  emailVerified: true,
                  providers: [],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final avatarContainer = tester
            .widgetList<Container>(find.byType(Container))
            .firstWhere(
              (c) =>
                  c.decoration is BoxDecoration &&
                  (c.decoration! as BoxDecoration).shape == BoxShape.circle &&
                  (c.decoration! as BoxDecoration).border != null,
            );
        final border =
            (avatarContainer.decoration! as BoxDecoration).border! as Border;

        expect(border.top.color, isNot(Colors.white));
        expect(border.top.color, AppPalette.dark.brandCreamCard);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // ── Finding 1 (widget) — Send Diagnostic Logs icon-pill background ──────
  //
  // The palette-only test above (line ~237) only proves the TOKEN PAIR
  // clears WCAG contrast — it does not touch the real widget, so reverting
  // settings_screen.dart's `iconBackground` back to the hardcoded literal
  // would not fail it. These pump the real `SettingsScreen` and read the
  // rendered tile's own decoration.

  group('Finding 1 (widget) — Send Diagnostic Logs icon-pill background', () {
    late _MockAuthRepository authRepo;

    setUp(() {
      authRepo = _MockAuthRepository();
      when(() => authRepo.currentUser).thenReturn(null);
    });

    tearDown(() async {});

    testWidgets(
      'the real Send Diagnostic Logs icon-pill reads brandCreamSoft (not '
      'the hardcoded 0xFFF0F1F5 literal) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          _buildSettingsScreen(authRepo: authRepo, theme: AppTheme.darkTheme()),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.scrollUntilVisible(
          find.text('Send Diagnostic Logs'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        final pill = tester.widget<Container>(
          find
              .ancestor(
                of: find.byIcon(Icons.bug_report_outlined),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = pill.decoration! as BoxDecoration;

        expect(decoration.color, AppPalette.dark.brandCreamSoft);
        expect(decoration.color, isNot(const Color(0xFFF0F1F5)));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'the real Send Diagnostic Logs icon-pill resolves brandCreamSoft in '
      'light mode too (no regression)',
      (tester) async {
        await tester.pumpWidget(_buildSettingsScreen(authRepo: authRepo));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.scrollUntilVisible(
          find.text('Send Diagnostic Logs'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        final pill = tester.widget<Container>(
          find
              .ancestor(
                of: find.byIcon(Icons.bug_report_outlined),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = pill.decoration! as BoxDecoration;

        expect(decoration.color, AppPalette.light.brandCreamSoft);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // ── Finding 2 (widget) — Parent Mode icon-pill background ────────────────

  group('Finding 2 (widget) — Parent Mode icon-pill background', () {
    late _MockAuthRepository authRepo;

    setUp(() {
      authRepo = _MockAuthRepository();
      when(() => authRepo.currentUser).thenReturn(null);
    });

    tearDown(() async {});

    testWidgets('the real Parent Mode icon-pill reads brandCoralSoft (not the '
        'hardcoded 0xFFF8E3E7 literal) in dark mode', (tester) async {
      await tester.pumpWidget(
        _buildSettingsScreen(
          authRepo: authRepo,
          theme: AppTheme.darkTheme(),
          extraOverrides: [
            activeProfileIdProvider.overrideWith(_FakeChildProfileId.new),
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value([_childProfileFixture()]),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.scrollUntilVisible(
        find.text('Parent Mode'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      final pill = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.admin_panel_settings_outlined),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = pill.decoration! as BoxDecoration;

      expect(decoration.color, AppPalette.dark.brandCoralSoft);
      expect(decoration.color, isNot(const Color(0xFFF8E3E7)));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'the real Parent Mode icon-pill resolves brandCoralSoft in light mode '
      'too (no regression)',
      (tester) async {
        await tester.pumpWidget(
          _buildSettingsScreen(
            authRepo: authRepo,
            extraOverrides: [
              activeProfileIdProvider.overrideWith(_FakeChildProfileId.new),
              profileListStreamProvider.overrideWith(
                (ref) => Stream.value([_childProfileFixture()]),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.scrollUntilVisible(
          find.text('Parent Mode'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        final pill = tester.widget<Container>(
          find
              .ancestor(
                of: find.byIcon(Icons.admin_panel_settings_outlined),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = pill.decoration! as BoxDecoration;

        expect(decoration.color, AppPalette.light.brandCoralSoft);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // ── Finding 3 (widget) — Tutor grant preview tile background ─────────────

  group('Finding 3 (widget) — Tutor grant preview tile background', () {
    late _MockAuthRepository authRepo;

    setUp(() {
      authRepo = _MockAuthRepository();
      when(() => authRepo.currentUser).thenReturn(null);
    });

    tearDown(() async {});

    testWidgets(
      'the real pending/active tutor-grant tiles read statusWarningSoft/'
      'statusSuccessSoftBg (not the hardcoded pastel literals) in dark mode',
      (tester) async {
        await tester.pumpWidget(
          _buildSettingsScreen(
            authRepo: authRepo,
            theme: AppTheme.darkTheme(),
            extraOverrides: [
              incomingTutorGrantsProvider.overrideWith(
                (ref) => Future.value([_activeGrantFixture()]),
              ),
              pendingTutorInvitesProvider.overrideWith(
                (ref) => Future.value([_pendingGrantFixture()]),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final pendingTile = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Yosef'),
                matching: find.byType(Container),
              )
              .first,
        );
        final pendingDecoration = pendingTile.decoration! as BoxDecoration;
        expect(pendingDecoration.color, AppPalette.dark.statusWarningSoft);
        expect(pendingDecoration.color, isNot(const Color(0xFFFFF8E1)));

        final activeTile = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Avigail'),
                matching: find.byType(Container),
              )
              .first,
        );
        final activeDecoration = activeTile.decoration! as BoxDecoration;
        expect(activeDecoration.color, AppPalette.dark.statusSuccessSoftBg);
        expect(activeDecoration.color, isNot(const Color(0xFFE8F5E9)));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'the real pending/active tutor-grant tiles resolve the token in light '
      'mode too (no regression)',
      (tester) async {
        await tester.pumpWidget(
          _buildSettingsScreen(
            authRepo: authRepo,
            extraOverrides: [
              incomingTutorGrantsProvider.overrideWith(
                (ref) => Future.value([_activeGrantFixture()]),
              ),
              pendingTutorInvitesProvider.overrideWith(
                (ref) => Future.value([_pendingGrantFixture()]),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final pendingTile = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Yosef'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          (pendingTile.decoration! as BoxDecoration).color,
          AppPalette.light.statusWarningSoft,
        );

        final activeTile = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Avigail'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          (activeTile.decoration! as BoxDecoration).color,
          AppPalette.light.statusSuccessSoftBg,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // ── Finding 8 (widget) — Sign-out-failure SnackBar background ────────────

  group('Finding 8 (widget) — Sign-out-failure SnackBar background', () {
    late _MockAppRouter router;
    late _MockAuthRepository authRepo;
    late _MockAccountManagementService service;
    late _MockConnectivityGateway connectivity;
    late _MockDeviceRegistryDatabase registry;

    setUp(() {
      router = _MockAppRouter();
      authRepo = _MockAuthRepository();
      service = _MockAccountManagementService();
      connectivity = _MockConnectivityGateway();
      registry = _MockDeviceRegistryDatabase();
      registerFallbackValue(_FakePageRouteInfo());
      registerFallbackValue(<PageRouteInfo>[]);
      when(
        () => router.replaceAll(any<List<PageRouteInfo>>()),
      ).thenAnswer((_) async {});
      when(() => authRepo.signOut()).thenAnswer((_) async {});
      when(() => authRepo.currentUser).thenReturn(null);
      when(
        () => authRepo.onAuthStateChanged(),
      ).thenAnswer((_) => const Stream.empty());
      // Red demo requires a genuine FAILURE path — service.signOut() throws
      // so showSignOutConfirmation's catch block fires and shows the
      // SnackBar under test (mirrors account_actions_test.dart's own
      // "sign-out exception shows SnackBar" test, which proves this mock
      // shape actually reaches the catch block).
      when(() => service.signOut()).thenThrow(Exception('network error'));
      when(() => connectivity.isOnline).thenAnswer((_) async => true);
    });

    tearDown(() async {});

    testWidgets(
      'the real sign-out-failure SnackBar reads theme.colorScheme.error/'
      'onError (not the hardcoded brandCoralDeep fill) in dark mode',
      (tester) async {
        final darkTheme = AppTheme.darkTheme();
        await tester.pumpWidget(
          _buildSignOutApp(
            router: router,
            authRepo: authRepo,
            service: service,
            connectivity: connectivity,
            registry: registry,
            theme: darkTheme,
          ),
        );
        await tester.pump();
        await tester.tap(find.text('trigger'));
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, darkTheme.colorScheme.error);
        expect(snackBar.backgroundColor, isNot(AppPalette.dark.brandCoralDeep));

        final content = snackBar.content as Text;
        expect(content.style?.color, darkTheme.colorScheme.onError);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'the real sign-out-failure SnackBar resolves theme.colorScheme.error/'
      'onError in light mode too (no regression, still >4.5:1)',
      (tester) async {
        final lightTheme = AppTheme.lightTheme();
        await tester.pumpWidget(
          _buildSignOutApp(
            router: router,
            authRepo: authRepo,
            service: service,
            connectivity: connectivity,
            registry: registry,
            theme: lightTheme,
          ),
        );
        await tester.pump();
        await tester.tap(find.text('trigger'));
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, lightTheme.colorScheme.error);

        final content = snackBar.content as Text;
        expect(content.style?.color, lightTheme.colorScheme.onError);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
