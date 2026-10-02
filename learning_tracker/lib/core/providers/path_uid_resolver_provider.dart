import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/registry/path_uid_resolver.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';

/// The app's [PathUidResolver] over the device registry — the single
/// accessor for the persisted Firestore-path uid (`users/{uid}/…`, AD-24
/// rule 2), and the reconcile step every session-establishing flow runs
/// after a sign-in or anonymous session (DNI-520).
final pathUidResolverProvider = Provider<PathUidResolver>(
  (ref) =>
      PathUidResolver(ref.watch(deviceRegistryProvider), logger: AppLogger.instance),
);
