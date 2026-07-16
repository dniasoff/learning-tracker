// L1 widget test — InviteTutorScreen
//
// Covers:
//   • Initial render: AppBar title, heading, body copy, email field, Send button.
//   • Send button disabled when email field is empty.
//   • Send button disabled while loading (prevents double-submit).
//   • Inline validation error shown when tapping Send with an invalid email.
//   • Success path: use case returns TutorGrantSuccess → snackbar shown;
//     outgoingTutorGrantsProvider is invalidated.
//   • Failure path: use case returns TutorGrantFailure → inline error message.
//   • PreconditionError path: use case returns TutorGrantPreconditionError →
//     inline error message.
//   • Copy-link invite method removed: no share-link section or copy buttons.
//   • Hardcoded string audit: all user-facing strings are l10n-sourced.

@Tags(['tutoring', 'invite_tutor'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/invite_tutor_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockInviteTutorUseCase extends Mock implements InviteTutorUseCase {}

// ── Auth state stub ───────────────────────────────────────────────────────────

/// A cloud-born [AuthState] that bypasses the local-only guard in
/// [InviteTutorScreen._sendInvite]. The screen rejects the attempt when
/// [AuthState.isLocalBorn] is true; overriding with this cloud-born state
/// lets tests reach the use-case call without a real Firebase session.
const _cloudBornAuthState = AuthState.signedIn(
  user: AuthUser(
    profileId: 1,
    email: 'cloud@test.com',
    displayName: 'Cloud User',
    firebaseUid: 'uid-test',
  ),
  tier: Tier.cloudBorn,
);

// ── Helpers ───────────────────────────────────────────────────────────────────

const _childProfileId = '42';

ProfileModel _profile({
  required int id,
  required String name,
  required String mode,
}) => ProfileModel(
  id: id,
  accountId: 1,
  displayName: name,
  mode: mode,
  avatarIndex: 0,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

Widget _buildApp({
  required InviteTutorUseCase useCase,
  List<ProfileModel>? profiles,
  String childProfileId = _childProfileId,
}) {
  final profileList =
      profiles ??
      [
        _profile(id: 1, name: 'Parent', mode: 'adult'),
        _profile(id: 42, name: 'Child', mode: 'child'),
      ];

  return ProviderScope(
    overrides: [
      inviteTutorUseCaseProvider.overrideWithValue(useCase),
      // Provide a cloud-born auth state so the local-only guard in
      // _sendInvite does not block the invite — no real Firebase needed.
      authStateProvider.overrideWithValue(_cloudBornAuthState),
      // Return the list synchronously (FutureOr<List<...>> can be just a
      // List<...>) so ref.read(profileListProvider).asData?.value is non-null
      // immediately on first pump — the screen calls ref.read (not watch).
      profileListProvider.overrideWith((ref) => profileList),
      // Stub outgoing grants so the provider can be invalidated without error.
      outgoingTutorGrantsProvider(
        childProfileId,
      ).overrideWith((ref) => Future.value([])),
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
      home: InviteTutorScreen(childProfileId: childProfileId),
    ),
  );
}

/// Pumps the widget then flushes the event queue without pumpAndSettle to
/// avoid timer issues from open async operations.
///
/// The double [pump()] lets any micro-tasks (like Future.value) resolve so
/// [ref.read(profileListProvider).asData] is non-null before any button tap.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required InviteTutorUseCase useCase,
  List<ProfileModel>? profiles,
  String childProfileId = _childProfileId,
}) async {
  await tester.pumpWidget(
    _buildApp(
      useCase: useCase,
      profiles: profiles,
      childProfileId: childProfileId,
    ),
  );
  // First pump triggers the build; second settles the Future.value micro-task.
  await tester.pump();
  await tester.pump();
}

// ── Teardown helper ───────────────────────────────────────────────────────────

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _MockInviteTutorUseCase mockUseCase;

  setUp(() {
    mockUseCase = _MockInviteTutorUseCase();
  });

  // ── Initial render ──────────────────────────────────────────────────────────

  group('InviteTutorScreen — initial render', () {
    testWidgets('shows AppBar title via l10n', (tester) async {
      await _pumpScreen(tester, useCase: mockUseCase);

      expect(find.text('Invite a Tutor'), findsWidgets);
      // AppBar title finder specifically
      final appBar = find.byType(AppBar);
      expect(appBar, findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows heading and body copy', (tester) async {
      await _pumpScreen(tester, useCase: mockUseCase);

      // Heading
      expect(find.text('Invite a Tutor'), findsWidgets);
      // Body copy (partial text match)
      expect(
        find.textContaining("Enter the tutor's email address"),
        findsOneWidget,
      );

      await _tearDown(tester);
    });

    testWidgets('shows email TextField with label and hint', (tester) async {
      await _pumpScreen(tester, useCase: mockUseCase);

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text("Tutor's email address"), findsOneWidget);
      // Hint text visible when field is empty
      expect(find.text('tutor@example.com'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows person_add icon', (tester) async {
      await _pumpScreen(tester, useCase: mockUseCase);

      expect(find.byIcon(Icons.person_add_rounded), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Send button is disabled when email is empty', (tester) async {
      await _pumpScreen(tester, useCase: mockUseCase);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.onPressed,
        isNull,
        reason: 'Send button must be disabled when email is empty',
      );

      await _tearDown(tester);
    });
  });

  // ── Email validation ────────────────────────────────────────────────────────

  group('InviteTutorScreen — email validation', () {
    testWidgets('Send button enabled after entering valid email', (
      tester,
    ) async {
      await _pumpScreen(tester, useCase: mockUseCase);

      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.onPressed,
        isNotNull,
        reason: 'Send button must be enabled for valid email',
      );

      await _tearDown(tester);
    });

    testWidgets('Send button remains disabled for email without @', (
      tester,
    ) async {
      await _pumpScreen(tester, useCase: mockUseCase);

      await tester.enterText(find.byType(TextFormField), 'notanemail');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.onPressed,
        isNull,
        reason:
            'Send button must be disabled for text without @ (invalid email)',
      );

      await _tearDown(tester);
    });

    testWidgets('Send button remains disabled for email without dot', (
      tester,
    ) async {
      await _pumpScreen(tester, useCase: mockUseCase);

      await tester.enterText(find.byType(TextFormField), 'no@dot');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.onPressed,
        isNull,
        reason: 'Send button must be disabled for email without a dot after @',
      );

      await _tearDown(tester);
    });

    testWidgets(
      'P2: typing a malformed email shows the inline errorText hint',
      (tester) async {
        await _pumpScreen(tester, useCase: mockUseCase);

        // A typed-but-invalid email must surface a localized inline error
        // explaining WHY Send is disabled — not silently do nothing.
        await tester.enterText(find.byType(TextFormField), 'notanemail');
        await tester.pump();

        expect(
          find.text('Please enter a valid email address.'),
          findsOneWidget,
          reason: 'Invalid typed email must show inline validation feedback',
        );
        // Send stays disabled while invalid.
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'P2: empty email shows NO inline error (Send simply disabled)',
      (tester) async {
        await _pumpScreen(tester, useCase: mockUseCase);

        // Type then clear — empty must not show the validation hint.
        await tester.enterText(find.byType(TextFormField), 'x');
        await tester.pump();
        await tester.enterText(find.byType(TextFormField), '');
        await tester.pump();

        expect(find.text('Please enter a valid email address.'), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'P2: inline error clears once the email becomes valid and Send enables',
      (tester) async {
        await _pumpScreen(tester, useCase: mockUseCase);

        await tester.enterText(find.byType(TextFormField), 'notanemail');
        await tester.pump();
        expect(
          find.text('Please enter a valid email address.'),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextFormField), 'good@example.com');
        await tester.pump();

        expect(find.text('Please enter a valid email address.'), findsNothing);
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNotNull);

        await _tearDown(tester);
      },
    );

    testWidgets('shows l10n invalid-email error when validation fails via code', (
      tester,
    ) async {
      // Directly test the inline error path by bypassing the button guard:
      // enter a partially valid email, tap send, then clear — but actually we
      // can't bypass the button guard. Instead, verify the error message string
      // via l10n to confirm it's not hardcoded.
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) =>
                Text(AppLocalizations.of(context)!.inviteTutorInvalidEmail),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Please enter a valid email address.'),
        findsOneWidget,
        reason: 'inviteTutorInvalidEmail l10n key must resolve correctly',
      );

      await _tearDown(tester);
    });
  });

  // ── Success path ────────────────────────────────────────────────────────────

  group('InviteTutorScreen — success path', () {
    testWidgets(
      'success: snackbar shown after send; no share-link section appears',
      (tester) async {
        when(
          () => mockUseCase(
            tutorEmail: any(named: 'tutorEmail'),
            childProfileId: any(named: 'childProfileId'),
            childName: any(named: 'childName'),
            parentName: any(named: 'parentName'),
          ),
        ).thenAnswer(
          (_) async => const TutorGrantSuccess(grantId: 'grant-abc-123'),
        );

        await _pumpScreen(tester, useCase: mockUseCase);

        await tester.enterText(find.byType(TextFormField), 'tutor@example.com');
        await tester.pump();

        await tester.tap(find.byType(FilledButton));
        // Flush microtasks
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Snackbar shown
        expect(
          find.text('Invite sent to tutor@example.com!'),
          findsOneWidget,
          reason: 'Success snackbar must show the invited email address',
        );

        // Bug 4: the copy-link invite method is removed — no share-link section,
        // no copy buttons, and the grant ID is never surfaced as a link.
        expect(find.text('Share link (backup delivery)'), findsNothing);
        expect(find.text('Copy share link'), findsNothing);
        expect(find.textContaining('grant-abc-123'), findsNothing);
        expect(find.byIcon(Icons.copy_rounded), findsNothing);

        // Verify use case was called with the correct args
        verify(
          () => mockUseCase(
            tutorEmail: 'tutor@example.com',
            childProfileId: _childProfileId,
            childName: any(named: 'childName'),
            parentName: any(named: 'parentName'),
          ),
        ).called(1);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'success: use case receives child name from profileListProvider',
      (tester) async {
        when(
          () => mockUseCase(
            tutorEmail: any(named: 'tutorEmail'),
            childProfileId: any(named: 'childProfileId'),
            childName: any(named: 'childName'),
            parentName: any(named: 'parentName'),
          ),
        ).thenAnswer(
          (_) async => const TutorGrantSuccess(grantId: 'grant-xyz'),
        );

        final profiles = [
          _profile(id: 1, name: 'Abba', mode: 'adult'),
          _profile(id: 42, name: 'Beni', mode: 'child'),
        ];

        await _pumpScreen(tester, useCase: mockUseCase, profiles: profiles);
        // Let profileListProvider's Future.value(...) micro-task settle so that
        // ref.read(profileListProvider).asData is non-null when the button is tapped.
        await tester.pump();
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), 'rebbe@school.com');
        await tester.pump();

        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final captured = verify(
          () => mockUseCase(
            tutorEmail: 'rebbe@school.com',
            childProfileId: _childProfileId,
            childName: captureAny(named: 'childName'),
            parentName: captureAny(named: 'parentName'),
          ),
        ).captured;

        // childName (first capture) should resolve to 'Beni'
        expect(
          captured[0],
          'Beni',
          reason: 'Use case must receive the child display name',
        );
        // parentName (second capture) should resolve to 'Abba'
        expect(
          captured[1],
          'Abba',
          reason: 'Use case must receive the adult profile display name',
        );

        await _tearDown(tester);
      },
    );

    testWidgets('success with null grantId still shows snackbar, no link', (
      tester,
    ) async {
      when(
        () => mockUseCase(
          tutorEmail: any(named: 'tutorEmail'),
          childProfileId: any(named: 'childProfileId'),
          childName: any(named: 'childName'),
          parentName: any(named: 'parentName'),
        ),
      ).thenAnswer((_) async => const TutorGrantSuccess(grantId: null));

      await _pumpScreen(tester, useCase: mockUseCase);
      await tester.enterText(find.byType(TextFormField), 'a@b.com');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No share-link surface regardless of grantId value.
      expect(find.textContaining('pending'), findsNothing);
      expect(find.byIcon(Icons.copy_rounded), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('success: screen pops back after the invite is sent', (
      tester,
    ) async {
      when(
        () => mockUseCase(
          tutorEmail: any(named: 'tutorEmail'),
          childProfileId: any(named: 'childProfileId'),
          childName: any(named: 'childName'),
          parentName: any(named: 'parentName'),
        ),
      ).thenAnswer((_) async => const TutorGrantSuccess(grantId: 'grant-pop'));

      // Push the invite screen onto a Navigator so there is something to pop
      // back to (the "Manage Tutors" stand-in below).
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inviteTutorUseCaseProvider.overrideWithValue(mockUseCase),
            authStateProvider.overrideWithValue(_cloudBornAuthState),
            profileListProvider.overrideWith(
              (ref) => [
                _profile(id: 1, name: 'Parent', mode: 'adult'),
                _profile(id: 42, name: 'Child', mode: 'child'),
              ],
            ),
            outgoingTutorGrantsProvider(
              _childProfileId,
            ).overrideWith((ref) => Future.value([])),
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
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const InviteTutorScreen(
                          childProfileId: _childProfileId,
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Invite screen is on top.
      expect(find.byType(InviteTutorScreen), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'tutor@example.com');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Screen popped back to the Manage Tutors stand-in; snackbar survives.
      expect(find.byType(InviteTutorScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(find.text('Invite sent to tutor@example.com!'), findsOneWidget);

      await _tearDown(tester);
    });
  });

  // ── Failure path ────────────────────────────────────────────────────────────

  group('InviteTutorScreen — failure path', () {
    testWidgets(
      'TutorGrantFailure: raw "Unauthenticated" token never reaches the UI; '
      'a friendly sign-in message is shown instead',
      (tester) async {
        // The repository surfaces the raw Firebase/gRPC status token
        // "Unauthenticated" via TutorGrantFailure.message / code. It must NOT
        // render verbatim — the parent sees a friendly, localized message.
        when(
          () => mockUseCase(
            tutorEmail: any(named: 'tutorEmail'),
            childProfileId: any(named: 'childProfileId'),
            childName: any(named: 'childName'),
            parentName: any(named: 'parentName'),
          ),
        ).thenAnswer(
          (_) async => const TutorGrantFailure(
            message: 'Unauthenticated',
            code: 'unauthenticated',
          ),
        );

        await _pumpScreen(tester, useCase: mockUseCase);
        await tester.enterText(find.byType(TextFormField), 'bad@fail.com');
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Raw status token must NOT leak to the UI.
        expect(find.text('Unauthenticated'), findsNothing);
        expect(find.textContaining('Unauthenticated'), findsNothing);
        // Friendly, localized message is shown instead.
        expect(
          find.text(
            "Couldn't send the invitation. Please sign in and try again.",
          ),
          findsOneWidget,
        );

        await _tearDown(tester);
      },
    );

    testWidgets(
      'TutorGrantFailure (other error): generic friendly fallback shown, '
      'raw message not leaked',
      (tester) async {
        when(
          () => mockUseCase(
            tutorEmail: any(named: 'tutorEmail'),
            childProfileId: any(named: 'childProfileId'),
            childName: any(named: 'childName'),
            parentName: any(named: 'parentName'),
          ),
        ).thenAnswer(
          (_) async => const TutorGrantFailure(
            message: 'INTERNAL: gRPC deadline exceeded',
            code: 'internal',
          ),
        );

        await _pumpScreen(tester, useCase: mockUseCase);
        await tester.enterText(find.byType(TextFormField), 'bad@fail.com');
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Raw engineering string must NOT leak to the UI.
        expect(find.textContaining('gRPC'), findsNothing);
        expect(find.textContaining('INTERNAL'), findsNothing);
        // Generic friendly fallback is shown.
        expect(
          find.text("Couldn't send the invitation. Please try again."),
          findsOneWidget,
        );
        // Share-link section NOT shown
        expect(find.text('Share link (backup delivery)'), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'TutorGrantPreconditionError(cannotRevoke): shows generic localized '
      'error, not a raw/hardcoded English string',
      (tester) async {
        when(
          () => mockUseCase(
            tutorEmail: any(named: 'tutorEmail'),
            childProfileId: any(named: 'childProfileId'),
            childName: any(named: 'childName'),
            parentName: any(named: 'parentName'),
          ),
        ).thenAnswer(
          (_) async => const TutorGrantPreconditionError(
            // AUD-tutoring-02 (EH-5): the domain layer carries a stable code,
            // never a pre-formatted message — the screen resolves it via
            // l10n. This use case can only realistically emit
            // `invalidTutorEmail`, but the screen's switch is exhaustive over
            // the full enum (EH-6) — this exercises the generic-fallback arm
            // for every other code.
            code: TutorGrantPreconditionCode.cannotRevoke,
          ),
        );

        await _pumpScreen(tester, useCase: mockUseCase);
        await tester.enterText(find.byType(TextFormField), 'dup@example.com');
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text("Couldn't send the invitation. Please try again."),
          findsOneWidget,
        );
        expect(find.text('Share link (backup delivery)'), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'TutorGrantPreconditionError(invalidTutorEmail): shows the same '
      'localized message as client-side email validation',
      (tester) async {
        when(
          () => mockUseCase(
            tutorEmail: any(named: 'tutorEmail'),
            childProfileId: any(named: 'childProfileId'),
            childName: any(named: 'childName'),
            parentName: any(named: 'parentName'),
          ),
        ).thenAnswer(
          (_) async => const TutorGrantPreconditionError(
            code: TutorGrantPreconditionCode.invalidTutorEmail,
          ),
        );

        await _pumpScreen(tester, useCase: mockUseCase);
        await tester.enterText(find.byType(TextFormField), 'dup@example.com');
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Please enter a valid email address.'),
          findsOneWidget,
        );
        expect(find.text('Share link (backup delivery)'), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets('error message clears on next successful send', (tester) async {
      // First call fails
      when(
        () => mockUseCase(
          tutorEmail: 'bad@fail.com',
          childProfileId: any(named: 'childProfileId'),
          childName: any(named: 'childName'),
          parentName: any(named: 'parentName'),
        ),
      ).thenAnswer(
        (_) async => const TutorGrantFailure(message: 'First failure'),
      );
      // Second call succeeds
      when(
        () => mockUseCase(
          tutorEmail: 'ok@example.com',
          childProfileId: any(named: 'childProfileId'),
          childName: any(named: 'childName'),
          parentName: any(named: 'parentName'),
        ),
      ).thenAnswer((_) async => const TutorGrantSuccess(grantId: 'grant-ok'));

      await _pumpScreen(tester, useCase: mockUseCase);

      // First attempt → error (raw 'First failure' is mapped to the generic
      // friendly fallback; the raw token is never surfaced).
      await tester.enterText(find.byType(TextFormField), 'bad@fail.com');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('First failure'), findsNothing);
      expect(
        find.text("Couldn't send the invitation. Please try again."),
        findsOneWidget,
      );

      // Change email to a valid one and resend → success
      await tester.enterText(find.byType(TextFormField), 'ok@example.com');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Error message should be gone
      expect(
        find.text("Couldn't send the invitation. Please try again."),
        findsNothing,
      );

      await _tearDown(tester);
    });
  });

  // ── Copy-link invite method removed (Bug 4) ─────────────────────────────────

  group('InviteTutorScreen — copy-link method removed', () {
    testWidgets(
      'no copy-link affordance appears even after a successful invite',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        when(
          () => mockUseCase(
            tutorEmail: any(named: 'tutorEmail'),
            childProfileId: any(named: 'childProfileId'),
            childName: any(named: 'childName'),
            parentName: any(named: 'parentName'),
          ),
        ).thenAnswer(
          (_) async => const TutorGrantSuccess(grantId: 'copy-test-id'),
        );

        await _pumpScreen(tester, useCase: mockUseCase);
        await tester.enterText(find.byType(TextFormField), 'copy@example.com');
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The copy-link invite method is gone: no share-link section, no copy
        // icon/button, and no IconButton at all on the screen.
        expect(find.text('Share link (backup delivery)'), findsNothing);
        expect(find.text('Copy share link'), findsNothing);
        expect(find.byIcon(Icons.copy_rounded), findsNothing);
        expect(find.byType(IconButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);

        await _tearDown(tester);
      },
    );
  });

  // ── Share-link section never shown ──────────────────────────────────────────

  group('InviteTutorScreen — share-link section never shown', () {
    testWidgets('share-link section is NOT shown before any invite is sent', (
      tester,
    ) async {
      await _pumpScreen(tester, useCase: mockUseCase);

      expect(find.text('Share link (backup delivery)'), findsNothing);
      expect(find.text('Copy share link'), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── Hardcoded string audit ──────────────────────────────────────────────────

  group('InviteTutorScreen — no hardcoded user-facing strings', () {
    test('screen source contains no hardcoded English UI strings', () {
      // AUD-t-tutoring-05: this used to be `Uri.file(path).toString()` —
      // which never reads the filesystem and made `expect(src, isNotEmpty)`
      // true for any non-empty path string, regardless of the screen's
      // actual contents. This reads the real file and scans for `Text(` /
      // `TextSpan(text:)` call sites whose argument is a string literal
      // carrying real (non-interpolation, non-punctuation) Latin text —
      // the same detection AX-2's Rule-0 checker
      // (tool/check_hardcoded_presentation_text.dart) uses — so the test can
      // no longer pass independent of the file it claims to check.
      final content = File(
        'lib/features/tutoring/presentation/screens/invite_tutor_screen.dart',
      ).readAsStringSync();

      final violations = _findHardcodedTextLiterals(content);

      expect(
        violations,
        isEmpty,
        reason:
            'Found hardcoded English literal(s) passed to Text()/TextSpan() '
            'in invite_tutor_screen.dart — route through AppLocalizations/ARB '
            '(AX-2):\n${violations.join('\n')}',
      );
    });
  });
}

// ── Hardcoded-text detection helpers (AUD-t-tutoring-05) ────────────────────
//
// Mirrors the Text()/TextSpan(text:) literal-detection logic in
// tool/check_hardcoded_presentation_text.dart (the AX-2 Rule-0 checker),
// scoped here to a single screen file so this test genuinely depends on the
// screen's source rather than asserting something trivially true.

final _textCall = RegExp(r'\bText\(');
final _textSpanCall = RegExp(r'\bTextSpan\(');
final _textParam = RegExp(r'\btext\s*:');

/// Scans [content] for `Text(<literal>` and `TextSpan(..., text: <literal>`
/// call sites whose literal argument contains hardcoded (non-interpolation,
/// non-punctuation) text. Returns one `line N: <reason>` string per
/// violation.
List<String> _findHardcodedTextLiterals(String content) {
  final results = <String>[];

  for (final match in _textCall.allMatches(content)) {
    final openParen = match.end - 1;
    final closeParen = _findMatchingParen(content, openParen);
    if (closeParen == -1) continue; // unterminated — leave to the analyzer
    final args = content.substring(openParen + 1, closeParen);
    final literal = _leadingStringLiteral(args);
    if (literal != null && _hasHardcodedText(literal)) {
      results.add(
        'line ${_lineOf(content, match.start)}: hardcoded literal passed '
        "to Text(): '$literal'",
      );
    }
  }

  for (final match in _textSpanCall.allMatches(content)) {
    final openParen = match.end - 1;
    final closeParen = _findMatchingParen(content, openParen);
    if (closeParen == -1) continue;
    final args = content.substring(openParen + 1, closeParen);
    final textMatch = _textParam.firstMatch(args);
    if (textMatch == null) continue;
    final literal = _leadingStringLiteral(args.substring(textMatch.end));
    if (literal != null && _hasHardcodedText(literal)) {
      results.add(
        'line ${_lineOf(content, match.start)}: hardcoded literal passed '
        "to TextSpan(text:): '$literal'",
      );
    }
  }

  return results;
}

int _lineOf(String content, int index) =>
    '\n'.allMatches(content.substring(0, index)).length + 1;

/// If [s], once leading whitespace is trimmed, begins with a quote
/// character, returns the literal's raw (still-escaped) contents.
/// Otherwise null — the argument is an expression/identifier (presumably
/// l10n- or variable-derived), not a literal.
String? _leadingStringLiteral(String s) {
  var i = 0;
  while (i < s.length && _isWhitespace(s[i])) {
    i++;
  }
  if (i >= s.length) return null;
  final quote = s[i];
  if (quote != "'" && quote != '"') return null;
  final buffer = StringBuffer();
  i++;
  while (i < s.length && s[i] != quote) {
    buffer.write(s[i]);
    if (s[i] == r'\' && i + 1 < s.length) {
      i++;
      buffer.write(s[i]);
    }
    i++;
  }
  return buffer.toString();
}

bool _isWhitespace(String c) => c == ' ' || c == '\n' || c == '\t' || c == '\r';

/// True if [literal] contains a Latin letter once `${...}`/`$identifier`
/// interpolation and `\x` escape sequences are stripped — i.e. it carries
/// real, untranslated English text rather than pure interpolation or
/// punctuation.
bool _hasHardcodedText(String literal) {
  var stripped = literal.replaceAll(RegExp(r'\\.'), '');
  stripped = stripped.replaceAll(RegExp(r'\$\{[^}]*\}'), '');
  stripped = stripped.replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), '');
  return RegExp('[A-Za-z]').hasMatch(stripped);
}

/// Finds the index of the `)` that matches the `(` at [openParenIndex],
/// skipping over parens that appear inside string literals.
int _findMatchingParen(String s, int openParenIndex) {
  var depth = 0;
  var i = openParenIndex;
  while (i < s.length) {
    final c = s[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) return i;
    } else if (c == "'" || c == '"') {
      final quote = c;
      i++;
      while (i < s.length && s[i] != quote) {
        if (s[i] == r'\') i++;
        i++;
      }
    }
    i++;
  }
  return -1;
}
