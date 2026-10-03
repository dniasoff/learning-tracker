/// Riverpod access to the grant-scoped learner read seam (Story 4.2a,
/// DNI-523, ruling B10).
///
/// A separate file (merge-hotspot ruling: new providers beside, not inside,
/// `repository_providers.dart` / `learner_state_repository_providers.dart`).
/// Like those, it takes its Firestore handle ONLY from
/// [activeAccountFirebaseProvider], and treats a missing or unauthenticated
/// account as "not ready" (null), never as a terminal error (ruling B1).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_tutor_scope_grant_source.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';

export 'package:learning_tracker/data/repositories/firestore_tutor_scope_grant_source.dart'
    show isLearnerScopeAccessDenied;

/// [TutorScopeGrantSource] for the signed-in account (as tutor), or null
/// while no account is active or it is unauthenticated.
final tutorScopeGrantSourceProvider = FutureProvider<TutorScopeGrantSource?>((
  ref,
) async {
  final AccountFirebaseHandles? handles;
  try {
    handles = await ref.watch(activeAccountFirebaseProvider.future);
  } on AccountNotAuthenticatedException {
    return null;
  }
  if (handles == null) return null;
  return FirestoreTutorScopeGrantSource(
    firestore: handles.firestore,
    tutorUid: handles.uid,
  );
}, retry: (retryCount, error) => null);
