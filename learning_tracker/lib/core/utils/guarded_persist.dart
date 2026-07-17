import 'package:learning_tracker/core/logging/logger.dart';

/// EH-2 / SM-5 guard for plain-value `Notifier<T>` mutation methods that
/// persist an already-applied optimistic `state` change (AUD-core-preferences-04).
///
/// Riverpod 3's canonical async-mutation shape (SM-5,
/// docs/coding-standards.md) is `state = await AsyncValue.guard(() => …)` —
/// but that only applies when `state` itself is `AsyncValue`-shaped. A
/// plain-value `Notifier<T>` (state is `T`, not `AsyncValue<T>`) has no
/// error channel at all, so an unguarded `await` on the persistence call
/// AFTER an optimistic `state = value` assignment becomes an unobserved
/// Future rejection on failure: the UI has already shown the new value, the
/// write silently never lands, and the change reverts with zero explanation
/// the next time the app reads the (unchanged) persisted value.
///
/// [write] performs the actual persistence (a `SharedPreferences` write, a
/// DAO/service call, a sync-snapshot push, …). On failure it is caught,
/// logged via [AppLogger] under [event] (with optional diagnostic [fields]),
/// and [onFailure] is invoked so the caller can roll back its optimistic
/// `state` assignment — keeping in-memory state from silently diverging
/// from what is actually persisted. The returned future never rejects: a
/// write failure is always converted into a logged event plus the
/// caller-supplied rollback, never a raw unhandled exception.
Future<void> guardedPersist({
  required String event,
  required Future<void> Function() write,
  required void Function() onFailure,
  Map<String, dynamic>? fields,
}) async {
  try {
    await write();
  } catch (e, st) {
    AppLogger.instance.error(
      event: event,
      exception: e,
      stackTrace: st,
      fields: fields,
    );
    onFailure();
  }
}
