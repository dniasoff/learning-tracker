/// Persisted "initial sync complete" flag.
///
/// The flag is set the FIRST TIME a full pull from Firestore completes
/// successfully in [SyncOrchestratorImpl.pullOnLaunch].  Before it is set
/// the dashboard must show a "syncing…" state for the count-derived tiles
/// (OVERDUE / TODAY / CHAZARA) rather than any number — including 0.
///
/// Architecture §10.2 of docs/planning/overdue-refactor-architecture.md.
///
/// ## Flag semantics
///   - UNSET (key absent or false) → dashboard count tiles show syncing state.
///   - SET (true) → projection runs on local data normally (online or offline;
///     local DB is the last-synced, complete truth).
///
/// ## Persistence
///   SharedPreferences — the same package used by the skipped-tasks notifier
///   in scheduler_providers.dart.
///
/// ## Write path
///   [markInitialSyncComplete] — write-once helper called by
///   [SyncOrchestratorImpl] after a full pull succeeds.  Idempotent.
///
/// ## Provider
///   [initialSyncCompleteProvider] — a plain [FutureProvider] that reads the
///   flag from SharedPreferences.  Consumers watch it; the provider is
///   invalidated (via the [onFirstSyncComplete] callback wired in
///   sync_orchestrator_providers.dart) whenever the flag is first set, so the
///   dashboard re-evaluates immediately after the first pull finishes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for the "initial sync complete" flag.
///
/// Public so the test (O6) can seed mock SharedPrefs via
/// [SharedPreferences.setMockInitialValues] without coupling to the internal
/// string literal directly.
const String kInitialSyncCompleteKey = 'initial_sync_complete';

/// Reads the "initial sync complete" flag from SharedPreferences.
///
/// Returns `true` if a full pull has ever completed successfully, `false`
/// otherwise (key absent OR explicitly stored as false).
///
/// This is a [FutureProvider] — consumers watch it with [ref.watch].  When
/// [markInitialSyncComplete] first writes the flag it calls an invalidation
/// callback supplied by the Riverpod provider layer
/// (sync_orchestrator_providers.dart) which calls
/// [Ref.invalidate(initialSyncCompleteProvider)], causing a fresh read.
///
/// Layering: lives in core/sync/ — no feature-layer imports.
final initialSyncCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kInitialSyncCompleteKey) ?? false;
});

/// Sets the "initial sync complete" flag to `true` in SharedPreferences, then
/// optionally calls [onComplete] to notify any Riverpod watchers.
///
/// IDEMPOTENT — reads the existing value first and returns immediately if the
/// flag is already `true`.  Only one write ever occurs across the lifetime of
/// the app.
///
/// [onComplete] is called only when the flag transitions from unset → true so
/// the caller can invalidate [initialSyncCompleteProvider] exactly once.
///
/// Called by [SyncOrchestratorImpl.pullOnLaunch] after every entity kind has
/// been pulled successfully.
Future<void> markInitialSyncComplete({void Function()? onComplete}) async {
  final prefs = await SharedPreferences.getInstance();
  final already = prefs.getBool(kInitialSyncCompleteKey) ?? false;
  if (!already) {
    await prefs.setBool(kInitialSyncCompleteKey, true);
    onComplete?.call();
  }
}
