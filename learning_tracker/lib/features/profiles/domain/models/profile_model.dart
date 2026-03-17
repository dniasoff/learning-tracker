import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/database/app_database.dart' as drift;

part 'profile_model.freezed.dart';

/// Domain model for a learner profile.
@freezed
abstract class ProfileModel with _$ProfileModel {
  const factory ProfileModel({
    required int id,
    required int accountId,
    required String displayName,
    required String mode, // 'child' or 'adult'
    required int avatarIndex,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ProfileModel;

  /// Converts a Drift [drift.Profile] row into a domain [ProfileModel].
  factory ProfileModel.fromDriftRow(drift.Profile row) => ProfileModel(
    id: row.id,
    accountId: row.accountId,
    displayName: row.displayName,
    mode: row.mode,
    avatarIndex: row.avatarIndex,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
