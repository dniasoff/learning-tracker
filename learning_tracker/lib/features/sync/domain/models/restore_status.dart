import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_error_code.dart';

part 'restore_status.freezed.dart';

/// Status of a new-device data restore operation.
@freezed
sealed class RestoreStatus with _$RestoreStatus {
  /// No restore needed (existing device with data).
  const factory RestoreStatus.idle() = RestoreStatusIdle;

  /// Checking whether this device needs a restore.
  const factory RestoreStatus.checking() = RestoreStatusChecking;

  /// Restore in progress with a descriptive phase label.
  const factory RestoreStatus.restoring({
    required String phase,
    required int completedSteps,
    required int totalSteps,
  }) = RestoreStatusRestoring;

  /// Restore completed successfully.
  const factory RestoreStatus.complete({required int collectionsRestored}) =
      RestoreStatusComplete;

  /// Restore failed with an error.
  ///
  /// EH-5: [code] is a stable, localizable category — never a pre-formatted
  /// human message. Presentation resolves the user-facing string for [code]
  /// through `AppLocalizations`. [debugDetail], when present, is technical
  /// and must NEVER be rendered directly to the user — logs/diagnostics only.
  const factory RestoreStatus.error({
    required SyncErrorCode code,
    String? debugDetail,
  }) = RestoreStatusError;
}
