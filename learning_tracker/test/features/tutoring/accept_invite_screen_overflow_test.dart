// Multi-device overflow guard — AcceptInviteScreen (W6.9 / FR-2.4).
//
// The screen has body states whose Columns previously had no scroll escape
// valve and would throw "RenderFlex overflowed by N pixels" on a short
// viewport / large accessibility text:
//
//   * readyToAccept — icon + heading + body + 4 permission rows + 2 actions
//     (already scroll-wrapped per TUT-03; covered here as a regression guard).
//   * success — centred icon + heading + body + "Go to dashboard" button.
//   * error   — centred icon + heading + message + "Try again" button.
//
// We render the REAL screen across the device/text-scale matrix using
// [expectNoOverflowAcrossDevices]. readyToAccept and error settle on their own
// (error is reached automatically by passing a null token), so they go through
// the harness directly. success needs a tap, so it reuses the harness's
// [defaultOverflowMatrix] and drives the tap per size. Flutter overflow is
// monotonic, so passing the extreme corners proves the whole continuum.

@Tags(['overflow', 'tutoring', 'accept_invite'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show incomingTutorGrantsProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show acceptTutorInviteUseCaseProvider, pendingTutorInvitesProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/accept_invite_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/overflow_harness.dart';

// ─── Mocks / stubs ────────────────────────────────────────────────────────────

class _MockAcceptUseCase extends Mock implements AcceptTutorInviteUseCase {}

class _MockStackRouter extends Mock implements StackRouter {}

class _StubTutorPinService implements TutorPinService {
  @override
  Future<bool> hasTutorPin(int profileId) async => true;
  @override
  Future<TutorPinResult> setTutorPin({
    required int profileId,
    required String rawPin,
  }) async => const TutorPinSuccess();
  @override
  Future<TutorPinResult> verifyTutorPin({
    required int profileId,
    required String rawPin,
  }) async => const TutorPinSuccess();
  @override
  Future<void> clearTutorPin(int profileId) async {}
  @override
  Future<int> lockoutRemainingMinutes(int profileId) async => 0;
}

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}

const _signedInState = AuthState.signedIn(
  user: AuthUser(profileId: 1, email: 't@t.com', displayName: 'T'),
  tier: Tier.localBorn,
);

TutorGrant _pendingGrant({String grantId = 'test-grant-id'}) {
  final now = DateTime.utc(2026, 1, 1);
  final doc = TutorGrantDoc(
    grantId: grantId,
    parentUid: 'parent-uid',
    childProfileId: 'child-profile-id',
    tutorEmail: 't@t.com',
    state: TutorGrantState.pending,
    invitedAt: now,
    updatedAt: now,
    expiresAt: now.add(const Duration(days: 7)),
    childName: 'Beni',
    parentName: 'Avi',
  );
  return TutorGrant.fromDoc(doc);
}

List<Override> _overrides({
  required _MockAcceptUseCase useCase,
  List<TutorGrant>? grants,
}) {
  return [
    authStateProvider.overrideWithValue(_signedInState),
    selectedProfileIdProvider.overrideWith(() => _FixedSelectedProfileId(1)),
    acceptTutorInviteUseCaseProvider.overrideWithValue(useCase),
    tutorPinServiceProvider.overrideWithValue(_StubTutorPinService()),
    incomingTutorGrantsProvider.overrideWith((ref) async => grants ?? []),
    pendingTutorInvitesProvider.overrideWith((ref) => []),
  ];
}

_MockStackRouter _stubbedRouter() {
  final router = _MockStackRouter();
  when(() => router.push(any())).thenAnswer((_) async => null);
  when(() => router.replaceAll(any())).thenAnswer((_) async => []);
  return router;
}

Widget _screen(_MockStackRouter router, {String? token = 'test-grant-id'}) {
  return StackRouterScope(
    controller: router,
    stateHash: 0,
    child: AcceptInviteScreen(token: token),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(const AppShellRoute());
    registerFallbackValue(<PageRouteInfo>[const AppShellRoute()]);
    registerFallbackValue(_pendingGrant());
  });

  // ── readyToAccept (settles on its own after _initialize) ─────────────────
  for (final locale in const [Locale('en'), Locale('he')]) {
    testWidgets(
      'readyToAccept state does not overflow across the device matrix '
      '(${locale.languageCode})',
      (tester) async {
        final useCase = _MockAcceptUseCase();
        await expectNoOverflowAcrossDevices(
          tester,
          () => _screen(_stubbedRouter()),
          overrides: _overrides(useCase: useCase, grants: [_pendingGrant()]),
          locale: locale,
        );
      },
    );
  }

  // ── error (null token → _initialize sets error automatically) ────────────
  testWidgets('error state does not overflow across the device matrix', (
    tester,
  ) async {
    final useCase = _MockAcceptUseCase();
    await expectNoOverflowAcrossDevices(
      tester,
      () => _screen(_stubbedRouter(), token: null),
      overrides: _overrides(useCase: useCase),
    );
  });

  // ── success (reached by tapping "Accept"); driven per size ───────────────
  testWidgets('success state does not overflow across the device matrix', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final c in defaultOverflowMatrix()) {
      tester.view.devicePixelRatio = c.devicePixelRatio;
      tester.view.physicalSize = c.size * c.devicePixelRatio;

      final useCase = _MockAcceptUseCase();
      when(() => useCase(grant: any(named: 'grant'))).thenAnswer(
        (_) async => const TutorGrantSuccess(grantId: 'test-grant-id'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(useCase: useCase, grants: [_pendingGrant()]),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
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
                data: media.copyWith(
                  textScaler: TextScaler.linear(c.textScale),
                ),
                child: child!,
              );
            },
            home: _screen(_stubbedRouter()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AcceptInviteScreen)),
      )!;
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.acceptInviteAccept),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'Accept success state overflowed at ${c.label}.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.reset();
    }
  });
}
