import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/account_functions_provider.dart';
import 'package:learning_tracker/data/repositories/parent_session_client.dart';
import 'package:learning_tracker/data/repositories/parent_session_controller.dart';
import 'package:learning_tracker/data/repositories/parent_session_persistence.dart';
import 'package:learning_tracker/data/repositories/parent_session_state.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:learning_tracker/data/repositories/parent_session_state.dart';

part 'parent_pin_session_provider.g.dart';

/// Profile id for which the parent PIN was verified in this app session.
///
/// When this equals the active profile id, the parent is treated as acting
/// for that (child) profile — e.g. manual lifetime completions in Settings.
// keepAlive: PIN verification must persist for the rest of the app session, not just one screen.
@Riverpod(keepAlive: true)
class ParentPinAuthenticatedProfileId
    extends _$ParentPinAuthenticatedProfileId {
  @override
  String? build() => null;

  void setAuthenticated(String profileId) => state = profileId;

  void clear() => state = null;
}

/// The short-lived server session API for the active named Firebase app.
final parentSessionClientProvider = Provider<ParentSessionClient>((ref) {
  final resolveFunctions = ref.watch(accountFunctionsProvider);
  return ParentSessionClient((name, data) async {
    final result = await (await resolveFunctions())
        .httpsCallable(name)
        .call<Map<String, dynamic>>(data);
    return decodeParentSessionCallableResult(result.data);
  });
});

final parentSessionPersistenceProvider = Provider<ParentSessionPersistence>(
  (ref) => ParentSessionPersistence(ref.watch(flutterSecureStorageProvider)),
);

/// The active account's session lifecycle. Every lease captures its account's
/// Firestore and Functions handles before the active-account pointer changes.
final parentSessionControllerProvider = Provider<ParentSessionController>((
  ref,
) {
  return ParentSessionController(
    client: ref.read(parentSessionClientProvider),
    currentSessionId: () => ref.read(parentSessionIdProvider),
    setSessionId: (sessionId) =>
        ref.read(parentSessionIdProvider.notifier).set(sessionId),
    setSessionProfileId: (profileId) =>
        ref.read(parentSessionProfileIdProvider.notifier).set(profileId),
    clearSessionId: () => ref.read(parentSessionIdProvider.notifier).clear(),
    clearSessionProfileId: () =>
        ref.read(parentSessionProfileIdProvider.notifier).clear(),
    resolveBinding: () => ref.read(parentSessionAccountBindingResolverProvider)(
      ref.read(parentSessionPersistenceProvider),
    ),
    onLockStateChanged: (state) =>
        ref.read(parentSessionLockStateProvider.notifier).set(state),
    disableNetwork: () async {},
    enableNetwork: () async {},
  );
});

/// On startup, revoke any lease that survived process death before allowing
/// this account's Firestore network back online.
final parentSessionStartupProvider = FutureProvider<void>((ref) async {
  final persistence = ref.read(parentSessionPersistenceProvider);
  final sessionId = await ref.read(parentSessionPersistedLeaseResolverProvider)(
    persistence,
  );
  if (sessionId == null) return;

  final controller = ref.read(parentSessionControllerProvider);
  try {
    await controller.recoverPersistedSession(sessionId);
  } catch (_) {
    // Keep startup moving with the network disabled. The controller exposes
    // lockFailed and retains the lease for an explicit retry from the UI.
  }
});
