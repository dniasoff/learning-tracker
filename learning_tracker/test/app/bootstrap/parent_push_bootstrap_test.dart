// bootstrapParentPush (Story 4.7 / DNI-515).
//
// AC-4 / AC-5: a launch is a lock — a parent-session marker left by a killed
// process is cleared before the first frame and its install token removed.
// AC-5: the data-only handlers are subscribed; a foreground push shows only
// while the marker allows it.
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/bootstrap/parent_push_bootstrap.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/data/repositories/firestore_fcm_token_repository.dart';
import 'package:learning_tracker/domain/repositories/fcm_token_repository.dart';
import 'package:learning_tracker/features/notifications/data/fcm_parent_push_service.dart';
import 'package:learning_tracker/features/notifications/data/parent_push_receiver.dart';
import 'package:learning_tracker/features/notifications/domain/models/parent_push_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = '01J8XKQ2M3N4P5R6S7T8V9W0XY';

class _RecordingTokens implements FcmTokenRepository {
  final ops = <String>[];

  @override
  Future<void> removeToken(
    FcmTokenOwner owner, {
    required String installId,
  }) async => ops.add('remove ${owner.uid} $installId');

  @override
  Future<void> upsertToken(
    FcmTokenOwner owner, {
    required String installId,
    required String token,
  }) async => ops.add('upsert ${owner.uid} $token');
}

class _FakePlatform implements PushMessagingPlatform {
  // Closed by the test's tearDown.
  // ignore: close_sinks
  final refresh = StreamController<String>.broadcast();

  @override
  bool get isIOS => false;
  @override
  Future<String?> getAPNSToken() async => null;
  @override
  Future<String?> getToken() async => 'tok-1';
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<bool> requestPermission() async => true;
}

class _RecordingNotifier implements ParentPushNotifier {
  final shown = <ParentPushMessage>[];

  @override
  Future<void> show(ParentPushMessage message) async => shown.add(message);
}

void main() {
  late _RecordingTokens tokens;
  late _FakePlatform platform;
  late _RecordingNotifier notifier;
  late StreamController<Map<String, dynamic>> foreground;
  late List<BackgroundMessageHandler> background;
  late ProviderContainer container;

  ParentPushChannels channels() => ParentPushChannels(
    registerBackgroundHandler: background.add,
    foregroundMessages: () => foreground.stream,
  );

  setUp(() {
    tokens = _RecordingTokens();
    platform = _FakePlatform();
    notifier = _RecordingNotifier();
    foreground = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(foreground.close);
    addTearDown(platform.refresh.close);
    background = [];
    container = ProviderContainer(
      overrides: [
        fcmTokenRepositoryProvider.overrideWithValue(tokens),
        pushMessagingPlatformProvider.overrideWithValue(platform),
        currentFcmTokenOwnerProvider.overrideWith(
          (ref) async =>
              const FcmTokenOwner(accountId: 'acct-1', uid: 'owner-uid'),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> boot() => bootstrapParentPush(
    container: container,
    log: AppLogger.instance,
    channels: channels(),
    notifier: notifier,
  );

  test(
    'clears a stale marker at launch and removes its install token',
    () async {
      SharedPreferences.setMockInitialValues({
        ParentPushSessionStore.sessionKey: const ParentPushSession(
          accountId: 'acct-1',
          ownerUid: 'owner-uid',
          profileId: _profile,
        ).encode(),
        ParentPushSessionStore.installIdKey: 'install-a',
      });

      await boot();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ParentPushSessionStore.sessionKey), isNull);
      await pumpEventQueue();
      expect(tokens.ops, ['remove owner-uid install-a']);
      expect(background, [parentPushBackgroundHandler]);
    },
  );

  test(
    'foreground pushes show only while the parent session is unlocked',
    () async {
      SharedPreferences.setMockInitialValues({});
      await boot();
      final push = container.read(parentPushServiceProvider)!;
      final data = {
        'type': 'tutor_change',
        'owner_uid': 'owner-uid',
        'profile_id': _profile,
        'action_id': '01JTEST0000000000000000001',
        'kind': 'mainTrack',
        'tutor_name': 'Rav Cohen',
        'learner_name': 'Yehuda',
      };

      foreground.add(data);
      await pumpEventQueue();
      expect(notifier.shown, isEmpty, reason: 'locked at launch');

      await push.onParentUnlocked(_profile);
      foreground.add(data);
      await pumpEventQueue();
      expect(notifier.shown, hasLength(1));

      unawaited(push.onParentLocked());
      foreground.add(data);
      await pumpEventQueue();
      expect(notifier.shown, hasLength(1));
    },
  );

  test('a rotated token is re-registered while unlocked', () async {
    SharedPreferences.setMockInitialValues({});
    await boot();
    await container.read(parentPushServiceProvider)!.onParentUnlocked(_profile);
    tokens.ops.clear();
    platform.refresh.add('tok-2');
    await pumpEventQueue();
    expect(tokens.ops, ['upsert owner-uid tok-2']);
  });

  test('a preferences failure is logged, never thrown', () async {
    final bare = ProviderContainer();
    addTearDown(bare.dispose);
    await expectLater(
      bootstrapParentPush(
        container: bare,
        log: AppLogger.instance,
        loadPreferences: () => Future.error(StateError('no prefs')),
        channels: channels(),
      ),
      completes,
    );
    expect(bare.read(parentPushServiceProvider), isNull);
  });
}
