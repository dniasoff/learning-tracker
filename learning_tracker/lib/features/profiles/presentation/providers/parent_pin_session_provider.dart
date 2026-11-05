import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/account_functions_provider.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/repositories/parent_session_client.dart';
import 'package:learning_tracker/data/repositories/parent_session_controller.dart';
import 'package:learning_tracker/data/repositories/parent_session_persistence.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

/// The currently active server-issued parent session id, or `null` when the
/// parent PIN gate is locked. This is intentionally separate from the local
/// PIN marker: a local unlock is not authorization until the callable returns
/// this id.
@Riverpod(keepAlive: true)
class ParentSessionId extends _$ParentSessionId {
  @override
  String? build() => null;

  void set(String sessionId) => state = sessionId;

  void clear() => state = null;
}

/// The short-lived server session API for the active named Firebase app.
final parentSessionClientProvider = Provider<ParentSessionClient>((ref) {
  final resolveFunctions = ref.watch(accountFunctionsProvider);
  return ParentSessionClient((name, data) async {
    final result = await (await resolveFunctions())
        .httpsCallable(name)
        .call<Map<String, dynamic>>(data);
    final raw = Map<String, Object?>.from(result.data as Map);
    final expiry = raw['expiresAt'];
    if (expiry is Timestamp) raw['expiresAt'] = expiry.toDate().toUtc();
    return raw;
  });
});

final parentSessionPersistenceProvider = Provider<ParentSessionPersistence>(
  (ref) => ParentSessionPersistence(ref.watch(flutterSecureStorageProvider)),
);

/// The active account's session lifecycle. Firestore is resolved lazily so
/// locking remains safe during account teardown and account switching.
final parentSessionControllerProvider = Provider<ParentSessionController>((
  ref,
) {
  Future<FirebaseFirestore?> firestore() async =>
      (await ref.read(activeAccountFirebaseProvider.future))?.firestore;

  return ParentSessionController(
    client: ref.read(parentSessionClientProvider),
    currentSessionId: () => ref.read(parentSessionIdProvider),
    setSessionId: (sessionId) =>
        ref.read(parentSessionIdProvider.notifier).set(sessionId),
    clearSessionId: () => ref.read(parentSessionIdProvider.notifier).clear(),
    disableNetwork: () async {
      await (await firestore())?.disableNetwork();
    },
    enableNetwork: () async {
      await (await firestore())?.enableNetwork();
    },
    persistSessionId: (sessionId) async {
      final handles = await ref.read(activeAccountFirebaseProvider.future);
      if (handles != null) {
        await ref
            .read(parentSessionPersistenceProvider)
            .write(handles.uid, sessionId);
      }
    },
    clearPersistedSessionId: () async {
      final handles = await ref.read(activeAccountFirebaseProvider.future);
      if (handles != null) {
        await ref.read(parentSessionPersistenceProvider).clear(handles.uid);
      }
    },
  );
});

/// On startup, revoke any lease that survived process death before allowing
/// this account's Firestore network back online.
final parentSessionStartupProvider = FutureProvider<void>((ref) async {
  final handles = await ref.read(activeAccountFirebaseProvider.future);
  if (handles == null) return;
  final persistence = ref.read(parentSessionPersistenceProvider);
  final sessionId = await persistence.read(handles.uid);
  if (sessionId == null) return;

  await handles.firestore.disableNetwork();
  await ref.read(parentSessionClientProvider).revoke(sessionId);
  await persistence.clear(handles.uid);
  await handles.firestore.enableNetwork();
});
