/// Firestore-native L1 coverage for ParentSettingsScreen.
@Tags(['profiles', 'parent_settings'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/network/connectivity_gateway.dart';
import 'package:learning_tracker/core/providers/network_providers.dart'
    show connectivityServiceProvider;
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/parent_settings_screen.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/pump_app.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _OnlineConnectivityGateway extends ConnectivityGateway {
  @override
  Future<bool> get isOnline async => true;
}

class _FixedActiveProfileDocId extends ActiveProfileDocId {
  _FixedActiveProfileDocId(this._id);
  final String _id;

  @override
  String? build() => _id;
}

const _uid = 'uid-parent-settings';
const _profileId = '01HPARENTSETTINGSPROFILE000';

LearnerProfileEntity _childProfile() => LearnerProfileEntity(
  profileId: _profileId,
  displayName: 'Moshe',
  mode: ProfileMode.child,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Widget _buildApp({
  required _MockStackRouter router,
  required FakeFirebaseFirestore firestore,
  TutorPermissions? tutorPerms,
  AppUser? user,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  int pendingCount = 0,
  int pointsBalance = 0,
}) {
  final auth = _MockAuthRepository();
  when(() => auth.currentUser).thenReturn(user);
  when(() => auth.reloadCurrentUser()).thenAnswer((_) async => user);
  return pumpApp(
    locale: locale,
    theme: theme,
    retry: (_, __) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      activeProfileIdProvider.overrideWithValue(_profileId),
      activeProfileDocIdProvider.overrideWith(
        () => _FixedActiveProfileDocId(_profileId),
      ),
      activeAccountFirebaseProvider.overrideWith(
        (ref) async => AccountFirebaseHandles(
          app: _MockFirebaseApp(),
          firestore: firestore,
          auth: _MockFirebaseAuth(),
          uid: _uid,
        ),
      ),
      profileListStreamProvider.overrideWith(
        (ref) => Stream.value([_childProfile()]),
      ),
      activeTutorPermissionsProvider.overrideWithValue(tutorPerms),
      pendingRedemptionsCountProvider.overrideWith(
        (ref) => Stream.value(pendingCount),
      ),
      activeProfilePointsBalanceProvider.overrideWith(
        (ref) async => pointsBalance,
      ),
      connectivityServiceProvider.overrideWithValue(
        _OnlineConnectivityGateway(),
      ),
    ],
    child: StackRouterScope(
      controller: router,
      stateHash: 0,
      child: const ParentSettingsScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// Reveal a lazily-built row before asserting it. `scrollUntilVisible` cannot
/// be used when the target is not yet in the ListView's element tree.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  final list = find.byType(ListView).first;
  for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -400));
    await tester.pump();
  }
  expect(target, findsOneWidget);
  // A lazily-built row may already have an element while still being outside
  // the viewport. Make the final target hittable as well as present.
  await tester.ensureVisible(target);
  await tester.pump();
}

void main() {
  setUpAll(() => registerFallbackValue(_FakePageRouteInfo()));
  late _MockStackRouter router;
  late FakeFirebaseFirestore firestore;

  setUp(() {
    router = _MockStackRouter();
    firestore = createFakeFirestore(authenticatedUid: _uid);
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
    when(() => router.canPop()).thenReturn(false);
    when(() => router.maybePop<Object?>()).thenAnswer((_) async => false);
  });

  testWidgets('owner context shows the edit and account-safety tiles', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(router: router, firestore: firestore));
    await _settle(tester);
    expect(find.text('Manage Tracks'), findsOneWidget);
    expect(find.text('Point Settings'), findsOneWidget);
    expect(find.text('Reward Configuration'), findsOneWidget);
    expect(find.text('Manage Goals'), findsOneWidget);
    expect(find.text('Adjust Points'), findsOneWidget);
    expect(find.text('Pending Prizes'), findsOneWidget);
    await _reveal(tester, find.text('Add Lifetime Learning'));
    expect(find.text('Add Lifetime Learning'), findsOneWidget);

    // The owner-only section is below the initially built portion of the
    // ListView. Scroll it into the tree before checking its real visibility.
    await _reveal(tester, find.text('Manage Tutors'));
    expect(find.text('Manage Tutors'), findsOneWidget);

    await _reveal(tester, find.text('ACCOUNT SAFETY'));
    expect(find.text('ACCOUNT SAFETY'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets(
    'owner tile matrix includes goals, lifetime learning, and pending copy',
    (tester) async {
      await tester.pumpWidget(_buildApp(router: router, firestore: firestore));
      await _settle(tester);
      for (final label in ['Manage Goals', 'Adjust Points', 'Pending Prizes']) {
        await _reveal(tester, find.text(label));
        expect(find.text(label), findsOneWidget);
      }
      await _reveal(tester, find.text('No pending prize requests.'));
      expect(find.text('No pending prize requests.'), findsOneWidget);
      await _reveal(tester, find.text('Add Lifetime Learning'));
      expect(find.text('Add Lifetime Learning'), findsOneWidget);
      await _teardown(tester);
    },
  );

  testWidgets('pending prizes shows the non-empty request count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, firestore: firestore, pendingCount: 2),
    );
    await _settle(tester);
    await _reveal(tester, find.text('Pending Prizes'));
    expect(find.text('2 prize requests waiting'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('owner navigation tiles push their routes', (tester) async {
    Future<void> tapAndVerify(String label, Type expectedRoute) async {
      await _reveal(tester, find.text(label));
      await tester.tap(find.text(label));
      await tester.pump();
      final route = verify(
        () => router.push<Object?>(
          captureAny(),
          onFailure: any(named: 'onFailure'),
        ),
      ).captured.single;
      expect(route, isA<PageRouteInfo>());
      expect(route.runtimeType, expectedRoute);
    }

    await tester.pumpWidget(_buildApp(router: router, firestore: firestore));
    await _settle(tester);
    await tapAndVerify('Manage Tracks', ParentTrackManagementRoute);
    await tapAndVerify('Manage Goals', ParentTrackManagementRoute);
    await tapAndVerify('Point Settings', PointConfigRoute);
    await tapAndVerify('Reward Configuration', RewardConfigurationRoute);
    await tapAndVerify('Add Lifetime Learning', LifetimeMarkingRoute);
    await tapAndVerify('Manage Tutors', ManageTutorsRoute);
    await _teardown(tester);
  });

  testWidgets('default tutor permissions retain learning edit tiles only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        firestore: firestore,
        tutorPerms: TutorPermissions.defaults(),
      ),
    );
    await _settle(tester);
    expect(find.text('Manage Tracks'), findsOneWidget);
    expect(find.text('Manage Goals'), findsOneWidget);
    expect(find.text('Point Settings'), findsOneWidget);
    expect(find.text('Reward Configuration'), findsOneWidget);
    expect(find.text('Manage Tutors'), findsNothing);
    expect(find.text('ACCOUNT SAFETY'), findsNothing);
    await _reveal(tester, find.text('Add Lifetime Learning'));
    expect(find.text('Add Lifetime Learning'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('Adjust Points dialog validates empty and zero amounts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, firestore: firestore, pointsBalance: 37),
    );
    await _settle(tester);
    await _reveal(tester, find.text('Adjust Points'));
    await tester.tap(find.text('Adjust Points'));
    await tester.pumpAndSettle();
    expect(find.text('Current balance: 37 pts'), findsOneWidget);
    final apply = find.widgetWithText(FilledButton, 'Apply');
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '0');
    await tester.pump();
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    await _teardown(tester);
  });

  testWidgets(
    'signed-in owner shows Delete Account while tutor hides owner safety',
    (tester) async {
      const user = AppUser(
        uid: _uid,
        email: 'owner@example.com',
        displayName: 'Owner',
        emailVerified: true,
        providers: ['password'],
      );
      await tester.pumpWidget(
        _buildApp(router: router, firestore: firestore, user: user),
      );
      await _settle(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      )!;
      await _reveal(tester, find.text(l10n.signOutLabel));
      await tester.tap(find.text(l10n.signOutLabel));
      await tester.pumpAndSettle();
      final signOutDialog = find.byType(Dialog);
      expect(signOutDialog, findsOneWidget);
      expect(
        find.descendant(
          of: signOutDialog,
          matching: find.widgetWithText(FilledButton, l10n.signOutLabel),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: signOutDialog,
          matching: find.text(l10n.signOutConfirmBody),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: signOutDialog,
          matching: find.widgetWithText(TextButton, l10n.actionCancel),
        ),
      );
      await tester.pumpAndSettle();

      await _reveal(tester, find.text(l10n.deleteAccountTitle));
      expect(find.text(l10n.deleteAccountTitle), findsOneWidget);
      await tester.tap(find.text(l10n.deleteAccountTitle));
      await tester.pumpAndSettle();
      final deleteDialog = find.byType(AlertDialog);
      expect(deleteDialog, findsOneWidget);
      expect(
        find.descendant(
          of: deleteDialog,
          matching: find.text(l10n.deleteAccountTypeConfirm),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: deleteDialog,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.hintText == l10n.deleteAccountHint,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: deleteDialog,
          matching: find.text(
            '${l10n.deleteAccountWarningBody}\n\n'
            '${l10n.deleteAccountReauthPassword}',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: deleteDialog,
          matching: find.widgetWithText(TextButton, l10n.actionCancel),
        ),
      );
      await tester.pumpAndSettle();
      await _teardown(tester);
    },
  );

  testWidgets('read-only tutor context hides all edit tiles', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        firestore: firestore,
        tutorPerms: TutorPermissions.readOnly(),
      ),
    );
    await _settle(tester);
    expect(find.text('Manage Tracks'), findsNothing);
    expect(find.text('Point Settings'), findsNothing);
    expect(find.text('Reward Configuration'), findsNothing);
    expect(find.text('Manage Tutors'), findsNothing);
    expect(find.text('ACCOUNT SAFETY'), findsNothing);
    expect(find.text('Sign Out'), findsNothing);
    await _teardown(tester);
  });

  testWidgets('tutor permissions independently gate tracks and rewards', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        firestore: firestore,
        tutorPerms: const TutorPermissions(
          canEditStages: true,
          canEditRewards: false,
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Manage Tracks'), findsOneWidget);
    expect(find.text('Reward Configuration'), findsNothing);
    await _teardown(tester);
  });

  testWidgets('Hebrew locale renders without throwing', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        firestore: firestore,
        locale: const Locale('he'),
      ),
    );
    await _settle(tester);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byIcon(Icons.route_rounded), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('dark mode uses theme-aware Manage Tutors tile colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        firestore: firestore,
        theme: AppTheme.darkTheme(),
      ),
    );
    await _settle(tester);
    await _reveal(tester, find.byIcon(Icons.school_rounded));
    final tutorIconContainer = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.school_rounded),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (tutorIconContainer.decoration! as BoxDecoration).color,
      AppPalette.dark.settingsProfileBadgeParentBg,
    );
    expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.card_giftcard_rounded)).color,
      AppPalette.dark.peachTintIconAccent,
    );
    expect(AppTheme.darkTheme().colorScheme.onPrimary, isNot(Colors.white));
    expect(AppPalette.dark.settingsProfileBadgeParentBg, isNotNull);
    await _teardown(tester);
  });
}
