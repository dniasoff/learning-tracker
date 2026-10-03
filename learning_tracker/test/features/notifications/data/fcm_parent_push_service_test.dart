// FcmParentPushService — parent-PIN token lifecycle (Story 4.7 / DNI-515).
//
// AC-4: a permission-granted parent unlock upserts only this install's token
//       on the owning account; lock / timeout / cold start removes only that
//       entry; repeated unlock is safe.
// AC-5: the durable parent-session marker is cleared synchronously on lock,
//       before any network call.
// AC-6: iOS awaits the APNs token before any other messaging call; the
//       permission is requested; a denial writes no token and no marker.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/repositories/fcm_token_repository.dart';
import 'package:learning_tracker/features/notifications/data/fcm_parent_push_service.dart';
import 'package:learning_tracker/features/notifications/domain/models/parent_push_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _owner = FcmTokenOwner(accountId: 'acct-1', uid: 'owner-uid');
const _profile = '01J8XKQ2M3N4P5R6S7T8V9W0XY';

class _FakePlatform implements PushMessagingPlatform {
  _FakePlatform({this.isIOS = false, this.apnsToken = 'apns'});

  @override
  final bool isIOS;
  String? apnsToken;
  bool granted = true;
  String? token = 'tok-1';
  Completer<void>? permissionGate;
  final calls = <String>[];

  @override
  Future<String?> getAPNSToken() async {
    calls.add('getAPNSToken');
    return apnsToken;
  }

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    await permissionGate?.future;
    return granted;
  }

  @override
  Future<String?> getToken() async {
    calls.add('getToken');
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

class _RecordingTokens implements FcmTokenRepository {
  final ops = <String>[];
  Completer<void>? upsertGate;

  @override
  Future<void> upsertToken(
    FcmTokenOwner owner, {
    required String installId,
    required String token,
  }) async {
    ops.add('upsert ${owner.accountId}/${owner.uid} $installId $token');
    await upsertGate?.future;
  }

  @override
  Future<void> removeToken(
    FcmTokenOwner owner, {
    required String installId,
  }) async {
    ops.add('remove ${owner.accountId}/${owner.uid} $installId');
  }
}

void main() {
  late SharedPreferences prefs;
  late _FakePlatform platform;
  late _RecordingTokens tokens;
  late ParentPushSessionStore store;
  late FcmParentPushService service;
  FcmTokenOwner? owner;

  FcmParentPushService build() => FcmParentPushService(
    platform: platform,
    tokens: tokens,
    store: store,
    currentOwner: () async => owner,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    platform = _FakePlatform();
    tokens = _RecordingTokens();
    store = ParentPushSessionStore(prefs, newInstallId: () => 'install-a');
    owner = _owner;
    service = build();
  });

  group('AC-4 / AC-6 registration on parent unlock', () {
    test('Android: permission, then token, then one install entry', () async {
      await service.onParentUnlocked(_profile);

      expect(platform.calls, ['requestPermission', 'getToken']);
      expect(tokens.ops, ['upsert acct-1/owner-uid install-a tok-1']);
      expect(
        store.read(),
        const ParentPushSession(
          accountId: 'acct-1',
          ownerUid: 'owner-uid',
          profileId: _profile,
        ),
      );
    });

    test(
      'iOS: the APNs token is awaited before any other messaging call',
      () async {
        platform = _FakePlatform(isIOS: true);
        service = build();
        await service.onParentUnlocked(_profile);
        expect(platform.calls, [
          'getAPNSToken',
          'requestPermission',
          'getToken',
        ]);
        expect(tokens.ops, hasLength(1));
      },
    );

    test('iOS without an APNs token registers nothing', () async {
      platform = _FakePlatform(isIOS: true, apnsToken: null);
      service = build();
      await service.onParentUnlocked(_profile);
      expect(platform.calls, ['getAPNSToken']);
      expect(tokens.ops, isEmpty);
      expect(store.read(), isNull);
    });

    test('denied permission stores no token and no marker', () async {
      platform.granted = false;
      await service.onParentUnlocked(_profile);
      expect(platform.calls, ['requestPermission']);
      expect(tokens.ops, isEmpty);
      expect(store.read(), isNull);
    });

    test('no FCM token registers nothing', () async {
      platform.token = null;
      await service.onParentUnlocked(_profile);
      expect(tokens.ops, isEmpty);
      expect(store.read(), isNull);
    });

    test('no active account registers nothing', () async {
      owner = null;
      await service.onParentUnlocked(_profile);
      expect(platform.calls, isEmpty);
      expect(tokens.ops, isEmpty);
    });

    test('repeated unlock rewrites the same install entry', () async {
      await service.onParentUnlocked(_profile);
      await service.onParentUnlocked(_profile);
      expect(tokens.ops, [
        'upsert acct-1/owner-uid install-a tok-1',
        'upsert acct-1/owner-uid install-a tok-1',
      ]);
    });

    test('the install id is stable across launches', () async {
      final first = await store.installId();
      final again = await ParentPushSessionStore(
        prefs,
        newInstallId: () => 'never-used',
      ).installId();
      expect(again, first);
    });

    test('a failing repository is logged, never thrown', () async {
      final failing = FcmParentPushService(
        platform: platform,
        tokens: _ThrowingTokens(),
        store: store,
        currentOwner: () async => owner,
      );
      await expectLater(failing.onParentUnlocked(_profile), completes);
      await expectLater(failing.onParentLocked(), completes);
    });
  });

  group('AC-4 / AC-5 removal on lock, timeout and cold start', () {
    test(
      'lock clears the marker synchronously, then removes only this install',
      () async {
        await service.onParentUnlocked(_profile);
        tokens.ops.clear();

        final pending = service.onParentLocked();
        // Before any await: the marker is already gone from this isolate.
        expect(store.read(), isNull);
        expect(tokens.ops, isEmpty);
        await pending;

        expect(tokens.ops, ['remove acct-1/owner-uid install-a']);
        final reloaded = await SharedPreferences.getInstance();
        expect(reloaded.getString(ParentPushSessionStore.sessionKey), isNull);
      },
    );

    test(
      'lock removes from the account that registered, after a switch',
      () async {
        await service.onParentUnlocked(_profile);
        owner = const FcmTokenOwner(accountId: 'acct-2', uid: 'second-uid');
        tokens.ops.clear();
        await service.onParentLocked();
        expect(tokens.ops, ['remove acct-1/owner-uid install-a']);
      },
    );

    test('lock without a registered session makes no network call', () async {
      await service.onParentLocked();
      expect(tokens.ops, isEmpty);
    });

    test('a lock during the permission prompt prevents registration', () async {
      platform.permissionGate = Completer<void>();
      final unlocking = service.onParentUnlocked(_profile);
      await Future<void>.delayed(Duration.zero);
      await service.onParentLocked();
      platform.permissionGate!.complete();
      await unlocking;
      expect(tokens.ops, isEmpty);
      expect(store.read(), isNull);
    });

    test('a lock racing the token write deletes the entry again', () async {
      tokens.upsertGate = Completer<void>();
      final unlocking = service.onParentUnlocked(_profile);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(tokens.ops, ['upsert acct-1/owner-uid install-a tok-1']);
      await service.onParentLocked();
      tokens.upsertGate!.complete();
      await unlocking;
      expect(tokens.ops.last, 'remove acct-1/owner-uid install-a');
      expect(store.read(), isNull);
    });

    test('cold start locks a marker left by a killed process', () async {
      await service.onParentUnlocked(_profile);
      tokens.ops.clear();
      final restarted = FcmParentPushService(
        platform: platform,
        tokens: tokens,
        store: ParentPushSessionStore(prefs),
        currentOwner: () async => owner,
      );
      await restarted.onColdStart();
      expect(tokens.ops, ['remove acct-1/owner-uid install-a']);
      expect(restarted.session, isNull);
    });
  });

  group('token refresh', () {
    test('re-registers while unlocked', () async {
      await service.onParentUnlocked(_profile);
      tokens.ops.clear();
      await service.onTokenRefresh('tok-2');
      expect(tokens.ops, ['upsert acct-1/owner-uid install-a tok-2']);
    });

    test('is ignored while locked', () async {
      await service.onTokenRefresh('tok-2');
      expect(tokens.ops, isEmpty);
    });
  });
}

class _ThrowingTokens implements FcmTokenRepository {
  @override
  Future<void> removeToken(FcmTokenOwner owner, {required String installId}) =>
      Future.error(StateError('offline'));

  @override
  Future<void> upsertToken(
    FcmTokenOwner owner, {
    required String installId,
    required String token,
  }) => Future.error(StateError('denied'));
}
