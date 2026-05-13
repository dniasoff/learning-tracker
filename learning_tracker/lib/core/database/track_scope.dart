import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

part 'track_scope.freezed.dart';

/// Identifies a single (profile, track, curriculum) tuple for DAO queries.
///
/// Threaded through track-aware DAO methods (`BaseDao<T>` consumers and
/// scheduler queries) so every read explicitly states which profile + track
/// + curriculum it targets — NFR9, FR1 (DNI-338).
@freezed
abstract class TrackScope with _$TrackScope {
  const factory TrackScope({
    required int profileId,
    required int trackId,
    required CurriculumId curriculumId,
  }) = _TrackScope;
}
