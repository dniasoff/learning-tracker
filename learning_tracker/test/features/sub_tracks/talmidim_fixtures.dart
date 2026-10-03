/// Shared fixtures for the My talmidim tests (Story 4.3, DNI-511).
library;

import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
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
