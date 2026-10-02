/// The AD-27 / AD-50 achievement latch record as every achievement surface
/// reads it (DNI-480): `preferences/gamification_settings
/// .unlocked_achievement_ids` of the active learner, live. No surface
/// derives "unlocked" from points thresholds any more; `LearningCommands`
/// is the only writer of the list (array union after a write).
library;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/repositories/firestore_reward_settings_repository.dart';
import 'package:learning_tracker/features/gamification/data/repositories/engine_points_reader.dart';

/// The active learner's latched achievement ids, live: a latch on any
/// device reaches every surface, because a change of the settings
/// document's list re-reads this provider.
///
/// A one-shot read plus a raw snapshot subscription rather than a
/// `StreamProvider`: Riverpod pauses an unlistened stream provider, which
/// would stall a surface read with `read(...future)`. Kept alive (one
/// document listener per active learner) so the auto-disposed surfaces that
/// read it can rebuild freely.
///
/// With no active learner it is an error (D-E: never a fabricated "nothing
/// unlocked").
final unlockedAchievementIdsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = await ref.watch(
    firestoreRewardSettingsRepositoryProvider.future,
  );
  if (repo == null) {
    throw PointsNotReadyException('no reward settings repository');
  }
  final current = await repo.readUnlockedAchievementIds();
  final changes = repo.watchUnlockedAchievementIds().listen((ids) {
    if (!setEquals(ids, current)) ref.invalidateSelf();
  }, onError: (Object _) {});
  ref.onDispose(changes.cancel);
  return current;
}, retry: (retryCount, error) => null);
