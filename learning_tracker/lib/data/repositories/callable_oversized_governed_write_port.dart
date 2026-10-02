/// The online [OversizedGovernedWritePort]: the `ownerOversizedGovernedWrite`
/// callable (DNI-472, `functions/src/owner_oversized_governed_write.ts`),
/// which wraps `writeWithChangeLog` (Admin SDK, no Rules access budget).
///
/// DNI-470 (1.8) owns this adapter; the callable's contract is verified by
/// Story 1.10's emulator tests, not by this client.
///
/// Wire shape (`decodeGovernedActionWire`):
/// `{profileId, actorRole, actionId, revertsActionId?, entries: [{id,
/// entity, entityId, docs: [{collection, docId, fields, mode}]}]}`. Field
/// values are AD-52 storage form; a tombstone `ended_at` (any instant) is
/// sent as `true` ("tombstone now", stamped by the server) and a cleared
/// one as `null`. `ownerUid` is never sent: the callable is owner-only and
/// writes under the caller's own uid.
///
/// Errors: `unavailable` (no connection, nothing sent) becomes
/// [OnlineRequiredException]. Only the callable's terminal contract errors
/// ([terminalCodes]: the `writeWithChangeLog` rejections for auth, grant,
/// payload, precondition and idempotency-alias failures) become a
/// [PermanentWriteRejection] carrying the code. Every other code, such as
/// `deadline-exceeded`, `internal`, `aborted`, `unknown`, `cancelled` or
/// `resource-exhausted`, leaves the outcome unknown (the server may have
/// committed), so it becomes [GovernedWriteOutcomeUnknown]. The callable is
/// idempotent on the client `actionId`, so re-sending the identical request
/// is safe.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart';

/// The callable's name.
const kOwnerOversizedGovernedWrite = 'ownerOversizedGovernedWrite';

/// Sends one callable request and returns its result map.
typedef GovernedCallableInvoker =
    Future<Map<String, Object?>> Function(Map<String, Object?> payload);

/// [OversizedGovernedWritePort] over the `ownerOversizedGovernedWrite`
/// callable of the active account's Functions handle.
final class CallableOversizedGovernedWritePort
    implements OversizedGovernedWritePort {
  /// Creates the port over the Functions handle [functions] returns,
  /// resolved on the first write (so building the port needs no platform
  /// channel).
  CallableOversizedGovernedWritePort(FirebaseFunctions Function() functions)
    : _invoke = ((payload) async {
        final result = await functions()
            .httpsCallable(kOwnerOversizedGovernedWrite)
            .call<Map<String, dynamic>>(payload);
        return Map<String, Object?>.from(result.data);
      });

  /// Creates the port over a raw [invoke] (tests).
  CallableOversizedGovernedWritePort.withInvoker(GovernedCallableInvoker invoke)
    : _invoke = invoke;

  final GovernedCallableInvoker _invoke;

  /// Callable codes meaning "no connection, nothing sent": the write is
  /// online-only.
  static const offlineCodes = {'unavailable'};

  /// The callable's terminal contract errors: re-sending the same request
  /// fails the same way.
  static const terminalCodes = {
    'invalid-argument',
    'failed-precondition',
    'permission-denied',
    'unauthenticated',
    'not-found',
    'already-exists',
    'out-of-range',
    'unimplemented',
  };

  /// The wire payload of [request] for [scope].
  static Map<String, Object?> encode(
    LearnerScope scope,
    OversizedGovernedWrite request,
  ) => {
    'profileId': scope.profileId,
    'actorRole': request.actorRole.storage,
    'actionId': request.actionId,
    if (request.revertsActionId != null)
      'revertsActionId': request.revertsActionId,
    'entries': [
      for (final e in request.entries)
        {
          'id': e.entryId,
          'entity': e.change.entity.storage,
          'entityId': e.change.entityId,
          'docs': [
            for (final d in e.change.docs)
              {
                'collection': d.collection,
                'docId': d.docId,
                'fields': {
                  for (final MapEntry(:key, :value) in d.fields.entries)
                    key: _wireValue(key, value),
                },
                'mode': d.mode.name,
              },
          ],
        },
    ],
  };

  static Object? _wireValue(String field, Object? value) {
    if (field == GovernedKeys.endedAt && value is DateTime) return true;
    if (value is DateTime) return value.toUtc().toIso8601String();
    return value;
  }

  @override
  Future<GovernedWriteReceipt> write(
    LearnerScope scope,
    OversizedGovernedWrite request,
  ) async {
    final Map<String, Object?> result;
    try {
      result = await _invoke(encode(scope, request));
    } on FirebaseFunctionsException catch (e) {
      if (offlineCodes.contains(e.code)) throw const OnlineRequiredException();
      if (terminalCodes.contains(e.code)) throw PermanentWriteRejection(e.code);
      throw GovernedWriteOutcomeUnknown(e.code);
    }
    final at = result['at'];
    return GovernedWriteReceipt(
      actionId: result['action_id'] as String? ?? request.actionId,
      changeIds: [
        for (final id in (result['change_ids'] as List<Object?>? ?? const []))
          id! as String,
      ],
      at: at is String ? DateTime.tryParse(at)?.toUtc() : null,
      replayed: result['replayed'] == true,
      noop: result['noop'] == true,
    );
  }
}
