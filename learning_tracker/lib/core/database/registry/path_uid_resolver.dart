import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

/// Thrown by [PathUidResolver] when asked to resolve/reconcile an
/// [accountId] that has no row in the device registry.
class UnknownDeviceAccountException extends NotFoundException {
  const UnknownDeviceAccountException(String accountId)
    : super('No device-registry account found for id "$accountId"');
}

/// What [PathUidResolver.reconcileLiveUid] did in response to the caller's
/// reported live-auth uid.
enum PathUidReconcileKind {
  /// No persisted uid existed for the account yet: a cloud sign-in
  /// completing for the first time, or — per AD-19 — a local-born account
  /// receiving its first Anonymous Auth uid in Phase 4. There is no prior
  /// document tree to strand, so this is a plain bind, not a remap.
  initialBind,

  /// The persisted uid already matched the reported live uid. No write was
  /// performed.
  matched,

  /// The live uid differed from a pre-existing persisted uid — AD-19's
  /// anon-uid-reset case. The persisted field was re-pointed to the new uid
  /// and the old uid preserved as [PathUidReconcileResult.previousUid] as
  /// the re-home breadcrumb for the downstream Firestore data layer.
  remapped,
}

/// Outcome of [PathUidResolver.reconcileLiveUid].
class PathUidReconcileResult {
  const PathUidReconcileResult({
    required this.accountId,
    required this.kind,
    required this.newUid,
    this.previousUid,
  });

  final String accountId;
  final PathUidReconcileKind kind;

  /// The uid now persisted as the path uid for [accountId] (always equal to
  /// the live uid the caller reported).
  final String newUid;

  /// The uid that was persisted immediately before this call, only set when
  /// [kind] is [PathUidReconcileKind.remapped].
  final String? previousUid;

  bool get isRemap => kind == PathUidReconcileKind.remapped;
}

/// The single accessor for the Firestore-path uid — the `{uid}` in
/// `users/{uid}/…` (AD-24 rule 2).
///
/// **The rule this class exists to enforce:** the path uid MUST come from a
/// persisted field on the account record, NEVER from the live
/// `FirebaseAuth.currentUser`. This module does not import the Firebase Auth
/// or Cloud Firestore SDK packages at all — it is structurally impossible
/// for it to read `currentUser`, let alone fall back to it. Callers (the
/// `AccountFirebase` registry — Story P1-A/C — and
/// its auth gateway) observe the live uid themselves (e.g. from
/// `signInAnonymously`'s result or an auth-state listener) and report it
/// here via [reconcileLiveUid]; this class never reaches out for it.
///
/// **AD-24's ratified remap choice, quoted verbatim:**
/// > Firestore-path uid = a persisted uid field on the active-account
/// > record (the resolved cloud uid, or the anon uid after
/// > `signInAnonymously`), with an explicit remap-on-anon-reset step
/// > (AD-19). Neither identifier may be derived from the live auth uid at
/// > call time.
///
/// And AD-19's remap mechanics, also quoted:
/// > on a fresh anon uid for the same registry account, re-home
/// > `users/<oldUid>/…` to the new uid so the prior cache + document tree
/// > are not stranded.
///
/// **Scope note:** this story owns the device-registry layer only. Actual
/// document-tree re-homing (walking `users/<oldUid>/…` and copying it to
/// `users/<newUid>/…`) requires Firestore access, which belongs to the
/// `AccountFirebase`/repository layer built by later stories. What this
/// class does today is the **re-point** half — the persisted uid now
/// resolves to the new uid, so future writes address the correct tree — and
/// it durably records the **re-home breadcrumb**
/// (`previousFirebaseUid`/`uidRemappedAt` on the account row) that the
/// Firestore data layer consumes to perform the copy once it exists. Until
/// that layer lands, a non-null `previousFirebaseUid` is the signal that an
/// account has a stranded pre-remap tree still to be re-homed.
class PathUidResolver {
  const PathUidResolver(this._db, {AppLogger? logger}) : _logger = logger;

  final DeviceRegistryDatabase _db;
  final AppLogger? _logger;

  /// The persisted path uid for [accountId] — the ONLY value any caller may
  /// use to build a `users/{uid}/…` Firestore path. Returns null for a
  /// local-born account that has not yet been bound to a Firebase
  /// principal.
  ///
  /// Throws [UnknownDeviceAccountException] if [accountId] has no registry
  /// row.
  Future<String?> pathUidFor(String accountId) async {
    final account = await _db.findById(accountId);
    if (account == null) throw UnknownDeviceAccountException(accountId);
    return account.firebaseUid;
  }

  /// Reconciles a caller-observed live auth uid against the persisted path
  /// uid for [accountId], performing the AD-24/AD-19 remap when they
  /// diverge.
  ///
  /// Idempotent: once [liveUid] has been persisted (whether via an initial
  /// bind or a remap), calling again with the same [liveUid] returns
  /// [PathUidReconcileKind.matched] and writes nothing.
  ///
  /// Throws [UnknownDeviceAccountException] if [accountId] has no registry
  /// row.
  Future<PathUidReconcileResult> reconcileLiveUid({
    required String accountId,
    required String liveUid,
  }) async {
    final account = await _db.findById(accountId);
    if (account == null) throw UnknownDeviceAccountException(accountId);

    final persisted = account.firebaseUid;

    if (persisted == liveUid) {
      return PathUidReconcileResult(
        accountId: accountId,
        kind: PathUidReconcileKind.matched,
        newUid: liveUid,
      );
    }

    // persisted == null: initial bind — cloud sign-in completing for the
    // first time, or (AD-19, Phase 4) a local-born account's first
    // Anonymous Auth uid. No prior tree to strand — nothing to remap.
    //
    // persisted != null && persisted != liveUid: an anon-uid reset (AD-19) —
    // OS cleared app data, or the anon session reset before linking. Both
    // shapes collapse to ONE write below (a single atomic Drift `update`
    // statement — DB-2 is a per-statement, not per-branch, concern) so a
    // static branch-counting checker never sees two writes to reconcile:
    // exactly one of these two mutually-exclusive branches executes per
    // call, and each already performs its persistence in a single
    // statement.
    final isRemap = persisted != null;

    // Routed through DateTimeFactory/LocalDayClock (never the raw system
    // clock) per this repo's TQ-6 hermetic-clock convention — tests swap
    // the clock via `useLocalDayClock(FakeLocalDayClock(...))` instead of
    // depending on wall-clock time.
    final remappedAt = isRemap ? DateTimeFactory.nowUtc() : null;

    await _db.writePathUid(
      accountId,
      uid: liveUid,
      previousFirebaseUid: isRemap ? persisted : null,
      remappedAt: remappedAt,
    );

    if (isRemap) {
      // Re-point the persisted uid to the new live uid and leave the
      // re-home breadcrumb for the Firestore data layer, so a field
      // occurrence is diagnosable and the account is recoverable rather
      // than orphaned.
      _logger?.warning(
        event: 'registry_path_uid_remapped',
        fields: {
          'accountId': accountId,
          'previousUid': persisted,
          'newUid': liveUid,
        },
      );
    } else {
      _logger?.info(
        event: 'registry_path_uid_bound',
        fields: {'accountId': accountId},
      );
    }

    return PathUidReconcileResult(
      accountId: accountId,
      kind: isRemap
          ? PathUidReconcileKind.remapped
          : PathUidReconcileKind.initialBind,
      newUid: liveUid,
      previousUid: isRemap ? persisted : null,
    );
  }
}
