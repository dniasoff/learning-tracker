// Multi-device overflow guard — DeclineInviteScreen (W6.10 / FR-2.5).
//
// The screen has THREE body states whose Columns previously had no scroll
// escape valve and would throw "RenderFlex overflowed by N pixels" on a short
// viewport / large accessibility text:
//
//   * confirm — icon + heading + body + Spacer() + 2 stadium buttons. The
//     Spacer pushes the actions to the bottom; on a tall screen it flexes,
//     on a short one the whole pile is now scroll-wrapped (LayoutBuilder +
//     SingleChildScrollView + ConstrainedBox(minHeight) + IntrinsicHeight).
//   * success — centred icon + heading + body + "Go to dashboard" button.
//   * error   — centred icon + heading + message + "Try again" button.
//
// We render the REAL screen across the device/text-scale matrix using
// [expectNoOverflowAcrossDevices]. The confirm state renders on first frame,
// so it is guarded directly through the harness. The success/error states are
// only reachable after the user taps "Decline invite" (and the use case
// returns), so for those we reuse the harness's [defaultOverflowMatrix] and
// drive the tap per size. Flutter overflow is monotonic, so passing the
// extreme corners proves the whole continuum of real devices.

@Tags(['overflow', 'tutoring', 'decline_invite'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_notification_service.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/decline_invite_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/overflow_harness.dart';
import '../../helpers/pump_app.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _MockDeclineUseCase extends Mock implements DeclineTutorInviteUseCase {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockNotificationGateway extends Mock
    implements TutorNotificationGateway {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _FakeTutorGrant extends Fake implements TutorGrant {}

// ─── Fixtures ─────────────────────────────────────────────────────────────────

final _kNow = DateTime.utc(2026, 1, 1);

TutorGrant _pendingGrant() {
  final doc = TutorGrantDoc(
    grantId: 'grant-pending-1',
    parentUid: 'parent-uid-abc',
    childProfileId: 'child-profile-xyz',
    tutorEmail: 'tutor@example.com',
    state: TutorGrantState.pending,
    invitedAt: _kNow,
    updatedAt: _kNow,
    expiresAt: _kNow.add(const Duration(days: 7)),
    childName: 'Beni',
    parentName: 'Reuven',
  );
  return TutorGrant.fromDoc(doc);
}

/// Overrides that satisfy every provider the screen reads in any state.
List<Override> _overrides(_MockDeclineUseCase useCase) {
  final auth = _MockAuthRepository();
  when(() => auth.currentUser).thenReturn(
    const AppUser(
      uid: 'tutor-uid-1',
      email: 'tutor@example.com',
      displayName: 'Test Tutor',
      emailVerified: true,
      providers: ['password'],
    ),
  );

  final notif = _MockNotificationGateway();
  when(
    () => notif.notifyParentOfDecline(
      parentEmail: any(named: 'parentEmail'),
      tutorEmail: any(named: 'tutorEmail'),
      childName: any(named: 'childName'),
      parentUid: any(named: 'parentUid'),
    ),
  ).thenAnswer((_) async {});

  return [
    declineTutorInviteUseCaseProvider.overrideWithValue(useCase),
    authRepositoryProvider.overrideWithValue(auth),
    tutorNotificationGatewayProvider.overrideWithValue(notif),
  ];
}

/// Wraps the REAL screen in the [StackRouterScope] it expects. The harness
/// supplies the surrounding ProviderScope + MaterialApp + sized MediaQuery.
Widget _screen(_MockStackRouter router) {
  return StackRouterScope(
    controller: router,
    stateHash: 0,
    child: DeclineInviteScreen(grant: _pendingGrant(), onDeclined: () {}),
  );
}

_MockStackRouter _stubbedRouter() {
  final router = _MockStackRouter();
  when(() => router.pop<Object?>(any())).thenAnswer((_) async => true);
  when(router.pop).thenAnswer((_) async => true);
  when(() => router.replaceAll(any())).thenAnswer((_) async {});
  return router;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(_FakePageRouteInfo());
    registerFallbackValue(_FakeTutorGrant());
    registerFallbackValue(<PageRouteInfo>[]);
  });

  // ── confirm state (initial frame) — the Spacer overflow site ─────────────
  for (final locale in const [Locale('en'), Locale('he')]) {
    testWidgets('confirm state does not overflow across the device matrix '
        '(${locale.languageCode})', (tester) async {
      final useCase = _MockDeclineUseCase();
      await expectNoOverflowAcrossDevices(
        tester,
        () => _screen(_stubbedRouter()),
        overrides: _overrides(useCase),
        locale: locale,
      );
    });
  }

  // ── success & error states (reached by tapping "Decline invite") ─────────
  //
  // These need an interaction, so we drive the tap per size, reusing the
  // harness's matrix + monotonicity guarantee.
  Future<void> drivenStateNoOverflow(
    WidgetTester tester, {
    required TutorGrantResult result,
  }) async {
    addTearDown(tester.view.reset);
    for (final c in defaultOverflowMatrix()) {
      tester.view.devicePixelRatio = c.devicePixelRatio;
      tester.view.physicalSize = c.size * c.devicePixelRatio;

      final useCase = _MockDeclineUseCase();
      when(
        () => useCase(grant: any(named: 'grant')),
      ).thenAnswer((_) async => result);

      await tester.pumpWidget(
        pumpApp(
          overrides: _overrides(useCase),
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(c.textScale)),
              child: child!,
            );
          },
          child: _screen(_stubbedRouter()),
        ),
      );
      await tester.pumpAndSettle();

      // Drive into the post-decline state.
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DeclineInviteScreen)),
      )!;
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.declineInviteConfirm),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'Post-decline state overflowed at ${c.label}.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.reset();
    }
  }

  testWidgets('success state does not overflow across the device matrix', (
    tester,
  ) async {
    await drivenStateNoOverflow(
      tester,
      result: const TutorGrantSuccess(grantId: 'grant-pending-1'),
    );
  });

  testWidgets('error state does not overflow across the device matrix', (
    tester,
  ) async {
    await drivenStateNoOverflow(
      tester,
      result: const TutorGrantFailure(
        message:
            'This invite could not be declined because it has already been '
            'handled on another device. Please refresh and try again later.',
      ),
    );
  });
}
