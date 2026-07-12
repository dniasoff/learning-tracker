import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/notifications/data/services/sacred_window_repository.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:timezone/timezone.dart' as tz;

/// Widget observer that, on app resume:
///   1. Re-detects the device timezone (IANA zone) and updates [tz.local].
///   2. Invalidates the [SacredWindowRepository] in-memory cache so the next
///      notification scheduling recomputes windows for the new timezone.
///   3. Triggers a reschedule of the 14-day reminder batch via
///      [reminderSyncEffectProvider].
///
/// DNI-367 (Story 26.24) — acceptance criterion 3.
///
/// Mount this widget above [MaterialApp] or alongside [SyncLifecycleObserver]
/// so it receives lifecycle events for the full app lifetime.
class TimezoneLifecycleObserver extends ConsumerStatefulWidget {
  const TimezoneLifecycleObserver({
    required this.child,
    required this.sacredWindowRepository,
    super.key,
  });

  final Widget child;
  final SacredWindowRepository sacredWindowRepository;

  @override
  ConsumerState<TimezoneLifecycleObserver> createState() =>
      _TimezoneLifecycleObserverState();
}

class _TimezoneLifecycleObserverState
    extends ConsumerState<TimezoneLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed) return;
    await _onResume();
  }

  Future<void> _onResume() async {
    // 1. Re-detect timezone and update tz.local.
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e, stackTrace) {
      // AUD-notifications-05 (EH-3): keep existing tz.local, but log so a
      // real platform-query failure leaves a diagnostic trail instead of
      // vanishing silently.
      AppLogger.instance.warning(
        event: 'timezone_redetect_on_resume_failed',
        exception: e,
        stackTrace: stackTrace,
      );
    }

    // 2. Invalidate Sacred Window cache so next scheduling recomputes.
    widget.sacredWindowRepository.invalidate();

    // 3. Trigger reschedule by invalidating the Riverpod provider.
    if (mounted) {
      // ignore: unused_result — side-effect-only provider
      ref.invalidate(reminderSyncEffectProvider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
