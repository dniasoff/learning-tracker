import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// LWW merger for profile-program association rows.
///
/// Natural key: `(profile_id, curriculum_id)` — one row per profile per
/// curriculum. Remote always wins (last-write-wins on `tracking_start_date`
/// is fine; `program_id` and `tracking_start_date` are only ever set via
/// the setup / onboarding flow, so the most-recent write is canonical).
///
/// The merge logic mirrors [SyncEngine._mergeProfilePrograms]: validate the
/// required fields (`curriculum_id`, `program_id`), skip malformed rows, and
/// upsert via [MergeStore.upsert] which routes to
/// [DriftMergeStore._upsertProfileProgram].
class ProfileProgramMerger implements EntityMerger {
  ProfileProgramMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;

  @override
  String get kind => EntityKind.profileProgram;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final curriculumId = row['curriculum_id'] as String?;
      final rawProgramId = row['program_id'];
      final programId = rawProgramId is int
          ? rawProgramId
          : int.tryParse(rawProgramId?.toString() ?? '');

      // Skip malformed rows — matches SyncEngine._mergeProfilePrograms behaviour.
      if (curriculumId == null || programId == null) continue;

      await _store.upsert(kind: kind, profileId: profileId, fields: row);
    }
  }
}
