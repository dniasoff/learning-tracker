// Parent push receive / display (Story 4.7 / DNI-515).
//
// AC-1: an allowed push posts one localized notification naming the tutor,
//       the learner and the change, whose tap payload leads to that
//       learner's Change history.
// AC-5: a push arriving while this install is in child role (no unlocked
//       parent-session marker) is never shown — even when the lock's token
//       deletion is still pending offline.
import 'dart:async';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/repositories/fcm_token_repository.dart';
import 'package:learning_tracker/features/notifications/data/fcm_parent_push_service.dart';
import 'package:learning_tracker/features/notifications/data/parent_push_receiver.dart';
import 'package:learning_tracker/features/notifications/domain/models/parent_push_message.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = '01J8XKQ2M3N4P5R6S7T8V9W0XY';
const _session = ParentPushSession(
  accountId: 'acct-1',
  ownerUid: 'owner-uid',
  profileId: _profile,
);

Map<String, dynamic> _push([Map<String, dynamic> over = const {}]) => {
  'type': 'tutor_change',
  'owner_uid': 'owner-uid',
  'profile_id': _profile,
  'action_id': '01JTEST0000000000000000001',
  'entry_id': '01JTEST0000000000000000001',
  'kind': 'deadline',
  'tutor_name': 'Rav Cohen',
  'learner_name': 'Yehuda',
  ...over,
};

class _RecordingNotifier implements ParentPushNotifier {
  final shown = <ParentPushMessage>[];

  @override
  Future<void> show(ParentPushMessage message) async => shown.add(message);
}

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

/// Token repository whose network calls never complete (offline).
class _OfflineTokens implements FcmTokenRepository {
  @override
  Future<void> removeToken(FcmTokenOwner owner, {required String installId}) =>
      Completer<void>().future;

  @override
  Future<void> upsertToken(
    FcmTokenOwner owner, {
    required String installId,
    required String token,
  }) async {}
}

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

void main() {
  late _RecordingNotifier notifier;

  setUp(() => notifier = _RecordingNotifier());

  group('deliverParentPush', () {
    test(
      'an unlocked parent session for that learner shows it (AC-1)',
      () async {
        final shown = await deliverParentPush(
          _push(),
          session: _session,
          notifier: notifier,
        );
        expect(shown, isTrue);
        expect(notifier.shown.single.tutorName, 'Rav Cohen');
      },
    );

    test('child role (no marker) never shows it (AC-5)', () async {
      expect(
        await deliverParentPush(_push(), session: null, notifier: notifier),
        isFalse,
      );
      expect(notifier.shown, isEmpty);
    });

    test('a marker for another account or learner does not show it', () async {
      for (final over in [
        {'owner_uid': 'someone-else'},
        {'profile_id': '01J8XKQ2M3N4P5R6S7T8V9W0ZZ'},
      ]) {
        expect(
          await deliverParentPush(
            _push(over),
            session: _session,
            notifier: notifier,
          ),
          isFalse,
        );
      }
      expect(notifier.shown, isEmpty);
    });

    test('other data messages are ignored', () async {
      expect(
        await deliverParentPush(
          {'type': 'something_else'},
          session: _session,
          notifier: notifier,
        ),
        isFalse,
      );
    });
  });

  group('AC-5: offline lock suppresses before the token is gone', () {
    test(
      'foreground: a push right after lock is suppressed; unlock shows it',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = ParentPushSessionStore(prefs);
        final service = FcmParentPushService(
          platform: _GrantedPlatform(),
          tokens: _OfflineTokens(),
          store: store,
          currentOwner: () async =>
              const FcmTokenOwner(accountId: 'acct-1', uid: 'owner-uid'),
        );

        await service.onParentUnlocked(_profile);
        expect(
          await deliverForegroundParentPush(
            _push(),
            store: store,
            notifier: notifier,
          ),
          isTrue,
        );

        // Lock while offline: the token deletion never completes.
        unawaited(service.onParentLocked());
        expect(
          await deliverForegroundParentPush(
            _push({'action_id': '01JTEST0000000000000000002'}),
            store: store,
            notifier: notifier,
          ),
          isFalse,
        );
        expect(notifier.shown, hasLength(1));
      },
    );
  });

  group('LocalParentPushNotifier', () {
    late _MockPlugin plugin;

    setUp(() {
      plugin = _MockPlugin();
      when(
        () => plugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});
    });

    test(
      'posts one high-priority notification with the history tap payload',
      () async {
        final message = ParentPushMessage.tryParse(_push())!;
        await LocalParentPushNotifier(plugin: plugin).show(message);

        final captured = verify(
          () => plugin.show(
            id: captureAny(named: 'id'),
            title: captureAny(named: 'title'),
            body: captureAny(named: 'body'),
            notificationDetails: captureAny(named: 'notificationDetails'),
            payload: captureAny(named: 'payload'),
          ),
        ).captured;
        expect(captured[0], parentPushNotificationId(message.actionId));
        expect(captured[2], contains('Rav Cohen'));
        expect(captured[2], contains('Yehuda'));
        final details = captured[3] as NotificationDetails;
        expect(details.android!.channelId, kParentPushChannelId);
        expect(details.android!.importance, Importance.high);
        expect(
          ParentPushTap.tryParsePayload(captured[4] as String),
          message.tap,
        );
      },
    );
  });

  group('copy', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final he = lookupAppLocalizations(const Locale('he'));
    ParentPushMessage msg([Map<String, dynamic> over = const {}]) =>
        ParentPushMessage.tryParse(_push(over))!;

    test('English names the tutor, the learner and the change', () {
      expect(parentPushBody(en, msg()), "Rav Cohen changed Yehuda's deadline");
      expect(
        parentPushBody(en, msg({'kind': 'mainTrack'})),
        "Rav Cohen changed Yehuda's main track",
      );
      expect(
        parentPushBody(en, msg({'kind': 'mainTrackStudyDays'})),
        "Rav Cohen changed Yehuda's study days",
      );
      expect(
        parentPushBody(en, msg({'kind': 'whatever'})),
        "Rav Cohen changed Yehuda's learning plan",
      );
    });

    test('Hebrew carries the same parts', () {
      final body = parentPushBody(he, msg());
      expect(body, contains('Rav Cohen'));
      expect(body, contains('Yehuda'));
      expect(body, contains('תאריך היעד'));
    });

    test('missing names fall back instead of leaving gaps', () {
      final body = parentPushBody(
        en,
        msg({'tutor_name': '', 'learner_name': ''}),
      );
      expect(body, "Your tutor changed your child's deadline");
    });

    test('every kind has its own English wording', () {
      final bodies = {
        for (final k in ParentPushKind.values)
          parentPushBody(en, msg({'kind': k.name})),
      };
      expect(bodies, hasLength(ParentPushKind.values.length));
    });
  });

  test('notification ids are stable and clear of the reminder blocks', () {
    final id = parentPushNotificationId('01JTEST0000000000000000001');
    expect(parentPushNotificationId('01JTEST0000000000000000001'), id);
    expect(id, greaterThan(2000000999));
    expect(id, lessThan(2147483647));
  });

  test('a queued tap is taken once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const tap = ParentPushTap(ownerUid: 'owner-uid', profileId: _profile);
    final pending = container.read(pendingParentPushTapProvider.notifier);
    pending.set(tap);
    expect(container.read(pendingParentPushTapProvider), tap);
    expect(pending.take(), tap);
    expect(pending.take(), isNull);
  });
}
