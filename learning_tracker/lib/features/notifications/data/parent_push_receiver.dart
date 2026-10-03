/// Receiving a tutor-change push (sub-tracks Story 4.7 / DNI-515, AC-1/AC-5).
///
/// The trigger sends DATA-ONLY messages, so the OS never shows one on its
/// own. Both the foreground listener and the background isolate handler run
/// [deliverParentPush]: a local notification is posted only while this
/// install's durable parent-session marker is unlocked for the push's owner
/// and learner. A device that dropped back to child role — even offline,
/// before its token deletion synced — has no marker and shows nothing.
///
/// Tapping the notification queues a [ParentPushTap] in
/// [pendingParentPushTapProvider]; the app shell opens the learner's Change
/// history from it through the ordinary route guards (own session, child
/// profile, parent PIN) — the tap never pre-authenticates anything.
library;

import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/notifications/data/fcm_parent_push_service.dart';
import 'package:learning_tracker/features/notifications/domain/models/parent_push_message.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android channel of the tutor-change notifications.
const String kParentPushChannelId = 'parent_push';

/// Posts the local notification for an allowed push.
abstract interface class ParentPushNotifier {
  /// Shows [message].
  Future<void> show(ParentPushMessage message);
}

/// Notification id of the push for [actionId]: stable (one notification per
/// action, a re-delivery replaces it) and outside the reminder id blocks of
/// `notification_gateway.dart` (which stay below 2,000,001,000).
int parentPushNotificationId(String actionId) {
  var hash = 0x811c9dc5;
  for (final codeUnit in actionId.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return 2100000000 + hash % 40000000;
}

/// The localized body, e.g. "Rav Cohen changed Yehuda's deadline".
String parentPushBody(AppLocalizations l10n, ParentPushMessage message) =>
    l10n.parentPushBody(
      message.tutorName.isEmpty
          ? l10n.parentPushTutorFallback
          : message.tutorName,
      message.learnerName.isEmpty
          ? l10n.parentPushLearnerFallback
          : message.learnerName,
      message.kind.name,
    );

/// [ParentPushNotifier] over flutter_local_notifications, in the device UI
/// language the app itself uses.
class LocalParentPushNotifier implements ParentPushNotifier {
  /// Creates the notifier. [initialize] is for the background isolate, where
  /// the plugin has not been initialized by the app.
  LocalParentPushNotifier({
    FlutterLocalNotificationsPlugin? plugin,
    bool initialize = false,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _initialize = initialize;

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _initialize;

  @override
  Future<void> show(ParentPushMessage message) async {
    if (_initialize) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
    }
    final l10n = lookupAppLocalizations(
      resolveDeviceUiLocale(PlatformDispatcher.instance.locales),
    );
    await _plugin.show(
      id: parentPushNotificationId(message.actionId),
      title: l10n.parentPushTitle,
      body: parentPushBody(l10n, message),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          kParentPushChannelId,
          l10n.parentPushChannelName,
          channelDescription: l10n.parentPushChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.tap.toPayload(),
    );
  }
}

/// Shows the push in [data] when [session] allows it. Returns whether a
/// notification was posted. Non-push data messages are ignored.
Future<bool> deliverParentPush(
  Map<String, dynamic> data, {
  required ParentPushSession? session,
  required ParentPushNotifier notifier,
  AppLogger? log,
}) async {
  final message = ParentPushMessage.tryParse(data);
  if (message == null) return false;
  if (session == null || !session.allows(message)) {
    (log ?? AppLogger.instance).info(event: 'parent_push_suppressed');
    return false;
  }
  await notifier.show(message);
  return true;
}

/// Foreground delivery: the marker is read from this isolate's cache, which
/// a lock clears synchronously.
Future<bool> deliverForegroundParentPush(
  Map<String, dynamic> data, {
  required ParentPushSessionStore store,
  required ParentPushNotifier notifier,
}) => deliverParentPush(data, session: store.read(), notifier: notifier);

/// Background isolate delivery (`FirebaseMessaging.onBackgroundMessage`):
/// reloads the marker from disk, where every lock has persisted its clear.
@pragma('vm:entry-point')
Future<void> parentPushBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await deliverParentPush(
      message.data,
      session: ParentPushSessionStore(prefs).read(),
      notifier: LocalParentPushNotifier(initialize: true),
    );
  } on Object catch (e, stack) {
    AppLogger.instance.warning(
      event: 'parent_push_background_failed',
      exception: e,
      stackTrace: stack,
    );
  }
}

/// A tapped parent push waiting for the app shell to open it.
class PendingParentPushTap extends Notifier<ParentPushTap?> {
  @override
  ParentPushTap? build() => null;

  /// Queues [tap].
  void set(ParentPushTap tap) => state = tap;

  /// Takes the queued tap (null when none).
  ParentPushTap? take() {
    final tap = state;
    state = null;
    return tap;
  }
}

/// See [PendingParentPushTap].
final pendingParentPushTapProvider =
    NotifierProvider<PendingParentPushTap, ParentPushTap?>(
      PendingParentPushTap.new,
    );
