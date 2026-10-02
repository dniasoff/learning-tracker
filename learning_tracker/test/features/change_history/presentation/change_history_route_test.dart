/// DNI-513 AC-1: the parent Change history is a NEW parent-scoped route
/// (not `/tutor/audit-log`) behind the parent-mode gates plus a guard that
/// refuses tutored sessions; Settings shows its entry only in parent mode;
/// and the screen's own access check admits only an own session whose
/// parent PIN is unlocked for the active profile.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/own_session_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/change_history/presentation/providers/change_history_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show incomingTutorGrantsProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../helpers/pump_app.dart';

class _MockAuthGuard extends Mock implements AutoRouteGuard {}

class _MockProfileGuard extends Mock implements ProfileGuard {}

class _MockChildModeGuard extends Mock implements ChildModeGuard {}

class _MockPinGuard extends Mock implements PinGuard {}

class _MockResolver extends Mock implements NavigationResolver {}

class _MockStackRouter extends Mock implements StackRouter {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockPinService extends Mock implements PinService {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo<Object?> {}

const _childId = '01J6Q2H4A8M7K3P9R5T6V8WXY8';
const _otherId = '01J6Q2H4A8M7K3P9R5T6V8WXY9';

const _tutored = TutoredProfileSelection(
  profileId: _childId,
  ownerUid: 'parent-uid',
  grantId: 'grant-1',
  permissions: TutorPermissions(),
);

class _Tutored extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => _tutored;
}

class _Own extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

class _PinFor extends ParentPinAuthenticatedProfileId {
  _PinFor(this._id);
  final String? _id;

  @override
  String? build() => _id;
}

LearnerProfileEntity _child() {
  final now = DateTime.utc(2026, 1, 1);
  return LearnerProfileEntity(
    profileId: _childId,
    displayName: 'Yehuda',
    mode: ProfileMode.child,
    avatar: '',
    createdAt: now,
    updatedAt: now,
  );
}

Future<bool> _resolve(OwnSessionGuard guard) async {
  final resolver = _MockResolver();
  bool? result;
  when(() => resolver.isResolved).thenReturn(false);
  when(() => resolver.next(any())).thenAnswer((i) {
    result = i.positionalArguments.first as bool;
  });
  await guard.onNavigation(resolver, _MockStackRouter());
  return result!;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
    PackageInfo.setMockInitialValues(
      appName: 'Learning Tracker',
      packageName: 'learning_tracker',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  group('route', () {
    test('a new parent-mode route, gated by own session, child mode and '
        'the parent PIN — not the per-grant audit log', () {
      final own = OwnSessionGuard(isTutoredSession: () => false);
      final childMode = _MockChildModeGuard();
      final pin = _MockPinGuard();
      final router = AppRouter(
        authGuard: _MockAuthGuard(),
        profileGuard: _MockProfileGuard(),
        childModeGuard: childMode,
        pinGuard: pin,
        ownSessionGuard: own,
      );
      final route = router.routes.firstWhere(
        (r) => r.path == '/parent-mode/change-history',
      );
      expect(route.name, ChangeHistoryRoute.name);
      expect(route.name, isNot(TutorAuditLogRoute.name));
      expect(route.guards, containsAll(<Object>[own, childMode, pin]));
      expect(
        route.guards.indexOf(own),
        lessThan(route.guards.indexOf(pin)),
        reason: 'a tutor is refused before any PIN prompt',
      );
      final audit = router.routes.firstWhere(
        (r) => r.path == '/tutor/audit-log',
      );
      expect(audit.name, TutorAuditLogRoute.name);
    });

    test('a router built without session wiring refuses the route', () async {
      final router = AppRouter(
        authGuard: _MockAuthGuard(),
        profileGuard: _MockProfileGuard(),
        childModeGuard: _MockChildModeGuard(),
        pinGuard: _MockPinGuard(),
      );
      expect(await _resolve(router.ownSessionGuard), isFalse);
    });

    test(
      'OwnSessionGuard refuses a tutored session and fails closed',
      () async {
        expect(
          await _resolve(OwnSessionGuard(isTutoredSession: () => true)),
          isFalse,
        );
        expect(
          await _resolve(OwnSessionGuard(isTutoredSession: () => false)),
          isTrue,
        );
        expect(
          await _resolve(
            OwnSessionGuard(isTutoredSession: () => throw StateError('x')),
          ),
          isFalse,
        );
      },
    );
  });

  group('screen access', () {
    bool access({
      required bool tutored,
      required String? pinFor,
      String? active = _childId,
    }) {
      final container = ProviderContainer(
        overrides: [
          activeTutoredProfileSelectionProvider.overrideWith(
            tutored ? _Tutored.new : _Own.new,
          ),
          activeProfileIdProvider.overrideWithValue(active),
          parentPinAuthenticatedProfileIdProvider.overrideWith(
            () => _PinFor(pinFor),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(changeHistoryAccessProvider);
    }

    test('parent PIN unlocked for the active learner: open', () {
      expect(access(tutored: false, pinFor: _childId), isTrue);
    });

    test('child role (no parent PIN session): closed', () {
      expect(access(tutored: false, pinFor: null), isFalse);
    });

    test('parent PIN unlocked for another learner: closed', () {
      expect(access(tutored: false, pinFor: _otherId), isFalse);
    });

    test('tutor device (tutored session): closed', () {
      expect(access(tutored: true, pinFor: _childId), isFalse);
    });
  });

  group('Settings entry', () {
    late _MockStackRouter router;
    late _MockAuthRepository auth;
    late _MockPinService pins;

    setUp(() {
      router = _MockStackRouter();
      auth = _MockAuthRepository();
      pins = _MockPinService();
      when(() => auth.currentUser).thenReturn(null);
      when(
        () => router.push<Object?>(
          any<PageRouteInfo>(),
          onFailure: any(named: 'onFailure'),
        ),
      ).thenAnswer((_) async => null);
      when(() => router.canPop()).thenReturn(false);
      when(() => router.currentPath).thenReturn('/settings');
      when(() => pins.hasProfilePin(any())).thenAnswer((_) async => true);
    });

    Future<void> pumpSettings(
      WidgetTester tester, {
      required bool parent,
    }) async {
      await tester.pumpWidget(
        pumpApp(
          retry: (_, _) => null,
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            authStateProvider.overrideWithValue(
              const AuthState.signedIn(
                user: AuthUser(
                  uid: 'uid',
                  email: 'parent@test.com',
                  displayName: 'Abba',
                ),
                tier: Tier.cloud,
              ),
            ),
            activeProfileIdProvider.overrideWithValue(_childId),
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value([_child()]),
            ),
            selectedProfileIdProvider.overrideWithValue(_childId),
            activeTutoredProfileSelectionProvider.overrideWith(_Own.new),
            activeTutorPermissionsProvider.overrideWithValue(null),
            incomingTutorGrantsProvider.overrideWith(
              (ref) => Future.value(const []),
            ),
            pendingTutorInvitesProvider.overrideWith(
              (ref) => Future.value(const []),
            ),
            parentPinAuthenticatedProfileIdProvider.overrideWith(
              () => _PinFor(parent ? _childId : null),
            ),
            pinServiceProvider.overrideWithValue(pins),
          ],
          child: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    final tile = find.byKey(const ValueKey('settingsChangeHistoryTile'));

    testWidgets('in parent mode Settings → Change history opens the route', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpSettings(tester, parent: true);
      expect(
        find.descendant(of: tile, matching: find.text('Change history')),
        findsOneWidget,
      );
      await tester.tap(tile);
      await tester.pump();
      final pushed = verify(
        () => router.push<Object?>(
          captureAny<PageRouteInfo>(),
          onFailure: any(named: 'onFailure'),
        ),
      ).captured;
      expect(pushed.single, isA<ChangeHistoryRoute>());
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('in the child role there is no link', (tester) async {
      await pumpSettings(tester, parent: false);
      expect(tile, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
