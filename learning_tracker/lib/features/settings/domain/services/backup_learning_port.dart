/// The learning half of a backup (AD-49, DNI-482): what the backup service
/// may not read or write as raw documents.
///
/// Sub-tracks are read through the Story 1.2 `SubTrackRepository`, and a
/// restore replays the learning record through `LearningCommands`
/// (`importBackup`) bound to each restored profile. The composition root
/// implements it (`data_export_import_providers.dart`); tests fake it.
library;

import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/backup_import_replay.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';

/// Reads and replays a profile's learning record.
abstract interface class BackupLearningPort {
  /// Every sub-track of [profileId], live and tombstoned, as one complete
  /// read. Throws when the read is incomplete or holds undecodable rows
  /// (never a partial export).
  Future<List<SubTrack>> readSubTracks(String profileId);

  /// Replays [input] onto [profileId] through `LearningCommands`.
  Future<BackupReplayResult> replay(String profileId, BackupReplayInput input);

  /// Re-sends [profileId]'s import write [pendingFailureId] unchanged.
  Future<CaptureResult> retry(String profileId, String pendingFailureId);
}
