// AUD-profiles-10 — StateError feedback on the tutored-pull entry path.
//
// TutoredChildrenSection._fireEntryPullAndNavigate wraps the tutored pull in
// a try/on StateError catch. buildTutoredPullServiceFromWidget throws
// StateError when the tutor has no live Firebase session (the documented
// "non-cloud accounts" case). Both sibling branches of the preceding switch
// (permissionDenied, error) show a ScaffoldMessenger snackbar so the user
// learns why entry failed; the StateError catch block must do the same
// instead of silently dismissing the loading spinner.
//
// This test drives the REAL flow end-to-end: tap the tutored-child row,
// pass the Tutor PIN gate, and let onPinVerified fire the real
// _fireEntryPullAndNavigate. The StateError is triggered by overriding
// authRepositoryProvider with a mock whose currentUser is null (no live
// Firebase session) — exactly the condition
// buildTutoredPullServiceFromWidget checks before throwing.

@Tags(['l1', 'profiles', 'tutored_children'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/providers/firestore_instance_provider.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/tutored_children_section.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_app.dart';

// ── Mocks / fakes ────────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Never dereferenced in this test — buildTutoredPullServiceFromWidget's
/// StateError check (no live Firebase session) fires before any Firestore
/// call is made. This only needs to satisfy FirestoreGatewayImpl's
/// constructor so `firebaseFirestoreProvider` doesn't hit the real
/// `FirebaseFirestore.instance` (which throws core/no-app in a widget test
/// with no initialized Firebase app).
class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockAppRouter extends Mock implements AppRouter {
  @override
  final PinGuard pinGuard = _FakePinGuard();
}

/// PinGuard stub — both mark* methods are no-ops (matches
/// pin_flow_and_setup_dialog_l1_test.dart's `_FakePinGuard` shape).
class _FakePinGuard extends Fake implements PinGuard {
  @override
  void markAuthenticated(int profileId) {}

  @override
  void markScopeAuthenticated(PinScope scope) {}
}

/// [TutorPinService] stub: PIN already set, any 4-digit entry verifies.
class _PinAlreadySetService extends Fake implements TutorPinService {
  @override
  Future<bool> hasTutorPin(int profileId) async => true;

  @override
  Future<TutorPinResult> verifyTutorPin({
    required int profileId,
    required String rawPin,
  }) async => const TutorPinSuccess();

  @override
  Future<TutorPinResult> setTutorPin({
    required int profileId,
    required String rawPin,
  }) async => const TutorPinSuccess();

  @override
  Future<void> clearTutorPin(int profileId) async {}
}

// ── Test data ────────────────────────────────────────────────────────────────

final _epoch = DateTime.utc(2026, 1, 1);

TutorGrant _activeGrant({
  String grantId = 'grant-active-aud-profiles-10',
  String childName = 'Yossi Levi',
}) {
  final doc = TutorGrantDoc(
    grantId: grantId,
    parentUid: 'parent-uid-aud-profiles-10',
    childProfileId: 'child-profile-$grantId',
    tutorEmail: 'tutor@example.com',
    state: TutorGrantState.active,
    invitedAt: _epoch,
    updatedAt: _epoch,
    acceptedAt: _epoch,
    childName: childName,
  );
  return TutorGrant.fromDoc(doc, permissions: TutorPermissions.defaults());
}

Future<void> _tapDigit(WidgetTester tester, String digit) async {
  await tester.tap(find.text(digit).last);
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await _tapDigit(tester, d);
  }
}

void main() {
  late UserDatabase db;
  late _MockAuthRepository noSessionAuth;
  late _MockAppRouter appRouter;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    // No live Firebase session — this is exactly the condition
    // buildTutoredPullServiceFromWidget's _build() checks before throwing
    // StateError ("non-cloud accounts" per the source comment).
    noSessionAuth = _MockAuthRepository();
    when(() => noSessionAuth.currentUser).thenReturn(null);
    appRouter = _MockAppRouter();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildHarness() {
    return pumpApp(
      retry: (_, __) => null,
      overrides: [
        incomingTutorGrantsProvider.overrideWith(
          (ref) async => [_activeGrant()],
        ),
        pendingTutorInvitesProvider.overrideWith((ref) async => []),
        userDatabaseProvider.overrideWithValue(db),
        authStateProvider.overrideWithValue(
          const AuthState.signedIn(
            user: AuthUser(
              profileId: 1,
              email: 'tutor@example.com',
              displayName: 'Tutor',
            ),
            tier: Tier.localBorn,
          ),
        ),
        authRepositoryProvider.overrideWithValue(noSessionAuth),
        firebaseFirestoreProvider.overrideWithValue(_MockFirestore()),
        routerProvider.overrideWithValue(appRouter),
        selectedProfileIdProvider.overrideWith(
          () => _FixedSelectedProfileId(1),
        ),
        tutorPinIsSetProvider.overrideWith((ref, profileId) async => true),
        tutorPinServiceProvider.overrideWithValue(_PinAlreadySetService()),
      ],
      child: const Scaffold(
        body: SingleChildScrollView(child: TutoredChildrenSection()),
      ),
    );
  }

  testWidgets(
    'AUD-profiles-10: StateError from buildTutoredPullServiceFromWidget '
    '(no live Firebase session) shows an error SnackBar to the user',
    (tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the tutored-child row to open the Tutor PIN gate.
      expect(find.text('Yossi Levi'), findsOneWidget);
      await tester.tap(find.text('Yossi Levi'));
      await tester.pumpAndSettle();

      // PIN already set → entry pad shown directly (no setup screen).
      expect(find.text('Enter your Tutor PIN'), findsOneWidget);

      // Enter a 4-digit PIN via the numpad — verifyTutorPin is stubbed to
      // always succeed, so onPinVerified fires the real
      // _fireEntryPullAndNavigate.
      await _enterPin(tester, '1234');
      await tester.pump(const Duration(milliseconds: 200));

      // _fireEntryPullAndNavigate: no cached mirror in the empty DB → the
      // network path runs buildTutoredPullServiceFromWidget, which throws
      // StateError because authRepositoryProvider.currentUser is null.
      // Give the async catch block time to run and the loading dialog to
      // dismiss.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // AC: the StateError catch block must give feedback consistent with
      // the permissionDenied/error branches — a SnackBar with a localized
      // message, not a silent dismiss.
      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason:
            'StateError from buildTutoredPullServiceFromWidget must surface '
            'a SnackBar — matching the permissionDenied/error branches — '
            'instead of silently dismissing the loading spinner.',
      );

      final context = tester.element(find.byType(TutoredChildrenSection));
      final l10n = AppLocalizations.of(context)!;
      expect(find.text(l10n.tutoredEntryAborted), findsOneWidget);
    },
  );
}

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}
