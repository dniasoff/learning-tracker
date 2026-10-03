/// The callable-backed [TutorRosterRepository] (Story 4.3, DNI-511, T1).
///
/// Reads `listTutorGrants({mode: 'incoming'})` through the existing tutor
/// grant read ([IncomingTutorGrantsRead], bound by the provider to
/// `TutorGrantRepository.listIncomingGrantsWithStatus`), keeps only ACTIVE
/// grants (the incoming mode also returns pending invites), and turns a
/// failed call into [TutorRosterLoadException]. No Firestore query, no new
/// callable (AD-53; story Dev context).
library;

import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart'
    show ActiveGrant, TutorGrant;

/// One `listTutorGrants({mode: 'incoming'})` call: the grants and whether
/// the call genuinely succeeded (D18).
typedef IncomingTutorGrantsRead =
    Future<({List<TutorGrant> grants, bool ok})> Function();

/// The roster over the incoming-grants callable.
final class FirestoreTutorRosterRepository implements TutorRosterRepository {
  /// Creates the repository over [readIncoming].
  const FirestoreTutorRosterRepository(this._readIncoming);

  final IncomingTutorGrantsRead _readIncoming;

  @override
  Future<List<TalmidRosterEntry>> loadActiveTalmidim() async {
    final ({List<TutorGrant> grants, bool ok}) result;
    try {
      result = await _readIncoming();
    } on Object {
      throw const TutorRosterLoadException();
    }
    if (!result.ok) throw const TutorRosterLoadException();
    final entries = [
      for (final grant in result.grants)
        if (grant.grantState case ActiveGrant(:final permissions))
          TalmidRosterEntry(
            grantId: grant.grantId,
            ownerUid: grant.parentUid,
            profileId: grant.childProfileId,
            displayName: _name(grant.childName),
            permissions: permissions,
          ),
    ];
    // A stable order across refreshes: by name, then grant id.
    entries.sort((a, b) {
      final byName = (a.displayName ?? '').toLowerCase().compareTo(
        (b.displayName ?? '').toLowerCase(),
      );
      return byName != 0 ? byName : a.grantId.compareTo(b.grantId);
    });
    return entries;
  }

  static String? _name(String? raw) {
    final name = raw?.trim();
    return name == null || name.isEmpty ? null : name;
  }
}
