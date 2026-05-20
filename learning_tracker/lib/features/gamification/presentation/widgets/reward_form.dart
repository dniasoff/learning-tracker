import 'package:learning_tracker/core/database/user/user_database.dart';

/// Immutable snapshot of the reward configuration form state.
///
/// Held by [RewardConfigController] and observed by the screen
/// to drive reactive UI updates without `setState`.
class RewardForm {
  const RewardForm({
    this.name = '',
    this.pointsText = '',
    this.iconIndex = 0,
    this.isGlobalReward = false,
    this.selectedTrackId,
    this.editingMilestoneId,
    this.tracks = const [],
    this.loading = true,
    this.error,
  });

  final String name;
  final String pointsText;
  final int iconIndex;
  final bool isGlobalReward;
  final int? selectedTrackId;
  final String? editingMilestoneId;
  final List<CurriculumTrack> tracks;
  final bool loading;
  final String? error;

  /// `true` when the selected reward ladder is the global (total-points) one.
  bool get usesGlobalLadder => tracks.isEmpty || isGlobalReward;

  int get previewPoints => int.tryParse(pointsText.trim()) ?? 0;

  RewardForm copyWith({
    String? name,
    String? pointsText,
    int? iconIndex,
    bool? isGlobalReward,
    Object? selectedTrackId = _sentinel,
    Object? editingMilestoneId = _sentinel,
    List<CurriculumTrack>? tracks,
    bool? loading,
    Object? error = _sentinel,
  }) {
    return RewardForm(
      name: name ?? this.name,
      pointsText: pointsText ?? this.pointsText,
      iconIndex: iconIndex ?? this.iconIndex,
      isGlobalReward: isGlobalReward ?? this.isGlobalReward,
      selectedTrackId: selectedTrackId == _sentinel
          ? this.selectedTrackId
          : selectedTrackId as int?,
      editingMilestoneId: editingMilestoneId == _sentinel
          ? this.editingMilestoneId
          : editingMilestoneId as String?,
      tracks: tracks ?? this.tracks,
      loading: loading ?? this.loading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();
