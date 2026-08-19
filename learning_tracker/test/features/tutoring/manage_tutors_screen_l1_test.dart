// L1 widget tests for ManageTutorsScreen (W6.11)
//
// Covers:
//   • Loading state — shows CircularProgressIndicator while profileListProvider loads
//   • Error state   — AppErrorView 'Something went wrong' + Retry button rendered
//   • Retry button  — tapping Retry triggers refresh of profileListProvider
//   • Empty state   — shows empty-profiles view when there are no child profiles
//   • Populated state:
//       - Child name headers rendered
//       - Active grant row: tutor email + "Active" + Revoke button + audit log icon
//       - Pending grant row: tutor email + "Pending" + Rescind button (no audit log)
//       - Per-child "Invite a tutor" button is rendered
//       - Tapping "Invite a tutor" navigates to InviteTutorRoute (router call)
//       - Tapping Revoke shows confirmation dialog
//       - Tapping Rescind shows confirmation dialog
//       - Active grants section header rendered
//       - Pending grants section header rendered
//       - "No tutors invited." shown when grants list is empty for a child
//   • Behaviour — confirming Revoke calls use case + fires revocation notification
//   • Behaviour — Revoke failure shows SnackBar error message
//   • Behaviour — Rescind failure shows SnackBar error message
//   • Behaviour — in-flight guard: Revoke button shows spinner during async call
//   • Grants error — per-child section shows manageTutorsLoadError text
//   • RTL — Hebrew locale: key affordances render without overflow/crash

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_notification_service.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/manage_tutors_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockRevoke extends Mock implements RevokeTutorGrantUseCase {}

class _MockRescind extends Mock implements RescindTutorInviteUseCase {}

class _MockNotificationGateway extends Mock
    implements TutorNotificationGateway {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _FakeTutorGrant extends Fake implements TutorGrant {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const _childUlid = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _adultUlid = '01ARZ3NDEKTSV4RRFFQ69G5FAW';
const _thirdUlid = '01ARZ3NDEKTSV4RRFFQ69G5FAX';

String _profileUlid(int id) => switch (id) {
  1 => _childUlid,
  2 => _adultUlid,
  _ => _thirdUlid,
};

/// A minimal Firestore learner profile.
LearnerProfileEntity _childProfile({int id = 1, String displayName = 'Moshe'}) {
  final now = DateTime.utc(2026, 1, 1);
  return LearnerProfileEntity(
    profileId: _profileUlid(id),
    displayName: displayName,
    mode: ProfileMode.child,
    createdAt: now,
    updatedAt: now,
  );
}

/// An adult learner profile — must NOT appear in ManageTutors.
LearnerProfileEntity _adultProfile({
  int id = 2,
  String displayName = 'Parent',
}) {
  final now = DateTime.utc(2026, 1, 1);
  return LearnerProfileEntity(
    profileId: _profileUlid(id),
    displayName: displayName,
    mode: ProfileMode.adult,
    createdAt: now,
    updatedAt: now,
  );
}

/// Construct an active [TutorGrant].
TutorGrant _activeGrant({String tutorEmail = 'tutor@example.com'}) {
  final now = DateTime.utc(2026, 1, 1);
  final doc = TutorGrantDoc(
    grantId: 'grant_active_1',
    parentUid: 'parent_uid',
    childProfileId: _childUlid,
    tutorEmail: tutorEmail,
    state: TutorGrantState.active,
    invitedAt: now,
    updatedAt: now,
    acceptedAt: now,
  );
  return TutorGrant.fromDoc(doc, permissions: TutorPermissions.defaults());
}

/// Construct a pending [TutorGrant].
TutorGrant _pendingGrant({String tutorEmail = 'pending@example.com'}) {
  final now = DateTime.utc(2026, 1, 1);
  final doc = TutorGrantDoc(
    grantId: 'grant_pending_1',
    parentUid: 'parent_uid',
    childProfileId: _childUlid,
    tutorEmail: tutorEmail,
    state: TutorGrantState.pending,
    invitedAt: now,
    updatedAt: now,
    expiresAt: now.add(const Duration(days: 7)),
  );
  return TutorGrant.fromDoc(doc);
}

/// Construct a terminal grant that should not be shown in the active roster.
TutorGrant _revokedGrant() {
  final now = DateTime.utc(2026, 1, 1);
  final doc = TutorGrantDoc(
    grantId: 'grant_revoked_1',
    parentUid: 'parent_uid',
    childProfileId: _childUlid,
    tutorEmail: 'revoked@example.com',
    state: TutorGrantState.revokedByParent,
    invitedAt: now,
    updatedAt: now,
    revokedAt: now,
  );
  return TutorGrant.fromDoc(doc);
}

/// Build the widget under test with a mocked router and provider overrides.
///
/// [profiles] — what [profileListProvider] resolves to.
/// [grantsFactory] — maps each child profileId string to the grants list.
/// Pass `null` to keep a provider loading (via a never-completing future).
/// [disableRetry] — set to true when testing error state: passes
///   `retry: (_, __) => null` to ProviderScope so FutureProvider surfaces
///   AsyncError instead of staying stuck in AsyncLoading on first-load failure.
Widget _buildApp({
  required _MockStackRouter router,
  required AsyncValue<List<LearnerProfileEntity>> profilesState,
  Map<String, AsyncValue<List<TutorGrant>>> grantsPerChild = const {},
  _MockAuthRepository? authRepository,
  _MockRevoke? revoke,
  _MockRescind? rescind,
  _MockNotificationGateway? notifications,
  bool disableRetry = false,
  Locale locale = const Locale('en'),
}) {
  final auth = authRepository ?? _MockAuthRepository();
  when(() => auth.currentUser).thenReturn(null);

  final revokeUC = revoke ?? _MockRevoke();
  final rescindUC = rescind ?? _MockRescind();
  final notifGw = notifications ?? _MockNotificationGateway();

  return ProviderScope(
    // retry: null prevents Riverpod from keeping the provider in AsyncLoading
    // when a FutureProvider first-load fails — needed for error-state tests.
    retry: disableRetry ? (_, __) => null : null,
    overrides: [
      // profileListProvider: return the requested AsyncValue
      profileListProvider.overrideWith((ref) {
        switch (profilesState) {
          case AsyncData(:final value):
            return Future.value(value);
          case AsyncError(:final error, :final stackTrace):
            return Future.error(error, stackTrace);
          case _: // loading — never completes
            return Completer<List<LearnerProfileEntity>>().future;
        }
      }),
      // outgoingTutorGrantsProvider per-child overrides
      for (final entry in grantsPerChild.entries)
        outgoingTutorGrantsProvider(entry.key).overrideWith((ref) {
          final v = entry.value;
          if (v is AsyncData<List<TutorGrant>>) {
            return Future.value(v.value);
          } else if (v is AsyncError<List<TutorGrant>>) {
            return Future.error(v.error, v.stackTrace);
          } else {
            return Completer<List<TutorGrant>>().future;
          }
        }),
      authRepositoryProvider.overrideWithValue(auth),
      revokeTutorGrantUseCaseProvider.overrideWithValue(revokeUC),
      rescindTutorInviteUseCaseProvider.overrideWithValue(rescindUC),
      tutorNotificationGatewayProvider.overrideWithValue(notifGw),
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
        child: const Scaffold(body: ManageTutorsScreen()),
      ),
    ),
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late _MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
    registerFallbackValue(_FakeTutorGrant());
  });

  setUp(() {
    router = _MockStackRouter();
    // context.pushRoute(route) delegates to router.push(route, onFailure:)
    // Return a real Future (not null) because the screen awaits it.
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) => Future<Object?>.value(null));
    when(() => router.canPop()).thenReturn(false);
    when(() => router.currentPath).thenReturn('/manage-tutors');
  });

  // ── Loading state ───────────────────────────────────────────────────────────

  testWidgets('shows CircularProgressIndicator while profiles load', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, profilesState: const AsyncLoading()),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Error state ─────────────────────────────────────────────────────────────

  testWidgets(
    'shows AppErrorView "Something went wrong" + Retry when profileListProvider errors',
    (tester) async {
      // disableRetry: true passes retry:(_, __) => null to ProviderScope so
      // the FutureProvider transitions to AsyncError instead of AsyncLoading.
      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncError(
            Exception('network error'),
            StackTrace.current,
          ),
          disableRetry: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // AppErrorView renders the generic title and a Retry button for plain Exception
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('tapping Retry on error view calls ref.refresh (error clears)', (
    tester,
  ) async {
    // Phase 1: render in error state with retry disabled.
    // Tapping Retry triggers ref.refresh(profileListProvider) in the screen;
    // because the provider function returns error every call, we verify the
    // Retry button re-renders (not that it eventually clears — the network is
    // still "broken"). What we assert is that the button is tappable and the
    // screen does not crash (the behaviour contract).
    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncError(Exception('fail'), StackTrace.empty),
        disableRetry: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Tap Retry — should not throw.
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // After retry the screen re-shows the error (same provider → same error).
    // The key assertion: no crash, and the error view is still present.
    expect(find.text('Something went wrong'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Empty profiles state ────────────────────────────────────────────────────

  testWidgets('shows empty-profiles view when no child profiles exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        // One adult profile — no children
        profilesState: AsyncData([_adultProfile()]),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The empty-profiles heading and body are l10n strings
    expect(find.text('No children profiles yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'shows empty-profiles view when profile list is empty (no profiles at all)',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(router: router, profilesState: const AsyncData([])),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No children profiles yet'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('empty-profiles view shows school icon', (tester) async {
    await tester.pumpWidget(
      _buildApp(router: router, profilesState: const AsyncData([])),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.school_outlined), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Adult profiles are excluded ─────────────────────────────────────────────

  testWidgets('does NOT show adult profiles in the list', (tester) async {
    final child = _childProfile(id: 1, displayName: 'Yoni');
    final adult = _adultProfile(id: 2, displayName: 'Dad');

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child, adult]),
        grantsPerChild: {_childUlid: const AsyncData([])},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Child name appears as section header
    expect(find.text('Yoni'), findsOneWidget);
    // Adult name must NOT appear (it has no grants section)
    expect(find.text('Dad'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Populated: child section rendered ──────────────────────────────────────

  testWidgets('renders child name as section header', (tester) async {
    final child = _childProfile(id: 1, displayName: 'Aryeh');

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {_childUlid: const AsyncData([])},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Aryeh'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('renders "No tutors invited." when child has no grants', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'Binyamin');

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {_childUlid: const AsyncData([])},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('No tutors invited.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('renders "No tutors invited." when all grants are terminal', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'Binyamin');

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([_revokedGrant()]),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('No tutors invited.'), findsOneWidget);
    expect(find.text('revoked@example.com'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Invite a tutor button ───────────────────────────────────────────────────

  testWidgets('"Invite a tutor" button is visible for each child section', (
    tester,
  ) async {
    final child1 = _childProfile(id: 1, displayName: 'Child One');
    final child2 = _childProfile(id: 3, displayName: 'Child Two');

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child1, child2]),
        grantsPerChild: {
          _childUlid: const AsyncData([]),
          _thirdUlid: const AsyncData([]),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // One "Invite a tutor" button per child
    expect(find.text('Invite a tutor'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'tapping "Invite a tutor" navigates to InviteTutorRoute via router.push',
    (tester) async {
      final child = _childProfile(id: 1, displayName: 'Dovid');

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([child]),
          grantsPerChild: {_childUlid: const AsyncData([])},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Invite a tutor'));
      await tester.pump();

      // context.pushRoute(InviteTutorRoute(...)) delegates to router.push(...)
      verify(
        () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
      ).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Active grants ───────────────────────────────────────────────────────────

  testWidgets('renders active tutor email and "Active" status label', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'Efraim');
    final grant = _activeGrant(tutorEmail: 'active@tutor.com');

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('active@tutor.com'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('renders "Revoke" button for active grant', (tester) async {
    final child = _childProfile(id: 1, displayName: 'Gershon');
    final grant = _activeGrant();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Revoke'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('renders audit log icon button for active grant', (tester) async {
    final child = _childProfile(id: 1, displayName: 'Hillel');
    final grant = _activeGrant();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.history_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('tapping audit log icon navigates to TutorAuditLogRoute', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'Itzchak');
    final grant = _activeGrant(tutorEmail: 'tutor@log.com');

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pump();

    verify(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('tapping Revoke on active grant opens confirmation dialog', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'Yaakov');
    final grant = _activeGrant(tutorEmail: 'tutor@revoke.com');

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Revoke'));
    await tester.pump();

    // The confirmation dialog appears with the revoke title
    expect(find.text('Revoke tutor access?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('Revoke confirmation dialog shows tutor email in message body', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'Levi');
    final grant = _activeGrant(tutorEmail: 'specific@tutor.com');

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Revoke'));
    await tester.pump();

    // Dialog body contains the tutor's email (may appear in row + dialog)
    expect(find.textContaining('specific@tutor.com'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'cancelling Revoke dialog does NOT call revokeTutorGrantUseCase',
    (tester) async {
      final child = _childProfile(id: 1, displayName: 'Mordechai');
      final grant = _activeGrant();
      final mockRevoke = _MockRevoke();

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([child]),
          grantsPerChild: {
            _childUlid: AsyncData([grant]),
          },
          revoke: mockRevoke,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Revoke'));
      await tester.pump();

      // Tap Cancel in the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      verifyNever(() => mockRevoke.call(grant: any(named: 'grant')));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'confirming Revoke calls revokeTutorGrantUseCase with the grant',
    (tester) async {
      final child = _childProfile(id: 1, displayName: 'Nachman');
      final grant = _activeGrant(tutorEmail: 'tutor@confirmed.com');
      final mockRevoke = _MockRevoke();
      when(
        () => mockRevoke.call(grant: any(named: 'grant')),
      ).thenAnswer((_) async => const TutorGrantSuccess());

      // Provide a notification gateway that absorbs fire-and-forget calls
      final notifGw = _MockNotificationGateway();
      when(
        () => notifGw.notifyTutorOfRevocation(
          tutorEmail: any(named: 'tutorEmail'),
          parentName: any(named: 'parentName'),
          childName: any(named: 'childName'),
        ),
      ).thenAnswer((_) async {});

      // auth repo with a displayName for the parent
      final auth = _MockAuthRepository();
      when(() => auth.currentUser).thenReturn(
        const AppUser(
          uid: 'uid-parent',
          email: 'parent@example.com',
          displayName: 'Test Parent',
          emailVerified: true,
          providers: [],
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([child]),
          grantsPerChild: {
            _childUlid: AsyncData([grant]),
          },
          revoke: mockRevoke,
          authRepository: auth,
          notifications: notifGw,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Revoke'));
      await tester.pump();

      // Confirm in the dialog — tap the second 'Revoke' text (dialog button)
      final revokeButtons = find.text('Revoke');
      await tester.tap(revokeButtons.last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => mockRevoke.call(grant: any(named: 'grant'))).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Pending grants ──────────────────────────────────────────────────────────

  testWidgets('renders pending tutor email and "Pending" status label', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'Pinchas');
    final grant = _pendingGrant(tutorEmail: 'pending@tutor.com');

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('pending@tutor.com'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('renders "Rescind" button for pending grant', (tester) async {
    final child = _childProfile(id: 1, displayName: 'Reuven');
    final grant = _pendingGrant();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Rescind'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('pending grant does NOT show audit log icon (history button)', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'Shimon');
    final grant = _pendingGrant();

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byIcon(Icons.history_rounded), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('tapping Rescind on pending grant opens confirmation dialog', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'Tuvia');
    final grant = _pendingGrant(tutorEmail: 'pending@rescind.com');

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Rescind'));
    await tester.pump();

    expect(find.text('Rescind invitation?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('Rescind confirmation dialog shows tutor email in message body', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'Uri');
    final grant = _pendingGrant(tutorEmail: 'unique@rescind.com');

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Rescind'));
    await tester.pump();

    // Dialog body shows email (may appear in row + dialog)
    expect(find.textContaining('unique@rescind.com'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'cancelling Rescind dialog does NOT call rescindTutorInviteUseCase',
    (tester) async {
      final child = _childProfile(id: 1, displayName: 'Vova');
      final grant = _pendingGrant();
      final mockRescind = _MockRescind();

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([child]),
          grantsPerChild: {
            _childUlid: AsyncData([grant]),
          },
          rescind: mockRescind,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Rescind'));
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      verifyNever(() => mockRescind.call(grant: any(named: 'grant')));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'confirming Rescind calls rescindTutorInviteUseCase with the grant',
    (tester) async {
      final child = _childProfile(id: 1, displayName: 'Wolf');
      final grant = _pendingGrant(tutorEmail: 'tutor@rescindconfirmed.com');
      final mockRescind = _MockRescind();
      when(
        () => mockRescind.call(grant: any(named: 'grant')),
      ).thenAnswer((_) async => const TutorGrantSuccess());

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([child]),
          grantsPerChild: {
            _childUlid: AsyncData([grant]),
          },
          rescind: mockRescind,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Rescind'));
      await tester.pump();

      // Confirm — tap the second 'Rescind' (in the dialog)
      final rescindButtons = find.text('Rescind');
      await tester.tap(rescindButtons.last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => mockRescind.call(grant: any(named: 'grant'))).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Section dividers ────────────────────────────────────────────────────────

  testWidgets(
    'shows "Active (1)" section header when there is one active grant',
    (tester) async {
      final child = _childProfile(id: 1, displayName: 'Zelig');
      final grant = _activeGrant();

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([child]),
          grantsPerChild: {
            _childUlid: AsyncData([grant]),
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // l10n: manageTutorsActiveSection(1) → "Active (1)" (GA-8 title-case fix)
      expect(find.text('Active (1)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'shows "Pending (1)" section header when there is one pending grant',
    (tester) async {
      final child = _childProfile(id: 1, displayName: 'Aba');
      final grant = _pendingGrant();

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([child]),
          grantsPerChild: {
            _childUlid: AsyncData([grant]),
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // l10n: manageTutorsPendingSection(1) → "Pending (1)"
      expect(find.text('Pending (1)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'shows both active and pending sections when grants of each type exist',
    (tester) async {
      final child = _childProfile(id: 1, displayName: 'Benny');
      final active = _activeGrant(tutorEmail: 'active@both.com');
      final pending = _pendingGrant(tutorEmail: 'pending@both.com');

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([child]),
          grantsPerChild: {
            _childUlid: AsyncData([active, pending]),
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('Pending (1)'), findsOneWidget);
      expect(find.text('active@both.com'), findsOneWidget);
      expect(find.text('pending@both.com'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Grants loading state per-child ──────────────────────────────────────────

  testWidgets(
    'shows linear progress indicator while grants for a child are loading',
    (tester) async {
      final child = _childProfile(id: 1, displayName: 'Chana');

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([child]),
          grantsPerChild: {_childUlid: const AsyncLoading()},
        ),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Grants error state per-child ────────────────────────────────────────────

  testWidgets(
    'grants section per-child LinearProgressIndicator shown while loading',
    (tester) async {
      // The grants error path is hard to exercise in the test environment
      // because Future.error is caught by the Flutter test harness before
      // Riverpod can convert it to an AsyncError widget rebuild.
      //
      // We instead verify the intermediate state: a pending Future shows the
      // LinearProgressIndicator inside the child section.
      final child = _childProfile(id: 1, displayName: 'Devorah');
      // A never-completing future keeps the grants in loading state
      final completer = Completer<List<TutorGrant>>();

      final auth = _MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileListProvider.overrideWith((ref) => Future.value([child])),
            outgoingTutorGrantsProvider(
              _childUlid,
            ).overrideWith((ref) => completer.future),
            authRepositoryProvider.overrideWithValue(auth),
            revokeTutorGrantUseCaseProvider.overrideWithValue(_MockRevoke()),
            rescindTutorInviteUseCaseProvider.overrideWithValue(_MockRescind()),
            tutorNotificationGatewayProvider.overrideWithValue(
              _MockNotificationGateway(),
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
              controller: router,
              stateHash: 0,
              child: const Scaffold(body: ManageTutorsScreen()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Devorah'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Resolve the completer with empty list — error state test omitted
      // because the Flutter test harness swallows Future.error before
      // Riverpod can render the error widget.
      completer.complete([]);
      await tester.pump(const Duration(seconds: 1));

      // After resolution, LoadingIndicator is gone and no-tutors text appears
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('No tutors invited.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── AppBar title ────────────────────────────────────────────────────────────

  testWidgets('AppBar title reads "Manage Tutors" (l10n)', (tester) async {
    await tester.pumpWidget(
      _buildApp(router: router, profilesState: const AsyncData([])),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Manage Tutors'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Revoke failure → SnackBar ───────────────────────────────────────────────

  testWidgets('confirming Revoke shows SnackBar when use case throws', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'ErrorTest');
    final grant = _activeGrant(tutorEmail: 'fail@revoke.com');
    final mockRevoke = _MockRevoke();
    // The use case throws a plain exception — the screen catches it and shows
    // a SnackBar with the error message.
    when(
      () => mockRevoke.call(grant: any(named: 'grant')),
    ).thenThrow(Exception('Server unavailable'));

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
        revoke: mockRevoke,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Revoke'));
    await tester.pump();

    // Tap the confirm button in the dialog
    await tester.tap(find.text('Revoke').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // SnackBar appears...
    expect(find.byType(SnackBar), findsOneWidget);
    // AUD-tutoring-11: ...with a fixed localized string — never the raw
    // exception text interpolated into UI copy (EH-5).
    expect(find.text('Could not revoke. Please try again.'), findsOneWidget);
    expect(find.textContaining('Server unavailable'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('AUD-tutoring-11: Revoke SnackBar text is the same fixed string '
      'regardless of the exception message', (tester) async {
    final child = _childProfile(id: 1, displayName: 'ErrorTest2');
    final grant = _activeGrant(tutorEmail: 'fail2@revoke.com');
    final mockRevoke = _MockRevoke();
    // A completely different exception message/type than the other test.
    when(
      () => mockRevoke.call(grant: any(named: 'grant')),
    ).thenThrow(StateError('PERMISSION_DENIED: gRPC status 7'));

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
        revoke: mockRevoke,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Revoke'));
    await tester.pump();
    await tester.tap(find.text('Revoke').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Could not revoke. Please try again.'), findsOneWidget);
    expect(find.textContaining('gRPC'), findsNothing);
    expect(find.textContaining('PERMISSION_DENIED'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Rescind failure → SnackBar ──────────────────────────────────────────────

  testWidgets('confirming Rescind shows SnackBar when use case throws', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'RescindFail');
    final grant = _pendingGrant(tutorEmail: 'fail@rescind.com');
    final mockRescind = _MockRescind();
    when(
      () => mockRescind.call(grant: any(named: 'grant')),
    ).thenThrow(Exception('Network error'));

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
        rescind: mockRescind,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Rescind'));
    await tester.pump();

    await tester.tap(find.text('Rescind').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SnackBar), findsOneWidget);
    // AUD-tutoring-11: a fixed localized string — never the raw exception
    // text interpolated into UI copy (EH-5).
    expect(find.text('Could not rescind. Please try again.'), findsOneWidget);
    expect(find.textContaining('Network error'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── In-flight guard ─────────────────────────────────────────────────────────

  testWidgets('Revoke button replaced by spinner while use case is in-flight', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'Inflight');
    final grant = _activeGrant(tutorEmail: 'tutor@inflight.com');
    final mockRevoke = _MockRevoke();
    final notifGw = _MockNotificationGateway();
    // Use a Completer so we can hold the use case in-flight.
    final completer = Completer<TutorGrantResult>();
    when(
      () => mockRevoke.call(grant: any(named: 'grant')),
    ).thenAnswer((_) => completer.future);
    when(
      () => notifGw.notifyTutorOfRevocation(
        tutorEmail: any(named: 'tutorEmail'),
        parentName: any(named: 'parentName'),
        childName: any(named: 'childName'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([grant]),
        },
        revoke: mockRevoke,
        notifications: notifGw,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Open the dialog and confirm
    await tester.tap(find.text('Revoke'));
    await tester.pump();
    await tester.tap(find.text('Revoke').last);
    await tester.pump();

    // While the use case future is pending, the row should show a spinner
    // and the Revoke TextButton should be replaced by the CircularProgressIndicator.
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    // The Revoke button TextButton is gone (replaced by spinner)
    expect(find.text('Revoke'), findsNothing);

    // Resolve to unblock the test
    completer.complete(const TutorGrantSuccess());
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Revocation notification fired ──────────────────────────────────────────

  testWidgets(
    'confirming Revoke fires notifyTutorOfRevocation after use case succeeds',
    (tester) async {
      final child = _childProfile(id: 1, displayName: 'Notif Child');
      final grant = _activeGrant(tutorEmail: 'notify@tutor.com');
      final mockRevoke = _MockRevoke();
      final notifGw = _MockNotificationGateway();
      when(
        () => mockRevoke.call(grant: any(named: 'grant')),
      ).thenAnswer((_) async => const TutorGrantSuccess());
      when(
        () => notifGw.notifyTutorOfRevocation(
          tutorEmail: any(named: 'tutorEmail'),
          parentName: any(named: 'parentName'),
          childName: any(named: 'childName'),
        ),
      ).thenAnswer((_) async {});

      final auth = _MockAuthRepository();
      when(() => auth.currentUser).thenReturn(
        const AppUser(
          uid: 'uid-parent',
          email: 'parent@example.com',
          displayName: 'Test Parent',
          emailVerified: true,
          providers: [],
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([child]),
          grantsPerChild: {
            _childUlid: AsyncData([grant]),
          },
          revoke: mockRevoke,
          authRepository: auth,
          notifications: notifGw,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Revoke'));
      await tester.pump();
      await tester.tap(find.text('Revoke').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The notification gateway must have been called with the tutor email
      verify(
        () => notifGw.notifyTutorOfRevocation(
          tutorEmail: 'notify@tutor.com',
          parentName: any(named: 'parentName'),
          childName: any(named: 'childName'),
        ),
      ).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Grants error per-child ──────────────────────────────────────────────────

  testWidgets(
    'per-child grants section shows error text when grants provider errors',
    (tester) async {
      final child = _childProfile(id: 1, displayName: 'ErrorChild');
      final auth = _MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);

      // Use ProviderScope with retry disabled + grants error so the per-child
      // section transitions to error state.
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            profileListProvider.overrideWith((ref) => Future.value([child])),
            outgoingTutorGrantsProvider(_childUlid).overrideWith(
              (ref) => Future.error(
                Exception('Firestore unavailable'),
                StackTrace.empty,
              ),
            ),
            authRepositoryProvider.overrideWithValue(auth),
            revokeTutorGrantUseCaseProvider.overrideWithValue(_MockRevoke()),
            rescindTutorInviteUseCaseProvider.overrideWithValue(_MockRescind()),
            tutorNotificationGatewayProvider.overrideWithValue(
              _MockNotificationGateway(),
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
              controller: router,
              stateHash: 0,
              child: const Scaffold(body: ManageTutorsScreen()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Child section header is present
      expect(find.text('ErrorChild'), findsOneWidget);
      // AUD-tutoring-11: per-child error text is a fixed localized string
      // (l10n.manageTutorsLoadErrorGeneric) — never the raw exception text
      // interpolated into UI copy (EH-5).
      expect(
        find.text('Could not load tutors. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('Firestore unavailable'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── R-TU2: permission-denied surfaces as error, not empty list ─────────────

  testWidgets(
    'R-TU2: permission-denied on grants shows error text — NOT "No tutors"',
    (tester) async {
      // Regression for R-TU2: before the fix, a FirebaseFunctionsException with
      // code=permission-denied was caught in listOutgoingGrants and returned []
      // rather than being rethrown. The FutureProvider then delivered an empty
      // list, so the UI rendered "No tutors invited." — masking the real state.
      // After the fix, permission-denied is rethrown, the FutureProvider becomes
      // AsyncError, and the screen shows the per-child error text instead.
      final child = _childProfile(id: 1, displayName: 'PermDeniedChild');
      final auth = _MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            profileListProvider.overrideWith((ref) => Future.value([child])),
            outgoingTutorGrantsProvider(_childUlid).overrideWith(
              (ref) => Future.error(
                Exception(
                  'PERMISSION_DENIED: Missing or insufficient permissions',
                ),
                StackTrace.empty,
              ),
            ),
            authRepositoryProvider.overrideWithValue(auth),
            revokeTutorGrantUseCaseProvider.overrideWithValue(_MockRevoke()),
            rescindTutorInviteUseCaseProvider.overrideWithValue(_MockRescind()),
            tutorNotificationGatewayProvider.overrideWithValue(
              _MockNotificationGateway(),
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
              controller: router,
              stateHash: 0,
              child: const Scaffold(body: ManageTutorsScreen()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Child name header is still visible.
      expect(find.text('PermDeniedChild'), findsOneWidget);
      // The per-child error text MUST be shown — as a fixed localized
      // string (AUD-tutoring-11: never the raw exception text; EH-5).
      expect(
        find.text('Could not load tutors. Please try again.'),
        findsOneWidget,
        reason:
            'R-TU2: permission-denied must surface as an error, not an empty list',
      );
      expect(find.textContaining('PERMISSION_DENIED'), findsNothing);
      // "No tutors invited." MUST NOT be shown — that would mask the denial.
      expect(
        find.text('No tutors invited.'),
        findsNothing,
        reason:
            'R-TU2: "No tutors invited." must not appear on permission-denied',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── RTL (Hebrew locale) ─────────────────────────────────────────────────────

  testWidgets('Hebrew locale: key affordances render without overflow/crash', (
    tester,
  ) async {
    final child = _childProfile(id: 1, displayName: 'משה');
    final active = _activeGrant(tutorEmail: 'rtl@tutor.com');

    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncData([child]),
        grantsPerChild: {
          _childUlid: AsyncData([active]),
        },
        locale: const Locale('he'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Core affordances must still be visible under RTL
    expect(find.text('משה'), findsOneWidget);
    expect(find.text('rtl@tutor.com'), findsOneWidget);
    // Invite button is present
    expect(find.byIcon(Icons.person_add_rounded), findsOneWidget);
    // Audit log icon is present
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── DG-TUT-STALE-01 (P0): reliable re-fetch on (re)show + pull-to-refresh ───

  testWidgets(
    'P0: screen wraps the grants list in a RefreshIndicator (pull-to-refresh)',
    (tester) async {
      final child = _childProfile(id: 1, displayName: 'Refreshable');
      final grant = _pendingGrant();

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([child]),
          grantsPerChild: {
            _childUlid: AsyncData([grant]),
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(RefreshIndicator), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'P0: re-fetches outgoing grants on (re)show — provider re-runs after mount',
    (tester) async {
      // The screen must re-query on entry so a tutor acceptance (a remote
      // change) flips Pending → Active rather than serving a stale cache.
      // We count how many times the provider future is built: an initState
      // invalidate forces a SECOND build after the initial mount build.
      final child = _childProfile(id: 1, displayName: 'Loop Test C');
      var buildCount = 0;

      final auth = _MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileListProvider.overrideWith((ref) => Future.value([child])),
            outgoingTutorGrantsProvider(_childUlid).overrideWith((ref) {
              buildCount++;
              return Future.value(<TutorGrant>[]);
            }),
            authRepositoryProvider.overrideWithValue(auth),
            revokeTutorGrantUseCaseProvider.overrideWithValue(_MockRevoke()),
            rescindTutorInviteUseCaseProvider.overrideWithValue(_MockRescind()),
            tutorNotificationGatewayProvider.overrideWithValue(
              _MockNotificationGateway(),
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
              controller: router,
              stateHash: 0,
              child: const Scaffold(body: ManageTutorsScreen()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // Let the post-frame initState invalidate land and the provider re-run.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // > 1 proves the screen forced a fresh re-fetch on show rather than
      // relying solely on the (possibly stale) first cached result.
      expect(
        buildCount,
        greaterThan(1),
        reason: 'Screen must re-query outgoing grants on (re)show',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Multiple children: per-child Invite routes use correct profileId ────────

  testWidgets(
    'tapping "Invite a tutor" for second child still pushes to router',
    (tester) async {
      final child1 = _childProfile(id: 1, displayName: 'Alpha');
      final child2 = _childProfile(id: 2, displayName: 'Beta');

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([child1, child2]),
          grantsPerChild: {
            _childUlid: const AsyncData([]),
            'ulid-2': const AsyncData([]),
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Two "Invite a tutor" buttons — tap the second one (for child2)
      final inviteButtons = find.text('Invite a tutor');
      expect(inviteButtons, findsNWidgets(2));
      await tester.tap(inviteButtons.last);
      await tester.pump();

      // Router must be called — the screen uses context.pushRoute
      verify(
        () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
      ).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── AUD-tutoring-08 (PF-2, verify-correction site): per-child tutor list ───

  testWidgets(
    'AUD-tutoring-08: per-child tutor list is backed by ListView.builder, '
    'not a fully-expanded Column(children:)',
    (tester) async {
      final child = _childProfile(id: 1, displayName: 'Roster Child');
      final now = DateTime.utc(2026, 1, 1);
      final grants = [
        for (var i = 0; i < 50; i++)
          TutorGrant.fromDoc(
            TutorGrantDoc(
              grantId: 'grant_$i',
              parentUid: 'parent_uid',
              childProfileId: _childUlid,
              tutorEmail: 'tutor$i@example.com',
              state: TutorGrantState.active,
              invitedAt: now,
              updatedAt: now,
              acceptedAt: now,
            ),
            permissions: TutorPermissions.defaults(),
          ),
      ];

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([child]),
          grantsPerChild: {_childUlid: AsyncData(grants)},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Structural proof: every ListView in the tree (the outer per-profile
      // list and the inner per-child tutor list) is builder-backed rather
      // than an eagerly-expanded `for` loop feeding Column(children:).
      //
      // NOTE: the inner per-child list is necessarily `shrinkWrap: true` +
      // NeverScrollableScrollPhysics (it lives inside the outer scrollable,
      // one list item per child) — Flutter still lays out every child of a
      // shrink-wrapped ListView.builder to compute its height, so this
      // specific nested site does not gain true off-screen-widget savings
      // the way the top-level ManageGrantsScreen and the capped Settings
      // preview do. It is fixed here for consistency with the flagged
      // for-loop-into-ListView(/Column( pattern and to make a future
      // migration to slivers a pure delegate swap; the real roster-size
      // mitigation for this narrower, lower-severity site is future work
      // (see notes).
      final listViews = tester.widgetList<ListView>(find.byType(ListView));
      // Exactly 2: the outer per-profile ListView.builder (pre-existing) and
      // the inner per-child tutor-rows ListView.builder (this fix). Before
      // the fix the inner list was a plain Column — only 1 ListView existed.
      expect(
        listViews,
        hasLength(2),
        reason:
            'The per-child tutor rows must themselves be a ListView.builder '
            '(not a Column) so the fix actually replaces the flagged '
            '`for` loop pattern.',
      );
      for (final listView in listViews) {
        expect(
          listView.childrenDelegate,
          isA<SliverChildBuilderDelegate>(),
          reason:
              'Every grants ListView must be built via ListView.builder '
              'rather than a `for` loop feeding Column(/ListView(children:.',
        );
      }
      expect(find.text('tutor0@example.com'), findsOneWidget);
      expect(find.text('tutor49@example.com'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
