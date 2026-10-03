// Story 4.4 (DNI-512) AC-4 / AC-5, T4 — the tutor's roster follows the live
// active-grant set.
//
// The roster is the existing My grants list until DNI-511's My talmidim
// reaches integ/sub-tracks (both read the same `listTutorGrants` active set).
// When a session ends for revocation, the list is re-read and only the
// revoked learner's row goes — on the next update, without a restart; other
// active learners stay. A stale read that resolves late never brings the
// revoked row back.

@Tags(['dni_512', 'tutor_mode', 'manage_grants'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_for_scope_provider.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_access_ended_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/manage_grants_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

const _owner = 'parent-uid';
const _yossiProfile = '01J8XKQ2M3N4P5R6S7T8V9W0XY';
const _doviProfile = '01J8XKQ2M3N4P5R6S7T8V9W0XZ';
const _yossi = 'grant-yossi';
const _dovi = 'grant-dovi';

class _MockListIncoming extends Mock
    implements ListIncomingTutorAccessUseCase {}

class _MockAuthRepository extends Mock implements AuthRepository {}

TutorGrant _active(
  String grantId,
  String profileId,
  String name, {
  bool canEditLearning = true,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return TutorGrant.fromDoc(
    TutorGrantDoc(
      grantId: grantId,
      parentUid: _owner,
      childProfileId: profileId,
      tutorEmail: 'rebbe@example.com',
      state: TutorGrantState.active,
      invitedAt: now,
      updatedAt: now,
      acceptedAt: now,
      childName: name,
    ),
    permissions: TutorPermissions(canEditLearning: canEditLearning),
  );
}

void main() {
  late _MockListIncoming listIncoming;
  late List<Completer<({List<TutorGrant> grants, bool ok})>> pendingReads;
  late StreamController<bool> connectivity;

  final both = [
    _active(_dovi, _doviProfile, 'Dovi'),
    _active(_yossi, _yossiProfile, 'Yossi'),
  ];
  final doviOnly = [_active(_dovi, _doviProfile, 'Dovi')];

  setUp(() {
    listIncoming = _MockListIncoming();
    pendingReads = [];
    when(() => listIncoming.callWithStatus()).thenAnswer((_) {
      final read = Completer<({List<TutorGrant> grants, bool ok})>();
      pendingReads.add(read);
      return read.future;
    });
    connectivity = StreamController<bool>.broadcast();
  });

  tearDown(() => connectivity.close());

  Future<ProviderContainer> pumpRoster(WidgetTester tester) async {
    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWithValue(
          const AuthState.signedIn(
            user: AuthUser(
              uid: 'tutor-uid',
              email: 'rebbe@example.com',
              displayName: 'Rebbe',
            ),
            tier: Tier.local,
          ),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        listIncomingGrantsUseCaseProvider.overrideWithValue(listIncoming),
        connectivityStreamProvider.overrideWith((ref) => connectivity.stream),
        learnerStateForScopeProvider.overrideWith(
          (ref, scope) => const AsyncLoading<LearnerState>(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(tutorSessionAccessWatchProvider, (_, _) {});
    container.listen(tutorAccessEndedProvider, (_, _) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
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
    pendingReads.single.complete((grants: both, ok: true));
    await tester.pumpAndSettle();
    expect(find.text('Yossi'), findsOneWidget);
    expect(find.text('Dovi'), findsOneWidget);
    return container;
  }

  /// A pull-to-refresh of the list: invalidate, then the screen's read.
  void refresh(ProviderContainer container) {
    container.invalidate(incomingTutorGrantsProvider);
    container.read(incomingTutorGrantsProvider);
  }

  void openYossi(ProviderContainer container) => container
      .read(activeTutoredProfileSelectionProvider.notifier)
      .enter(
        const TutoredProfileSelection(
          profileId: _yossiProfile,
          ownerUid: _owner,
          grantId: _yossi,
          permissions: TutorPermissions(canEditLearning: true),
        ),
      );

  testWidgets(
    'a revoked session removes only that row on the next list update',
    (tester) async {
      final container = await pumpRoster(tester);
      openYossi(container);

      container.read(tutorAccessEndedProvider.notifier).end(_yossi);
      await tester.pump();
      expect(pendingReads, hasLength(2), reason: 'the live set is re-read');
      pendingReads.last.complete((grants: doviOnly, ok: true));
      await tester.pumpAndSettle();

      expect(find.text('Yossi'), findsNothing);
      expect(find.text('Dovi'), findsOneWidget);
      expect(container.read(activeTutoredProfileSelectionProvider), isNull);
    },
  );

  testWidgets('a stale read resolving late never brings the revoked row back', (
    tester,
  ) async {
    final container = await pumpRoster(tester);

    // An earlier refresh is still in flight when the revocation re-read starts.
    refresh(container);
    await tester.pump();
    final stale = pendingReads.last;
    refresh(container);
    await tester.pump();
    final fresh = pendingReads.last;
    expect(identical(stale, fresh), isFalse);

    fresh.complete((grants: doviOnly, ok: true));
    await tester.pumpAndSettle();
    stale.complete((grants: both, ok: true));
    await tester.pumpAndSettle();

    expect(find.text('Yossi'), findsNothing);
    expect(find.text('Dovi'), findsOneWidget);
  });

  testWidgets('AC-6: an accepted re-invite shows the learner again with its own '
      'can_edit_learning', (tester) async {
    final container = await pumpRoster(tester);
    openYossi(container);
    container.read(tutorAccessEndedProvider.notifier).end(_yossi);
    await tester.pump();
    pendingReads.last.complete((grants: doviOnly, ok: true));
    await tester.pumpAndSettle();
    expect(find.text('Yossi'), findsNothing);

    // The parent re-invites with the box unchecked; the tutor accepts.
    refresh(container);
    await tester.pump();
    pendingReads.last.complete((
      grants: [
        ...doviOnly,
        _active(_yossi, _yossiProfile, 'Yossi', canEditLearning: false),
      ],
      ok: true,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Yossi'), findsOneWidget);
    final regranted = container
        .read(incomingTutorGrantsProvider)
        .requireValue
        .singleWhere((g) => g.grantId == _yossi);
    expect(
      (regranted.grantState as ActiveGrant).permissions.canEditLearning,
      isFalse,
    );
    expect(
      container.read(tutorAccessEndedProvider),
      isNotNull,
      reason:
          'the earlier notice is the shell\'s to acknowledge; nothing else changes',
    );
  });
}
