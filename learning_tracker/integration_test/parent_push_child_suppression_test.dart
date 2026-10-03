// Story 4.7 / DNI-515 AC-5 — a shared family device whose parent PIN
// session was locked offline never shows a tutor-change push in child role.
//
// On-device evidence (ruling B12: written now, run on the Android emulator /
// in the release device-verification sweep; not part of the ubuntu CI unit
// run):
//   1. the parent unlocks → marker written, token registered;
//   2. the device goes offline and the parent session locks → the local
//      marker is cleared synchronously and persisted, while the remote token
//      deletion stays pending (never acknowledged);
//   3. a data message for that learner arrives on the background-isolate
//      path (SharedPreferences reloaded from disk) → no local notification is
//      posted;
//   4. after a fresh parent unlock the same push IS posted.
//
// Run: flutter test integration_test/parent_push_child_suppression_test.dart
//      -d <android-emulator>

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/domain/repositories/fcm_token_repository.dart';
import 'package:learning_tracker/features/notifications/data/fcm_parent_push_service.dart';
import 'package:learning_tracker/features/notifications/data/parent_push_receiver.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = '01J8XKQ2M3N4P5R6S7T8V9W0XY';
const _owner = FcmTokenOwner(accountId: 'acct-1', uid: 'owner-uid');

Map<String, dynamic> _push(String actionId) => {
  'type': 'tutor_change',
  'owner_uid': _owner.uid,
  'profile_id': _profile,
  'action_id': actionId,
  'entry_id': actionId,
  'kind': 'deadline',
  'tutor_name': 'Rav Cohen',
  'learner_name': 'Yehuda',
};

/// Offline account repository: registration lands locally, the lock's
/// deletion is queued and never acknowledged.
class _OfflineTokens implements FcmTokenRepository {
  int pendingRemovals = 0;

  @override
  Future<void> upsertToken(
    FcmTokenOwner owner, {
    required String installId,
    required String token,
  }) async {}

  @override
  Future<void> removeToken(FcmTokenOwner owner, {required String installId}) {
    pendingRemovals++;
    return Completer<void>().future;
  }
}

/// Permission granted, token issued — the device's real FCM is not needed to
/// prove the suppression path.
class _GrantedPlatform implements PushMessagingPlatform {
  @override
  bool get isIOS => false;
  @override
  Future<String?> getAPNSToken() async => 'apns';
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<String?> getToken() async => 'device-token';
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

Future<bool> _isPosted(
  FlutterLocalNotificationsPlugin plugin,
  String action,
) async {
  final active = await plugin.getActiveNotifications();
  return active.any((n) => n.id == parentPushNotificationId(action));
}

/// The background isolate's view: a fresh preferences read from disk.
Future<bool> _deliverInBackground(
  Map<String, dynamic> data,
  FlutterLocalNotificationsPlugin plugin,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return deliverParentPush(
    data,
    session: ParentPushSessionStore(prefs).read(),
    notifier: LocalParentPushNotifier(plugin: plugin, initialize: true),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline lock: child role posts nothing; unlocked parent does', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ParentPushSessionStore.sessionKey);
    final plugin = FlutterLocalNotificationsPlugin();
    final tokens = _OfflineTokens();
    final service = FcmParentPushService(
      platform: _GrantedPlatform(),
      tokens: tokens,
      store: ParentPushSessionStore(prefs),
      currentOwner: () async => _owner,
    );
    const lockedAction = '01JTEST0000000000000000101';
    const unlockedAction = '01JTEST0000000000000000102';
    await plugin.cancelAll();

    // 1. Parent unlock.
    await service.onParentUnlocked(_profile);
    expect(service.session, isNotNull);

    // 2. Offline lock: remote deletion pending, local marker gone at once.
    unawaited(service.onParentLocked());
    expect(service.session, isNull);
    await tester.pump();
    expect(tokens.pendingRemovals, 1);

    // 3. The push arrives while in child role.
    expect(await _deliverInBackground(_push(lockedAction), plugin), isFalse);
    expect(await _isPosted(plugin, lockedAction), isFalse);

    // 4. The unlocked parent case still displays.
    await service.onParentUnlocked(_profile);
    expect(await _deliverInBackground(_push(unlockedAction), plugin), isTrue);
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (await android?.areNotificationsEnabled() ?? true) {
      expect(await _isPosted(plugin, unlockedAction), isTrue);
    }

    await service.onParentLocked().timeout(
      const Duration(milliseconds: 100),
      onTimeout: () {},
    );
    await plugin.cancelAll();
  });
}
