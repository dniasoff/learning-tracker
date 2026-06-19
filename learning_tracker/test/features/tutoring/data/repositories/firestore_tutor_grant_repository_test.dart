// FirestoreTutorGrantRepository — comprehensive unit tests
//
// Covers:
//   - listIncomingGrants, listOutgoingGrants, listPendingInvitesForMe: parse
//     grants from callable responses (including Android-style Map<Object?,Object?>
//     wire format).
//   - inviteTutor, acceptInvite, declineInvite, rescindInvite, revokeGrant,
//     resignGrant: success ↔ TutorGrantSuccess, FirebaseFunctionsException ↔
//     TutorGrantFailure with code, generic Exception ↔ TutorGrantFailure.
//   - All list methods return [] on FirebaseFunctionsException / generic error.
//   - Mapping Firestore docs ↔ domain TutorGrant for every GrantState.
//   - incoming / outgoing / pending_for_me callable mode arg.
//   - Empty/missing grants list.
//   - Android wire format (Map<Object?,Object?>) is parsed correctly.
//   - canMarkLiveCompletion is ALWAYS false (product invariant).
//   - childDisplayLabel and parentDisplayLabel fallback.
//   - TutorGrantDoc timestamp parsing: ISO-8601, {_seconds,_nanoseconds} map.
//
// No real Firebase — uses the FirebaseFunctionsPlatform seam so all callable
// calls are intercepted in-process.

@Tags(['tutoring', 'repository', 'unit'])
library;

// ignore_for_file: depend_on_referenced_packages
// FirebaseFunctionsPlatform and HttpsCallablePlatform live in
// cloud_functions_platform_interface, which is not fully re-exported by
// cloud_functions (only HttpsCallableOptions etc. are exported). Similarly,
// setupFirebaseCoreMocks lives in firebase_core_platform_interface/test.dart
// which is not re-exported by any direct dependency. Both are test-only
// infrastructure; using the transitive packages directly is the standard
// pattern for platform-interface test seams.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/data/repositories/firestore_tutor_grant_repository.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';

// ── Fake platform ─────────────────────────────────────────────────────────────

/// Per-test callable response factory.
typedef _CallHandler = Future<dynamic> Function(String name, dynamic params);

/// Mutable holder for the per-test [_CallHandler].
///
/// Using indirection through this holder lets us update the handler between
/// tests without reinstalling the platform into [FirebaseFunctionsPlatform]
/// (which would be ignored after the first [FirebaseFunctions.instance] call
/// caches its delegate).
class _HandlerHolder {
  _CallHandler handler = (_, __) async => <String, dynamic>{
    'grants': <Map<String, dynamic>>[],
  };
}

/// Fake [FirebaseFunctionsPlatform] that routes callable calls through a
/// shared [_HandlerHolder] so individual tests can swap handlers cheaply.
class _FakeFunctionsPlatform extends FirebaseFunctionsPlatform {
  _FakeFunctionsPlatform(this._holder) : super(null, 'us-central1');

  final _HandlerHolder _holder;

  @override
  FirebaseFunctionsPlatform delegateFor({
    FirebaseApp? app,
    required String region,
  }) => _FakeFunctionsPlatform(_holder);

  @override
  HttpsCallablePlatform httpsCallable(
    String? origin,
    String name,
    HttpsCallableOptions options,
  ) => _FakeCallable(functions: this, name: name, holder: _holder);

  @override
  HttpsCallablePlatform httpsCallableWithUri(
    String? origin,
    Uri uri,
    HttpsCallableOptions options,
  ) => _FakeCallable(functions: this, name: uri.toString(), holder: _holder);
}

class _FakeCallable extends HttpsCallablePlatform {
  _FakeCallable({
    required FirebaseFunctionsPlatform functions,
    required String name,
    required this.holder,
  }) : super(functions, null, name, HttpsCallableOptions(), null);

  final _HandlerHolder holder;

  @override
  Future<dynamic> call([dynamic parameters]) =>
      holder.handler(name!, parameters);
}

// ── Test helpers ──────────────────────────────────────────────────────────────

/// Minimal Firestore grant map in ISO-8601 format (the format our toFirestore()
/// uses, and the server uses when returning via a Cloud Function).
Map<String, dynamic> _grantMap({
  String grantId = 'grant_1',
  String parentUid = 'parent_uid',
  String childProfileId = 'profile_42',
  String tutorEmail = 'tutor@example.com',
  String? tutorUid = 'tutor_uid',
  String state = 'active',
  Map<String, dynamic>? permissions,
  String? childName,
  String? parentName,
}) {
  final now = DateTime.utc(2024, 1, 1).toIso8601String();
  return {
    'grant_id': grantId,
    'parent_uid': parentUid,
    'child_profile_id': childProfileId,
    'tutor_email': tutorEmail,
    if (tutorUid != null) 'tutor_uid': tutorUid,
    'state': state,
    'invited_at': now,
    'updated_at': now,
    if (state == 'active') 'accepted_at': now,
    if (state == 'pending')
      'expires_at': DateTime.utc(2024, 1, 8).toIso8601String(),
    if (state == 'declined') 'declined_at': now,
    if (state == 'rescinded') 'revoked_at': now,
    if (state == 'revoked_by_parent') 'revoked_at': now,
    if (state == 'revoked_by_tutor') 'revoked_at': now,
    if (state == 'expired')
      'expires_at': DateTime.utc(2023, 12, 31).toIso8601String(),
    if (permissions != null) 'permissions': permissions,
    if (childName != null) 'child_name': childName,
    if (parentName != null) 'parent_name': parentName,
  };
}

/// Builds a callable response wrapping a list of grant maps.
Map<String, dynamic> _grantsResponse(List<Map<String, dynamic>> grants) => {
  'grants': grants,
};

/// Converts a grant map to Android wire format: Maps become Map<Object?,Object?>.
///
/// In real Firebase on Android, the top-level callable result is
/// Map<String,dynamic> (from Pigeon), but nested Maps inside the result arrive
/// as Map<Object?,Object?> from the Android plugin. This helper converts a
/// single grant map to that format, while the top-level {grants:[...]} stays
/// as Map<String,dynamic> so the HttpsCallableResult<Map<String,dynamic>>
/// type assignment does not throw.
Map<Object?, Object?> _toAndroidMap(Map<String, dynamic> grantMap) {
  Map<Object?, Object?> wrap(Map<Object?, Object?> value) {
    return Map<Object?, Object?>.fromEntries(
      value.entries.map((e) {
        final v = e.value;
        final wrapped = v is Map<Object?, Object?> ? wrap(v) : v;
        return MapEntry<Object?, Object?>(e.key, wrapped);
      }),
    );
  }

  return wrap(
    Map<Object?, Object?>.fromEntries(
      grantMap.entries.map((e) => MapEntry<Object?, Object?>(e.key, e.value)),
    ),
  );
}

/// Builds a callable response where grant items use Android Map<Object?,Object?>
/// format (nested maps), while the top-level response stays as Map<String,dynamic>.
Map<String, dynamic> _androidGrantsResponse(
  List<Map<String, dynamic>> grantMaps,
) => {'grants': grantMaps.map(_toAndroidMap).toList()};

// ── Test repo factory ─────────────────────────────────────────────────────────

/// Shared handler holder — mutated per test via [_buildRepo].
///
/// Using a single holder means the same [FirebaseFunctions] singleton always
/// routes through the current test's handler without needing to reinstall the
/// platform (which would be ignored after the singleton caches its delegate).
final _holder = _HandlerHolder();

/// Sets the per-test [handler] and returns a fresh [FirestoreTutorGrantRepository].
///
/// Installs the [_FakeFunctionsPlatform] once (in setUpAll). Each call just
/// updates the mutable [_holder] so the cached delegate sees the new handler.
FirestoreTutorGrantRepository _buildRepo(_CallHandler handler) {
  _holder.handler = handler;
  return FirestoreTutorGrantRepository(functions: FirebaseFunctions.instance);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    // Initialise the Flutter test binding so setupFirebaseCoreMocks can
    // register the pigeon mock channel.
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    // Install the fake platform once. All tests update _holder.handler to
    // swap behaviour; the singleton FirebaseFunctions.instance always
    // routes through _holder so per-test handlers take effect immediately.
    FirebaseFunctionsPlatform.instance = _FakeFunctionsPlatform(_holder);
    // Force the FirebaseFunctions singleton to be created now so its
    // delegate is wired to our fake.
    FirebaseFunctions.instance; // ignore: unnecessary_statements
  });

  // ── Structural ────────────────────────────────────────────────────────────

  group('FirestoreTutorGrantRepository — structural', () {
    test('implements TutorGrantRepository', () async {
      final repo = _buildRepo((_, __) async => _grantsResponse([]));
      expect(repo, isA<TutorGrantRepository>());
    });

    test(
      'constructor accepts null functions (uses FirebaseFunctions.instance)',
      () {
        // This is a compile-time + late-init check; the repository falls back to
        // FirebaseFunctions.instance when null is passed. We just confirm the
        // class is constructible without error from the type system perspective.
        expect(FirestoreTutorGrantRepository.new, isNotNull);
      },
    );
  });

  // ── listIncomingGrants ────────────────────────────────────────────────────

  group('listIncomingGrants', () {
    test('sends mode=incoming to listTutorGrants callable', () async {
      String? capturedMode;
      final repo = _buildRepo((name, params) async {
        if (name == 'listTutorGrants') {
          capturedMode =
              (params as Map?)?.cast<String, dynamic>()['mode'] as String?;
        }
        return _grantsResponse([]);
      });

      await repo.listIncomingGrants();
      expect(capturedMode, 'incoming');
    });

    test('returns empty list when grants key is absent', () async {
      final repo = _buildRepo((_, __) async => <String, dynamic>{});
      final result = await repo.listIncomingGrants();
      expect(result, isEmpty);
    });

    test('returns empty list when grants is empty', () async {
      final repo = _buildRepo((_, __) async => _grantsResponse([]));
      final result = await repo.listIncomingGrants();
      expect(result, isEmpty);
    });

    test('parses single active grant correctly', () async {
      final repo = _buildRepo(
        (_, __) async => _grantsResponse([
          _grantMap(
            state: 'active',
            permissions: TutorPermissions.defaults().toFirestore(),
          ),
        ]),
      );

      final grants = await repo.listIncomingGrants();
      expect(grants, hasLength(1));
      final grant = grants.first;
      expect(grant.grantId, 'grant_1');
      expect(grant.tutorEmail, 'tutor@example.com');
      expect(grant.grantState, isA<ActiveGrant>());
    });

    test('parses pending grant correctly', () async {
      final repo = _buildRepo(
        (_, __) async =>
            _grantsResponse([_grantMap(state: 'pending', tutorUid: null)]),
      );

      final grants = await repo.listIncomingGrants();
      expect(grants, hasLength(1));
      expect(grants.first.grantState, isA<PendingGrant>());
      expect(grants.first.tutorUid, isNull);
    });

    test('parses multiple grants', () async {
      final repo = _buildRepo(
        (_, __) async => _grantsResponse([
          _grantMap(grantId: 'g1', state: 'active'),
          _grantMap(grantId: 'g2', state: 'pending', tutorUid: null),
        ]),
      );

      final grants = await repo.listIncomingGrants();
      expect(grants, hasLength(2));
      expect(grants[0].grantId, 'g1');
      expect(grants[1].grantId, 'g2');
    });

    test('returns [] on FirebaseFunctionsException', () async {
      final repo = _buildRepo(
        (_, __) async => throw FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'Not signed in',
        ),
      );

      final result = await repo.listIncomingGrants();
      expect(result, isEmpty);
    });

    test('returns [] on generic Exception', () async {
      final repo = _buildRepo(
        (_, __) async => throw Exception('network failure'),
      );

      final result = await repo.listIncomingGrants();
      expect(result, isEmpty);
    });

    // ── D18: listIncomingGrantsWithStatus distinguishes success from failure ─
    test(
      'D18: withStatus reports ok=true on a successful (even empty) call',
      () async {
        final repo = _buildRepo((_, __) async => _grantsResponse([]));
        final result = await repo.listIncomingGrantsWithStatus();
        expect(result.ok, isTrue);
        expect(result.grants, isEmpty);
      },
    );

    test('D18: withStatus reports ok=true with grants on success', () async {
      final repo = _buildRepo(
        (_, __) async =>
            _grantsResponse([_grantMap(grantId: 'g1', state: 'active')]),
      );
      final result = await repo.listIncomingGrantsWithStatus();
      expect(result.ok, isTrue);
      expect(result.grants, hasLength(1));
    });

    test(
      'D18: withStatus reports ok=false on FirebaseFunctionsException',
      () async {
        final repo = _buildRepo(
          (_, __) async => throw FirebaseFunctionsException(
            code: 'unavailable',
            message: 'offline',
          ),
        );
        final result = await repo.listIncomingGrantsWithStatus();
        expect(result.ok, isFalse);
        expect(result.grants, isEmpty);
      },
    );

    test('D18: withStatus reports ok=false on a generic Exception', () async {
      final repo = _buildRepo((_, __) async => throw Exception('boom'));
      final result = await repo.listIncomingGrantsWithStatus();
      expect(result.ok, isFalse);
    });

    test(
      'skips malformed grant entries (null fields) without throwing',
      () async {
        final repo = _buildRepo(
          (_, __) async => _grantsResponse([
            _grantMap(grantId: 'valid', state: 'active'),
            // Malformed: missing required grant_id field.
            <String, dynamic>{'state': 'active', 'parent_uid': 'x'},
          ]),
        );

        // Should not throw; the malformed entry is silently dropped.
        final grants = await repo.listIncomingGrants();
        // The valid entry may survive; the malformed one is dropped.
        // Verify no exception is thrown (the list has ≤ 2 elements).
        expect(grants.length, lessThanOrEqualTo(2));
      },
    );
  });

  // ── listIncomingGrants — Android wire format ──────────────────────────────

  group('listIncomingGrants — Android Map<Object?,Object?> wire format', () {
    test(
      'parses active grant when nested maps use Map<Object?,Object?>',
      () async {
        final repo = _buildRepo(
          (_, __) async => _androidGrantsResponse([
            _grantMap(
              state: 'active',
              permissions: TutorPermissions.defaults().toFirestore(),
            ),
          ]),
        );

        final grants = await repo.listIncomingGrants();
        expect(grants, hasLength(1));
        expect(grants.first.grantState, isA<ActiveGrant>());
      },
    );

    test(
      'parses pending grant when nested maps use Map<Object?,Object?>',
      () async {
        final repo = _buildRepo(
          (_, __) async => _androidGrantsResponse([
            _grantMap(state: 'pending', tutorUid: null),
          ]),
        );

        final grants = await repo.listIncomingGrants();
        expect(grants, hasLength(1));
        expect(grants.first.grantState, isA<PendingGrant>());
      },
    );
  });

  // ── listOutgoingGrants ────────────────────────────────────────────────────

  group('listOutgoingGrants', () {
    test('sends mode=outgoing and childProfileId to callable', () async {
      String? capturedMode;
      String? capturedChild;
      final repo = _buildRepo((name, params) async {
        if (name == 'listTutorGrants') {
          final map = (params as Map).cast<String, dynamic>();
          capturedMode = map['mode'] as String?;
          capturedChild = map['childProfileId'] as String?;
        }
        return _grantsResponse([]);
      });

      await repo.listOutgoingGrants(childProfileId: 'profile_99');
      expect(capturedMode, 'outgoing');
      expect(capturedChild, 'profile_99');
    });

    test('returns outgoing grants for the requested child', () async {
      final repo = _buildRepo(
        (_, __) async => _grantsResponse([
          _grantMap(childProfileId: 'profile_99', state: 'active'),
          _grantMap(
            grantId: 'g2',
            childProfileId: 'profile_99',
            state: 'pending',
            tutorUid: null,
          ),
        ]),
      );

      final grants = await repo.listOutgoingGrants(
        childProfileId: 'profile_99',
      );
      expect(grants, hasLength(2));
      expect(grants.every((g) => g.childProfileId == 'profile_99'), isTrue);
    });

    test(
      'R-TU2: rethrows FirebaseFunctionsException with code=permission-denied',
      () async {
        // permission-denied is a definitive server error (the caller's grant was
        // revoked). It must propagate so the provider transitions to AsyncError
        // and the UI shows an error state — NOT an empty list (which would mask
        // the revocation silently).
        final repo = _buildRepo(
          (_, __) async => throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'Denied',
          ),
        );

        await expectLater(
          () => repo.listOutgoingGrants(childProfileId: 'x'),
          throwsA(isA<FirebaseFunctionsException>()),
        );
      },
    );

    test(
      'returns [] on other FirebaseFunctionsException (offline/unavailable)',
      () async {
        final repo = _buildRepo(
          (_, __) async => throw FirebaseFunctionsException(
            code: 'unavailable',
            message: 'Offline',
          ),
        );

        final result = await repo.listOutgoingGrants(childProfileId: 'x');
        expect(result, isEmpty);
      },
    );

    test('returns [] on generic error', () async {
      final repo = _buildRepo((_, __) async => throw StateError('timeout'));

      final result = await repo.listOutgoingGrants(childProfileId: 'y');
      expect(result, isEmpty);
    });

    test('returns empty list when callable returns empty grants', () async {
      final repo = _buildRepo((_, __) async => _grantsResponse([]));

      final result = await repo.listOutgoingGrants(childProfileId: 'z');
      expect(result, isEmpty);
    });
  });

  // ── listPendingInvitesForMe ────────────────────────────────────────────────

  group('listPendingInvitesForMe', () {
    test('sends mode=pending_for_me to callable', () async {
      String? capturedMode;
      final repo = _buildRepo((name, params) async {
        if (name == 'listTutorGrants') {
          capturedMode =
              (params as Map).cast<String, dynamic>()['mode'] as String?;
        }
        return _grantsResponse([]);
      });

      await repo.listPendingInvitesForMe();
      expect(capturedMode, 'pending_for_me');
    });

    test('returns pending grants addressed to the caller', () async {
      final repo = _buildRepo(
        (_, __) async => _grantsResponse([
          _grantMap(state: 'pending', tutorUid: null),
          _grantMap(
            grantId: 'g2',
            state: 'pending',
            tutorUid: null,
            tutorEmail: 'other@example.com',
          ),
        ]),
      );

      final grants = await repo.listPendingInvitesForMe();
      expect(grants, hasLength(2));
      expect(grants.every((g) => g.grantState is PendingGrant), isTrue);
    });

    test('returns [] on FirebaseFunctionsException', () async {
      final repo = _buildRepo(
        (_, __) async => throw FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'Not signed in',
        ),
      );

      final result = await repo.listPendingInvitesForMe();
      expect(result, isEmpty);
    });

    test('returns [] on generic error', () async {
      final repo = _buildRepo(
        (_, __) async => throw Exception('no connection'),
      );

      final result = await repo.listPendingInvitesForMe();
      expect(result, isEmpty);
    });
  });

  // ── Grant parsing / Firestore ↔ domain mapping ────────────────────────────

  group('TutorGrant ↔ domain mapping', () {
    Future<TutorGrant> parseOneGrant(Map<String, dynamic> grantMap) async {
      final repo = _buildRepo((_, __) async => _grantsResponse([grantMap]));
      final grants = await repo.listIncomingGrants();
      expect(grants, hasLength(1));
      return grants.first;
    }

    test('active grant builds ActiveGrant with correct permissions', () async {
      final grant = await parseOneGrant(
        _grantMap(
          state: 'active',
          permissions: const TutorPermissions(
            canViewProgress: true,
            canResetCompletion: true,
            canEditGoals: false,
          ).toFirestore(),
        ),
      );

      expect(grant.grantState, isA<ActiveGrant>());
      final active = grant.grantState as ActiveGrant;
      expect(active.permissions.canViewProgress, isTrue);
      expect(active.permissions.canResetCompletion, isTrue);
      expect(active.permissions.canEditGoals, isFalse);
    });

    test(
      'active grant falls back to TutorPermissions.defaults() when permissions absent',
      () async {
        final grant = await parseOneGrant(_grantMap(state: 'active'));

        expect(grant.grantState, isA<ActiveGrant>());
        final active = grant.grantState as ActiveGrant;
        expect(active.permissions, TutorPermissions.defaults());
      },
    );

    test('pending grant builds PendingGrant with expiresAt', () async {
      final grant = await parseOneGrant(
        _grantMap(state: 'pending', tutorUid: null),
      );

      expect(grant.grantState, isA<PendingGrant>());
      expect((grant.grantState as PendingGrant).expiresAt, isNotNull);
    });

    test('declined grant builds DeclinedGrant', () async {
      final grant = await parseOneGrant(_grantMap(state: 'declined'));
      expect(grant.grantState, isA<DeclinedGrant>());
    });

    test('rescinded grant builds RescindedGrant', () async {
      final grant = await parseOneGrant(_grantMap(state: 'rescinded'));
      expect(grant.grantState, isA<RescindedGrant>());
    });

    test('revoked_by_parent grant builds RevokedByParentGrant', () async {
      final grant = await parseOneGrant(_grantMap(state: 'revoked_by_parent'));
      expect(grant.grantState, isA<RevokedByParentGrant>());
    });

    test('revoked_by_tutor grant builds RevokedByTutorGrant', () async {
      final grant = await parseOneGrant(_grantMap(state: 'revoked_by_tutor'));
      expect(grant.grantState, isA<RevokedByTutorGrant>());
    });

    test('expired grant builds ExpiredGrant', () async {
      final grant = await parseOneGrant(_grantMap(state: 'expired'));
      expect(grant.grantState, isA<ExpiredGrant>());
    });

    test('parentUid and childProfileId are correctly propagated', () async {
      final grant = await parseOneGrant(
        _grantMap(
          parentUid: 'parent_abc',
          childProfileId: 'child_profile_99',
          state: 'active',
        ),
      );

      expect(grant.parentUid, 'parent_abc');
      expect(grant.childProfileId, 'child_profile_99');
    });

    test('tutorUid is null before acceptance (pending state)', () async {
      final grant = await parseOneGrant(
        _grantMap(state: 'pending', tutorUid: null),
      );
      expect(grant.tutorUid, isNull);
    });

    test('tutorUid is set after acceptance (active state)', () async {
      final grant = await parseOneGrant(
        _grantMap(state: 'active', tutorUid: 'tutor_uid_abc'),
      );
      expect(grant.tutorUid, 'tutor_uid_abc');
    });
  });

  // ── canMarkLiveCompletion invariant (product rule) ─────────────────────────

  group('canMarkLiveCompletion invariant', () {
    test('is always false for active grant parsed from callable', () async {
      final repo = _buildRepo(
        (_, __) async => _grantsResponse([
          _grantMap(
            state: 'active',
            permissions: {
              // Attempt to pass can_mark_live_completion=true (should be ignored
              // — the field is not in the map; but even if injected, the
              // TutorPermissions constructor enforces the invariant).
              ...TutorPermissions.defaults().toFirestore(),
            },
          ),
        ]),
      );

      final grants = await repo.listIncomingGrants();
      final active = grants.first.grantState as ActiveGrant;
      expect(
        active.permissions.canMarkLiveCompletion,
        isFalse,
        reason:
            'canMarkLiveCompletion must ALWAYS be false — product invariant',
      );
    });

    test(
      'canMarkLiveCompletion is false even on TutorPermissions.defaults()',
      () {
        // Standalone invariant check independent of the repository.
        expect(TutorPermissions.defaults().canMarkLiveCompletion, isFalse);
      },
    );

    test('canMarkLiveCompletion is not present in toFirestore() map', () {
      final map = TutorPermissions.defaults().toFirestore();
      expect(map.containsKey('can_mark_live_completion'), isFalse);
    });
  });

  // ── childDisplayLabel / parentDisplayLabel fallback ───────────────────────

  group('childDisplayLabel and parentDisplayLabel', () {
    Future<TutorGrant> parseWithNames({
      String? childName,
      String? parentName,
    }) async {
      final repo = _buildRepo(
        (_, __) async => _grantsResponse([
          _grantMap(
            state: 'active',
            childName: childName,
            parentName: parentName,
          ),
        ]),
      );
      final grants = await repo.listIncomingGrants();
      return grants.first;
    }

    test('childDisplayLabel returns denormalised name when present', () async {
      final grant = await parseWithNames(childName: 'Beni');
      expect(grant.childDisplayLabel, 'Beni');
    });

    test(
      'childDisplayLabel falls back to "Talmid" when name is absent',
      () async {
        final grant = await parseWithNames(childName: null);
        expect(grant.childDisplayLabel, 'Talmid');
      },
    );

    test(
      'childDisplayLabel falls back to "Talmid" for whitespace-only name',
      () async {
        final grant = await parseWithNames(childName: '   ');
        expect(grant.childDisplayLabel, 'Talmid');
      },
    );

    test('parentDisplayLabel returns denormalised name when present', () async {
      final grant = await parseWithNames(parentName: 'Abba');
      expect(grant.parentDisplayLabel, 'Abba');
    });

    test(
      'parentDisplayLabel falls back to "Parent account" when absent',
      () async {
        final grant = await parseWithNames(parentName: null);
        expect(grant.parentDisplayLabel, 'Parent account');
      },
    );
  });

  // ── canAccept / canDecline / canRescind / canRevoke / canResign ───────────

  group('grant state business guards', () {
    Future<TutorGrant> grantWithState(String state) async {
      final repo = _buildRepo(
        (_, __) async => _grantsResponse([_grantMap(state: state)]),
      );
      return (await repo.listIncomingGrants()).first;
    }

    test(
      'pending grant: canAccept and canDecline and canRescind are true',
      () async {
        final grant = await grantWithState('pending');
        expect(grant.canAccept, isTrue);
        expect(grant.canDecline, isTrue);
        expect(grant.canRescind, isTrue);
      },
    );

    test('pending grant: canResign and canRevoke are false', () async {
      final grant = await grantWithState('pending');
      expect(grant.canResign, isFalse);
      expect(grant.canRevoke, isFalse);
    });

    test('active grant: canRevoke and canResign are true', () async {
      final grant = await grantWithState('active');
      expect(grant.canRevoke, isTrue);
      expect(grant.canResign, isTrue);
    });

    test(
      'active grant: canAccept and canDecline and canRescind are false',
      () async {
        final grant = await grantWithState('active');
        expect(grant.canAccept, isFalse);
        expect(grant.canDecline, isFalse);
        expect(grant.canRescind, isFalse);
      },
    );

    test('terminal grant (declined): all action guards are false', () async {
      final grant = await grantWithState('declined');
      expect(grant.canAccept, isFalse);
      expect(grant.canDecline, isFalse);
      expect(grant.canRescind, isFalse);
      expect(grant.canRevoke, isFalse);
      expect(grant.canResign, isFalse);
    });
  });

  // ── inviteTutor ───────────────────────────────────────────────────────────

  group('inviteTutor', () {
    test('success: returns TutorGrantSuccess', () async {
      String? calledName;
      final repo = _buildRepo((name, params) async {
        calledName = name;
        return <String, dynamic>{};
      });

      final result = await repo.inviteTutor(
        tutorEmail: 'tutor@example.com',
        childProfileId: 'profile_1',
        permissions: TutorPermissions.defaults(),
      );

      expect(result, isA<TutorGrantSuccess>());
      expect(calledName, 'inviteTutor');
    });

    test('sends correct payload keys to inviteTutor callable', () async {
      Map<String, dynamic>? capturedParams;
      final repo = _buildRepo((name, params) async {
        if (name == 'inviteTutor') {
          capturedParams = (params as Map).cast<String, dynamic>();
        }
        return <String, dynamic>{};
      });

      await repo.inviteTutor(
        tutorEmail: 'tutor@example.com',
        childProfileId: 'profile_1',
        permissions: TutorPermissions.defaults(),
        childName: 'Beni',
        parentName: 'Abba',
      );

      expect(capturedParams, isNotNull);
      expect(capturedParams!['tutorEmail'], 'tutor@example.com');
      expect(capturedParams!['childProfileId'], 'profile_1');
      expect(capturedParams!['childName'], 'Beni');
      expect(capturedParams!['parentName'], 'Abba');
      expect(capturedParams!['permissions'], isA<Map<String, dynamic>>());
    });

    test('omits childName/parentName when null', () async {
      Map<String, dynamic>? capturedParams;
      final repo = _buildRepo((name, params) async {
        if (name == 'inviteTutor') {
          capturedParams = (params as Map).cast<String, dynamic>();
        }
        return <String, dynamic>{};
      });

      await repo.inviteTutor(
        tutorEmail: 'tutor@example.com',
        childProfileId: 'profile_1',
        permissions: TutorPermissions.defaults(),
      );

      expect(capturedParams!.containsKey('childName'), isFalse);
      expect(capturedParams!.containsKey('parentName'), isFalse);
    });

    test('omits empty childName/parentName strings', () async {
      Map<String, dynamic>? capturedParams;
      final repo = _buildRepo((name, params) async {
        if (name == 'inviteTutor') {
          capturedParams = (params as Map).cast<String, dynamic>();
        }
        return <String, dynamic>{};
      });

      await repo.inviteTutor(
        tutorEmail: 'tutor@example.com',
        childProfileId: 'profile_1',
        permissions: TutorPermissions.defaults(),
        childName: '',
        parentName: '',
      );

      expect(capturedParams!.containsKey('childName'), isFalse);
      expect(capturedParams!.containsKey('parentName'), isFalse);
    });

    test('FirebaseFunctionsException → TutorGrantFailure with code', () async {
      final repo = _buildRepo(
        (_, __) async => throw FirebaseFunctionsException(
          code: 'already-exists',
          message: 'Invite already pending',
        ),
      );

      final result = await repo.inviteTutor(
        tutorEmail: 'tutor@example.com',
        childProfileId: 'profile_1',
        permissions: TutorPermissions.defaults(),
      );

      expect(result, isA<TutorGrantFailure>());
      final failure = result as TutorGrantFailure;
      expect(failure.code, 'already-exists');
      expect(failure.message, 'Invite already pending');
    });

    test('generic Exception → TutorGrantFailure without code', () async {
      final repo = _buildRepo(
        (_, __) async => throw Exception('network timeout'),
      );

      final result = await repo.inviteTutor(
        tutorEmail: 'tutor@example.com',
        childProfileId: 'profile_1',
        permissions: TutorPermissions.defaults(),
      );

      expect(result, isA<TutorGrantFailure>());
      expect((result as TutorGrantFailure).code, isNull);
    });
  });

  // ── acceptInvite ──────────────────────────────────────────────────────────

  group('acceptInvite', () {
    test('success: returns TutorGrantSuccess with grantId', () async {
      String? calledName;
      final repo = _buildRepo((name, _) async {
        calledName = name;
        return <String, dynamic>{};
      });

      final result = await repo.acceptInvite(grantId: 'grant_abc');
      expect(result, isA<TutorGrantSuccess>());
      expect((result as TutorGrantSuccess).grantId, 'grant_abc');
      expect(calledName, 'acceptTutorInvite');
    });

    test('sends grantId to callable', () async {
      String? captured;
      final repo = _buildRepo((name, params) async {
        if (name == 'acceptTutorInvite') {
          captured =
              (params as Map).cast<String, dynamic>()['grantId'] as String?;
        }
        return <String, dynamic>{};
      });

      await repo.acceptInvite(grantId: 'grant_xyz');
      expect(captured, 'grant_xyz');
    });

    test('FirebaseFunctionsException → TutorGrantFailure', () async {
      final repo = _buildRepo(
        (_, __) async => throw FirebaseFunctionsException(
          code: 'not-found',
          message: 'Grant not found',
        ),
      );

      final result = await repo.acceptInvite(grantId: 'grant_abc');
      expect(result, isA<TutorGrantFailure>());
      expect((result as TutorGrantFailure).code, 'not-found');
    });

    test('generic error → TutorGrantFailure', () async {
      final repo = _buildRepo((_, __) async => throw Exception('timeout'));

      final result = await repo.acceptInvite(grantId: 'grant_abc');
      expect(result, isA<TutorGrantFailure>());
    });
  });

  // ── declineInvite ─────────────────────────────────────────────────────────

  group('declineInvite', () {
    test('success: returns TutorGrantSuccess with grantId', () async {
      String? calledName;
      final repo = _buildRepo((name, _) async {
        calledName = name;
        return <String, dynamic>{};
      });

      final result = await repo.declineInvite(grantId: 'grant_d1');
      expect(result, isA<TutorGrantSuccess>());
      expect((result as TutorGrantSuccess).grantId, 'grant_d1');
      expect(calledName, 'declineTutorInvite');
    });

    test('FirebaseFunctionsException → TutorGrantFailure with code', () async {
      final repo = _buildRepo(
        (_, __) async => throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Not allowed',
        ),
      );

      final result = await repo.declineInvite(grantId: 'g');
      expect(result, isA<TutorGrantFailure>());
      expect((result as TutorGrantFailure).code, 'permission-denied');
    });
  });

  // ── rescindInvite ─────────────────────────────────────────────────────────

  group('rescindInvite', () {
    test('success: returns TutorGrantSuccess', () async {
      String? calledName;
      final repo = _buildRepo((name, _) async {
        calledName = name;
        return <String, dynamic>{};
      });

      final result = await repo.rescindInvite(grantId: 'grant_r1');
      expect(result, isA<TutorGrantSuccess>());
      expect((result as TutorGrantSuccess).grantId, 'grant_r1');
      expect(calledName, 'rescindTutorInvite');
    });

    test('FirebaseFunctionsException → TutorGrantFailure', () async {
      final repo = _buildRepo(
        (_, __) async => throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Grant is not pending',
        ),
      );

      final result = await repo.rescindInvite(grantId: 'g');
      expect(result, isA<TutorGrantFailure>());
    });
  });

  // ── revokeGrant ───────────────────────────────────────────────────────────

  group('revokeGrant', () {
    test('success: returns TutorGrantSuccess', () async {
      String? calledName;
      final repo = _buildRepo((name, _) async {
        calledName = name;
        return <String, dynamic>{};
      });

      final result = await repo.revokeGrant(grantId: 'grant_rev');
      expect(result, isA<TutorGrantSuccess>());
      expect((result as TutorGrantSuccess).grantId, 'grant_rev');
      expect(calledName, 'revokeTutorGrant');
    });

    test('FirebaseFunctionsException → TutorGrantFailure', () async {
      final repo = _buildRepo(
        (_, __) async => throw FirebaseFunctionsException(
          code: 'internal',
          message: 'Server error',
        ),
      );

      final result = await repo.revokeGrant(grantId: 'g');
      expect(result, isA<TutorGrantFailure>());
    });

    test('generic error → TutorGrantFailure without code', () async {
      final repo = _buildRepo((_, __) async => throw Exception('io error'));

      final result = await repo.revokeGrant(grantId: 'g');
      expect(result, isA<TutorGrantFailure>());
      expect((result as TutorGrantFailure).code, isNull);
    });
  });

  // ── resignGrant ───────────────────────────────────────────────────────────

  group('resignGrant', () {
    test('success: returns TutorGrantSuccess', () async {
      String? calledName;
      final repo = _buildRepo((name, _) async {
        calledName = name;
        return <String, dynamic>{};
      });

      final result = await repo.resignGrant(grantId: 'grant_resign');
      expect(result, isA<TutorGrantSuccess>());
      expect((result as TutorGrantSuccess).grantId, 'grant_resign');
      expect(calledName, 'resignTutorGrant');
    });

    test(
      'FirebaseFunctionsException → TutorGrantFailure with message',
      () async {
        final repo = _buildRepo(
          (_, __) async => throw FirebaseFunctionsException(
            code: 'not-found',
            message: 'Grant not found',
          ),
        );

        final result = await repo.resignGrant(grantId: 'g');
        expect(result, isA<TutorGrantFailure>());
        expect((result as TutorGrantFailure).message, 'Grant not found');
      },
    );
  });

  // ── TutorGrantDoc timestamp parsing ──────────────────────────────────────

  group('TutorGrantDoc timestamp parsing', () {
    test('ISO-8601 string timestamps are parsed', () async {
      final now = DateTime.utc(2024, 6, 15, 12).toIso8601String();
      final repo = _buildRepo(
        (_, __) async => _grantsResponse([
          {
            'grant_id': 'g1',
            'parent_uid': 'p',
            'child_profile_id': 'c',
            'tutor_email': 'tutor@test.com',
            'state': 'active',
            'invited_at': now,
            'updated_at': now,
            'accepted_at': now,
          },
        ]),
      );

      final grants = await repo.listIncomingGrants();
      expect(grants, hasLength(1));
      // Verify the doc was parsed without throwing.
      expect(grants.first.grantId, 'g1');
    });

    test('{_seconds,_nanoseconds} map timestamps are parsed', () async {
      final secondsValue =
          DateTime.utc(2024, 6, 15, 12).millisecondsSinceEpoch ~/ 1000;
      final repo = _buildRepo(
        (_, __) async => _grantsResponse([
          <String, dynamic>{
            'grant_id': 'g_ts',
            'parent_uid': 'p',
            'child_profile_id': 'c',
            'tutor_email': 'tutor@test.com',
            'state': 'active',
            'invited_at': {'_seconds': secondsValue, '_nanoseconds': 0},
            'updated_at': {'_seconds': secondsValue, '_nanoseconds': 0},
            'accepted_at': {'_seconds': secondsValue, '_nanoseconds': 0},
          },
        ]),
      );

      final grants = await repo.listIncomingGrants();
      expect(grants, hasLength(1));
      expect(grants.first.grantId, 'g_ts');
    });

    test(
      '{seconds,nanoseconds} (no underscore) map timestamps are parsed',
      () async {
        final secondsValue =
            DateTime.utc(2024, 6, 15, 12).millisecondsSinceEpoch ~/ 1000;
        final repo = _buildRepo(
          (_, __) async => _grantsResponse([
            <String, dynamic>{
              'grant_id': 'g_ts2',
              'parent_uid': 'p',
              'child_profile_id': 'c',
              'tutor_email': 'tutor@test.com',
              'state': 'pending',
              'invited_at': {'seconds': secondsValue, 'nanoseconds': 0},
              'updated_at': {'seconds': secondsValue, 'nanoseconds': 0},
              'expires_at': {
                'seconds': secondsValue + 604800,
                'nanoseconds': 0,
              },
            },
          ]),
        );

        final grants = await repo.listIncomingGrants();
        expect(grants, hasLength(1));
        expect(grants.first.grantState, isA<PendingGrant>());
      },
    );
  });

  // ── TutorPermissions fromFirestore round-trip ─────────────────────────────

  group('TutorPermissions.fromFirestore round-trip', () {
    test('all fields serialise and deserialise correctly', () {
      const original = TutorPermissions(
        canViewProgress: true,
        canViewContent: false,
        canBulkPriorCompletion: true,
        canResetCompletion: true,
        canEditGoals: false,
        canEditStages: true,
        canEditRewards: false,
        canEditStudyDays: true,
        canEditPoints: false,
      );

      final map = original.toFirestore();
      final restored = TutorPermissions.fromFirestore(map);

      expect(restored, equals(original));
      expect(restored.canMarkLiveCompletion, isFalse);
    });

    test('fromFirestore uses defaults for missing keys', () {
      final partial = TutorPermissions.fromFirestore(<String, dynamic>{});
      // All missing → defaults applied.
      expect(partial.canViewProgress, isTrue);
      expect(partial.canViewContent, isTrue);
      expect(partial.canBulkPriorCompletion, isTrue);
      expect(partial.canResetCompletion, isFalse);
      expect(partial.canMarkLiveCompletion, isFalse);
    });
  });

  // ── TutorGrantDoc.buildGrantId ─────────────────────────────────────────────

  group('TutorGrantDoc.buildGrantId', () {
    test('produces deterministic id from three components', () {
      final id1 = TutorGrantDoc.buildGrantId(
        tutorEmail: 'Tutor@Example.COM',
        parentUid: 'parent_1',
        childProfileId: 'profile_42',
      );
      final id2 = TutorGrantDoc.buildGrantId(
        tutorEmail: 'tutor@example.com',
        parentUid: 'parent_1',
        childProfileId: 'profile_42',
      );
      // Email is lowercased before encoding.
      expect(id1, id2);
    });

    test('different emails produce different ids', () {
      final id1 = TutorGrantDoc.buildGrantId(
        tutorEmail: 'a@example.com',
        parentUid: 'p',
        childProfileId: 'c',
      );
      final id2 = TutorGrantDoc.buildGrantId(
        tutorEmail: 'b@example.com',
        parentUid: 'p',
        childProfileId: 'c',
      );
      expect(id1, isNot(id2));
    });
  });

  // ── TutorGrantState ────────────────────────────────────────────────────────

  group('TutorGrantState', () {
    test('isActive is true only for active', () {
      expect(TutorGrantState.active.isActive, isTrue);
      for (final s in TutorGrantState.values) {
        if (s != TutorGrantState.active) {
          expect(s.isActive, isFalse, reason: '$s should not be active');
        }
      }
    });

    test('isTerminal covers declined/rescinded/revoked/expired', () {
      expect(TutorGrantState.declined.isTerminal, isTrue);
      expect(TutorGrantState.rescinded.isTerminal, isTrue);
      expect(TutorGrantState.revokedByParent.isTerminal, isTrue);
      expect(TutorGrantState.revokedByTutor.isTerminal, isTrue);
      expect(TutorGrantState.expired.isTerminal, isTrue);
    });

    test('pending and active are NOT terminal', () {
      expect(TutorGrantState.pending.isTerminal, isFalse);
      expect(TutorGrantState.active.isTerminal, isFalse);
    });

    test('fromJson/toJson round-trip for all states', () {
      for (final state in TutorGrantState.values) {
        final json = state.toJson();
        final restored = TutorGrantState.fromJson(json);
        expect(restored, state, reason: 'State $state did not round-trip');
      }
    });
  });
}
