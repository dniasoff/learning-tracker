import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/notifications/data/fcm_parent_push_service.dart';
import 'package:learning_tracker/features/notifications/data/parent_push_receiver.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The FCM entry points the parent-push bootstrap subscribes to — injectable
/// so tests never touch the Firebase plugin.
class ParentPushChannels {
  /// Creates the channels.
  const ParentPushChannels({
    required this.registerBackgroundHandler,
    required this.foregroundMessages,
  });

  /// `FirebaseMessaging.onBackgroundMessage` and `FirebaseMessaging.onMessage`.
  factory ParentPushChannels.firebase() => ParentPushChannels(
    registerBackgroundHandler: FirebaseMessaging.onBackgroundMessage,
    foregroundMessages: () => FirebaseMessaging.onMessage.map((m) => m.data),
  );

  /// Registers the background-isolate handler.
  final void Function(BackgroundMessageHandler handler)
  registerBackgroundHandler;

  /// Data of the messages received while the app is in the foreground.
  final Stream<Map<String, dynamic>> Function() foregroundMessages;
}

/// Starts the parent-push side of the app (sub-tracks Story 4.7 / DNI-515).
///
/// - Loads the preferences the parent-session marker lives in, then treats
///   the launch as a lock: the in-memory parent PIN session is always locked
///   at process start, so a marker a killed process left behind is cleared at
///   once (before the first frame) and its install token deleted in the
///   background (AC-4/AC-5).
/// - Subscribes the data-only push handlers — background isolate and
///   foreground — which post a local notification only while the marker
///   allows it (AC-5), and re-registers a rotated token while unlocked.
///
/// Non-fatal — a failure here must never prevent app startup.
Future<void> bootstrapParentPush({
  required ProviderContainer container,
  required AppLogger log,
  Future<SharedPreferences> Function()? loadPreferences,
  ParentPushChannels? channels,
  ParentPushNotifier? notifier,
}) async {
  try {
    final prefs = await (loadPreferences ?? SharedPreferences.getInstance)();
    container.read(parentPushPreferencesProvider.notifier).set(prefs);
    final push = container.read(parentPushServiceProvider);
    if (push == null) return;
    // The marker is cleared synchronously inside onColdStart; only the
    // network delete continues in the background.
    unawaited(push.onColdStart());

    final fcm = channels ?? ParentPushChannels.firebase();
    final show = notifier ?? LocalParentPushNotifier();
    final store = ParentPushSessionStore(prefs);
    fcm.registerBackgroundHandler(parentPushBackgroundHandler);
    fcm.foregroundMessages().listen(
      (data) async {
        try {
          await deliverForegroundParentPush(data, store: store, notifier: show);
        } on Object catch (e, stack) {
          log.warning(
            event: 'parent_push_foreground_failed',
            exception: e,
            stackTrace: stack,
          );
        }
      },
      onError: (Object e, StackTrace stack) => log.warning(
        event: 'parent_push_foreground_failed',
        exception: e,
        stackTrace: stack,
      ),
    );
    container
        .read(pushMessagingPlatformProvider)
        .onTokenRefresh
        .listen(
          (token) => unawaited(push.onTokenRefresh(token)),
          onError: (Object e, StackTrace stack) => log.warning(
            event: 'parent_push_token_stream_failed',
            exception: e,
            stackTrace: stack,
          ),
        );
  } on Object catch (e, stack) {
    log.error(
      event: 'parent_push_init_failed',
      exception: e,
      stackTrace: stack,
    );
  }
}
