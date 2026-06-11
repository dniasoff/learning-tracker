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
    this.loading = false,
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

  /// Maximum allowed length for a reward name (GA-2).
  static const int kMaxNameLength = 50;

  /// Maximum allowed point cost for a reward (GA-2).
  static const int kMaxPointsCost = 99999;

  /// `true` when the selected reward ladder is the global (total-points) one.
  bool get usesGlobalLadder => tracks.isEmpty || isGlobalReward;

  int get previewPoints => int.tryParse(pointsText.trim()) ?? 0;

  /// `true` when the form is editing an existing milestone (GA-7).
  bool get isEditing => editingMilestoneId != null;

  /// `true` when the form state is valid enough to enable the Save button (GA-7).
  ///
  /// Name must be non-empty (after trim); points must parse as a positive
  /// integer within the allowed range. This mirrors the validation in
  /// [RewardConfigController.saveReward] so the Save button is disabled
  /// before a submit attempt, preventing the silent-no-op UX.
  bool get canSave {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > kMaxNameLength)
      return false;
    final pts = int.tryParse(pointsText.trim()) ?? 0;
    if (pts <= 0 || pts > kMaxPointsCost) return false;
    return true;
  }

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
