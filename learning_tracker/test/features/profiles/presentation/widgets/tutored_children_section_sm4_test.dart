// AUD-profiles-14 (SM-4) — TutoredChildrenSection._fireEntryPullAndNavigate
//
// Regression: the offline-first cached-mirror check
// (`await ref.read(userDatabaseProvider).profileDao.getTutoredProfile(...)`)
// runs BEFORE any dismiss barrier goes up. The profile-switcher sheet that
// hosts the talmid row is swipe/backdrop-dismissible for that entire window
// (see profile_switcher_sheet.dart's `showModalBottomSheet` — neither
// `isDismissible` nor `enableDrag` is overridden). If the user dismisses the
// sheet while that read is in flight, `_TutoredChildRow` (a `ConsumerWidget`)
// unmounts, and the very next lines touched `ref` on a disposed `WidgetRef`
// with no liveness guard — `WidgetRef.read` throws a `StateError` ("Using
// "ref" when a widget is about to or has been unmounted is unsafe") the
// instant that happens (flutter_riverpod's `_assertNotDisposed`), and since
// the whole call runs via `unawaited(...)`, that exception is uncaught.
//
// This test drives the real tap → PIN-gate → verify → entry-pull flow,
// dismisses the row mid-await, completes the pending read, and asserts no
// uncaught exception surfaces.

@Tags(['l1', 'tutoring', 'profiles', 'sm4'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/tutored_children_section.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show incomingTutorGrantsProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

// ── Mocks / fakes ────────────────────────────────────────────────────────────

class _FakeUserDatabase extends Mock implements UserDatabase {}

class _FakeProfileDao extends Mock implements ProfileDao {}

class _MockTutorPinService extends Mock implements TutorPinService {}

/// Records `markScopeAuthenticated` calls; every other member is a no-op via
/// [Fake]'s default `noSuchMethod` throw (never exercised by this flow).
class _FakePinGuard extends Fake implements PinGuard {
  final List<PinScope> markScopeAuthenticatedCalls = [];

  @override
  void markScopeAuthenticated(PinScope scope) {
    markScopeAuthenticatedCalls.add(scope);
  }
}

/// [AppRouter] fake — the row captures this via `ref.read(routerProvider)`
/// and (in the code path under test) never gets far enough to call
/// `replaceAll` (the unmount guard returns first), so only `pinGuard` needs a
/// working implementation.
class _FakeAppRouter extends Mock implements AppRouter {
  _FakeAppRouter() : pinGuard = _FakePinGuard();

  @override
  final _FakePinGuard pinGuard;
}

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._id);
  final int? _id;
  @override
  int? build() => _id;
}

// ── Fixtures ─────────────────────────────────────────────────────────────────

const int _kTutorProfileId = 7;

TutorGrant _activeGrant() {
  final now = DateTimeFactory.nowUtc();
  return TutorGrant.fromDoc(
    TutorGrantDoc(
      grantId: 'grant-sm4-001',
      parentUid: 'parent-uid-sm4',
      childProfileId: 'child-profile-sm4',
      tutorEmail: 'tutor-sm4@example.com',
      state: TutorGrantState.active,
      invitedAt: now.subtract(const Duration(days: 1)),
      updatedAt: now,
      acceptedAt: now.subtract(const Duration(hours: 12)),
      childName: 'Sm4Child',
    ),
    permissions: TutorPermissions.defaults(),
  );
}

LearnerProfile _cachedMirrorProfile() {
  final now = DateTimeFactory.nowUtc();
  return LearnerProfile(
    id: 99,
    accountId: 1,
    displayName: 'Sm4Child',
    mode: 'child',
    avatarIndex: 0,
    createdAt: now,
    updatedAt: now,
    isTutored: true,
    tutorParentUid: 'parent-uid-sm4',
    tutorRemoteProfileId: 'child-profile-sm4',
    tutorGrantId: 'grant-sm4-001',
  );
}

// ── Harness ──────────────────────────────────────────────────────────────────

/// Wraps [TutoredChildrenSection] with a toggle that removes it from the tree
/// — simulating the profile-switcher sheet being swiped/backdrop-dismissed,
/// which unmounts the still-live `_TutoredChildRow` underneath it (the row is
/// intentionally left mounted through the PIN gate + entry-pull per
/// tutored_children_section.dart's `dismissSwitcherSheet` doc comment).
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _sheetMounted = true;

  void dismissSheet() => setState(() => _sheetMounted = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _sheetMounted
          ? const TutoredChildrenSection()
          : const SizedBox.shrink(),
    );
  }
}

Future<void> _tapDigit(WidgetTester tester, String digit) async {
  await tester.tap(find.widgetWithText(InkWell, digit));
  await tester.pump();
}

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (var i = 0; i < pin.length; i++) {
    await _tapDigit(tester, pin[i]);
  }
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'AUD-profiles-14: dismissing the switcher sheet while getTutoredProfile '
    'is pending does not throw an uncaught exception',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final grant = _activeGrant();

      // Controls exactly when the cached-mirror DB read resolves, so the test
      // can dismiss the row while that await is still in flight.
      final getTutoredProfileCompleter = Completer<LearnerProfile?>();
      final fakeDb = _FakeUserDatabase();
      final fakeDao = _FakeProfileDao();
      when(() => fakeDb.profileDao).thenReturn(fakeDao);
      when(
        () => fakeDao.getTutoredProfile(
          parentUid: any(named: 'parentUid'),
          remoteChildProfileId: any(named: 'remoteChildProfileId'),
          grantId: any(named: 'grantId'),
        ),
      ).thenAnswer((_) => getTutoredProfileCompleter.future);

      final mockPinService = _MockTutorPinService();
      when(
        () => mockPinService.verifyTutorPin(
          profileId: any(named: 'profileId'),
          rawPin: any(named: 'rawPin'),
        ),
      ).thenAnswer((_) async => const TutorPinSuccess());

      await tester.pumpWidget(
        pumpApp(
          child: const _Harness(),
          overrides: [
            incomingTutorGrantsProvider.overrideWith((ref) async => [grant]),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(_kTutorProfileId),
            ),
            userDatabaseProvider.overrideWithValue(fakeDb),
            routerProvider.overrideWithValue(_FakeAppRouter()),
            tutorPinServiceProvider.overrideWithValue(mockPinService),
            tutorPinIsSetProvider(
              _kTutorProfileId,
            ).overrideWith((_) async => true),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap the talmid row -> pushes TutorPinEntryGate.
      expect(find.text('Sm4Child'), findsOneWidget);
      await tester.tap(find.text('Sm4Child'));
      await tester.pumpAndSettle();

      // Enter the PIN -> onPinVerified -> pops the gate -> unawaited
      // _fireEntryPullAndNavigate starts and awaits getTutoredProfile, which
      // is still pending on our completer.
      await _enterPin(tester, '1234');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Back to the (still-mounted) row underneath — matches production:
      // the sheet/row survives the PIN gate popping.
      expect(
        find.text('Sm4Child'),
        findsOneWidget,
        reason:
            'The row must still be present after the PIN gate pops — only '
            'an explicit user dismiss (simulated below) should unmount it',
      );

      // Simulate the switcher sheet being swiped/backdrop-dismissed WHILE the
      // getTutoredProfile future is still pending — unmounts _TutoredChildRow.
      tester.state<_HarnessState>(find.byType(_Harness)).dismissSheet();
      await tester.pump();

      expect(find.text('Sm4Child'), findsNothing);

      // Now let getTutoredProfile resolve — this resumes
      // _fireEntryPullAndNavigate past the await, where (pre-fix) it touched
      // `ref` unconditionally on the now-disposed WidgetRef.
      getTutoredProfileCompleter.complete(_cachedMirrorProfile());
      await tester.pump(const Duration(seconds: 1));

      expect(
        tester.takeException(),
        isNull,
        reason:
            'AUD-profiles-14 (SM-4): ref must not be touched after the '
            'getTutoredProfile await once the row has unmounted (switcher '
            'sheet dismissed mid-flight) — this must not throw',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
