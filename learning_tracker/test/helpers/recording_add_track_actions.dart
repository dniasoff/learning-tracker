/// A recording [AddTrackActionRepository] for TrackCreationService tests
/// (DNI-476 AC-5): every Add track action is captured as its plan.
library;

import 'package:learning_tracker/features/tracks/setup/domain/repositories/add_track_action_repository.dart';

/// Records every Add track action.
final class RecordingAddTrackActions implements AddTrackActionRepository {
  /// Every plan applied, in order.
  final List<AddTrackPlan> plans = [];

  /// When set, [applyAddTrack] throws it.
  Exception? failWith;

  @override
  Future<String?> applyAddTrack(AddTrackPlan plan) async {
    final error = failWith;
    if (error != null) throw error;
    plans.add(plan);
    return 'action-${plans.length}';
  }
}
