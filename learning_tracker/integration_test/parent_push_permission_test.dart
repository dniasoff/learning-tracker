// Story 4.7 / DNI-515 AC-6 — registration order and permission on a real
// device, through the production FirebasePushMessagingPlatform.
//
//   * iOS: getAPNSToken() is awaited before any other messaging call, then
//     requestPermission(), then getToken().
//   * Android 13+: requestPermission() is called (POST_NOTIFICATIONS).
//   * A denied permission stores no token and no parent-session marker, and
//     changes nothing else.
//
// Ruling B12 + user decision 2026-10-01: Android is verified on the
// emulator / release device sweep; the iOS leg needs the APNs key and push
// capability, deferred to bead learning-tracker-fyh.65 — it is skipped on
// non-iOS devices and never fails the build.
//
// Run: flutter test integration_test/parent_push_permission_test.dart -d <device>

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/domain/repositories/fcm_token_repository.dart';
import 'package:learning_tracker/features/notifications/data/fcm_parent_push_service.dart';
import 'package:learning_tracker/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = '01J8XKQ2M3N4P5R6S7T8V9W0XY';

/// Records every messaging call the registration makes, in order, while
/// delegating to the real platform (or forcing a denial).
class _RecordingPlatform implements PushMessagingPlatform {
  _RecordingPlatform(this._real, {this.deny = false});

  final PushMessagingPlatform _real;
  final bool deny;
  final calls = <String>[];

  @override
  bool get isIOS => _real.isIOS;

  @override
  Future<String?> getAPNSToken() async {
    calls.add('getAPNSToken');
    return _real.getAPNSToken();
  }

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    final granted = await _real.requestPermission();
    return granted && !deny;
  }

  @override
  Future<String?> getToken() async {
    calls.add('getToken');
    return _real.getToken();
  }

  @override
  Stream<String> get onTokenRefresh => _real.onTokenRefresh;
}

class _RecordingTokens implements FcmTokenRepository {
  final upserts = <String>[];

  @override
  Future<void> upsertToken(
    FcmTokenOwner owner, {
    required String installId,
    required String token,
  }) async => upserts.add(installId);

  @override
  Future<void> removeToken(
    FcmTokenOwner owner, {
    required String installId,
  }) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  });

  Future<(FcmParentPushService, _RecordingPlatform, _RecordingTokens)> build({
    bool deny = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ParentPushSessionStore.sessionKey);
    final platform = _RecordingPlatform(
      FirebasePushMessagingPlatform(),
      deny: deny,
    );
    final tokens = _RecordingTokens();
    final service = FcmParentPushService(
      platform: platform,
      tokens: tokens,
      store: ParentPushSessionStore(prefs),
      currentOwner: () async =>
          const FcmTokenOwner(accountId: 'acct-1', uid: 'owner-uid'),
    );
    return (service, platform, tokens);
  }

  testWidgets('iOS awaits the APNs token before any other messaging call', (
    tester,
  ) async {
    final (service, platform, _) = await build();
    await service.onParentUnlocked(_profile);
    expect(platform.calls.first, 'getAPNSToken');
  }, skip: !Platform.isIOS);

  testWidgets('Android requests notification permission before the token', (
    tester,
  ) async {
    final (service, platform, tokens) = await build();
    await service.onParentUnlocked(_profile);
    expect(platform.calls, isNot(contains('getAPNSToken')));
    expect(platform.calls.first, 'requestPermission');
    if (platform.calls.contains('getToken')) {
      expect(tokens.upserts, hasLength(1));
      expect(service.session, isNotNull);
    }
    await service.onParentLocked();
  }, skip: !Platform.isAndroid);

  testWidgets('a denied permission stores no token and no marker', (
    tester,
  ) async {
    final (service, platform, tokens) = await build(deny: true);
    await service.onParentUnlocked(_profile);
    expect(platform.calls, contains('requestPermission'));
    expect(platform.calls, isNot(contains('getToken')));
    expect(tokens.upserts, isEmpty);
    expect(service.session, isNull);
  });
}
