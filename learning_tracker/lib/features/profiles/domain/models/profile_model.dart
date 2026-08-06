import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/database/user/user_database.dart'
    as drift;
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';

part 'profile_model.freezed.dart';

/// Domain model for a learner profile.
@freezed
abstract class ProfileModel with _$ProfileModel {
  // Private const constructor required for custom getters on freezed classes.
  const ProfileModel._();

  const factory ProfileModel({
    required int id,
    required int accountId,
    required String displayName,
    required String mode, // 'child' or 'adult' — raw storage key
    required int avatarIndex,
    required DateTime createdAt,
    required DateTime updatedAt,
    // Firestore-native profile identity, minted eagerly and unconditionally
    // at creation (`ProfileRepositoryImpl`, P2-2) — never null, never
    // cleared. This field disappears along with the Drift-backed [id] once
    // the app is fully cut over to Firestore-native profile identity.
    required String ulid,
  }) = _ProfileModel;

  /// Typed profile mode derived from the raw [mode] storage key.
  ///
  /// Prefer this over direct string comparisons (`profile.mode == 'child'`).
  /// Falls back to [ProfileMode.adult] for any unrecognised [mode] value.
  ///
  /// Delegates to [ProfileMode.tryFromStorageKey] rather than
  /// re-implementing the string↔enum mapping here (AUD-core-domain-04: the
  /// two mappings had drifted to different error-handling semantics — throw
  /// vs. silent default — for what is meant to be the same conversion).
  /// This deliberately uses [ProfileMode.tryFromStorageKey] rather than
  /// wrapping the throwing [ProfileMode.fromStorageKey] in a try/catch: EH-4
  /// (`docs/coding-standards.md`) forbids catching `Error` subtypes as
  /// control flow, and [ProfileMode.fromStorageKey] throws [ArgumentError]
  /// (an [Error]) for exactly this case — see the "never the right way to
  /// get a fallback" note on [ProfileMode.tryFromStorageKey] itself, which
  /// mirrors `AccountTier.tryFromStorageKey` / `DeviceAccountX.accountTier`'s
  /// established EH-4-compliant shape.
  ProfileMode get profileMode =>
      ProfileMode.tryFromStorageKey(mode) ?? ProfileMode.adult;

  /// Converts a Drift [drift.LearnerProfile] row into a domain [ProfileModel].
  ///
  /// The Drift `ulid` column stays nullable (it is not worth a schema bump
  /// for a column deleted wholesale in Phase 4 — see `learner_profiles.dart`),
  /// so this factory is the enforcement point for [ulid]'s non-null domain
  /// contract. A `null` column value here means the row predates P2-2's eager
  /// mint — greenfield, so the remedy is to wipe and reseed the device, never
  /// a silent fallback identity.
  factory ProfileModel.fromDriftRow(drift.LearnerProfile row) {
    final ulid = row.ulid;
    if (ulid == null) {
      throw StateError(
        'ProfileModel.fromDriftRow: profile id ${row.id} has no ulid — '
        'pre-P2-2 profile row with no ULID — wipe and reseed the device',
      );
    }
    return ProfileModel(
      id: row.id,
      accountId: row.accountId,
      displayName: row.displayName,
      mode: row.mode,
      avatarIndex: row.avatarIndex,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      ulid: ulid,
    );
  }
}
