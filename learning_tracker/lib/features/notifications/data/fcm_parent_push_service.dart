/// Parent push on tutor goal / main-track changes — the device side
/// (sub-tracks Story 4.7 / DNI-515, AD-39).
///
/// - **Registration (AC-4, AC-6).** On a parent-scope PIN unlock this install
///   asks for notification permission and, only if it is granted, writes its
///   FCM token to the owning account's `fcm_tokens[installId]`. On iOS the
///   APNs token is awaited before any other messaging call. A denial stores
///   nothing and changes nothing else.
/// - **Lock (AC-4, AC-5).** Every parent lock (and every cold start, when the
///   in-memory PIN session is always locked) clears the durable local
///   parent-session marker synchronously, then deletes this install's token
///   from the account that registered it — offline, that delete is queued.
/// - Tutor PIN sessions never register.
///
/// Firestore stays behind [FcmTokenRepository] (`lib/data/repositories/`);
/// the platform messaging calls stay behind [PushMessagingPlatform] so their
/// order is unit-tested (ruling B12).
library;

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/data/repositories/firestore_fcm_token_repository.dart';
import 'package:learning_tracker/domain/repositories/fcm_token_repository.dart';
import 'package:learning_tracker/features/notifications/domain/models/parent_push_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// Platform seam
// ---------------------------------------------------------------------------

/// The FCM calls registration makes, injectable so their order is testable.
abstract interface class PushMessagingPlatform {
  /// Whether this is iOS (APNs token first).
  bool get isIOS;

  /// The APNs token (iOS only), or null when APNs has none yet.
  Future<String?> getAPNSToken();

  /// Requests notification permission (iOS, Android 13+; a no-op grant on
  /// older Android). True when notifications may be shown.
  Future<bool> requestPermission();

  /// This install's FCM registration token, or null.
  Future<String?> getToken();

  /// New tokens FCM issues for this install.
  Stream<String> get onTokenRefresh;
}

/// [PushMessagingPlatform] over `FirebaseMessaging.instance`.
class FirebasePushMessagingPlatform implements PushMessagingPlatform {
  /// Creates the adapter.
  FirebasePushMessagingPlatform({FirebaseMessaging? messaging})
    : _messaging = messaging;

  final FirebaseMessaging? _messaging;

  FirebaseMessaging get _fm => _messaging ?? FirebaseMessaging.instance;

  @override
  bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<String?> getAPNSToken() => _fm.getAPNSToken();

  @override
  Future<bool> requestPermission() async {
    final settings = await _fm.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _fm.getToken();

  @override
  Stream<String> get onTokenRefresh => _fm.onTokenRefresh;
}

/// Runs the registration sequence on [platform]: on iOS the APNs token is
/// awaited first (no APNs token → no registration); then permission is
/// requested; only a grant fetches the FCM token. Returns null when this
/// install must not be registered.
Future<String?> obtainParentPushToken(PushMessagingPlatform platform) async {
  if (platform.isIOS) {
    final apns = await platform.getAPNSToken();
    if (apns == null || apns.isEmpty) return null;
  }
  if (!await platform.requestPermission()) return null;
  final token = await platform.getToken();
  return token == null || token.isEmpty ? null : token;
}

// ---------------------------------------------------------------------------
// Durable local state
// ---------------------------------------------------------------------------

/// The parent-session marker and the stable install id, in
/// SharedPreferences so the background message isolate can read them.
///
/// [clear] drops the marker from the in-memory cache synchronously (before
/// its first await), so a lock suppresses pushes on this isolate at once and
/// is persisted before any network call is made.
class ParentPushSessionStore {
  /// Creates the store over [prefs].
  ParentPushSessionStore(this._prefs, {String Function()? newInstallId})
    : _newInstallId = newInstallId ?? (() => const Uuid().v4());

  /// Marker key.
  static const String sessionKey = 'parent_push_session_v1';

  /// Install id key.
  static const String installIdKey = 'parent_push_install_id_v1';

  final SharedPreferences _prefs;
  final String Function() _newInstallId;

  /// The unlocked parent session, or null when locked.
  ParentPushSession? read() =>
      ParentPushSession.tryDecode(_prefs.getString(sessionKey));

  /// Records an unlocked parent session.
  Future<void> write(ParentPushSession session) =>
      _prefs.setString(sessionKey, session.encode());

  /// Clears the marker (cache now, disk when the future completes).
  Future<void> clear() => _prefs.remove(sessionKey);

  /// This install's stable id, created once and kept across launches.
  Future<String> installId() async {
    final existing = _prefs.getString(installIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _newInstallId();
    await _prefs.setString(installIdKey, created);
    return created;
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Ties this install's FCM token to the parent PIN session.
class FcmParentPushService {
  /// Creates the service.
  FcmParentPushService({
    required PushMessagingPlatform platform,
    required FcmTokenRepository tokens,
    required ParentPushSessionStore store,
    required Future<FcmTokenOwner?> Function() currentOwner,
    AppLogger? log,
  }) : _platform = platform,
       _tokens = tokens,
       _store = store,
       _currentOwner = currentOwner,
       _log = log ?? AppLogger.instance;

  final PushMessagingPlatform _platform;
  final FcmTokenRepository _tokens;
  final ParentPushSessionStore _store;
  final Future<FcmTokenOwner?> Function() _currentOwner;
  final AppLogger _log;

  /// Bumped by every unlock and lock, so an unlock still awaiting
  /// permission or the network never registers after a later lock.
  int _generation = 0;

  /// The durable marker (null while locked).
  ParentPushSession? get session => _store.read();

  /// A parent-scope PIN session for [profileId] was unlocked: register this
  /// install's token on the active account, if permission is granted.
  /// Repeating it is safe (same install entry is overwritten).
  Future<void> onParentUnlocked(String profileId) async {
    final generation = ++_generation;
    try {
      final owner = await _currentOwner();
      if (owner == null || generation != _generation) return;
      final token = await obtainParentPushToken(_platform);
      if (token == null) {
        _log.info(event: 'parent_push_not_registered');
        return;
      }
      if (generation != _generation) return;
      await _store.write(
        ParentPushSession(
          accountId: owner.accountId,
          ownerUid: owner.uid,
          profileId: profileId,
        ),
      );
      if (generation != _generation) return;
      final installId = await _store.installId();
      await _tokens.upsertToken(owner, installId: installId, token: token);
      if (generation != _generation) {
        // A lock ran while the write was in flight; its delete may have
        // been ordered before this upsert, so delete again.
        await _tokens.removeToken(owner, installId: installId);
      }
    } on Object catch (e, stack) {
      _log.warning(
        event: 'parent_push_register_failed',
        exception: e,
        stackTrace: stack,
      );
    }
  }

  /// The parent PIN session was locked (lock, timeout, profile or account
  /// switch, sign-out): clear the marker synchronously, then delete this
  /// install's token from the account that registered it.
  Future<void> onParentLocked() async {
    _generation++;
    final session = _store.read();
    // Synchronous cache clear happens inside this call, before any await.
    final cleared = _store.clear();
    try {
      await cleared;
      if (session == null) return;
      final installId = await _store.installId();
      await _tokens.removeToken(
        FcmTokenOwner(accountId: session.accountId, uid: session.ownerUid),
        installId: installId,
      );
    } on Object catch (e, stack) {
      _log.warning(
        event: 'parent_push_unregister_failed',
        exception: e,
        stackTrace: stack,
      );
    }
  }

  /// App start: the in-memory PIN session is always locked here, so a marker
  /// left by a killed process is a stale unlock — lock it.
  Future<void> onColdStart() => onParentLocked();

  /// FCM rotated this install's token: re-register it while unlocked.
  ///
  /// The generation is captured before the first await, like
  /// [onParentUnlocked]: a lock that lands while the install id or the
  /// upsert is in flight wins. Before the upsert the refresh just stops;
  /// after it, the lock's delete may have been ordered first, so the entry
  /// is deleted again unless the same owner has been unlocked since.
  Future<void> onTokenRefresh(String token) async {
    final generation = _generation;
    final current = _store.read();
    if (current == null || token.isEmpty) return;
    final owner = FcmTokenOwner(
      accountId: current.accountId,
      uid: current.ownerUid,
    );
    try {
      final installId = await _store.installId();
      if (generation != _generation) return;
      await _tokens.upsertToken(owner, installId: installId, token: token);
      if (generation != _generation && !_isUnlockedFor(owner)) {
        await _tokens.removeToken(owner, installId: installId);
      }
    } on Object catch (e, stack) {
      _log.warning(
        event: 'parent_push_token_refresh_failed',
        exception: e,
        stackTrace: stack,
      );
    }
  }

  /// Whether the durable marker currently holds an unlocked session on
  /// [owner]'s account.
  bool _isUnlockedFor(FcmTokenOwner owner) {
    final s = _store.read();
    return s != null &&
        s.accountId == owner.accountId &&
        s.ownerUid == owner.uid;
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Holds the SharedPreferences the parent-push store uses; set once by the
/// notifications bootstrap. Until then the service is unavailable (null).
class ParentPushPreferences extends Notifier<SharedPreferences?> {
  @override
  SharedPreferences? build() => null;

  /// Supplies the loaded preferences.
  void set(SharedPreferences prefs) => state = prefs;
}

/// SharedPreferences for the parent-push store (see [ParentPushPreferences]).
final parentPushPreferencesProvider =
    NotifierProvider<ParentPushPreferences, SharedPreferences?>(
      ParentPushPreferences.new,
    );

/// The FCM platform seam.
final pushMessagingPlatformProvider = Provider<PushMessagingPlatform>(
  (ref) => FirebasePushMessagingPlatform(),
);

/// The parent-push service, or null before bootstrap has loaded the
/// preferences (widget tests that never bootstrap get no push side effects).
final parentPushServiceProvider = Provider<FcmParentPushService?>((ref) {
  final prefs = ref.watch(parentPushPreferencesProvider);
  if (prefs == null) return null;
  return FcmParentPushService(
    platform: ref.watch(pushMessagingPlatformProvider),
    tokens: ref.watch(fcmTokenRepositoryProvider),
    store: ParentPushSessionStore(prefs),
    currentOwner: () => ref.read(currentFcmTokenOwnerProvider.future),
  );
});
