import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/notifications/data/fcm_parent_push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts the parent-push side of the app (sub-tracks Story 4.7 / DNI-515).
///
/// Loads the preferences the parent-session marker lives in, then treats the
/// launch as a lock: the in-memory parent PIN session is always locked at
/// process start, so a marker a killed process left behind is cleared at once
/// (before the first frame) and its install token deleted in the background.
///
/// Non-fatal — a failure here must never prevent app startup.
Future<void> bootstrapParentPush({
  required ProviderContainer container,
  required AppLogger log,
  Future<SharedPreferences> Function()? loadPreferences,
}) async {
  try {
    final prefs = await (loadPreferences ?? SharedPreferences.getInstance)();
    container.read(parentPushPreferencesProvider.notifier).set(prefs);
    final push = container.read(parentPushServiceProvider);
    if (push == null) return;
    // The marker is cleared synchronously inside onColdStart; only the
    // network delete continues in the background.
    unawaited(push.onColdStart());
  } on Object catch (e, stack) {
    log.error(
      event: 'parent_push_init_failed',
      exception: e,
      stackTrace: stack,
    );
  }
}
