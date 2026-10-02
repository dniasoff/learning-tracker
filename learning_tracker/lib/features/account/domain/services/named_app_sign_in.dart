import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/registry/path_uid_resolver.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:uuid/uuid.dart';

/// A signed-in session on one device account's named app.
class NamedAppSession {
  const NamedAppSession({
    required this.accountId,
    required this.user,
    required this.registryRow,
  });

  /// The device-registry account id whose named app is now signed in.
  final String accountId;

  /// The user signed in on that named app.
  final AppUser user;

  /// The device-registry row this session belongs to, or `null` when the
  /// account is new to this device ([accountId] was freshly minted and has
  /// no row yet).
  final DeviceAccount? registryRow;

  bool get isNewToDevice => registryRow == null;
}

/// One cloud sign-in on the RIGHT named app, exactly once (parent AD-1 /
/// AD-24, DNI-520).
///
/// The app used to sign the default app in first and then repeat the same
/// credential on the account's named app. Now the account is chosen BEFORE
/// the single sign-in:
///
/// 1. the device-registry row for the email the user typed (or the Google
///    picker reported) when there is one, else a freshly minted account id
///    (a UUID — the named-app key, never the Firebase uid);
/// 2. [signIn] authenticates THAT account's named app once;
/// 3. if the signed-in uid already belongs to a DIFFERENT registry row (the
///    account's email changed since it was added to this device), the
///    session moves to that row's own named app, and the first app is signed
///    out (or torn down, when its id was freshly minted). That second
///    sign-in is on another named app, never the default app, and happens
///    only in this edge case.
///
/// [reconcilePathUid] then persists the path uid for an existing row through
/// [PathUidResolver] (AD-24), replacing the old silent `firebaseUid`
/// re-point.
class NamedAppSignIn {
  NamedAppSignIn({
    required AuthRepository auth,
    required DeviceRegistryDatabase registry,
    required PathUidResolver pathUids,
    String Function()? newAccountId,
  }) : _auth = auth,
       _registry = registry,
       _pathUids = pathUids,
       _newAccountId = newAccountId ?? const Uuid().v4;

  final AuthRepository _auth;
  final DeviceRegistryDatabase _registry;
  final PathUidResolver _pathUids;
  final String Function() _newAccountId;

  /// Picks the target account for [emailHint] and signs its named app in
  /// with [authenticate] (one of the `AuthRepository.signInToAccount…`
  /// calls). A failed sign-in on a freshly minted id tears that app down
  /// before rethrowing.
  Future<NamedAppSession> signIn({
    required String? emailHint,
    required Future<AppUser> Function(String accountId) authenticate,
  }) async {
    // Heal duplicate-email rows first so the email lookup below is
    // unambiguous (one-shot, cheap when there are none).
    await _registry.dedupeByEmail();

    final byEmail = (emailHint == null || emailHint.isEmpty)
        ? null
        : await _registry.findByEmail(emailHint);
    var accountId = byEmail?.accountId ?? _newAccountId();
    var minted = byEmail == null;

    var user = await _authenticate(accountId, minted, authenticate);

    final byUid = await _registry.findByFirebaseUid(user.uid);
    if (byUid != null && byUid.accountId != accountId) {
      await _release(accountId, minted: minted);
      accountId = byUid.accountId;
      minted = false;
      user = await authenticate(accountId);
    }

    return NamedAppSession(
      accountId: accountId,
      user: user,
      registryRow: byUid ?? byEmail,
    );
  }

  /// AD-24: persists the signed-in uid as [session]'s path uid — an initial
  /// bind, a no-op match, or (when the row held another uid) an AD-19 remap
  /// that keeps the old uid as the re-home breadcrumb. A session new to the
  /// device has no row yet: its uid is written when the row is registered.
  Future<void> reconcilePathUid(NamedAppSession session) async {
    if (session.isNewToDevice) return;
    await _pathUids.reconcileLiveUid(
      accountId: session.accountId,
      liveUid: session.user.uid,
    );
  }

  /// Abandons [session] (unverified email, device-account cap): signs its
  /// named app out and, for an account new to this device, tears the app
  /// down. Best-effort — a cleanup failure never masks the caller's error.
  Future<void> abandon(NamedAppSession session) =>
      _release(session.accountId, minted: session.isNewToDevice);

  Future<AppUser> _authenticate(
    String accountId,
    bool minted,
    Future<AppUser> Function(String accountId) authenticate,
  ) async {
    try {
      return await authenticate(accountId);
    } catch (_) {
      if (minted) await _release(accountId, minted: true);
      rethrow;
    }
  }

  Future<void> _release(String accountId, {required bool minted}) async {
    try {
      await _auth.forAccount(accountId).signOut();
    } on Exception catch (e) {
      AppLogger.instance.warning(
        event: 'named_app_sign_in_release_sign_out_failed',
        exception: e,
      );
    }
    if (!minted) return;
    try {
      await _auth.discardAccountSession(accountId);
    } on Exception catch (e) {
      AppLogger.instance.warning(
        event: 'named_app_sign_in_release_discard_failed',
        exception: e,
      );
    }
  }
}
