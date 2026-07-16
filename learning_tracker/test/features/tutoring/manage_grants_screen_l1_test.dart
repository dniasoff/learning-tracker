// L1 widget test for ManageGrantsScreen (W6.12)
//
// Verifies:
//   1. Loading state shows CircularProgressIndicator.
//   2. Empty state shows correct l10n heading and body.
//   3. Active grants: section header rendered, child/parent labels shown,
//      "Resign" button rendered per active row.
//   4. Pending grants: section header rendered, no Resign button shown.
//   5. Mixed (active + pending): both sections render correctly.
//   6. Error state shows AppErrorView (error widget present).
//   7. Resign button tapped → confirmation dialog appears with correct l10n strings.
//   8. Confirm resign → calls ResignTutorGrantUseCase.
//   9. Cancel resign dialog → use-case NOT called.
//  10. childDisplayLabel falls back to "Talmid" when childName is null.
//  11. parentDisplayLabel falls back to "Parent account" when parentName is null.
//  12. Failed resignation shows error snackbar.
//
// BUG LOG:
//   "Talmid" (test 10) and "Parent account" (test 11) are hardcoded English
//   strings inside TutorGrant.childDisplayLabel / parentDisplayLabel
//   (tutor_grant_aggregate.dart:144/150) — not surfaced via l10n.

@Tags(['needs_flutter', 'tutor_mode', 'manage_grants'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_notification_service.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/manage_grants_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/drift_memory.dart';
import '../../helpers/pump_app.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockResignUseCase extends Mock implements ResignTutorGrantUseCase {}

class _MockNotificationGateway extends Mock
    implements TutorNotificationGateway {}

// Fake for registerFallbackValue so `any(named: 'grant')` works with mocktail.
class _FakeTutorGrant extends Fake implements TutorGrant {}

// ── Helpers ──────────────────────────────────────────────────────────────────

final _kNow = DateTime.utc(2026, 1, 1);

TutorGrantDoc _buildDoc({
  required String grantId,
  required TutorGrantState state,
  String? childName,
  String? parentName,
}) {
  return TutorGrantDoc(
    grantId: grantId,
    parentUid: 'parent-uid-1',
    childProfileId: 'child-profile-1',
    tutorEmail: 'tutor@example.com',
    state: state,
    invitedAt: _kNow,
    updatedAt: _kNow,
    acceptedAt: state == TutorGrantState.active ? _kNow : null,
    expiresAt: state == TutorGrantState.pending
        ? _kNow.add(const Duration(days: 7))
        : null,
    childName: childName,
    parentName: parentName,
  );
}

TutorGrant _activeGrant({
  String grantId = 'grant-active-1',
  String? childName = 'Yossi Levi',
  String? parentName = 'Reuven Levi',
}) {
  final doc = _buildDoc(
    grantId: grantId,
    state: TutorGrantState.active,
    childName: childName,
    parentName: parentName,
  );
  return TutorGrant.fromDoc(doc, permissions: TutorPermissions.defaults());
}

TutorGrant _pendingGrant({
  String grantId = 'grant-pending-1',
  String? childName = 'Moshe Cohen',
  String? parentName = 'Avraham Cohen',
}) {
  final doc = _buildDoc(
    grantId: grantId,
    state: TutorGrantState.pending,
    childName: childName,
    parentName: parentName,
  );
  return TutorGrant.fromDoc(doc);
}

AppUser _fakeUser() => const AppUser(
  uid: 'tutor-uid-1',
  email: 'tutor@example.com',
  displayName: 'Test Tutor',
  emailVerified: true,
  providers: ['password'],
);

void main() {
  setUpAll(() {
    // mocktail requires a registered fallback value for any type used with
    // `any(named: 'grant')` in verify/when calls.
    registerFallbackValue(_FakeTutorGrant());
  });

  late _MockAuthRepository mockAuthRepo;
  late _MockResignUseCase mockResignUseCase;
  late _MockNotificationGateway mockNotificationGateway;

  setUp(() {
    mockAuthRepo = _MockAuthRepository();
    mockResignUseCase = _MockResignUseCase();
    mockNotificationGateway = _MockNotificationGateway();

    when(() => mockAuthRepo.currentUser).thenReturn(_fakeUser());
    when(
      () => mockNotificationGateway.notifyParentOfResignation(
        parentEmail: any(named: 'parentEmail'),
        parentUid: any(named: 'parentUid'),
        tutorName: any(named: 'tutorName'),
        childName: any(named: 'childName'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget buildSubject(
    Future<List<TutorGrant>> Function() grantsFactory, {
    ResignTutorGrantUseCase? resignUseCase,
    // AUD-t-tutoring-07: parameterized so RTL (Hebrew) coverage can reuse
    // the exact same harness instead of hardcoding Locale('en') with no way
    // to exercise a directional-layout regression.
    Locale locale = const Locale('en'),
  }) {
    final db = inMemoryDb();
    return ProviderScope(
      // RP3: match production (provider retry disabled) so a first-load error
      // surfaces AsyncError immediately and .when(error:) renders the error view.
      retry: (_, __) => null,
      overrides: [
        incomingTutorGrantsProvider.overrideWith((ref) => grantsFactory()),
        resignTutorGrantUseCaseProvider.overrideWithValue(
          resignUseCase ?? mockResignUseCase,
        ),
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        tutorNotificationGatewayProvider.overrideWithValue(
          mockNotificationGateway,
        ),
        userDatabaseProvider.overrideWithValue(db),
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
        home: const ManageGrantsScreen(),
      ),
    );
  }

  Future<void> tearDownWidget(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  // ── 1. Loading state ─────────────────────────────────────────────────────────

  testWidgets('shows CircularProgressIndicator while loading', (tester) async {
    final completer = Completer<List<TutorGrant>>();
    await tester.pumpWidget(buildSubject(() => completer.future));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete([]);
    await tester.pump(const Duration(seconds: 1));
    await tearDownWidget(tester);
  });

  // ── 2. Empty state ───────────────────────────────────────────────────────────

  testWidgets('empty state shows heading and body', (tester) async {
    await tester.pumpWidget(buildSubject(() => Future.value([])));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // AppBar title (l10n key: manageGrantsAppBarTitle)
    expect(find.text('My Tutoring Grants'), findsOneWidget);

    // Empty heading (l10n key: manageGrantsEmptyHeading)
    expect(find.text('No tutoring relationships'), findsOneWidget);

    // Empty body (l10n key: manageGrantsEmptyBody)
    expect(
      find.text(
        'When a parent invites you to tutor their child, '
        'the grant will appear here.',
      ),
      findsOneWidget,
    );

    // Empty state icon
    expect(find.byIcon(Icons.school_outlined), findsOneWidget);

    await tearDownWidget(tester);
  });

  // ── 3. Active grants ─────────────────────────────────────────────────────────

  testWidgets(
    'active grants: section header, child/parent label, and Resign button',
    (tester) async {
      final grant = _activeGrant();
      await tester.pumpWidget(buildSubject(() => Future.value([grant])));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Section header (l10n key: manageGrantsActiveSection(1) → "Active (1)")
      expect(find.text('Active (1)'), findsOneWidget);

      // Child display name
      expect(find.text('Yossi Levi'), findsOneWidget);

      // Parent display name
      expect(find.text('Reuven Levi'), findsOneWidget);

      // "Active" status badge (l10n key: statusActive)
      expect(find.text('Active'), findsOneWidget);

      // Resign button (l10n key: manageGrantsResign)
      expect(find.text('Resign'), findsOneWidget);

      await tearDownWidget(tester);
    },
  );

  // ── 4. Pending grants ────────────────────────────────────────────────────────

  testWidgets('pending grants: section header shown, Resign button NOT shown', (
    tester,
  ) async {
    final grant = _pendingGrant();
    await tester.pumpWidget(buildSubject(() => Future.value([grant])));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Section header (l10n key: manageGrantsPendingSection(1))
    expect(find.text('Pending invites (1)'), findsOneWidget);

    // Child and parent labels
    expect(find.text('Moshe Cohen'), findsOneWidget);
    expect(find.text('Avraham Cohen'), findsOneWidget);

    // "Pending" status badge (l10n key: statusPending)
    expect(find.text('Pending'), findsOneWidget);

    // No Resign button for pending grants (canResign=false)
    expect(find.text('Resign'), findsNothing);

    await tearDownWidget(tester);
  });

  // ── 5. Mixed active + pending ────────────────────────────────────────────────

  testWidgets('mixed: both section headers rendered, Resign only for active', (
    tester,
  ) async {
    final active = _activeGrant(grantId: 'grant-a1');
    final pending = _pendingGrant(grantId: 'grant-p1');
    await tester.pumpWidget(
      buildSubject(() => Future.value([active, pending])),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Active (1)'), findsOneWidget);
    expect(find.text('Pending invites (1)'), findsOneWidget);

    // Resign button appears exactly once (only for active grant)
    expect(find.text('Resign'), findsOneWidget);

    // Both child names visible
    expect(find.text('Yossi Levi'), findsOneWidget);
    expect(find.text('Moshe Cohen'), findsOneWidget);

    await tearDownWidget(tester);
  });

  // ── 6. Error state ───────────────────────────────────────────────────────────

  // RP3-RETRY (fixed): with provider retry disabled (production via bootstrap +
  // buildSubject here), a first-load error surfaces AsyncError, so
  // grantsAsync.when(error:) renders AppErrorView instead of a stuck spinner.
  testWidgets('error state shows AppErrorView instead of spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        () => Future<List<TutorGrant>>.error(Exception('network failure')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // No stuck spinner — the generic error view + Retry button render.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tearDownWidget(tester);
  });

  // ── 7. Resign button shows confirmation dialog ───────────────────────────────

  testWidgets(
    'tapping Resign button shows confirmation dialog with l10n strings',
    (tester) async {
      final grant = _activeGrant();
      await tester.pumpWidget(buildSubject(() => Future.value([grant])));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Resign'));
      await tester.pump();

      // Dialog title (l10n key: manageGrantsResignTitle)
      expect(find.text('Resign from tutoring?'), findsOneWidget);

      // Dialog body includes child and parent names
      expect(find.textContaining('Yossi Levi'), findsWidgets);
      expect(find.textContaining('Reuven Levi'), findsWidgets);

      // Cancel action (l10n key: actionCancel)
      expect(find.text('Cancel'), findsOneWidget);

      // Resign action in dialog (in addition to the row button)
      expect(find.text('Resign'), findsAtLeastNWidgets(2));

      await tearDownWidget(tester);
    },
  );

  // ── 8. Confirm resign → use case called ─────────────────────────────────────

  testWidgets('confirming resignation calls ResignTutorGrantUseCase', (
    tester,
  ) async {
    final grant = _activeGrant();
    when(
      () => mockResignUseCase.call(grant: any(named: 'grant')),
    ).thenAnswer((_) async => const TutorGrantSuccess());

    await tester.pumpWidget(buildSubject(() => Future.value([grant])));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Open dialog
    await tester.tap(find.text('Resign'));
    await tester.pump();

    // Tap the Resign button inside the dialog (last found widget with text Resign)
    await tester.tap(find.text('Resign').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => mockResignUseCase.call(grant: any(named: 'grant'))).called(1);

    await tearDownWidget(tester);
  });

  // ── 9. Cancel resign → use case NOT called ───────────────────────────────────

  testWidgets(
    'cancelling the resign dialog does NOT call ResignTutorGrantUseCase',
    (tester) async {
      final grant = _activeGrant();

      await tester.pumpWidget(buildSubject(() => Future.value([grant])));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Open dialog
      await tester.tap(find.text('Resign'));
      await tester.pump();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      verifyNever(() => mockResignUseCase.call(grant: any(named: 'grant')));

      await tearDownWidget(tester);
    },
  );

  // ── 10. childDisplayLabel fallback ──────────────────────────────────────────
  // "Talmid" is a hardcoded English string in TutorGrant.childDisplayLabel
  // (tutor_grant_aggregate.dart line ~144) — not in l10n.

  testWidgets(
    'childDisplayLabel falls back to "Talmid" when childName is null',
    (tester) async {
      final grant = _activeGrant(childName: null);
      await tester.pumpWidget(buildSubject(() => Future.value([grant])));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Talmid'), findsOneWidget);

      await tearDownWidget(tester);
    },
  );

  // ── 11. owner label fallback ────────────────────────────────────────────────
  // P2 (M3): when no genuine owner name is available the subtitle shows the
  // LOCALIZED relationship fallback (l10n.tutorFallbackParent → "Parent"),
  // never the raw UID and never a server placeholder.

  testWidgets(
    'owner label falls back to localized "Parent" when parentName is null',
    (tester) async {
      final grant = _activeGrant(parentName: null);
      await tester.pumpWidget(buildSubject(() => Future.value([grant])));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Parent'), findsOneWidget);

      await tearDownWidget(tester);
    },
  );

  // ── 11b. "CloudUser" placeholder must never reach the UI ────────────────────
  // P2 (M3): the server can denormalise the owner name as the placeholder token
  // "CloudUser". The card subtitle and the Resign confirmation dialog must show
  // the localized relationship fallback instead — never the literal "CloudUser".

  testWidgets(
    'owner "CloudUser" placeholder is replaced by localized fallback in subtitle',
    (tester) async {
      final grant = _activeGrant(parentName: 'CloudUser');
      await tester.pumpWidget(buildSubject(() => Future.value([grant])));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The placeholder must NOT be shown anywhere.
      expect(find.textContaining('CloudUser'), findsNothing);
      // The localized fallback is shown instead.
      expect(find.text('Parent'), findsOneWidget);

      await tearDownWidget(tester);
    },
  );

  testWidgets(
    'owner "CloudUser" placeholder is replaced by localized fallback in Resign dialog',
    (tester) async {
      final grant = _activeGrant(parentName: 'CloudUser');
      await tester.pumpWidget(buildSubject(() => Future.value([grant])));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Resign'));
      await tester.pump();

      // Dialog body interpolates the owner label — it must not contain the
      // placeholder token.
      expect(find.textContaining('CloudUser'), findsNothing);

      await tearDownWidget(tester);
    },
  );

  testWidgets('a genuine owner name is shown verbatim (not the fallback)', (
    tester,
  ) async {
    final grant = _activeGrant(parentName: 'Loop Test C');
    await tester.pumpWidget(buildSubject(() => Future.value([grant])));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Loop Test C'), findsOneWidget);

    await tearDownWidget(tester);
  });

  // ── 12. Resign failure shows snackbar ────────────────────────────────────────

  testWidgets('failed resignation shows error snackbar with l10n prefix', (
    tester,
  ) async {
    final grant = _activeGrant();
    when(
      () => mockResignUseCase.call(grant: any(named: 'grant')),
    ).thenThrow(Exception('CF error'));

    await tester.pumpWidget(buildSubject(() => Future.value([grant])));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Open dialog and confirm
    await tester.tap(find.text('Resign'));
    await tester.pump();
    await tester.tap(find.text('Resign').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // AUD-tutoring-11: the snackbar shows a fixed localized string — never
    // the raw exception text interpolated into UI copy (EH-5).
    expect(find.text('Could not resign. Please try again.'), findsOneWidget);
    expect(find.textContaining('CF error'), findsNothing);

    await tearDownWidget(tester);
  });

  // ── 13. AUD-tutoring-01: TutorGrantFailure must NOT be treated as success ──
  //
  // Regression for the P1 finding: the resign handler previously discarded
  // the awaited TutorGrantResult and ran the success side effects (mirror
  // wipe, provider invalidate, parent notification) unconditionally. A
  // genuine server rejection (e.g. permission-denied) must NOT wipe the
  // local mirror, must NOT invalidate the grants list, must NOT notify the
  // parent, and MUST show an error to the tutor.

  testWidgets(
    'AUD-tutoring-01: TutorGrantFailure does not wipe the mirror, notify, '
    'or invalidate — and shows an error',
    (tester) async {
      final grant = _activeGrant();
      when(() => mockResignUseCase.call(grant: any(named: 'grant'))).thenAnswer(
        (_) async =>
            const TutorGrantFailure(message: 'nope', code: 'permission-denied'),
      );

      // Count how many times the grants provider is (re)built — an
      // `ref.invalidate` on failure would force a second build.
      var fetchCount = 0;
      Future<List<TutorGrant>> grantsFactory() {
        fetchCount++;
        return Future.value([grant]);
      }

      // Seed a tutored-mirror profile row keyed to this grantId so a real
      // `wipeMirrorForGrant` call would delete it — proving (by its
      // survival) that the wipe was never invoked on the failure path.
      final db = inMemoryDb();
      final accountId = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'tutor@example.com',
              tier: 'localBorn',
              displayName: 'Test Tutor',
              createdAt: _kNow,
              updatedAt: _kNow,
            ),
          );
      await db.profileDao.upsertTutoredProfile(
        accountId: accountId,
        parentUid: grant.parentUid,
        remoteChildProfileId: grant.childProfileId,
        grantId: grant.grantId,
        displayName: 'Mirrored Child',
        mode: 'child',
        now: _kNow,
      );

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, __) => null,
          overrides: [
            incomingTutorGrantsProvider.overrideWith((ref) => grantsFactory()),
            resignTutorGrantUseCaseProvider.overrideWithValue(
              mockResignUseCase,
            ),
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            tutorNotificationGatewayProvider.overrideWithValue(
              mockNotificationGateway,
            ),
            userDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: ManageGrantsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(fetchCount, 1);

      // Confirm resign.
      await tester.tap(find.text('Resign'));
      await tester.pump();
      await tester.tap(find.text('Resign').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 1. An error is shown — the fixed generic string, never the raw
      //    failure message/code.
      expect(find.text('Could not resign. Please try again.'), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsNothing);

      // 2. No re-fetch was triggered — ref.invalidate(incomingTutorGrantsProvider)
      //    was NOT called.
      expect(fetchCount, 1);

      // 3. The notification gateway was never invoked.
      verifyNever(
        () => mockNotificationGateway.notifyParentOfResignation(
          parentEmail: any(named: 'parentEmail'),
          parentUid: any(named: 'parentUid'),
          tutorName: any(named: 'tutorName'),
          childName: any(named: 'childName'),
        ),
      );

      // 4. The seeded tutored mirror was NOT deleted — proves
      //    wipeMirrorForGrant was never invoked.
      final survivors = await db.profileDao.getTutoredMirrorsForAccount(
        accountId,
      );
      expect(survivors, hasLength(1));

      await tearDownWidget(tester);
      await db.close();
    },
  );

  // ── 14. AUD-tutoring-08: lazy-build the grants roster (PF-2) ────────────────

  testWidgets(
    'AUD-tutoring-08: grants list is backed by ListView.builder (lazy), not '
    'a fully-expanded ListView(children:)',
    (tester) async {
      // 50 active grants — a dedicated tutor's talmid roster has no
      // archiving path and is not bounded small.
      final grants = [
        for (var i = 0; i < 50; i++)
          _activeGrant(grantId: 'grant-$i', childName: 'Talmid $i'),
      ];
      await tester.pumpWidget(buildSubject(() => Future.value(grants)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Structural proof of laziness: ListView.builder uses a
      // SliverChildBuilderDelegate; the old ListView(children: [...]) used a
      // SliverChildListDelegate that eagerly builds every row up front.
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(
        listView.childrenDelegate,
        isA<SliverChildBuilderDelegate>(),
        reason:
            'The grants list must be built via ListView.builder (lazy) so '
            'off-screen rows are not realized on every open/rebuild.',
      );

      // Behavioural proof: the first talmid (near the top) is realized;
      // one deep in the roster, far past the viewport + cache extent, is
      // not — it was never built.
      expect(find.text('Talmid 0'), findsOneWidget);
      expect(find.text('Talmid 49'), findsNothing);

      await tearDownWidget(tester);
    },
  );

  // ── 15. AUD-t-tutoring-06: mirror wipe on successful resignation ────────────
  //
  // R4-M3 fires an unawaited buildTutoredMirrorWipeServiceFromWidget(...)
  // .wipeMirrorForGrant(grantId) after a successful resign. No test asserted
  // the Drift tutored-mirror row was actually deleted — a regression that
  // silently dropped the unawaited(...) call, or broke the onWipe wiring,
  // would ship undetected (the same stale-local-data bug class as
  // DG-TUT-STALE-01 / iter10_outgoing_grants_stale_cache_test.dart).

  testWidgets('AUD-t-tutoring-06: confirming resignation deletes the Drift '
      'tutored-mirror row for the resigned grant', (tester) async {
    final grant = _activeGrant();
    when(
      () => mockResignUseCase.call(grant: any(named: 'grant')),
    ).thenAnswer((_) async => const TutorGrantSuccess());

    final db = inMemoryDb();
    final accountId = await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            email: 'tutor@example.com',
            tier: 'localBorn',
            displayName: 'Test Tutor',
            createdAt: _kNow,
            updatedAt: _kNow,
          ),
        );
    // Seed a tutored-mirror row keyed to this grantId — this is the row
    // wipeMirrorForGrant must delete on a successful resignation.
    await db.profileDao.upsertTutoredProfile(
      accountId: accountId,
      parentUid: grant.parentUid,
      remoteChildProfileId: grant.childProfileId,
      grantId: grant.grantId,
      displayName: 'Mirrored Child',
      mode: 'child',
      now: _kNow,
    );
    final before = await db.profileDao.getTutoredMirrorsForAccount(accountId);
    expect(
      before,
      hasLength(1),
      reason: 'precondition: mirror row exists before resignation',
    );

    await tester.pumpWidget(
      pumpApp(
        retry: (_, __) => null,
        overrides: [
          incomingTutorGrantsProvider.overrideWith(
            (ref) => Future.value([grant]),
          ),
          resignTutorGrantUseCaseProvider.overrideWithValue(mockResignUseCase),
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          tutorNotificationGatewayProvider.overrideWithValue(
            mockNotificationGateway,
          ),
          userDatabaseProvider.overrideWithValue(db),
        ],
        child: const ManageGrantsScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Resign'));
    await tester.pump();
    await tester.tap(find.text('Resign').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final after = await db.profileDao.getTutoredMirrorsForAccount(accountId);
    expect(
      after,
      isEmpty,
      reason:
          'wipeMirrorForGrant must delete the tutored-mirror row for the '
          'resigned grant',
    );

    await tearDownWidget(tester);
    await db.close();
  });

  // ── 16. AUD-t-tutoring-06: active tutored session exits on resign ───────────
  //
  // When the resigned grant IS the tutor's currently-active tutored session
  // (activeTutoredProfileSelectionProvider), the R4-M3 onWipe callback must
  // call ActiveTutoredProfileSelection.exit() so the session clears
  // immediately instead of leaving the tutor "inside" a talmid view whose
  // backing grant no longer exists.

  testWidgets(
    'AUD-t-tutoring-06: confirming resignation for the active tutored '
    'session clears activeTutoredProfileSelectionProvider',
    (tester) async {
      final grant = _activeGrant();
      when(
        () => mockResignUseCase.call(grant: any(named: 'grant')),
      ).thenAnswer((_) async => const TutorGrantSuccess());

      final db = inMemoryDb();
      final accountId = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'tutor@example.com',
              tier: 'localBorn',
              displayName: 'Test Tutor',
              createdAt: _kNow,
              updatedAt: _kNow,
            ),
          );
      await db.profileDao.upsertTutoredProfile(
        accountId: accountId,
        parentUid: grant.parentUid,
        remoteChildProfileId: grant.childProfileId,
        grantId: grant.grantId,
        displayName: 'Mirrored Child',
        mode: 'child',
        now: _kNow,
      );

      final container = ProviderContainer(
        retry: (_, __) => null,
        overrides: [
          incomingTutorGrantsProvider.overrideWith(
            (ref) => Future.value([grant]),
          ),
          resignTutorGrantUseCaseProvider.overrideWithValue(mockResignUseCase),
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          tutorNotificationGatewayProvider.overrideWithValue(
            mockNotificationGateway,
          ),
          userDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      // Enter the resigned grant as the active tutored session.
      container
          .read(activeTutoredProfileSelectionProvider.notifier)
          .enter(
            TutoredProfileSelection(
              profileId: grant.childProfileId,
              ownerUid: grant.parentUid,
              grantId: grant.grantId,
              permissions: TutorPermissions.defaults(),
            ),
          );
      expect(
        container.read(activeTutoredProfileSelectionProvider),
        isNotNull,
        reason: 'precondition: tutored session must be active',
      );

      await tester.pumpWidget(
        pumpApp(container: container, child: const ManageGrantsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Resign'));
      await tester.pump();
      await tester.tap(find.text('Resign').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        container.read(activeTutoredProfileSelectionProvider),
        isNull,
        reason:
            'resigning from the active tutored session must call exit(), '
            'clearing activeTutoredProfileSelectionProvider',
      );

      await tearDownWidget(tester);
      await db.close();
    },
  );

  // ── 17. AUD-t-tutoring-07: RTL (Hebrew locale) ───────────────────────────────
  //
  // Sibling l1 tests in this batch (manage_tutors_screen_l1_test.dart,
  // tutor_audit_log_screen_l1_test.dart) each carry a Locale('he') case —
  // the audit-log one exists specifically because an earlier RTL clipping
  // bug was found there. buildSubject hardcoded Locale('en') with no way to
  // parameterize it, so a directional-layout regression on the active/
  // pending grant rows would ship with green tests.

  testWidgets(
    'he locale: active and pending grant rows render without RenderFlex '
    'overflow',
    (tester) async {
      final active = _activeGrant(grantId: 'grant-a1');
      final pending = _pendingGrant(grantId: 'grant-p1');
      await tester.pumpWidget(
        buildSubject(
          () => Future.value([active, pending]),
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Key affordances must still be present and unclipped under RTL.
      // Section headers/action label are l10n-driven, so assert on the
      // Hebrew (app_he.arb) strings, not the English ones; the grant
      // display names are data, not copy, so they render verbatim in
      // either locale.
      expect(find.text('פעילות (1)'), findsOneWidget); // "Active (1)"
      expect(
        find.text('הזמנות ממתינות (1)'),
        findsOneWidget,
      ); // "Pending invites (1)"
      expect(find.text('Yossi Levi'), findsOneWidget);
      expect(find.text('Moshe Cohen'), findsOneWidget);
      expect(find.text('התפטרות'), findsOneWidget); // "Resign"

      // No RenderFlex overflow (or any other) exception was reported.
      expect(
        tester.takeException(),
        isNull,
        reason:
            'ManageGrantsScreen must render the active/pending grant rows '
            'without a RenderFlex overflow under Locale(he) (RTL)',
      );

      await tearDownWidget(tester);
    },
  );
}
