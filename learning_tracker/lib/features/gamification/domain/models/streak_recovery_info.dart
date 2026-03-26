import 'package:freezed_annotation/freezed_annotation.dart';

part 'streak_recovery_info.freezed.dart';

/// Information about a streak recovery event.
///
/// When a user misses exactly 1 day but their streak is preserved
/// via the grace period mechanism.
@freezed
abstract class StreakRecoveryInfo with _$StreakRecoveryInfo {
  const factory StreakRecoveryInfo({
    required bool wasRecovered,
    required int currentStreak,
    DateTime? missedDate,
  }) = _StreakRecoveryInfo;
}
