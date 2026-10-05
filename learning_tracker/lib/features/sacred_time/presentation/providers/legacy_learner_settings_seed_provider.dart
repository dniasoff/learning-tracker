/// Heals the stuck Sacred-Time lock of profiles created before learner
/// settings existed (pre-1.0.74): while the signed-in account's learner
/// settings cannot be read, this device seeds them once
/// ([LegacyLearnerSettingsSeeder]), and `learnerLockSettingsProvider`
/// then delivers them live.
///
/// Mounted app-wide by `LearningTrackerApp`, beside the lock overlay it
/// unblocks.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/legacy_learner_settings_seeder.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';

/// Watches every learner that drives this device's lock; when one's
/// settings error (a legacy profile with no `time_zone` decodes as an
/// error), asks the seeder to seed it — once per learner while this
/// provider lives, again after a failed attempt (e.g. offline). The seeder
/// writes nothing for a profile that already has settings, and a learner
/// whose settings are merely not ready yet is skipped.
final legacyLearnerSettingsSeedProvider = Provider<void>((ref) {
  final scopes = ref.watch(lockDrivingScopesProvider).value ?? const [];
  final attempted = <LearnerScope>{};
  for (final scope in scopes) {
    ref.listen(learnerLockSettingsProvider(scope), (_, next) {
      final error = next.error;
      if (error == null ||
          error is LearnerSettingsNotReadyException ||
          !attempted.add(scope)) {
        return;
      }
      unawaited(
        ref
            .read(legacyLearnerSettingsSeederProvider)
            .seedIfLegacy(scope)
            .then<void>(
              (_) {},
              onError: (Object e, StackTrace st) {
                attempted.remove(scope); // retry on the next error
                AppLogger.instance.warning(
                  event: 'legacy_learner_settings_seed_failed',
                  fields: {'profileId': scope.profileId},
                  exception: e,
                  stackTrace: st,
                );
              },
            ),
      );
    }, fireImmediately: true);
  }
});
