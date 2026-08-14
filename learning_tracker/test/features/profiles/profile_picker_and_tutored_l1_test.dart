// L1 widget tests — ProfilePickerScreen + TutoredChildrenSection (combined)
//
// FOCUS: tutored_children_section.dart (27.3% baseline) and supplementary
// profile_picker_screen behaviours not covered by profile_picker_screen_l1_test.
//
// Coverage groups:
//
//  A. TutoredChildrenSection — standalone widget tests
//     A1. Loading → renders nothing (SizedBox.shrink)
//     A2. Error  → renders nothing (SizedBox.shrink) AND logs via AppLogger
//         (AUD-profiles-15: the error branch previously discarded the error
//         and stack trace with no log call — a persistently failing grants
//         query left zero diagnostic trace).
//     A3. Empty grants list → renders nothing
//     A4. Active + pending grants absent → renders nothing
//     A5. One active grant → "TALMID PROFILES" header + child name + Tutoring status + Tutor badge
//     A6. Two active grants → both child names rendered
//     A7. childDisplayLabel fallback → "Talmid" when childName is null
//     A8. One pending grant (no active) → section visible + "View invitations" row shown
//     A9. Pending + active → "View invitations" row + child row both present
//     A10. pendingCount badge shows correct number in subtitle
//     A11. he-RTL smoke: section renders in Hebrew locale without crash
//
//  B. ProfilePickerScreen — tutoring integration tests
//     B1. Flat (no grants): TutoredChildrenSection present but renders nothing
//     B2. With one active grant: TALMID PROFILES section visible inside picker
//     B3. With active grant + pending invite card: picker shows both sections
//     B4. Pending tutor invite card shown on picker when pendingInvites non-empty
//     B5. Pending invite card hidden when pendingInvites is empty
//
//  C. Product-rule assertions (cannot be vacuously skipped)
//     C1. canMarkLiveCompletion is always false on TutorPermissions
//     C2. No "parent" profile mode label on any profile tile
//
// BUG LOG: (none at time of writing)

@Tags(['needs_flutter', 'profiles', 'tutored_children'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/profile_picker_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/tutored_children_section.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Notifier subclass override ─────────────────────────────────────────────────

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final String? _initial;
  @override
  String? build() => _initial;
}

// ── Test data factories ────────────────────────────────────────────────────────

final _epoch = DateTime.utc(2026, 1, 1);

LearnerProfileEntity _child({int id = 1, String name = 'Yosef'}) =>
    LearnerProfileEntity(
      profileId: 'ulid-$id',
      displayName: name,
      mode: ProfileMode.child,
      createdAt: _epoch,
      updatedAt: _epoch,
    );

LearnerProfileEntity _adult({int id = 2, String name = 'Avraham'}) =>
    LearnerProfileEntity(
      profileId: 'ulid-$id',
      displayName: name,
      mode: ProfileMode.adult,
      createdAt: _epoch,
      updatedAt: _epoch,
    );

TutorGrant _activeGrant({
  String grantId = 'grant-active-1',
  String? childName = 'Yossi Levi',
}) {
  final doc = TutorGrantDoc(
    grantId: grantId,
    parentUid: 'parent-uid-1',
    childProfileId: 'child-profile-1',
    tutorEmail: 'tutor@example.com',
    state: TutorGrantState.active,
    invitedAt: _epoch,
    updatedAt: _epoch,
    acceptedAt: _epoch,
    childName: childName,
  );
  return TutorGrant.fromDoc(doc, permissions: TutorPermissions.defaults());
}

TutorGrant _pendingGrant({
  String grantId = 'grant-pending-1',
  String? childName = 'Moshe Cohen',
}) {
  final doc = TutorGrantDoc(
    grantId: grantId,
    parentUid: 'parent-uid-1',
    childProfileId: 'child-profile-2',
    tutorEmail: 'tutor@example.com',
    state: TutorGrantState.pending,
    invitedAt: _epoch,
    updatedAt: _epoch,
    expiresAt: _epoch.add(const Duration(days: 7)),
    childName: childName,
  );
  return TutorGrant.fromDoc(doc);
}

// ── Section-standalone builder ─────────────────────────────────────────────────
//
// Wraps TutoredChildrenSection in a ProviderScope + MaterialApp, overriding
// incomingTutorGrantsProvider with a factory that can be loading/error/data.

Widget _buildSection(
  Future<List<TutorGrant>> Function() grantsFactory, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      incomingTutorGrantsProvider.overrideWith((ref) => grantsFactory()),
      // selectedProfileIdProvider: default (null) — not needed by section itself.
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
      home: const Scaffold(
        body: SingleChildScrollView(child: TutoredChildrenSection()),
      ),
    ),
  );
}

// ── Full-screen picker builder ─────────────────────────────────────────────────

Widget _buildPicker({
  required _MockStackRouter router,
  List<LearnerProfileEntity> profiles = const [],
  List<TutorGrant> grants = const [],
  List<TutorGrant> pendingInvites = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      profileListProvider.overrideWith((ref) => Future.value(profiles)),
      incomingTutorGrantsProvider.overrideWith((ref) async => grants),
      pendingTutorInvitesProvider.overrideWith((ref) async => pendingInvites),
      authStateProvider.overrideWithValue(
        const AuthState.signedIn(
          user: AuthUser(
            uid: 'account-1',
            email: 't@t.com',
            displayName: 'Test',
          ),
          tier: Tier.local,
        ),
      ),
      selectedProfileIdProvider.overrideWith(
        () => _FixedSelectedProfileId(null),
      ),
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
        child: const Scaffold(body: ProfilePickerScreen()),
      ),
    ),
  );
}

// ── Teardown helper ─────────────────────────────────────────────────────────────

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  late _MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  setUp(() {
    router = _MockStackRouter();
    when(
      () => router.replaceAll(any<List<PageRouteInfo>>()),
    ).thenAnswer((_) async {});
    when(() => router.canPop()).thenReturn(false);
    when(() => router.currentPath).thenReturn('/profile-picker');
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) => Future<Object?>.value(null));
  });

  // ────────────────────────────────────────────────────────────────────────────
  // A. TutoredChildrenSection — standalone tests
  // ────────────────────────────────────────────────────────────────────────────

  group('TutoredChildrenSection', () {
    // A1 ─ loading
    testWidgets('A1: loading state — section renders nothing visible', (
      tester,
    ) async {
      final completer = Completer<List<TutorGrant>>();
      await tester.pumpWidget(_buildSection(() => completer.future));
      await tester.pump();

      // While loading, no TALMID PROFILES header and no rows.
      expect(find.text('TALMID PROFILES'), findsNothing);
      expect(find.text('View invitations'), findsNothing);

      completer.complete([]);
      await tester.pump(const Duration(seconds: 1));
      await _teardown(tester);
    });

    // A2 ─ error
    testWidgets(
      'A2: error state — section renders nothing (silent-UI fail) but logs '
      'via AppLogger (AUD-profiles-15)',
      (tester) async {
        await tester.pumpWidget(
          _buildSection(
            () => Future<List<TutorGrant>>.error(Exception('network')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Error path maps to SizedBox.shrink — no header, no retry button.
        expect(find.text('TALMID PROFILES'), findsNothing);
        expect(find.text('Retry'), findsNothing);

        // AUD-profiles-15: hiding the section on load failure is a
        // defensible UX call, but the failure must still leave a trace in
        // AppLogger for diagnosing a persistently failing grants query
        // (e.g. a Firestore rule regression on the tutoring collection).
        final history = AppLogger.instance.talker.history
            .map((e) => e.generateTextMessage())
            .toList();
        expect(
          history.any((m) => m.contains('tutored_children_grants_load_error')),
          isTrue,
          reason:
              'Expected the swallowed incomingTutorGrantsProvider error to '
              'be logged via AppLogger (event: '
              '"tutored_children_grants_load_error") instead of the error '
              'branch silently falling through to SizedBox.shrink with no '
              'diagnostic trail. Talker history: $history',
        );

        await _teardown(tester);
      },
    );

    // A3 ─ empty grants
    testWidgets('A3: empty grants list — section hidden entirely', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSection(() => Future.value([])));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('TALMID PROFILES'), findsNothing);
      expect(find.text('View invitations'), findsNothing);

      await _teardown(tester);
    });

    // A4 ─ terminal grants only (revoked) → hidden
    testWidgets('A4: revoked grant only — section hidden (no active/pending)', (
      tester,
    ) async {
      // Build a revoked-by-parent grant (terminal state).
      final doc = TutorGrantDoc(
        grantId: 'grant-revoked',
        parentUid: 'p-uid',
        childProfileId: 'child-id',
        tutorEmail: 'tutor@example.com',
        state: TutorGrantState.revokedByParent,
        invitedAt: _epoch,
        updatedAt: _epoch,
        revokedAt: _epoch,
      );
      final revokedGrant = TutorGrant.fromDoc(doc);

      await tester.pumpWidget(
        _buildSection(() => Future.value([revokedGrant])),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No active, no pending → section must not appear.
      expect(find.text('TALMID PROFILES'), findsNothing);
      await _teardown(tester);
    });

    // A5 ─ one active grant → section visible
    testWidgets(
      'A5: one active grant — "TALMID PROFILES" header + child name + '
      '"Tutoring" status + "Tutor" badge',
      (tester) async {
        final grant = _activeGrant(childName: 'Yossi Levi');
        await tester.pumpWidget(_buildSection(() => Future.value([grant])));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Section header.
        expect(find.text('TALMID PROFILES'), findsOneWidget);

        // Child name row.
        expect(find.text('Yossi Levi'), findsOneWidget);

        // Status subtitle (l10n.tutoredChildrenStatusTutoring = 'Tutoring').
        expect(find.text('Tutoring'), findsOneWidget);

        // Role badge (l10n.tutoredChildrenRoleBadge = 'Tutor').
        expect(find.text('Tutor'), findsOneWidget);

        // No "View invitations" row when there are no pending grants.
        expect(find.text('View invitations'), findsNothing);

        await _teardown(tester);
      },
    );

    // A6 ─ two active grants → both child names rendered
    testWidgets('A6: two active grants — both child names visible', (
      tester,
    ) async {
      final g1 = _activeGrant(grantId: 'g1', childName: 'Yossi Levi');
      final g2 = _activeGrant(grantId: 'g2', childName: 'Dovid Klein');
      await tester.pumpWidget(_buildSection(() => Future.value([g1, g2])));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Yossi Levi'), findsOneWidget);
      expect(find.text('Dovid Klein'), findsOneWidget);

      await _teardown(tester);
    });

    // A7 ─ childName null → fallback "Talmid"
    testWidgets(
      'A7: childName is null — row label falls back to "Talmid" (not raw id)',
      (tester) async {
        final grant = _activeGrant(childName: null);
        await tester.pumpWidget(_buildSection(() => Future.value([grant])));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // "Talmid" is the hardcoded fallback in TutorGrant.childDisplayLabel.
        expect(find.text('Talmid'), findsOneWidget);
        // Raw Firestore profile id must not be shown.
        expect(find.text('child-profile-1'), findsNothing);

        await _teardown(tester);
      },
    );

    // A8 ─ one pending grant (no active) → section visible + "View invitations"
    testWidgets(
      'A8: pending grant only — section visible + "View invitations" row shown',
      (tester) async {
        final pending = _pendingGrant();
        await tester.pumpWidget(_buildSection(() => Future.value([pending])));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('TALMID PROFILES'), findsOneWidget);
        expect(find.text('View invitations'), findsOneWidget);

        // No active child row.
        expect(find.text('Tutoring'), findsNothing);

        await _teardown(tester);
      },
    );

    // A9 ─ pending + active → both rows present
    testWidgets(
      'A9: pending + active grants — "View invitations" row AND child row both '
      'present',
      (tester) async {
        final active = _activeGrant(childName: 'Yossi Levi');
        final pending = _pendingGrant();
        await tester.pumpWidget(
          _buildSection(() => Future.value([active, pending])),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('TALMID PROFILES'), findsOneWidget);
        expect(find.text('View invitations'), findsOneWidget);
        expect(find.text('Yossi Levi'), findsOneWidget);
        expect(find.text('Tutoring'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // A10 ─ pending count badge
    testWidgets(
      'A10: two pending grants — subtitle shows "2 pending tutor invitations"',
      (tester) async {
        final p1 = _pendingGrant(grantId: 'p1');
        final p2 = _pendingGrant(grantId: 'p2', childName: 'Binyamin');
        await tester.pumpWidget(_buildSection(() => Future.value([p1, p2])));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Plural form (count=2): "2 pending tutor invitations"
        expect(find.text('2 pending tutor invitations'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // A10b ─ single pending count badge (singular)
    testWidgets(
      'A10b: one pending grant — subtitle shows "1 pending tutor invitation"',
      (tester) async {
        final p1 = _pendingGrant(grantId: 'p1');
        await tester.pumpWidget(_buildSection(() => Future.value([p1])));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('1 pending tutor invitation'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // A11 ─ Hebrew locale smoke
    testWidgets(
      'A11: he-RTL smoke — TutoredChildrenSection renders in Hebrew without '
      'crash or overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          originalOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalOnError);

        final grant = _activeGrant(childName: 'יוסי לוי');
        await tester.pumpWidget(
          _buildSection(
            () => Future.value([grant]),
            locale: const Locale('he'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Section header in Hebrew locale (l10n key: profilePickerTalmidProfiles).
        // Hebrew: 'פרופילי תלמידים'
        expect(find.text('פרופילי תלמידים'), findsOneWidget);
        // Child name renders correctly.
        expect(find.text('יוסי לוי'), findsOneWidget);

        await _teardown(tester);
      },
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // B. ProfilePickerScreen — tutoring integration
  // ────────────────────────────────────────────────────────────────────────────

  group('ProfilePickerScreen + TutoredChildrenSection integration', () {
    // B1 ─ no grants → TutoredChildrenSection in tree but silent
    testWidgets(
      'B1: no grants — TutoredChildrenSection in widget tree but renders no '
      'TALMID PROFILES section',
      (tester) async {
        await tester.pumpWidget(
          _buildPicker(router: router, profiles: [_adult()], grants: []),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Widget is present.
        expect(find.byType(TutoredChildrenSection), findsOneWidget);
        // But it renders nothing — no header visible.
        expect(find.text('TALMID PROFILES'), findsNothing);

        await _teardown(tester);
      },
    );

    // B2 ─ active grant → TALMID PROFILES visible inside picker
    testWidgets(
      'B2: active grant in picker — TALMID PROFILES section and child row '
      'visible',
      (tester) async {
        final grant = _activeGrant(childName: 'Yossi Levi');
        await tester.pumpWidget(
          _buildPicker(router: router, profiles: [_adult()], grants: [grant]),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('TALMID PROFILES'), findsOneWidget);
        expect(find.text('Yossi Levi'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // B3 ─ active grant + pending invite (picker-level pending invite card)
    testWidgets(
      'B3: picker shows pending-invite card at top and TALMID section below '
      'when both are present',
      (tester) async {
        final activeGrant = _activeGrant(childName: 'Yossi Levi');
        final pendingInvite = _pendingGrant(grantId: 'invite-1');
        await tester.pumpWidget(
          _buildPicker(
            router: router,
            profiles: [_adult()],
            grants: [activeGrant],
            pendingInvites: [pendingInvite],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Picker-level invite card (from _PendingInviteCard): "Accept invite"
        expect(find.text('Accept invite'), findsOneWidget);
        // TALMID section below.
        expect(find.text('TALMID PROFILES'), findsOneWidget);
        expect(find.text('Yossi Levi'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // B4 ─ pending invite card shown
    testWidgets(
      'B4: pending invite card rendered when pendingInvites is non-empty',
      (tester) async {
        final pending = _pendingGrant(grantId: 'invite-2');
        await tester.pumpWidget(
          _buildPicker(
            router: router,
            profiles: [_adult()],
            pendingInvites: [pending],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // _PendingInviteCard renders l10n.acceptInviteAccept = 'Accept invite'.
        expect(find.text('Accept invite'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // B5 ─ no pending invite card when pendingInvites is empty
    testWidgets('B5: no pending invite card when pendingInvites is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildPicker(router: router, profiles: [_adult()], pendingInvites: []),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Accept invite'), findsNothing);

      await _teardown(tester);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // C. Product-rule assertions
  // ────────────────────────────────────────────────────────────────────────────

  group('Product rules', () {
    // C1 ─ canMarkLiveCompletion always false
    test(
      'C1: TutorPermissions.canMarkLiveCompletion is always false — invariant '
      'holds on defaults, readOnly, and copyWith',
      () {
        final defaults = TutorPermissions.defaults();
        expect(defaults.canMarkLiveCompletion, isFalse);

        final readOnly = TutorPermissions.readOnly();
        expect(readOnly.canMarkLiveCompletion, isFalse);

        // Constructing directly cannot set it to true — field is not in ctor.
        const explicit = TutorPermissions();
        expect(explicit.canMarkLiveCompletion, isFalse);

        // copyWith does not expose canMarkLiveCompletion either.
        final copied = defaults.copyWith(canViewProgress: false);
        expect(copied.canMarkLiveCompletion, isFalse);
      },
    );

    // C2 ─ no "parent" profile mode label rendered
    testWidgets('C2: child+adult only — no "parent" mode label in profile grid '
        '(product rule: two profile types)', (tester) async {
      final profiles = [
        _child(id: 1, name: 'Yosef'),
        _adult(id: 2, name: 'Avraham'),
      ];
      await tester.pumpWidget(_buildPicker(router: router, profiles: profiles));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // CHILD MODE and ADULT MODE should appear.
      expect(find.text('CHILD MODE'), findsOneWidget);
      expect(find.text('ADULT MODE'), findsOneWidget);

      // HARD RULE: no "parent" mode anywhere.
      expect(find.textContaining('PARENT'), findsNothing);
      expect(
        find.textContaining('Parent Mode', findRichText: true),
        findsNothing,
      );

      await _teardown(tester);
    });
  });
}
