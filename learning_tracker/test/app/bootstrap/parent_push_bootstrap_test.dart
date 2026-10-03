// bootstrapParentPush (Story 4.7 / DNI-515, AC-4 / AC-5): a launch is a
// lock — a parent-session marker left by a killed process is cleared before
// the first frame and its install token removed.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/bootstrap/parent_push_bootstrap.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/data/repositories/firestore_fcm_token_repository.dart';
import 'package:learning_tracker/domain/repositories/fcm_token_repository.dart';
import 'package:learning_tracker/features/notifications/data/fcm_parent_push_service.dart';
import 'package:learning_tracker/features/notifications/domain/models/parent_push_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingTokens implements FcmTokenRepository {
  final removed = <String>[];

  @override
  Future<void> removeToken(
    FcmTokenOwner owner, {
    required String installId,
  }) async => removed.add('${owner.uid} $installId');

  @override
  Future<void> upsertToken(
    FcmTokenOwner owner, {
    required String installId,
    required String token,
  }) async {}
}

class _NoPlatform implements PushMessagingPlatform {
  @override
  bool get isIOS => false;
  @override
  Future<String?> getAPNSToken() async => null;
  @override
  Future<String?> getToken() async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Future<bool> requestPermission() async => false;
}

void main() {
  test(
    'clears a stale marker at launch and removes its install token',
    () async {
      SharedPreferences.setMockInitialValues({
        ParentPushSessionStore.sessionKey: const ParentPushSession(
          accountId: 'acct-1',
          ownerUid: 'owner-uid',
          profileId: 'p1',
        ).encode(),
        ParentPushSessionStore.installIdKey: 'install-a',
      });
      final tokens = _RecordingTokens();
      final container = ProviderContainer(
        overrides: [
          fcmTokenRepositoryProvider.overrideWithValue(tokens),
          pushMessagingPlatformProvider.overrideWithValue(_NoPlatform()),
          currentFcmTokenOwnerProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      await bootstrapParentPush(container: container, log: AppLogger.instance);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ParentPushSessionStore.sessionKey), isNull);
      expect(container.read(parentPushServiceProvider), isNotNull);
      await pumpEventQueue();
      expect(tokens.removed, ['owner-uid install-a']);
    },
  );

  test('a preferences failure is logged, never thrown', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await expectLater(
      bootstrapParentPush(
        container: container,
        log: AppLogger.instance,
        loadPreferences: () => Future.error(StateError('no prefs')),
      ),
      completes,
    );
    expect(container.read(parentPushServiceProvider), isNull);
  });
}
