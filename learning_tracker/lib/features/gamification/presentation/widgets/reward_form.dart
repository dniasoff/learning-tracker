import 'package:freezed_annotation/freezed_annotation.dart';

part 'reward_form.freezed.dart';

/// Immutable snapshot of the reward configuration form state.
///
/// Held by [RewardConfigController] and observed by the screen
/// to drive reactive UI updates without `setState`.
///
/// AUD-gamification-22 (SM/coding-standards "Domain/state models are
/// immutable @freezed classes ... never hand-write ==/hashCode"):
/// previously a hand-written class with no `==`/`hashCode` override, so
/// Riverpod's default identity-based `updateShouldNotify` always treated
/// every `copyWith()` result — including a no-op one — as changed,
/// defeating rebuild-skipping for every widget watching
/// [RewardConfigController]. Converted to `@freezed` for generated
/// value-equality; the private const constructor + getters/statics below
/// preserve the original public API exactly (mirrors the
/// `TutorPermissions` freezed-with-extra-getters pattern).
@freezed
abstract class RewardForm with _$RewardForm {
  const RewardForm._();

  const factory RewardForm({
    @Default('') String name,
    @Default('') String pointsText,
    @Default(0) int iconIndex,
    String? editingMilestoneId,
    @Default(false) bool loading,
    String? error,
  }) = _RewardForm;

  /// Maximum allowed length for a reward name (GA-2).
  static const int kMaxNameLength = 50;

  /// Maximum allowed point cost for a reward (GA-2).
  static const int kMaxPointsCost = 99999;

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
    if (trimmedName.isEmpty || trimmedName.length > kMaxNameLength) {
      return false;
    }
    final pts = int.tryParse(pointsText.trim()) ?? 0;
    if (pts <= 0 || pts > kMaxPointsCost) return false;
    return true;
  }
}
