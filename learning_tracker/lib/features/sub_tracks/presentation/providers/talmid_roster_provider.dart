/// The My talmidim roster read (Story 4.3, DNI-511, T1; FR-29, AD-53).
///
/// [talmidRosterProvider] is the tutor's ACTIVE grants, from one
/// authoritative `listTutorGrants` read per load. It is scoped to the
/// signed-in account ([talmidRosterAccountKeyProvider]), so an account
/// switch never shows the previous tutor's rows, and it is `autoDispose`,
/// so every visit re-reads the live grant set. A failed read stays an
/// error ([TutorRosterLoadException]), never an empty roster (AC-6).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/repositories/firestore_tutor_roster_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart'
    show tutorGrantRepositoryProvider;

/// The roster repository: the existing incoming-grants callable read.
final tutorRosterRepositoryProvider = Provider<TutorRosterRepository>(
  (ref) => FirestoreTutorRosterRepository(
    ref.watch(tutorGrantRepositoryProvider).listIncomingGrantsWithStatus,
  ),
);

/// The signed-in account the roster belongs to (its Firebase uid); a change
/// re-reads the roster so no previous account's talmid survives a switch.
final talmidRosterAccountKeyProvider = Provider<String?>(
  (ref) =>
      ref.watch(authStateProvider.select((s) => s.currentUser?.firebaseUid)),
);

/// The tutor's active talmidim, re-read on every visit and account change.
final talmidRosterProvider =
    FutureProvider.autoDispose<List<TalmidRosterEntry>>((ref) {
      ref.watch(talmidRosterAccountKeyProvider);
      return ref.watch(tutorRosterRepositoryProvider).loadActiveTalmidim();
    }, retry: (retryCount, error) => null);
