// Story 4.4 (DNI-512) AC-4 / AC-5 — the revoked tutored session boundary.
//
// One outcome for every revocation signal — a listener `permission-denied`
// (DNI-523's grant-gated learner read), a write callable rejected for
// revocation, and the authoritative active-grant list — : the learner's name
// is resolved first, the tutored selection and learner-scoped state are
// cleared, the roster is re-read, and the shell shows "Access to {name} has
// ended." and returns to the roster, discarding any open form or picker.

@Tags(['dni_512', 'tutor_mode'])
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_for_scope_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_access_ended_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/widgets/tutor_access_ended_listener.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

const _owner = 'parent-uid';
const _profile = '01J8XKQ2M3N4P5R6S7T8V9W0XY';
const _otherProfile = '01J8XKQ2M3N4P5R6S7T8V9W0XZ';
const _grant = 'grant-yossi';
const _otherGrant = 'grant-dovi';

const _selection = TutoredProfileSelection(
  profileId: _profile,
  ownerUid: _owner,
  grantId: _grant,
  permissions: TutorPermissions(canEditLearning: true),
);
final _scope = LearnerScope(ownerUid: _owner, profileId: _profile);

const _signedIn = AuthState.signedIn(
  user: AuthUser(uid: 'tutor-uid', email: 't@t.com', displayName: 'Rebbe'),
  tier: Tier.local,
);

class _MockListIncoming extends Mock
    implements ListIncomingTutorAccessUseCase {}

/// The test's handle on `learnerStateForScopeProvider(scope)`'s value.
class _ScopeValue extends Notifier<AsyncValue<LearnerState>> {
  @override
  AsyncValue<LearnerState> build() => const AsyncLoading();

  void set(AsyncValue<LearnerState> value) => state = value;
}

final _scopeValueProvider =
    NotifierProvider<_ScopeValue, AsyncValue<LearnerState>>(_ScopeValue.new);

TutorGrant _activeGrant(String grantId, String profileId, String childName) {
  final now = DateTime.utc(2026, 1, 1);
  return TutorGrant.fromDoc(
    TutorGrantDoc(
      grantId: grantId,
      parentUid: _owner,
      childProfileId: profileId,
      tutorEmail: 't@t.com',
      state: TutorGrantState.active,
      invitedAt: now,
      updatedAt: now,
      acceptedAt: now,
      childName: childName,
    ),
    permissions: const TutorPermissions(canEditLearning: true),
  );
}

LearnerProfileEntity _talmidProfile(String name) => LearnerProfileEntity(
  profileId: _profile,
  displayName: name,
  mode: ProfileMode.child,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

AsyncValue<LearnerState> _denied(TutorScopeDenialReason reason) => AsyncError(
  TutorScopeAccessDeniedException(_scope, reason),
  StackTrace.empty,
);

void main() {
  late _MockListIncoming listIncoming;
  late List<TutorGrant> serverGrants;
  late int rosterReads;
  late StreamController<bool> connectivity;

  setUp(() {
    listIncoming = _MockListIncoming();
    serverGrants = [
      _activeGrant(_grant, _profile, 'Yossi'),
      _activeGrant(_otherGrant, _otherProfile, 'Dovi'),
    ];
    rosterReads = 0;
    when(() => listIncoming.callWithStatus()).thenAnswer((_) async {
      rosterReads++;
      return (grants: List<TutorGrant>.of(serverGrants), ok: true);
    });
    connectivity = StreamController<bool>.broadcast();
  });

  tearDown(() => connectivity.close());

  List<Override> overrides({String? mirrorName = 'Yossi'}) => [
    authStateProvider.overrideWithValue(_signedIn),
    listIncomingGrantsUseCaseProvider.overrideWithValue(listIncoming),
    learnerStateForScopeProvider.overrideWith(
      (ref, scope) => ref.watch(_scopeValueProvider),
    ),
    activeProfileProvider.overrideWith(
      (ref) async => mirrorName == null ? null : _talmidProfile(mirrorName),
    ),
    connectivityStreamProvider.overrideWith((ref) => connectivity.stream),
  ];

  /// A container with the tutor inside Yossi's context and the boundary armed.
  Future<ProviderContainer> openSession({String? mirrorName = 'Yossi'}) async {
    final container = ProviderContainer(
      overrides: overrides(mirrorName: mirrorName),
    );
    addTearDown(container.dispose);
    container.listen(tutorAccessEndedProvider, (_, _) {});
    container.listen(tutorSessionAccessWatchProvider, (_, _) {});
    container.listen(activeProfileProvider, (_, _) {});
    container.listen(incomingTutorGrantsProvider, (_, _) {});
    await container.read(incomingTutorGrantsProvider.future);
    container
        .read(activeTutoredProfileSelectionProvider.notifier)
        .enter(_selection);
    await container.read(activeProfileProvider.future);
    await pumpEventQueue();
    return container;
  }

  group('DNI-512 AC-4 — one revoked-session outcome', () {
    test(
      'end(): name first, then selection cleared and roster re-read',
      () async {
        final container = await openSession();
        final readsBefore = rosterReads;

        container.read(tutorAccessEndedProvider.notifier).end(_grant);

        expect(container.read(activeTutoredProfileSelectionProvider), isNull);
        expect(
          container.read(tutorAccessEndedProvider),
          const TutorAccessEnded(grantId: _grant, learnerName: 'Yossi'),
        );
        await container.read(incomingTutorGrantsProvider.future);
        expect(
          rosterReads,
          readsBefore + 1,
          reason: 'the active-grant list is re-read',
        );
      },
    );

    test('a signal for a grant that is not the open one is ignored', () async {
      final container = await openSession();

      container.read(tutorAccessEndedProvider.notifier).end(_otherGrant);

      expect(container.read(activeTutoredProfileSelectionProvider), _selection);
      expect(container.read(tutorAccessEndedProvider), isNull);
    });

    test('the name falls back to the grant child name, then to none', () async {
      final container = await openSession(mirrorName: null);
      container.read(tutorAccessEndedProvider.notifier).end(_grant);
      expect(container.read(tutorAccessEndedProvider)?.learnerName, 'Yossi');

      serverGrants = [];
      final bare = await openSession(mirrorName: null);
      bare.invalidate(incomingTutorGrantsProvider);
      // The re-read drops Yossi's grant and ends the session itself.
      await bare.read(incomingTutorGrantsProvider.future);
      expect(bare.read(tutorAccessEndedProvider)?.learnerName, isNull);
    });

    for (final reason in [
      TutorScopeDenialReason.permissionDenied,
      TutorScopeDenialReason.grantNotActive,
      TutorScopeDenialReason.noGrant,
    ]) {
      test(
        'listener: learner scope denied (${reason.name}) ends the session',
        () async {
          final container = await openSession();

          container.read(_scopeValueProvider.notifier).set(_denied(reason));
          await pumpEventQueue();

          expect(container.read(activeTutoredProfileSelectionProvider), isNull);
          expect(container.read(tutorAccessEndedProvider)?.grantId, _grant);
        },
      );
    }

    test('listener: a signed-out verdict is not a revocation', () async {
      final container = await openSession();

      container
          .read(_scopeValueProvider.notifier)
          .set(_denied(TutorScopeDenialReason.notSignedIn));
      await pumpEventQueue();

      expect(container.read(activeTutoredProfileSelectionProvider), _selection);
      expect(container.read(tutorAccessEndedProvider), isNull);
    });

    test(
      'roster: an authoritative list without the open grant ends it',
      () async {
        final container = await openSession();
        serverGrants = [_activeGrant(_otherGrant, _otherProfile, 'Dovi')];

        container.invalidate(incomingTutorGrantsProvider);
        final roster = await container.read(incomingTutorGrantsProvider.future);

        expect(roster.map((g) => g.grantId), [
          _otherGrant,
        ], reason: 'only Yossi\'s row is gone');
        expect(container.read(activeTutoredProfileSelectionProvider), isNull);
        expect(
          container.read(tutorAccessEndedProvider),
          const TutorAccessEnded(grantId: _grant, learnerName: 'Yossi'),
        );
      },
    );

    test('a failed (offline) list read does not end the session', () async {
      final container = await openSession();
      when(
        () => listIncoming.callWithStatus(),
      ).thenAnswer((_) async => (grants: <TutorGrant>[], ok: false));

      container.invalidate(incomingTutorGrantsProvider);
      await container.read(incomingTutorGrantsProvider.future);

      expect(container.read(activeTutoredProfileSelectionProvider), _selection);
      expect(container.read(tutorAccessEndedProvider), isNull);
    });
  });

  group('DNI-512 AC-4 — a write callable rejected for revocation', () {
    TutorWriteService service(Exception error, List<String?> heard) =>
        TutorWriteService(
          invoker: (_, _) async => throw error,
          onAccessLost: heard.add,
        );

    Future<TutorWriteResult> write(TutorWriteService s) => s.editProfile(
      grantId: _grant,
      ownerUid: _owner,
      profileId: _profile,
      displayName: 'x',
    );

    for (final message in [
      'No active grant for this profile',
      'No grant for this profile',
      'Grant $_grant is not active (state=revoked_by_parent)',
    ]) {
      test(
        '"$message" is heard as access lost; the failure is unchanged',
        () async {
          final heard = <String?>[];
          final result = await write(
            service(
              FirebaseFunctionsException(
                code: 'permission-denied',
                message: message,
              ),
              heard,
            ),
          );
          expect(heard, [_grant]);
          expect(result, isA<TutorWriteFailure>());
          expect((result as TutorWriteFailure).code, 'permission-denied');
          expect(result, isNot(isA<TutorWriteEditingTurnedOff>()));
        },
      );
    }

    test(
      '"Grant lacks can_edit_learning" is editing turned off, not access lost',
      () async {
        final heard = <String?>[];
        final result = await write(
          service(
            FirebaseFunctionsException(
              code: 'permission-denied',
              message: 'Grant lacks can_edit_learning',
            ),
            heard,
          ),
        );
        expect(heard, isEmpty);
        expect(result, isA<TutorWriteEditingTurnedOff>());
      },
    );

    test('other failures (offline, invalid) are never access lost', () async {
      for (final code in ['unavailable', 'invalid-argument', 'not-found']) {
        final heard = <String?>[];
        await write(
          service(FirebaseFunctionsException(code: code, message: 'x'), heard),
        );
        expect(heard, isEmpty, reason: code);
      }
    });

    test(
      'the access-lost signal ends the open session through the boundary',
      () async {
        final container = await openSession();
        final s = TutorWriteService(
          invoker: (_, _) async => throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'No active grant for this profile',
          ),
          onAccessLost: (grantId) =>
              container.read(tutorAccessEndedProvider.notifier).end(grantId!),
        );

        await write(s);

        expect(container.read(activeTutoredProfileSelectionProvider), isNull);
        expect(container.read(tutorAccessEndedProvider)?.learnerName, 'Yossi');
      },
    );
  });

  group('DNI-512 AC-5 — reconnect re-resolves the active grants', () {
    test(
      'back online re-reads the list; a revoked grant then ends the session',
      () async {
        final container = await openSession();
        connectivity.add(false);
        await pumpEventQueue();
        final readsWhileOffline = rosterReads;
        // Revoked while the tutor was offline.
        serverGrants = [_activeGrant(_otherGrant, _otherProfile, 'Dovi')];

        connectivity.add(true);
        await pumpEventQueue();
        await container.read(incomingTutorGrantsProvider.future);
        await pumpEventQueue();

        expect(rosterReads, greaterThan(readsWhileOffline));
        expect(container.read(activeTutoredProfileSelectionProvider), isNull);
        expect(container.read(tutorAccessEndedProvider)?.grantId, _grant);
        expect(
          container
              .read(incomingTutorGrantsProvider)
              .value
              ?.map((g) => g.grantId),
          [_otherGrant],
          reason: 'other active learners remain',
        );
      },
    );

    /// The roster screen state: no tutored session, the list cached.
    Future<ProviderContainer> rosterOnly() async {
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      container.listen(tutorSessionAccessWatchProvider, (_, _) {});
      container.listen(incomingTutorGrantsProvider, (_, _) {});
      await container.read(incomingTutorGrantsProvider.future);
      return container;
    }

    test(
      'no session open: reconnect drops a row revoked while offline',
      () async {
        final container = await rosterOnly();
        connectivity.add(false);
        await pumpEventQueue();
        serverGrants = [_activeGrant(_otherGrant, _otherProfile, 'Dovi')];

        connectivity.add(true);
        await pumpEventQueue();
        final roster = await container.read(incomingTutorGrantsProvider.future);

        expect(roster.map((g) => g.grantId), [_otherGrant]);
        expect(
          container.read(tutorAccessEndedProvider),
          isNull,
          reason: 'no session to end',
        );
      },
    );

    test(
      'no session and no cached active row: reconnect costs no call',
      () async {
        serverGrants = [];
        final container = await rosterOnly();
        final reads = rosterReads;
        connectivity.add(false);
        await pumpEventQueue();
        connectivity.add(true);
        await pumpEventQueue();
        await container.read(incomingTutorGrantsProvider.future);

        expect(rosterReads, reads);
      },
    );

    test('back online with the grant still active keeps the session', () async {
      final container = await openSession();
      connectivity.add(false);
      await pumpEventQueue();
      connectivity.add(true);
      await pumpEventQueue();
      await container.read(incomingTutorGrantsProvider.future);

      expect(container.read(activeTutoredProfileSelectionProvider), _selection);
      expect(container.read(tutorAccessEndedProvider), isNull);
    });
  });

  group('DNI-512 AC-4 / T7 — the shell outcome in each surface', () {
    /// A learner-scoped surface: shows the open learner's data (from the
    /// tutored selection) and holds unsaved input.
    Widget surface(String label) => Consumer(
      builder: (context, ref, _) {
        final selection = ref.watch(activeTutoredProfileSelectionProvider);
        return Scaffold(
          appBar: AppBar(title: Text(label)),
          body: Column(
            children: [
              Text('learner:${selection?.profileId ?? 'none'}'),
              const TextField(key: Key('draft')),
            ],
          ),
        );
      },
    );

    Future<ProviderContainer> pumpShell(
      WidgetTester tester,
      String label,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final container = ProviderContainer(
        overrides: [
          ...overrides(),
          tutorRosterReturnProvider.overrideWithValue(
            (_) => navigatorKey.currentState!.pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('My talmidim')),
              ),
              (_) => false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(activeProfileProvider, (_, _) {});
      container
          .read(activeTutoredProfileSelectionProvider.notifier)
          .enter(_selection);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: TutorAccessEndedListener(child: surface('roster-root')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The surface is pushed above the shell, as the real forms are.
      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => surface(label)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('draft')).last,
        'unsaved 12 dapim',
      );
      expect(find.text('learner:$_profile'), findsWidgets);
      return container;
    }

    for (final label in ['sub-track form', 'ground picker', 'Learn tab']) {
      testWidgets('$label: copy shown, input discarded, back to the roster', (
        tester,
      ) async {
        final container = await pumpShell(tester, label);

        container
            .read(_scopeValueProvider.notifier)
            .set(_denied(TutorScopeDenialReason.permissionDenied));
        await tester.pumpAndSettle();

        expect(find.text('Access to Yossi has ended.'), findsOneWidget);
        expect(
          find.byKey(const Key('tutorAccessEndedSnackBar')),
          findsOneWidget,
        );
        expect(find.byType(SnackBarAction), findsNothing, reason: 'no retry');
        expect(find.text('My talmidim'), findsOneWidget);
        expect(find.text(label), findsNothing);
        expect(find.text('unsaved 12 dapim'), findsNothing);
        expect(
          find.textContaining(_profile),
          findsNothing,
          reason: 'no learner data stays',
        );
        expect(container.read(activeTutoredProfileSelectionProvider), isNull);
        expect(
          container.read(tutorAccessEndedProvider),
          isNull,
          reason: 'acknowledged',
        );
        expect(
          FocusManager.instance.primaryFocus?.context?.widget,
          isNot(isA<EditableText>()),
        );
      });
    }

    testWidgets('Hebrew copy names the learner', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('he'));
      expect(
        tutorAccessEndedMessage(
          l10n,
          const TutorAccessEnded(grantId: _grant, learnerName: 'יוסי'),
        ),
        contains('יוסי'),
      );
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        tutorAccessEndedMessage(en, const TutorAccessEnded(grantId: _grant)),
        'Access to this learner has ended.',
      );
    });
  });
}
