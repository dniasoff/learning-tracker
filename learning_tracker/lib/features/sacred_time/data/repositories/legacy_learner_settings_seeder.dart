/// Seeds the AD-37 learner settings of the signed-in account's profiles
/// that were created before learner settings existed (pre-1.0.74), the
/// repository-layer half of the stuck Sacred-Time lock hotfix.
///
/// Such a profile has no `time_zone`, so `learnerLockSettingsProvider`
/// errors and every lock reader fails closed: the overlay judged the
/// learner with the fail-closed window and every capture was refused.
/// Profile creation seeds the creating device's settings (DNI-470 AC-6);
/// an existing profile is seeded the same way, once, by the owner's
/// device: the device's IANA zone, diaspora, no location (the FR-23
/// fail-closed no-location window until a parent sets one).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/profiles/data/repositories/creating_device_settings_source.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart'
    show LearnerTimeZoneUnavailableException;

/// Seeds a legacy profile's settings from this device.
abstract interface class LegacyLearnerSettingsSeeder {
  /// Seeds [scope]'s settings when its profile has none; true when a seed
  /// was written. A profile that already has settings, a scope outside the
  /// signed-in account, or a device zone that cannot be read writes
  /// nothing.
  Future<bool> seedIfLegacy(LearnerScope scope);
}

/// The Firestore [LegacyLearnerSettingsSeeder]: the signed-in account's
/// profile repository and the creating-device settings source.
final class FirestoreLegacyLearnerSettingsSeeder
    implements LegacyLearnerSettingsSeeder {
  /// Creates the seeder over [ref].
  FirestoreLegacyLearnerSettingsSeeder(this._ref);

  final Ref _ref;

  @override
  Future<bool> seedIfLegacy(LearnerScope scope) async {
    final repo = await _ref.read(
      firestoreLearnerProfileRepositoryProvider.future,
    );
    if (repo == null || repo.uid != scope.ownerUid) return false;
    final device = await _ref.read(creatingDeviceSettingsSourceProvider).read();
    try {
      final seeded = await repo.seedLegacySettings(
        device.seedFor(scope.profileId),
      );
      if (seeded) {
        AppLogger.instance.info(
          event: 'legacy_learner_settings_seeded',
          fields: {'profileId': scope.profileId},
        );
      }
      return seeded;
    } on LearnerTimeZoneUnavailableException {
      return false; // the fail-closed lock stays until a zone can be read
    }
  }
}

/// The [LegacyLearnerSettingsSeeder] (tests override it).
final legacyLearnerSettingsSeederProvider =
    Provider<LegacyLearnerSettingsSeeder>(
      FirestoreLegacyLearnerSettingsSeeder.new,
    );
