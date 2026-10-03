/// Shared fixtures for the My talmidim tests (Story 4.3, DNI-511).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is only re-exported from `misc.dart` (as test/helpers/pump_app).
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_row_state_provider.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

/// The owner uid of the [n]th test parent.
String talmidOwner(int n) => 'parent-uid-$n';

/// The learner profile ULID of the [n]th talmid.
String talmidProfile(int n) => engineUlid(7000 + n);

/// A `listTutorGrants` grant in [state] for talmid [n].
TutorGrant talmidGrant(
  int n, {
  TutorGrantState state = TutorGrantState.active,
  String? name,
  bool canEditLearning = true,
  int owner = 1,
}) {
  final at = DateTime.utc(2026, 9, 1);
  return TutorGrant.fromDoc(
    TutorGrantDoc(
      grantId: 'grant-$n',
      parentUid: talmidOwner(owner),
      childProfileId: talmidProfile(n),
      tutorEmail: 'rebbe@example.com',
      tutorUid: 'tutor-uid',
      state: state,
      invitedAt: at,
      updatedAt: at,
      childName: name,
    ),
    permissions: TutorPermissions(canEditLearning: canEditLearning),
  );
}

/// The roster entry of talmid [n].
TalmidRosterEntry talmidEntry(
  int n, {
  String? name,
  bool canEditLearning = true,
  int owner = 1,
}) => TalmidRosterEntry(
  grantId: 'grant-$n',
  ownerUid: talmidOwner(owner),
  profileId: talmidProfile(n),
  displayName: name,
  permissions: TutorPermissions(canEditLearning: canEditLearning),
);

/// A roster repository answering from a script: each load pops the next
/// answer (a list, or an error to throw); the last one repeats.
final class ScriptedTutorRosterRepository implements TutorRosterRepository {
  /// Creates the repository.
  ScriptedTutorRosterRepository(this.answers);

  /// The scripted answers.
  final List<Object> answers;

  /// Loads so far.
  int loads = 0;

  @override
  Future<List<TalmidRosterEntry>> loadActiveTalmidim() async {
    final answer = answers[loads < answers.length ? loads : answers.length - 1];
    loads++;
    if (answer is List<TalmidRosterEntry>) return answer;
    if (answer is Exception) throw answer;
    throw StateError('unscripted answer: $answer');
  }
}

/// The scope of talmid [n].
LearnerScope talmidScope(int n, {int owner = 1}) =>
    LearnerScope(ownerUid: talmidOwner(owner), profileId: talmidProfile(n));

/// Per-scope inputs for the row providers: engine states and lock states
/// (loading when absent), and how often each was read.
final class FakeTalmidInputs {
  /// The engine state of each scope.
  final Map<LearnerScope, AsyncValue<LearnerState>> states = {};

  /// The lock state of each scope; open by default.
  final Map<LearnerScope, AsyncValue<bool>> locks = {};

  /// Scopes without an entry in [locks] are this.
  AsyncValue<bool> defaultLock = const AsyncData(false);

  /// Engine-state reads per scope (one per row evaluation).
  final Map<LearnerScope, int> stateReads = {};

  /// The overrides feeding the row providers from this object.
  List<Override> get overrides => [
    talmidLearnerStateProvider.overrideWith((ref, scope) {
      stateReads[scope] = (stateReads[scope] ?? 0) + 1;
      return states[scope] ?? const AsyncLoading<LearnerState>();
    }),
    talmidLockProvider.overrideWith(
      (ref, scope) => locks[scope] ?? defaultLock,
    ),
  ];
}

/// Records every row timeout diagnostic.
final class RecordingTalmidRowDiagnostics implements TalmidRowDiagnostics {
  /// The stages reported, in order.
  final List<TalmidLoadStage> timeouts = [];

  @override
  void engineLoadTimedOut(TalmidLoadStage stage) => timeouts.add(stage);
}
