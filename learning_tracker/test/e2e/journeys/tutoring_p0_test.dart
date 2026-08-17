/// E2E Wave 1 P0 journeys — Tutoring area.
///
/// Journeys implemented:
///   E2E-1001  Parent invites a tutor for a child
///   E2E-1002  Tutor accepts invite via email deep-link
///   E2E-1003  Tutor accepts invite from profile-picker pending invite card
///   E2E-1005  Tutor enters talmid session via ManageGrantsScreen (device-only)
///   E2E-1007  Parent revokes an active tutor grant
///   E2E-1010  Tutor sets up PIN for first time — from TutorPinEntryGate
///   E2E-1012  Tutor live-mark blocked in talmid session
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 10 / §7 R-TU*
@Tags(['e2e', 'journey'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show connectivityStreamProvider;
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart'
    show TextContent;
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart'
    show adjacentContentRefsProvider;
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart'
    show textContentProvider;
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart'
    show isStageCompletedProvider, trackStorageKeyForTrackIdProvider;
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart'
    show
        dashboardActiveTracksStreamProvider,
        dashboardStreakProvider,
        dashboardStreakRecoveryProvider;
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart'
    show StreakRecoveryInfo;
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart'
    show currentSacredWindowProvider;
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart'
    show allDailyTasksProvider, coarsePacedTrackIdsProvider;
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_notification_service.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show
        incomingTutorGrantsProvider,
        outgoingTutorGrantsProvider,
        revokeTutorGrantUseCaseProvider,
        tutorNotificationGatewayProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider, tutorGrantRepositoryProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart'
    show tutorPinIsSetProvider, tutorPinServiceProvider;
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_entry_gate.dart'
    show TutorPinEntryGate;
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../helpers/firestore_fixtures.dart';
import '../fakes/e2e_fakes.dart';
import '../harness/e2e_common_overrides.dart';
import '../harness/e2e_harness.dart';

// ── Fakes / Stubs ─────────────────────────────────────────────────────────────

/// Fake [TutorGrantRepository] that records calls and returns fixed results.
class _FakeTutorGrantRepository extends Fake implements TutorGrantRepository {
  final List<String> invitedEmails = [];
  final List<TutorGrant> _incoming;
  final List<TutorGrant> _outgoing;
  final List<String> revokedGrants = [];

  _FakeTutorGrantRepository({
    List<TutorGrant> incoming = const [],
    List<TutorGrant> outgoing = const [],
  }) : _incoming = incoming,
       _outgoing = outgoing;

  @override
  Future<TutorGrantResult> inviteTutor({
    required String tutorEmail,
    required String childProfileId,
    required TutorPermissions permissions,
    String? childName,
    String? parentName,
  }) async {
    invitedEmails.add(tutorEmail);
    return const TutorGrantSuccess();
  }

  @override
  Future<TutorGrantResult> acceptInvite({required String grantId}) async =>
      const TutorGrantSuccess();

  @override
  Future<TutorGrantResult> declineInvite({required String grantId}) async =>
      const TutorGrantSuccess();

  @override
  Future<TutorGrantResult> rescindInvite({required String grantId}) async =>
      const TutorGrantSuccess();

  @override
  Future<TutorGrantResult> revokeGrant({required String grantId}) async {
    revokedGrants.add(grantId);
    return const TutorGrantSuccess();
  }

  @override
  Future<TutorGrantResult> resignGrant({required String grantId}) async =>
      const TutorGrantSuccess();

  @override
  Future<List<TutorGrant>> listIncomingGrants() async => _incoming;

  @override
  Future<({List<TutorGrant> grants, bool ok})>
  listIncomingGrantsWithStatus() async => (grants: _incoming, ok: true);

  @override
  Future<List<TutorGrant>> listOutgoingGrants({
    required String childProfileId,
  }) async => _outgoing;

  @override
  Future<List<TutorGrant>> listPendingInvitesForMe() async =>
      _incoming.where((g) => g.grantState is PendingGrant).toList();
}

/// Fake [RevokeTutorGrantUseCase] that records calls without hitting Firestore.
class _FakeRevokeTutorGrantUseCase extends Fake
    implements RevokeTutorGrantUseCase {
  final List<TutorGrant> revokedGrants = [];

  _FakeRevokeTutorGrantUseCase(TutorGrantRepository _);

  @override
  Future<TutorGrantResult> call({required TutorGrant grant}) async {
    revokedGrants.add(grant);
    return const TutorGrantSuccess();
  }
}

/// [TutorPinService] stub: hasTutorPin always returns false.
/// setTutorPin records the PIN and returns success.
class _NoPinTutorPinService extends Fake implements TutorPinService {
  final List<String> savedPins = [];

  @override
  Future<bool> hasTutorPin(String profileId) async => false;

  @override
  Future<TutorPinResult> setTutorPin({
    required String profileId,
    required String rawPin,
  }) async {
    savedPins.add(rawPin);
    return const TutorPinSuccess();
  }

  @override
  Future<TutorPinResult> verifyTutorPin({
    required String profileId,
    required String rawPin,
  }) async => const TutorPinIncorrect();

  @override
  Future<void> clearTutorPin(String profileId) async {}
}

/// [TutorPinService] stub: hasTutorPin always returns true (PIN already set).
class _PinAlreadySetService extends Fake implements TutorPinService {
  @override
  Future<bool> hasTutorPin(String profileId) async => true;

  @override
  Future<TutorPinResult> setTutorPin({
    required String profileId,
    required String rawPin,
  }) async => const TutorPinSuccess();

  @override
  Future<TutorPinResult> verifyTutorPin({
    required String profileId,
    required String rawPin,
  }) async => const TutorPinSuccess();

  @override
  Future<void> clearTutorPin(String profileId) async {}
}

/// Fake [TutorNotificationGateway] that discards all fire-and-forget calls.
class _NoopTutorNotificationGateway extends Fake
    implements TutorNotificationGateway {
  @override
  Future<void> notifyTutorOfRevocation({
    required String tutorEmail,
    required String parentName,
    required String childName,
  }) async {}

  @override
  Future<void> notifyParentOfDecline({
    required String parentEmail,
    required String tutorEmail,
    required String childName,
    String parentUid = '',
  }) async {}

  @override
  Future<void> notifyParentOfResignation({
    required String parentEmail,
    required String tutorName,
    required String childName,
    String parentUid = '',
  }) async {}
}

/// Fixed-value notifier for [ActiveTutoredProfileSelection] with a live session.
class _FixedTutoredSelection extends ActiveTutoredProfileSelection {
  _FixedTutoredSelection(this._fixed);
  final TutoredProfileSelection _fixed;

  @override
  TutoredProfileSelection? build() => _fixed;
}

// ── Grant factory helpers ─────────────────────────────────────────────────────

TutorGrant _pendingGrant({
  String grantId = 'grant-001',
  String tutorEmail = 'tutor@example.com',
  String childProfileId = 'child-profile-1',
}) {
  final now = DateTimeFactory.nowUtc();
  return TutorGrant.fromDoc(
    TutorGrantDoc(
      grantId: grantId,
      parentUid: 'parent-uid-1',
      childProfileId: childProfileId,
      tutorEmail: tutorEmail,
      state: TutorGrantState.pending,
      invitedAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(days: 7)),
      childName: 'TestChild',
    ),
  );
}

TutorGrant _activeGrant({
  String grantId = 'grant-active-001',
  String tutorEmail = 'activetutor@example.com',
  String childProfileId = 'child-profile-2',
}) {
  final now = DateTimeFactory.nowUtc();
  return TutorGrant.fromDoc(
    TutorGrantDoc(
      grantId: grantId,
      parentUid: 'parent-uid-1',
      childProfileId: childProfileId,
      tutorEmail: tutorEmail,
      state: TutorGrantState.active,
      invitedAt: now.subtract(const Duration(days: 1)),
      updatedAt: now,
      acceptedAt: now.subtract(const Duration(hours: 12)),
      childName: 'TestChild',
    ),
    permissions: TutorPermissions.defaults(),
  );
}

// ── Common provider overrides ─────────────────────────────────────────────────

/// Silence heavy providers that create timers or make network calls.
List<Override> _baseSilences(E2EHarness h) => [
  ...h.dashboardSilenceOverrides,
  currentSacredWindowProvider.overrideWithValue(null),
  connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
  incomingTutorGrantsProvider.overrideWith((ref) => Future.value([])),
  pendingTutorInvitesProvider.overrideWith((ref) => Future.value([])),
];

/// Streak + active-tracks silence for non-dashboard routes (deep-links etc.).
///
/// [E2EHarness.dashboardSilenceOverrides] covers dashboard tests. For routes
/// that do NOT start at the shell (e.g. `/invite`, `/text/<ref>`), these
/// providers must still be overridden to prevent the 15-minute
/// [StreakStateService] periodic timer from leaking into the test teardown.
List<Override> _nonDashboardStreakSilences() => [
  dashboardStreakProvider.overrideWith(
    (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
  ),
  dashboardStreakRecoveryProvider.overrideWith(
    (ref) => Future.value(
      const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
    ),
  ),
  dashboardActiveTracksStreamProvider.overrideWith(
    (ref) => Stream.value(const []),
  ),
];

/// Navigate to [route] and pump until all animations settle.
///
/// Use instead of [_navigateTo] when a slide-in route transition might
/// produce a transient [RenderFlex] overflow in a sub-frame (the
/// "DISPOSED OVERFLOWING" variant where the overflowing render object is
/// already disposed when the error is reported). [pumpAndSettle] completes
/// all animation frames before Flutter reports layout errors, so no
/// disposed-overflow error reaches the test harness.
Future<void> _navigateToSettle(
  E2EHarness h,
  WidgetTester tester,
  PageRouteInfo route,
) async {
  unawaited(h.router.push(route));
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

// ── Numpad tap helper ─────────────────────────────────────────────────────────

/// Taps the last widget containing [digit] text (the on-screen numpad button).
Future<void> _tapDigit(WidgetTester tester, String digit) async {
  await tester.tap(find.text(digit).last);
  await tester.pump(const Duration(milliseconds: 50));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-1001 ─────────────────────────────────────────────────────────────────

  group('E2E-1001 — Parent invites a tutor for a child', () {
    // Seed a child profile so InviteTutorScreen has a valid childProfileId.
    // Navigate directly to /tutor/invite?childProfileId=<id>.
    // The product no longer supports local-born sessions (91798ab8), so this
    // journey exercises the current cloud-account invite path.

    testWidgets(
      'cloud-born parent: tapping Send invite calls inviteTutorUseCase with '
      'the entered email',
      (tester) async {
        final identity = E2EIdentity.cloudBorn(
          email: 'parent1001@example.com',
          displayName: 'Parent1001',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final fakeRepo = _FakeTutorGrantRepository();

        await h.pumpApp(
          path: '/dashboard',
          extraOverrides: [
            ..._baseSilences(h),
            tutorGrantRepositoryProvider.overrideWithValue(fakeRepo),
            outgoingTutorGrantsProvider.overrideWith(
              (ref, childProfileId) => Future.value(<TutorGrant>[]),
            ),
            tutorNotificationGatewayProvider.overrideWithValue(
              _NoopTutorNotificationGateway(),
            ),
            activeTutoredProfileSelectionProvider.overrideWith(
              () => NullTutoredSelection(),
            ),
          ],
        );

        // Seed a child profile into Firestore using its ULID document identity.
        const childProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXYB';
        await seedProfile(
          h.firestore,
          uid: identity.accountId,
          profileId: childProfileId,
          displayName: 'ChildToTutor',
          mode: ProfileMode.child,
        );

        // Navigate to InviteTutorScreen with the child's profile id.
        // Use _navigateToSettle so all animation frames complete before Flutter
        // reports any layout errors — prevents "DISPOSED OVERFLOWING" from a
        // transient slide-in frame with minimal height constraints.
        await _navigateToSettle(
          h,
          tester,
          InviteTutorRoute(childProfileId: childProfileId),
        );

        // InviteTutor screen heading should be visible.
        h.expectOnScreen('Invite a Tutor');

        // Enter a valid tutor email.
        const tutorEmail = 'newtutor1001@example.com';
        await h.enterText(find.byType(TextFormField), tutorEmail);
        await h.pump(const Duration(milliseconds: 100));

        // Tap the Send invite button.
        await h.tapText('Send invite');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // Current product behavior dispatches the invite for cloud accounts.
        expect(
          fakeRepo.invitedEmails,
          contains(tutorEmail),
          reason:
              'Expected inviteTutorUseCase to be called with the entered '
              'email for a cloud-born account.',
        );
      },
    );
  });

  // ── E2E-1002 ─────────────────────────────────────────────────────────────────

  group('E2E-1002 — Tutor accepts invite via email deep-link', () {
    // Deep-link path: /invite?token=<grantId>
    // AcceptInviteScreen initialises → reads incomingTutorGrantsProvider →
    // shows "ready to accept" body. Tap "Accept invite" → success heading.
    //
    // tutorPinServiceProvider stubbed to return hasTutorPin=true so the
    // pin-setup step is skipped and the success state renders directly.

    testWidgets(
      'navigating to /invite?token=X shows accept screen; tapping Accept '
      'leads to success state',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'tutor1002@example.com',
          displayName: 'Tutor1002',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        const grantId = 'grant-deep-link-001';
        final pending = _pendingGrant(grantId: grantId);
        final fakeRepo = _FakeTutorGrantRepository(incoming: [pending]);

        await h.pumpApp(
          path: '/invite?token=$grantId',
          extraOverrides: [
            // Silence the 15-minute StreakStateService periodic timer.
            // The invite deep-link skips the shell, but the provider scope
            // still initialises dashboard providers that create this timer.
            ..._nonDashboardStreakSilences(),
            tutorGrantRepositoryProvider.overrideWithValue(fakeRepo),
            incomingTutorGrantsProvider.overrideWith(
              (ref) => Future.value([pending]),
            ),
            pendingTutorInvitesProvider.overrideWith((ref) => Future.value([])),
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value(true),
            ),
            currentSacredWindowProvider.overrideWithValue(null),
            // hasTutorPin=true → skip PIN setup, go straight to success.
            tutorPinServiceProvider.overrideWithValue(_PinAlreadySetService()),
            tutorPinIsSetProvider.overrideWith(
              (ref, profileId) => Future.value(true),
            ),
          ],
        );

        // Extra pumps so the initState postFrameCallback (_initialize) runs.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Accept invite screen should show the "ready to accept" body.
        h.expectOnScreen('Accept tutor invite');
        h.expectOnScreen('Accept invite');

        // Tap the Accept invite button.
        await h.tapText('Accept invite');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // After acceptance (with PIN already set) the success heading appears.
        h.expectOnScreen('Invite accepted!');
      },
    );
  });

  // ── E2E-1003 ─────────────────────────────────────────────────────────────────

  group('E2E-1003 — Tutor accepts invite from profile-picker pending invite '
      'card', () {
    // Risk: R-TU8 (_ViewInvitationsRow double Navigator.pop).
    //
    // BUG: _PendingInviteCard (ProfilePickerScreen) does NOT display the
    // tutor email or child name — it only shows the generic l10n
    // acceptInviteHeading string ("Accept tutor invite") and the
    // acceptInviteBody text, with no per-grant identifier. The catalog
    // assertion "The pending invite card displays the tutor email" cannot
    // pass until the card is updated to show the tutorEmail field from the
    // TutorGrant. The test is skipped until that fix lands.
    //
    // Correct-behavior assertion: pendingInviteCard shows `tutorEmail` from
    // the TutorGrant so the parent can distinguish multiple pending invites.

    testWidgets(
      'pending invite card on /profile-picker taps to AcceptInviteScreen',
      // BUG: _PendingInviteCard does not display tutorEmail —
      // correct-behavior assertion kept; fix _PendingInviteCard first.
      skip: true,
      (tester) async {
        final identity = E2EIdentity.localBorn(
          email: 'tutor1003@example.com',
          displayName: 'Tutor1003',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final pending = _pendingGrant(
          grantId: 'grant-picker-001',
          tutorEmail: 'tutor1003@example.com',
        );
        final fakeRepo = _FakeTutorGrantRepository(incoming: [pending]);

        await h.pumpApp(
          path: '/profile-picker',
          extraOverrides: [
            ..._nonDashboardStreakSilences(),
            tutorGrantRepositoryProvider.overrideWithValue(fakeRepo),
            pendingTutorInvitesProvider.overrideWith(
              (ref) => Future.value([pending]),
            ),
            incomingTutorGrantsProvider.overrideWith((ref) => Future.value([])),
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value(true),
            ),
            currentSacredWindowProvider.overrideWithValue(null),
            tutorPinServiceProvider.overrideWithValue(_PinAlreadySetService()),
            tutorPinIsSetProvider.overrideWith(
              (ref, profileId) => Future.value(true),
            ),
          ],
        );

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));

        // KEY ASSERTION (correct-behavior): the pending invite card must show
        // the tutor email so the user can identify which invite to accept.
        h.expectOnScreen('tutor1003@example.com');

        // Tap the invite card → AcceptInviteScreen pushed.
        await h.tapText('tutor1003@example.com');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));

        // AcceptInviteScreen is now visible (app bar title).
        h.expectOnScreen('Accept Tutor Invite');
      },
    );
  });

  // ── E2E-1005 ─────────────────────────────────────────────────────────────────

  group(
    'E2E-1005 — Tutor enters talmid session (PIN gate + pull + navigation)',
    () {
      // The full PIN-gate + _fireEntryPullAndNavigate flow requires the
      // PersistentSwitcherScaffold which is NOT mounted in the headless harness
      // (R-IC1). The ManageGrantsScreen itself has no "tap grant to enter" action
      // — talmid entry is driven from the switcher sheet mounted in
      // LearningTrackerApp. The entry path passes through providers that touch
      // TutoredPullService (live Firestore pull), also device-only.
      //
      // Smoke test: ManageGrantsScreen renders with an active grant row visible,
      // confirming the screen is reachable and the grant data is surfaced.

      // device-test required (R-IC1): TutorPinEntryGate + talmid entry
      // requires PersistentSwitcherScaffold not mounted in headless harness.
      testWidgets(
        'ManageGrantsScreen renders with active grant row visible '
        '(smoke — full entry flow is device-only: R-IC1)',
        skip: true,
        (tester) async {
          final identity = E2EIdentity.localBorn(
            email: 'tutor1005@example.com',
            displayName: 'Tutor1005',
            profileMode: 'adult',
          );
          final h = E2EHarness(tester, identity: identity);
          addTearDown(h.dispose);

          final activeGrant = _activeGrant();
          final fakeRepo = _FakeTutorGrantRepository(incoming: [activeGrant]);

          await h.pumpApp(
            path: '/dashboard',
            extraOverrides: [
              ..._baseSilences(h),
              tutorGrantRepositoryProvider.overrideWithValue(fakeRepo),
              incomingTutorGrantsProvider.overrideWith(
                (ref) => Future.value([activeGrant]),
              ),
              activeTutoredProfileSelectionProvider.overrideWith(
                () => NullTutoredSelection(),
              ),
            ],
          );

          await navigateTo(h, const ManageGrantsRoute());
          await tester.pump(const Duration(milliseconds: 300));

          h.expectOnScreen('My Tutoring Grants');
          h.expectOnScreen('TestChild');
        },
      );
    },
  );

  // ── E2E-1007 ─────────────────────────────────────────────────────────────────

  group('E2E-1007 — Parent revokes an active tutor grant', () {
    // Risk: R-TU1 (AlertDialog overflow risk) — overflow guard in Wave 3.
    // Risk: R-TU2 (pull-to-refresh swallows permission-denied) — P1 sub-case.
    //
    // Approach:
    //   1. Seed a child profile in Drift.
    //   2. Override outgoingTutorGrantsProvider with an active grant.
    //   3. Override revokeTutorGrantUseCaseProvider with _FakeRevokeTutorGrantUseCase.
    //   4. Navigate to ManageTutorsScreen.
    //   5. Tap "Revoke" button on the active grant row.
    //   6. Confirm the AlertDialog.
    //   7. Assert the fake use case was called with the grant.

    testWidgets('tapping Revoke and confirming dialog calls '
        'RevokeTutorGrantUseCase with the active grant', (tester) async {
      final identity = E2EIdentity.localBorn(
        email: 'parent1007@example.com',
        displayName: 'Parent1007',
        profileMode: 'adult',
      );
      // Use the same stable ULID for the seeded child and the grant row.
      const childProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXYC';
      final activeGrant = _activeGrant(childProfileId: childProfileId);

      final fakeRevoke = _FakeRevokeTutorGrantUseCase(
        _FakeTutorGrantRepository(),
      );

      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ..._baseSilences(h),
          // Return [activeGrant] for every childProfileId argument so the
          // grant row is visible regardless of which DB-assigned profile id
          // the child gets.
          outgoingTutorGrantsProvider.overrideWith(
            (ref, childProfileId) => Future.value([activeGrant]),
          ),
          revokeTutorGrantUseCaseProvider.overrideWithValue(fakeRevoke),
          tutorNotificationGatewayProvider.overrideWithValue(
            _NoopTutorNotificationGateway(),
          ),
          activeTutoredProfileSelectionProvider.overrideWith(
            () => NullTutoredSelection(),
          ),
        ],
      );

      await seedProfile(
        h.firestore,
        uid: identity.accountId,
        profileId: childProfileId,
        displayName: 'ChildForRevoke',
        mode: ProfileMode.child,
      );

      await navigateTo(h, const ManageTutorsRoute());
      await tester.pump(const Duration(milliseconds: 300));

      // ManageTutorsScreen shows the child's name as a section header.
      h.expectOnScreen('Manage Tutors');
      h.expectOnScreen('ChildForRevoke');

      // The active grant row shows the tutor email.
      h.expectOnScreen(activeGrant.tutorEmail);

      // The "Revoke" button is visible for active grants.
      h.expectOnScreen('Revoke');
      await h.tapText('Revoke');
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation dialog should appear.
      h.expectOnScreen('Revoke tutor access?');

      // Tap the confirm (Revoke) button inside the dialog.
      // There are two "Revoke" texts — dialog label + action button.
      // Tap the last one (action button in dialog actions row).
      await tester.tap(find.text('Revoke').last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));

      // Assert use case was called with the active grant.
      expect(
        fakeRevoke.revokedGrants,
        isNotEmpty,
        reason: 'Expected RevokeTutorGrantUseCase to be called',
      );
      expect(
        fakeRevoke.revokedGrants.first.grantId,
        equals(activeGrant.grantId),
        reason: 'Expected the correct grant to be revoked',
      );
    });
  });

  // ── E2E-1010 ─────────────────────────────────────────────────────────────────

  group(
    'E2E-1010 — Tutor sets up PIN for first time from TutorPinEntryGate',
    () {
      // TutorPinEntryGate is not a routed screen — it is embedded inline
      // (e.g. inside ManageGrantsScreen's talmid entry flow). We mount it
      // directly via pumpWidget wrapping with ProviderScope + MaterialApp so
      // the gate's tutorPinIsSetProvider returns false → TutorPinSetupScreen
      // is shown. We tap the numpad digits to set a PIN and assert the fake
      // TutorPinService.setTutorPin was called.

      testWidgets(
        'tutorPinIsSet=false → TutorPinSetupScreen shown; entering and '
        'confirming PIN calls tutorPinService.setTutorPin',
        (tester) async {
          final fakePinService = _NoPinTutorPinService();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                tutorPinServiceProvider.overrideWithValue(fakePinService),
                tutorPinIsSetProvider.overrideWith(
                  (ref, profileId) => Future.value(false),
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
                home: Scaffold(
                  body: TutorPinEntryGate(
                    profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYD',
                    onPinVerified: () {},
                    onCancel: () {},
                  ),
                ),
              ),
            ),
          );

          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 100));

          // Gate sees tutorPinIsSet=false → shows TutorPinSetupScreen.
          expect(find.text('Set Tutor PIN'), findsWidgets);
          expect(find.text('Create your Tutor PIN'), findsOneWidget);

          // Enter 4 digits for the first PIN via the on-screen numpad.
          await _tapDigit(tester, '1');
          await _tapDigit(tester, '2');
          await _tapDigit(tester, '3');
          await _tapDigit(tester, '4');
          await tester.pump(const Duration(milliseconds: 200));

          // Screen advances to confirm step.
          expect(find.text('Confirm your Tutor PIN'), findsOneWidget);

          // Re-enter the same PIN to confirm.
          await _tapDigit(tester, '1');
          await _tapDigit(tester, '2');
          await _tapDigit(tester, '3');
          await _tapDigit(tester, '4');
          await tester.pump(const Duration(milliseconds: 300));

          // The fake PIN service must have recorded the setTutorPin call.
          expect(
            fakePinService.savedPins,
            isNotEmpty,
            reason: 'Expected tutorPinService.setTutorPin to be called',
          );
          expect(
            fakePinService.savedPins.first,
            equals('1234'),
            reason: 'Expected the entered PIN digits to be saved',
          );
        },
      );
    },
  );

  // ── E2E-1012 ─────────────────────────────────────────────────────────────────

  group('E2E-1012 — Tutor live-mark blocked in talmid session', () {
    // Risk: R-LC2 (contentDatabaseProvider) — mitigated: harness already
    // overrides contentDatabaseProvider with in-memory DB.
    //
    // The UI invariant: when activeTutoredProfileSelectionProvider is non-null
    // (tutor session active), the Mark Complete button:
    //   • label = l10n.markCompleteTutorUnavailable ("Not available (tutor mode)")
    //   • onPressed = null (button disabled)
    //
    // We navigate to /text/<ref> with all text-display providers silenced and
    // an active TutoredProfileSelection override. This is the tutoring-area
    // assertion for the same invariant covered by E2E-303 in learning area.

    testWidgets(
      'Mark Complete button shows tutor-unavailable label and is disabled '
      'when activeTutoredProfileSelectionProvider is non-null',
      (tester) async {
        final identity = E2EIdentity.cloudBorn(
          email: 'tutor1012@example.com',
          displayName: 'Tutor1012',
          profileMode: 'adult',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        const sefariaRef = 'Berakhot.2a';
        const talmidProfileId = 'talmid-remote-profile-1012';

        // Build a minimal DailyTask so the mark-complete section renders.
        const task = DailyTask(
          curriculumId: CurriculumId.mishnayos,
          contentItemSefariaRef: sefariaRef,
          stageOrder: 1,
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
          reason: 'test',
          stageName: 'Learn',
          trackLabel: 'Test Track',
        );

        await h.pumpApp(
          path: '/text/$sefariaRef',
          extraOverrides: [
            // Silence the 15-minute streak rollover timer that leaks across
            // non-dashboard routes (same fix as E2E-1002/E2E-1003).
            ..._nonDashboardStreakSilences(),
            incomingTutorGrantsProvider.overrideWith((ref) => Future.value([])),
            pendingTutorInvitesProvider.overrideWith((ref) => Future.value([])),
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value(true),
            ),
            currentSacredWindowProvider.overrideWithValue(null),
            // Silence daily-task + coarse-paced providers.
            allDailyTasksProvider.overrideWith((ref) => Future.value([task])),
            coarsePacedTrackIdsProvider.overrideWith(
              (ref) => Future.value(<CurriculumId>{}),
            ),
            // The completion footer now reads Firestore-backed completion
            // state. Keep this journey focused on tutor-mode gating rather
            // than waiting on the live completion query.
            trackStorageKeyForTrackIdProvider(
              CurriculumId.mishnayos,
            ).overrideWithValue(const AsyncData<String>('personal')),
            isStageCompletedProvider((
              sefariaRef: sefariaRef,
              stageId: 1,
              trackType: 'personal',
            )).overrideWithValue(const AsyncData<bool>(false)),
            adjacentContentRefsProvider(
              sefariaRef,
            ).overrideWith((ref) => Future.value((prev: null, next: null))),
            // textContentProvider must return non-null so _TextContentView
            // (which contains _CompletionSection) is rendered instead of
            // _OfflineMessage. Without this override the in-memory ContentDB
            // has no rows → provider returns null → button never appears.
            textContentProvider(sefariaRef).overrideWith(
              (ref) => Future.value(
                TextContent.single(
                  sefariaRef: sefariaRef,
                  hebrewText: 'בְּרֵאשִׁית',
                  englishText: 'In the beginning',
                ),
              ),
            ),
            // Enter an active tutored session.
            activeTutoredProfileSelectionProvider.overrideWith(
              () => _FixedTutoredSelection(
                const TutoredProfileSelection(
                  profileId: talmidProfileId,
                  ownerUid: 'owner-uid-1012',
                  grantId: 'grant-1012',
                  permissions: TutorPermissions(),
                  tutorOwnProfileId: '01J6Q2H4A8M7K3P9R5T6V8WXYD',
                ),
              ),
            ),
          ],
        );

        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 200));

        // Key assertion: the button shows the tutor-unavailable label.
        h.expectOnScreen('Not available (tutor mode)');

        // The normal "Mark complete" label must be absent.
        h.expectNotOnScreen('Mark complete');
      },
    );
  });
}
