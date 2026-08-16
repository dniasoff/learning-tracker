// iter10_outgoing_grants_stale_cache_test.dart
//
// Regression test for DG-TUT-STALE-01: outgoingTutorGrantsProvider served
// stale data (pending) to the parent even after the tutor had accepted
// (grant became active server-side).
//
// Root cause: outgoingTutorGrantsProvider was declared without .autoDispose.
// In Riverpod 2.x a non-autoDispose FutureProvider.family keeps its cached
// result in memory even when no widget is watching it. When the parent
// navigated away and back to ManageTutors, the _ChildGrantsSection widget
// re-subscribed to the still-alive provider, which returned the stale
// "pending" result from the earlier fetch — even though the grant had been
// accepted in the meantime.
//
// Fix: declare with FutureProvider.autoDispose.family so the provider is
// evicted from cache when the ManageTutors screen is unmounted. On re-entry
// the provider re-runs its future, querying the listTutorGrants CF again and
// returning the authoritative "active" state.
//
// Test strategy:
//   We use a single ProviderScope (matching production: the scope lives at
//   app root, persisting across navigation). The outgoingTutorGrantsProvider
//   is NOT overridden — it runs its real logic backed by a mock repository.
//   We swap the repository's return value between the two mounts to simulate
//   the tutor accepting while the parent is on a different screen.
//
//   Under the old (non-autoDispose) declaration, the provider keeps serving
//   its cached "pending" response on the second subscribe → test shows RED.
//   Under the fix (.autoDispose), the provider is evicted from cache while
//   no widget watches it, so the second subscribe re-runs the future against
//   the updated repository → test shows GREEN.
//
//   The mock repository approach is non-tautological because the test never
//   overrides the provider itself — it only controls the repository layer.

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_notification_service.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    hide incomingTutorGrantsProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    hide resignTutorGrantUseCaseProvider, revokeTutorGrantUseCaseProvider;
import 'package:learning_tracker/features/tutoring/presentation/screens/manage_tutors_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockRouter extends Mock implements StackRouter {}

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockRevoke extends Mock implements RevokeTutorGrantUseCase {}

class _MockRescind extends Mock implements RescindTutorInviteUseCase {}

class _MockNotifGw extends Mock implements TutorNotificationGateway {}

class _MockGrantRepo extends Mock implements TutorGrantRepository {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _FakeTutorGrant extends Fake implements TutorGrant {}

// ── Helpers ───────────────────────────────────────────────────────────────────

LearnerProfileEntity _child() {
  final now = DateTime.utc(2026, 1, 1);
  return LearnerProfileEntity(
    profileId: 'ulid-1',
    displayName: 'LoopChild',
    mode: ProfileMode.child,
    createdAt: now,
    updatedAt: now,
  );
}

TutorGrant _pendingGrant() {
  final now = DateTime.utc(2026, 1, 1);
  final doc = TutorGrantDoc(
    grantId: 'grant_1',
    parentUid: 'parent_uid',
    childProfileId: 'ulid-1',
    tutorEmail: 'tutor@loop.test',
    state: TutorGrantState.pending,
    invitedAt: now,
    updatedAt: now,
    expiresAt: now.add(const Duration(days: 7)),
  );
  return TutorGrant.fromDoc(doc);
}

TutorGrant _activeGrant() {
  final now = DateTime.utc(2026, 1, 1);
  final doc = TutorGrantDoc(
    grantId: 'grant_1',
    parentUid: 'parent_uid',
    childProfileId: 'ulid-1',
    tutorEmail: 'tutor@loop.test',
    state: TutorGrantState.active,
    invitedAt: now,
    updatedAt: now,
    acceptedAt: now,
  );
  return TutorGrant.fromDoc(doc, permissions: TutorPermissions.defaults());
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late _MockRouter router;
  late _MockGrantRepo grantRepo;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
    registerFallbackValue(_FakeTutorGrant());
  });

  setUp(() {
    router = _MockRouter();
    grantRepo = _MockGrantRepo();
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) => Future<Object?>.value(null));
    when(() => router.canPop()).thenReturn(false);
    when(() => router.currentPath).thenReturn('/manage-tutors');
  });

  // ── DG-TUT-STALE-01 ──────────────────────────────────────────────────────────

  testWidgets('DG-TUT-STALE-01: re-entering screen re-fetches grants; '
      'Active state visible after tutor accepts while parent is away', (
    tester,
  ) async {
    final auth = _MockAuthRepo();
    when(() => auth.currentUser).thenReturn(null);

    // Phase 1: repository returns a pending grant (before acceptance).
    when(
      () => grantRepo.listOutgoingGrants(childProfileId: 'ulid-1'),
    ).thenAnswer((_) async => [_pendingGrant()]);

    // Build a persistent ProviderScope (matches app root scope in production).
    // outgoingTutorGrantsProvider is NOT overridden — it runs the real provider
    // backed by the mock repository. This is the non-tautological coupling.
    final app = ProviderScope(
      overrides: [
        profileListProvider.overrideWith((_) => Future.value([_child()])),
        tutorGrantRepositoryProvider.overrideWithValue(grantRepo),
        authRepositoryProvider.overrideWithValue(auth),
        revokeTutorGrantUseCaseProvider.overrideWithValue(_MockRevoke()),
        rescindTutorInviteUseCaseProvider.overrideWithValue(_MockRescind()),
        tutorNotificationGatewayProvider.overrideWithValue(_MockNotifGw()),
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
    );

    await tester.pumpWidget(app);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Sanity: first mount shows the pending grant.
    expect(
      find.text('Pending'),
      findsOneWidget,
      reason: 'first mount: pending grant displayed',
    );
    expect(
      find.text('Rescind'),
      findsOneWidget,
      reason: 'first mount: Rescind button shown for pending grant',
    );

    // Phase 2: parent navigates AWAY (simulated by swapping to a blank screen
    // within the SAME ProviderScope). The outgoingTutorGrantsProvider should
    // be evicted from cache when the widget stops watching it.
    await tester.pumpWidget(
      ProviderScope(
        // SAME scope re-used by pumpWidget when the root widget changes, but
        // here we replace the entire tree to force widget disposal.
        overrides: [
          profileListProvider.overrideWith((_) => Future.value([_child()])),
          tutorGrantRepositoryProvider.overrideWithValue(grantRepo),
          authRepositoryProvider.overrideWithValue(auth),
          revokeTutorGrantUseCaseProvider.overrideWithValue(_MockRevoke()),
          rescindTutorInviteUseCaseProvider.overrideWithValue(_MockRescind()),
          tutorNotificationGatewayProvider.overrideWithValue(_MockNotifGw()),
        ],
        child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      ),
    );
    await tester.pump(Duration.zero);

    // Phase 3: tutor accepts server-side — update the repository stub.
    when(
      () => grantRepo.listOutgoingGrants(childProfileId: 'ulid-1'),
    ).thenAnswer((_) async => [_activeGrant()]);

    // Phase 4: parent navigates BACK to Manage Tutors.
    // If the provider auto-disposed (fix applied), it re-fetches and returns
    // the active grant from the updated repository.
    // If not auto-disposed (bug), it serves the cached pending grant.
    await tester.pumpWidget(app);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // MUST show active after re-entry when the repository now returns active.
    expect(
      find.text('Active'),
      findsOneWidget,
      reason: 'DG-TUT-STALE-01: after re-entry, Active status must be shown',
    );
    expect(
      find.text('Revoke'),
      findsOneWidget,
      reason: 'DG-TUT-STALE-01: after re-entry, Revoke button must be shown',
    );

    // These stale values must NOT appear.
    expect(
      find.text('Pending'),
      findsNothing,
      reason: 'DG-TUT-STALE-01: stale Pending status must not survive re-entry',
    );
    expect(
      find.text('Rescind'),
      findsNothing,
      reason: 'DG-TUT-STALE-01: stale Rescind button must not survive re-entry',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
