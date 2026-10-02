/// Riverpod provider for the parent Change history read port (Story 4.5 /
/// DNI-513). Kept in its own file (orchestrator merge-hotspot ruling) and
/// re-exported from `repository_providers.dart`.
///
/// Built only on the existing seams: the Firestore handle comes from
/// [activeAccountFirebaseProvider] (parent AD-1/AD-24 named-app handles),
/// and the profile scope is passed per call ([LearnerScope] from
/// `activeLearnerScopeProvider`, ruling B10).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_change_history_repository.dart';
import 'package:learning_tracker/features/change_history/domain/repositories/change_history_repository.dart';

/// [ChangeHistoryRepository] over the active account's Firestore handle, or
/// null while no account is active or its session is unauthenticated
/// (ruling B1: not ready, never a terminal error).
final changeHistoryRepositoryProvider =
    FutureProvider<ChangeHistoryRepository?>((ref) async {
      final AccountFirebaseHandles? handles;
      try {
        handles = await ref.watch(activeAccountFirebaseProvider.future);
      } on AccountNotAuthenticatedException {
        return null;
      }
      if (handles == null) return null;
      return FirestoreChangeHistoryRepository(firestore: handles.firestore);
    }, retry: (retryCount, error) => null);
