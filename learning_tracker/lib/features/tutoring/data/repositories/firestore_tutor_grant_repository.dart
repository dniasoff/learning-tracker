// FirestoreTutorGrantRepository — V2-R3 C3
//
// Real implementation of [TutorGrantRepository] backed by Cloud Functions
// callables. All grant state mutations are server-side (Admin SDK) via
// these callables; reads are performed directly from Firestore where the
// Firestore rules (V2-R3 C2) grant access.
//
// Layering: Cloud Functions are called via `package:cloud_functions` which
// is permitted in features/ (following the pattern of AccountManagementService).

import 'package:cloud_functions/cloud_functions.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';

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
  }) async {
    try {
      final callable = _functions.httpsCallable('inviteTutor');
      await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'tutorEmail': tutorEmail,
        'childProfileId': childProfileId,
        'permissions': permissions.toFirestore(),
      });
      return const TutorGrantSuccess();
    } on FirebaseFunctionsException catch (e) {
      return TutorGrantFailure(
        message: e.message ?? 'Failed to send invite',
        code: e.code,
      );
    } catch (e) {
      return TutorGrantFailure(message: e.toString());
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
    } catch (e) {
      return TutorGrantFailure(message: e.toString());
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
    } catch (e) {
      return TutorGrantFailure(message: e.toString());
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
    } catch (e) {
      return TutorGrantFailure(message: e.toString());
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
    } catch (e) {
      return TutorGrantFailure(message: e.toString());
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
    } catch (e) {
      return TutorGrantFailure(message: e.toString());
    }
  }

  // ── List operations ──────────────────────────────────────────────────────────

  @override
  Future<List<TutorGrant>> listIncomingGrants() async {
    try {
      final callable = _functions.httpsCallable('listTutorGrants');
      final result = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{'mode': 'incoming'},
      );
      // ignore: avoid_dynamic_calls
      final data = result.data;
      final grantsRaw =
          (data as Map<String, dynamic>?)?['grants'] as List<dynamic>? ??
          const [];
      return grantsRaw
          .map((e) => _parseGrant(e as Map<String, dynamic>))
          .whereType<TutorGrant>()
          .toList();
    } on FirebaseFunctionsException {
      return const [];
    } catch (_) {
      return const [];
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
      final grantsRaw =
          (data as Map<String, dynamic>?)?['grants'] as List<dynamic>? ??
          const [];
      return grantsRaw
          .map((e) => _parseGrant(e as Map<String, dynamic>))
          .whereType<TutorGrant>()
          .toList();
    } on FirebaseFunctionsException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

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
