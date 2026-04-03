import 'package:freezed_annotation/freezed_annotation.dart';

part 'chazara_status.freezed.dart';

/// Source of chazara (review) stage configuration.
///
/// [prescribed]      -- program defines review stages (read-only)
/// [userConfigured]  -- user set up review via wizard
enum ChazaraSource { prescribed, userConfigured }

/// Chazara (review) compliance status for a track.
///
/// Secondary signal overlaid on any card variant when review
/// stages are configured.
@freezed
abstract class ChazaraStatus with _$ChazaraStatus {
  const factory ChazaraStatus({
    /// Number of chazara tasks due today.
    required int dueToday,

    /// Number of chazara tasks past their due date.
    required int overdue,

    /// True when no reviews are due or overdue.
    required bool isCaughtUp,

    /// Whether chazara stages are program-prescribed or user-configured.
    required ChazaraSource source,
  }) = _ChazaraStatus;
}
