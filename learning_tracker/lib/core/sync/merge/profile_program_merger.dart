/// LWW merger for profile-program association rows.
///
/// Natural key: `(profile_id, curriculum_id)` — one row per profile per
/// curriculum. Remote always wins (last-write-wins on `tracking_start_date`
/// is fine; `program_id` and `tracking_start_date` are only ever set via
/// the setup / onboarding flow, so the most-recent write is canonical).
library;

import 'package:learning_tracker/core/sync/codec/profile_program_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class ProfileProgramMerger implements EntityMerger {
  ProfileProgramMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;
  static const _codec = ProfileProgramCodec();

  @override
  String get kind => EntityKind.profileProgram;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final decoded = _codec.decode(row);
      // Skip malformed rows — codec validates curriculum_id + program_id.
      if (decoded == null) continue;

      await _store.upsert(kind: kind, profileId: profileId, fields: row);
    }
  }
}
