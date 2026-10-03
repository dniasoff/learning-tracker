// routerProvider's PinGuard → parent push wiring (Story 4.7 / DNI-515, AC-4):
// a parent PIN unlock registers this install, every lock (sign-out, account
// or profile switch, leaving parent mode) removes it, and a tutored session
// never registers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/domain/repositories/fcm_token_repository.dart';
import 'package:learning_tracker/features/notifications/data/fcm_parent_push_service.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPinService extends Mock implements PinService {}

class _GrantedPlatform implements PushMessagingPlatform {
  @override
  bool get isIOS => false;
  @override
  Future<String?> getAPNSToken() async => null;
  @override
  Future<String?> getToken() async => 'tok-1';
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Future<bool> requestPermission() async => true;
}

class _RecordingTokens implements FcmTokenRepository {
  final ops = <String>[];

  @override
  Future<void> removeToken(
    FcmTokenOwner owner, {
    required String installId,
  }) async => ops.add('remove ${owner.uid}');

  @override
  Future<void> upsertToken(
    FcmTokenOwner owner, {
    required String installId,
    required String token,
  }) async => ops.add('upsert ${owner.uid} $token');
}

void main() {
  late _RecordingTokens tokens;
  late ProviderContainer container;
  late ParentPushSessionStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tokens = _RecordingTokens();
    store = ParentPushSessionStore(prefs);
    container = ProviderContainer(
      overrides: [
        pinServiceProvider.overrideWithValue(_MockPinService()),
        parentPushServiceProvider.overrideWithValue(
          FcmParentPushService(
            platform: _GrantedPlatform(),
            tokens: tokens,
            store: store,
            currentOwner: () async =>
                const FcmTokenOwner(accountId: 'acct-1', uid: 'owner-uid'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('parent unlock registers; lock clears the marker and removes', () async {
    final guard = container.read(routerProvider).pinGuard;

    guard.markAuthenticated('01J8XKQ2M3N4P5R6S7T8V9W0XY');
    await pumpEventQueue();
    expect(tokens.ops, ['upsert owner-uid tok-1']);
    expect(store.read(), isNotNull);

    guard.lock();
    expect(store.read(), isNull, reason: 'cleared synchronously on lock');
    await pumpEventQueue();
    expect(tokens.ops.last, 'remove owner-uid');
  });

  test('a tutored session never registers', () async {
    container
        .read(activeTutoredProfileSelectionProvider.notifier)
        .enter(
          const TutoredProfileSelection(
            profileId: '01J8XKQ2M3N4P5R6S7T8V9W0XY',
            ownerUid: 'other-owner',
            grantId: 'grant-1',
            permissions: TutorPermissions(),
            tutorOwnProfileId: 'tutor-own',
          ),
        );
    final guard = container.read(routerProvider).pinGuard;

    guard.markAuthenticated('01J8XKQ2M3N4P5R6S7T8V9W0XY');
    await pumpEventQueue();
    expect(tokens.ops, isEmpty);
    expect(store.read(), isNull);
  });
}
