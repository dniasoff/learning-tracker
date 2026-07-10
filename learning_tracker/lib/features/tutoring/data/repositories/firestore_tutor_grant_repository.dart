// FirestoreTutorGrantRepository — V2-R3 C3
//
// Real implementation of [TutorGrantRepository] backed by Cloud Functions
// callables. All grant state mutations are server-side (Admin SDK) via
// these callables; reads are performed directly from Firestore where the
// Firestore rules (V2-R3 C2) grant access.
//
// Layering: Cloud Functions are called via `package:cloud_functions` which
// is permitted in features/ (following the pattern of AccountManagementService).
//
// AUD-tutoring-10: imports [TutorGrantRepository]/[TutorGrantResult] from
// domain/repositories/ directly rather than via domain/use_cases/ — this
// data-layer implementation only needs the repository contract, not the
// use-case classes.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/repositories/tutor_grant_repository.dart';

/// Cloud-Functions-backed implementation of [TutorGrantRepository].
///
/// All mutations dispatch to callable Cloud Functions (Admin SDK writes).
/// List operations use the `listTutorGrants` callable which reads from
/// Firestore server-side and returns denormalised grant docs.
class FirestoreTutorGrantRepository implements TutorGrantRepository {
  FirestoreTutorGrantRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  // ── Mutations ────────────────────────────────────────────────────────────────

  @override
  Future<TutorGrantResult> inviteTutor({
    required String tutorEmail,
    required String childProfileId,
    required TutorPermissions permissions,
    String? childName,
    String? parentName,
  }) async {
    try {
      final callable = _functions.httpsCallable('inviteTutor');
      await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'tutorEmail': tutorEmail,
        'childProfileId': childProfileId,
        'permissions': permissions.toFirestore(),
        if (childName != null && childName.isNotEmpty) 'childName': childName,
        if (parentName != null && parentName.isNotEmpty)
          'parentName': parentName,
      });
      return const TutorGrantSuccess();
    } on FirebaseFunctionsException catch (e) {
      return TutorGrantFailure(
        message: e.message ?? 'Failed to send invite',
        code: e.code,
      );
    } catch (e, st) {
      return _unexpectedFailure('inviteTutor', e, st);
    }
  }

  @override
  Future<TutorGrantResult> acceptInvite({required String grantId}) async {
    try {
      final callable = _functions.httpsCallable('acceptTutorInvite');
      await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'grantId': grantId,
      });
      return TutorGrantSuccess(grantId: grantId);
    } on FirebaseFunctionsException catch (e) {
      return TutorGrantFailure(
        message: e.message ?? 'Failed to accept invite',
        code: e.code,
      );
    } catch (e, st) {
      return _unexpectedFailure('acceptInvite', e, st);
    }
  }

  @override
  Future<TutorGrantResult> declineInvite({required String grantId}) async {
    try {
      final callable = _functions.httpsCallable('declineTutorInvite');
      await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'grantId': grantId,
      });
      return TutorGrantSuccess(grantId: grantId);
    } on FirebaseFunctionsException catch (e) {
      return TutorGrantFailure(
        message: e.message ?? 'Failed to decline invite',
        code: e.code,
      );
    } catch (e, st) {
      return _unexpectedFailure('declineInvite', e, st);
    }
  }

  @override
  Future<TutorGrantResult> rescindInvite({required String grantId}) async {
    try {
      final callable = _functions.httpsCallable('rescindTutorInvite');
      await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'grantId': grantId,
      });
      return TutorGrantSuccess(grantId: grantId);
    } on FirebaseFunctionsException catch (e) {
      return TutorGrantFailure(
        message: e.message ?? 'Failed to rescind invite',
        code: e.code,
      );
    } catch (e, st) {
      return _unexpectedFailure('rescindInvite', e, st);
    }
  }

  @override
  Future<TutorGrantResult> revokeGrant({required String grantId}) async {
    try {
      final callable = _functions.httpsCallable('revokeTutorGrant');
      await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'grantId': grantId,
      });
      return TutorGrantSuccess(grantId: grantId);
    } on FirebaseFunctionsException catch (e) {
      return TutorGrantFailure(
        message: e.message ?? 'Failed to revoke grant',
        code: e.code,
      );
    } catch (e, st) {
      return _unexpectedFailure('revokeGrant', e, st);
    }
  }

  @override
  Future<TutorGrantResult> resignGrant({required String grantId}) async {
    try {
      final callable = _functions.httpsCallable('resignTutorGrant');
      await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'grantId': grantId,
      });
      return TutorGrantSuccess(grantId: grantId);
    } on FirebaseFunctionsException catch (e) {
      return TutorGrantFailure(
        message: e.message ?? 'Failed to resign grant',
        code: e.code,
      );
    } catch (e, st) {
      return _unexpectedFailure('resignGrant', e, st);
    }
  }

  /// AUD-tutoring-11: a non-[FirebaseFunctionsException] error (client
  /// plugin/network failure) — log the real exception for diagnostics but
  /// never stash its raw text in the value the UI eventually reads (EH-5).
  /// [FirebaseFunctionsException] already carries a structured code/message
  /// (see the `on FirebaseFunctionsException catch` branches above) — this
  /// covers only the genuinely-unexpected fallback.
  TutorGrantFailure _unexpectedFailure(
    String operation,
    Object e,
    StackTrace st,
  ) {
    AppLogger.instance.error(
      event: 'FirestoreTutorGrantRepository.$operation unexpected error',
      exception: e,
      stackTrace: st,
    );
    return const TutorGrantFailure(
      message: 'An unexpected error occurred.',
      code: 'unknown-error',
    );
  }

  // ── List operations ──────────────────────────────────────────────────────────

  @override
  Future<List<TutorGrant>> listIncomingGrants() async =>
      (await listIncomingGrantsWithStatus()).grants;

  @override
  Future<({List<TutorGrant> grants, bool ok})>
  listIncomingGrantsWithStatus() async {
    try {
      final callable = _functions.httpsCallable('listTutorGrants');
      final result = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{'mode': 'incoming'},
      );
      // ignore: avoid_dynamic_calls
      final data = result.data;
      // D18: a successful call is authoritative even when it returns zero
      // grants (every prior grant was revoked).
      return (grants: _grantsFromCallableData(data), ok: true);
    } on FirebaseFunctionsException {
      // Offline / transient / permission-denied — NOT authoritative. Keep the
      // local mirror so a cached talmid is not hidden by a transient failure.
      return (grants: const <TutorGrant>[], ok: false);
    } catch (_) {
      return (grants: const <TutorGrant>[], ok: false);
    }
  }

  @override
  Future<List<TutorGrant>> listOutgoingGrants({
    required String childProfileId,
  }) async {
    try {
      final callable = _functions.httpsCallable('listTutorGrants');
      final result = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{'mode': 'outgoing', 'childProfileId': childProfileId},
      );
      // ignore: avoid_dynamic_calls
      final data = result.data;
      return _grantsFromCallableData(data);
    } on FirebaseFunctionsException catch (e) {
      // permission-denied is a definitive server error (not an offline/transient
      // failure), so let it propagate so the UI can surface an error state instead
      // of silently showing an empty list — which would mask a revoked grant.
      if (e.code == 'permission-denied') rethrow;
      // For other Firebase errors (offline, unavailable, etc.) return empty so
      // the screen degrades gracefully when the server is temporarily unreachable.
      return const [];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<TutorGrant>> listPendingInvitesForMe() async {
    try {
      final callable = _functions.httpsCallable('listTutorGrants');
      final result = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{'mode': 'pending_for_me'},
      );
      // ignore: avoid_dynamic_calls
      return _grantsFromCallableData(result.data);
    } on FirebaseFunctionsException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Extracts and parses the grants list from a callable's response.
  ///
  /// On Android the cloud_functions plugin decodes nested objects as
  /// `Map<Object?, Object?>` / `List<Object?>`, so a direct
  /// `e as Map<String, dynamic>` throws and (being swallowed by the caller's
  /// catch) silently drops every grant. We convert defensively instead.
  List<TutorGrant> _grantsFromCallableData(dynamic data) {
    final raw = data is Map ? data['grants'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map((e) => _parseGrant(Map<String, dynamic>.from(e)))
        .whereType<TutorGrant>()
        .toList();
  }

  TutorGrant? _parseGrant(Map<String, dynamic> data) {
    try {
      final doc = TutorGrantDoc.fromFirestore(data);
      TutorPermissions? permissions;
      if (data['permissions'] is Map) {
        permissions = TutorPermissions.fromFirestore(
          Map<String, dynamic>.from(data['permissions'] as Map),
        );
      }
      return TutorGrant.fromDoc(doc, permissions: permissions);
    } catch (_) {
      return null;
    }
  }
}
