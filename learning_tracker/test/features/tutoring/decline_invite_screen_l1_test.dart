// L1 widget tests — DeclineInviteScreen (W6.10 / FR-2.5)
//
// Covers:
//   1. Confirmation step renders with AppBar title, heading, body, and both
//      buttons (Decline invite + Cancel) via l10n.
//   2. Tapping "Decline invite" calls DeclineTutorInviteUseCase with the
//      resolved grant (grant-object path).
//   3. Tapping "Decline invite" calls DeclineTutorInviteUseCase with a stub
//      grant built from the raw token (token path).
//   4. Success → success step shown (heading + body + Go to dashboard button).
//   5. TutorGrantFailure → error step shown with the failure message.
//   6. TutorGrantPreconditionError → error step shown (already-declined).
//   7. Unhandled exception → error step shows l10n generic error string.
//   8. Cancel does NOT call the use case and calls router.pop().
//   9. Error → "Try again" button returns to the confirm step.
//  10. In-progress indicator shown while use case is running.
//  11. Hebrew / RTL locale — confirm step renders without overflow.
//
// HARDCODED-STRING AUDIT:
//   All visible strings checked below use l10n keys.
//   "Talmid" / "Parent account" fallbacks in TutorGrant.childDisplayLabel /
//   parentDisplayLabel are not user-facing on this screen.

@Tags(['tutoring', 'decline_invite'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _MockDeclineUseCase extends Mock implements DeclineTutorInviteUseCase {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockNotificationGateway extends Mock
    implements TutorNotificationGateway {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _FakeTutorGrant extends Fake implements TutorGrant {}

// ── Fixtures ─────────────────────────────────────────────────────────────────

final _kNow = DateTime.utc(2026, 1, 1);

TutorGrant _pendingGrant({String grantId = 'grant-pending-1'}) {
  final doc = TutorGrantDoc(
    grantId: grantId,
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

// ── Builder ───────────────────────────────────────────────────────────────────

/// Builds the widget-under-test.
///
/// Exactly one of [grant] or [token] must be supplied (mirrors the screen's
/// constructor constraint). [onDeclined] defaults to a no-op.
Widget _buildApp({
  required _MockStackRouter router,
  required _MockDeclineUseCase useCase,
  TutorGrant? grant,
  String? token,
  VoidCallback? onDeclined,
  _MockAuthRepository? authRepo,
  _MockNotificationGateway? notifGateway,
  Locale locale = const Locale('en'),
}) {
  assert(
    (grant != null) != (token != null),
    'Exactly one of grant or token must be provided.',
  );

  final auth = authRepo ?? _MockAuthRepository();
  when(() => auth.currentUser).thenReturn(
    const AppUser(
      uid: 'tutor-uid-1',
      email: 'tutor@example.com',
      displayName: 'Test Tutor',
      emailVerified: true,
      providers: ['password'],
    ),
  );

  final notif = notifGateway ?? _MockNotificationGateway();
  when(
    () => notif.notifyParentOfDecline(
      parentEmail: any(named: 'parentEmail'),
      tutorEmail: any(named: 'tutorEmail'),
      childName: any(named: 'childName'),
      parentUid: any(named: 'parentUid'),
    ),
  ).thenAnswer((_) async {});

  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      declineTutorInviteUseCaseProvider.overrideWithValue(useCase),
      authRepositoryProvider.overrideWithValue(auth),
      tutorNotificationGatewayProvider.overrideWithValue(notif),
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
        controller: router,
        stateHash: 0,
        child: DeclineInviteScreen(
          grant: grant,
          token: token,
          onDeclined: onDeclined ?? () {},
        ),
      ),
    ),
  );
}

// ── Pump helpers ──────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(_FakePageRouteInfo());
    registerFallbackValue(_FakeTutorGrant());
  });

  late _MockStackRouter router;
  late _MockDeclineUseCase mockUseCase;

  setUp(() {
    router = _MockStackRouter();
    mockUseCase = _MockDeclineUseCase();

    when(() => router.canPop()).thenReturn(true);
    when(
      () => router.pop<Object?>(any()),
    ).thenAnswer((_) => Future<bool>.value(true));
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) => Future<Object?>.value(null));
    // replaceAll is called by the success "Go to dashboard" button.
    when(
      () => router.replaceAll(any()),
    ).thenAnswer((_) => Future<void>.value());
  });

  // ── 1. Confirmation step renders ─────────────────────────────────────────────

  group('confirm step — initial render', () {
    testWidgets('shows AppBar title via l10n', (tester) async {
      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      expect(find.text('Decline Invite'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows confirm heading via l10n', (tester) async {
      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      expect(find.text('Decline tutor invite?'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows confirm body via l10n', (tester) async {
      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      expect(
        find.textContaining('You are about to decline this tutor invite.'),
        findsOneWidget,
      );

      await _tearDown(tester);
    });

    testWidgets(
      'shows "Decline invite" FilledButton and Cancel OutlinedButton',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            router: router,
            useCase: mockUseCase,
            grant: _pendingGrant(),
          ),
        );
        await _pump(tester);

        // "Decline invite" is the l10n key declineInviteConfirm
        expect(find.text('Decline invite'), findsOneWidget);
        // "Cancel" is the l10n key actionCancel
        expect(find.text('Cancel'), findsOneWidget);

        await _tearDown(tester);
      },
    );

    testWidgets('shows do_not_disturb icon on confirm step', (tester) async {
      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      expect(find.byIcon(Icons.do_not_disturb_on_rounded), findsOneWidget);

      await _tearDown(tester);
    });
  });

  // ── 2. Decline → use case called with grant object ────────────────────────────

  group('decline — grant object path', () {
    testWidgets('tapping Decline calls use case with the supplied grant', (
      tester,
    ) async {
      final grant = _pendingGrant(grantId: 'grant-obj-1');

      when(
        () => mockUseCase.call(grant: any(named: 'grant')),
      ).thenAnswer((_) async => const TutorGrantSuccess());

      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: grant),
      );
      await _pump(tester);

      await tester.tap(find.text('Decline invite'));
      await _pump(tester);

      final captured = verify(
        () => mockUseCase.call(grant: captureAny(named: 'grant')),
      ).captured;
      expect(captured, hasLength(1));
      final usedGrant = captured.first as TutorGrant;
      expect(
        usedGrant.grantId,
        'grant-obj-1',
        reason: 'Use case must be called with the exact grant passed in',
      );

      await _tearDown(tester);
    });
  });

  // ── 3. Decline → use case called with stub grant from token ──────────────────

  group('decline — token path', () {
    testWidgets('tapping Decline with a token calls use case with a stub grant '
        'whose grantId matches the token', (tester) async {
      const testToken = 'tok-abc-xyz-123';

      when(
        () => mockUseCase.call(grant: any(named: 'grant')),
      ).thenAnswer((_) async => const TutorGrantSuccess());

      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, token: testToken),
      );
      await _pump(tester);

      await tester.tap(find.text('Decline invite'));
      await _pump(tester);

      final captured = verify(
        () => mockUseCase.call(grant: captureAny(named: 'grant')),
      ).captured;
      expect(captured, hasLength(1));
      final usedGrant = captured.first as TutorGrant;
      expect(
        usedGrant.grantId,
        testToken,
        reason: 'Stub grant grantId must equal the raw token string',
      );
      expect(
        usedGrant.grantState,
        isA<PendingGrant>(),
        reason: 'Stub grant built from token must be in pending state',
      );

      await _tearDown(tester);
    });
  });

  // ── 4. Success path ───────────────────────────────────────────────────────────

  group('success path', () {
    testWidgets('success step shows heading and body via l10n', (tester) async {
      when(
        () => mockUseCase.call(grant: any(named: 'grant')),
      ).thenAnswer((_) async => const TutorGrantSuccess());

      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      await tester.tap(find.text('Decline invite'));
      await _pump(tester);

      // l10n key: declineInviteSuccessHeading
      expect(find.text('Invite declined'), findsOneWidget);
      // l10n key: declineInviteSuccessBody (partial match)
      expect(
        find.textContaining('You have declined this tutor invite.'),
        findsOneWidget,
      );

      await _tearDown(tester);
    });

    testWidgets('success step shows check_circle_rounded icon', (tester) async {
      when(
        () => mockUseCase.call(grant: any(named: 'grant')),
      ).thenAnswer((_) async => const TutorGrantSuccess());

      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      await tester.tap(find.text('Decline invite'));
      await _pump(tester);

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets(
      'success step shows "Go to dashboard" button and tapping it calls '
      'router.replaceAll',
      (tester) async {
        when(
          () => mockUseCase.call(grant: any(named: 'grant')),
        ).thenAnswer((_) async => const TutorGrantSuccess());

        await tester.pumpWidget(
          _buildApp(
            router: router,
            useCase: mockUseCase,
            grant: _pendingGrant(),
          ),
        );
        await _pump(tester);

        await tester.tap(find.text('Decline invite'));
        await _pump(tester);

        // l10n key: actionGoToDashboard
        expect(find.text('Go to dashboard'), findsOneWidget);

        await tester.tap(find.text('Go to dashboard'));
        await _pump(tester);

        verify(() => router.replaceAll(any())).called(1);

        await _tearDown(tester);
      },
    );
  });

  // ── 5. TutorGrantFailure path ─────────────────────────────────────────────────

  group('TutorGrantFailure path', () {
    testWidgets('shows error heading and failure message', (tester) async {
      when(() => mockUseCase.call(grant: any(named: 'grant'))).thenAnswer(
        (_) async =>
            const TutorGrantFailure(message: 'Cloud Function rejected'),
      );

      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      await tester.tap(find.text('Decline invite'));
      await _pump(tester);

      // l10n key: declineInviteErrorHeading
      expect(find.text('Could not decline invite'), findsOneWidget);
      expect(find.text('Cloud Function rejected'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('error step shows error_rounded icon', (tester) async {
      when(() => mockUseCase.call(grant: any(named: 'grant'))).thenAnswer(
        (_) async => const TutorGrantFailure(message: 'Something went wrong'),
      );

      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      await tester.tap(find.text('Decline invite'));
      await _pump(tester);

      expect(find.byIcon(Icons.error_rounded), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('use case is called exactly once (not retried automatically)', (
      tester,
    ) async {
      when(
        () => mockUseCase.call(grant: any(named: 'grant')),
      ).thenAnswer((_) async => const TutorGrantFailure(message: 'fail'));

      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      await tester.tap(find.text('Decline invite'));
      await _pump(tester);

      verify(() => mockUseCase.call(grant: any(named: 'grant'))).called(1);

      await _tearDown(tester);
    });
  });

  // ── 6. TutorGrantPreconditionError (already-declined) ────────────────────────

  group('TutorGrantPreconditionError path', () {
    testWidgets('shows error heading and precondition message', (tester) async {
      when(() => mockUseCase.call(grant: any(named: 'grant'))).thenAnswer(
        (_) async => const TutorGrantPreconditionError(
          message:
              'Grant grant-pending-1 is not in a state that can be declined '
              '(current state: declined).',
        ),
      );

      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      await tester.tap(find.text('Decline invite'));
      await _pump(tester);

      expect(find.text('Could not decline invite'), findsOneWidget);
      expect(
        find.textContaining('is not in a state that can be declined'),
        findsOneWidget,
      );

      await _tearDown(tester);
    });
  });

  // ── 7. Unhandled exception → generic error ────────────────────────────────────

  group('unhandled exception path', () {
    testWidgets('shows l10n generic error string on thrown exception', (
      tester,
    ) async {
      when(
        () => mockUseCase.call(grant: any(named: 'grant')),
      ).thenThrow(Exception('network timeout'));

      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      await tester.tap(find.text('Decline invite'));
      await _pump(tester);

      // l10n key: declineInviteGenericError
      expect(
        find.text('Unable to decline invite. Please try again.'),
        findsOneWidget,
      );

      await _tearDown(tester);
    });
  });

  // ── 8. Cancel does NOT call use case ─────────────────────────────────────────

  group('cancel button', () {
    testWidgets('tapping Cancel does not call DeclineTutorInviteUseCase', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      await tester.tap(find.text('Cancel'));
      await _pump(tester);

      verifyNever(() => mockUseCase.call(grant: any(named: 'grant')));

      await _tearDown(tester);
    });

    testWidgets('tapping Cancel calls router.pop()', (tester) async {
      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      await tester.tap(find.text('Cancel'));
      await _pump(tester);

      verify(() => router.pop<Object?>(any())).called(1);

      await _tearDown(tester);
    });
  });

  // ── 9. Error → Try again → back to confirm ────────────────────────────────────

  group('error step — Try again button', () {
    testWidgets('"Try again" returns to the confirm step', (tester) async {
      when(() => mockUseCase.call(grant: any(named: 'grant'))).thenAnswer(
        (_) async => const TutorGrantFailure(message: 'temporary failure'),
      );

      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      // Trigger failure
      await tester.tap(find.text('Decline invite'));
      await _pump(tester);

      // We should be on the error step
      expect(find.text('Could not decline invite'), findsOneWidget);

      // l10n key: actionTryAgain
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await _pump(tester);

      // Back on the confirm step
      expect(find.text('Decline tutor invite?'), findsOneWidget);
      expect(find.text('Could not decline invite'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets(
      '"Try again" then decline calls use case again on second attempt',
      (tester) async {
        var callCount = 0;
        when(() => mockUseCase.call(grant: any(named: 'grant'))).thenAnswer((
          _,
        ) async {
          callCount++;
          if (callCount == 1) {
            return const TutorGrantFailure(message: 'first attempt failed');
          }
          return const TutorGrantSuccess();
        });

        await tester.pumpWidget(
          _buildApp(
            router: router,
            useCase: mockUseCase,
            grant: _pendingGrant(),
          ),
        );
        await _pump(tester);

        // First attempt → error
        await tester.tap(find.text('Decline invite'));
        await _pump(tester);
        expect(find.text('Could not decline invite'), findsOneWidget);

        // Retry → back to confirm
        await tester.tap(find.text('Try again'));
        await _pump(tester);

        // Second attempt → success
        await tester.tap(find.text('Decline invite'));
        await _pump(tester);

        expect(find.text('Invite declined'), findsOneWidget);
        expect(callCount, 2);

        await _tearDown(tester);
      },
    );
  });

  // ── 10. In-progress indicator ─────────────────────────────────────────────────

  group('in-progress state', () {
    testWidgets('CircularProgressIndicator is shown while declining', (
      tester,
    ) async {
      // Use a Completer so we can hold the use case in the "loading" state.
      final completer = Completer<TutorGrantResult>();
      when(
        () => mockUseCase.call(grant: any(named: 'grant')),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        _buildApp(router: router, useCase: mockUseCase, grant: _pendingGrant()),
      );
      await _pump(tester);

      await tester.tap(find.text('Decline invite'));
      await tester.pump(); // one pump — still in-progress

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // l10n key: declineInviteInProgress
      expect(find.text('Declining invite…'), findsOneWidget);

      // Complete so the widget can be disposed cleanly.
      completer.complete(const TutorGrantSuccess());
      await _pump(tester);

      await _tearDown(tester);
    });
  });

  // ── 11. Hebrew / RTL locale ───────────────────────────────────────────────────

  group('he-RTL locale', () {
    testWidgets('confirm step renders without overflow under RTL (he locale)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          useCase: mockUseCase,
          grant: _pendingGrant(),
          locale: const Locale('he'),
        ),
      );
      await _pump(tester);

      // Key affordances still present — no crash or overflow error.
      expect(find.byType(Scaffold), findsOneWidget);
      // The Decline button (FilledButton) must still be present.
      expect(find.byType(FilledButton), findsOneWidget);
      // Cancel button (OutlinedButton) must still be present.
      expect(find.byType(OutlinedButton), findsOneWidget);

      await _tearDown(tester);
    });
  });
}
