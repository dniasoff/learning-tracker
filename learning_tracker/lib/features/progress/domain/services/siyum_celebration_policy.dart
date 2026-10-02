/// Which siyumim to celebrate on this device (DNI-474 AC-4; Consistency →
/// Siyum; FR-17; `prd-deviations` #11).
///
/// The engine's completed units are the sole trigger. A completion is keyed
/// per device by `(profileId, unit, first_completed_at(1))`
/// ([ProfileScopedPreferenceKeys.siyumShown]):
///
/// * a unit whose k = 1 key is not stored yet is celebrated once (from any
///   source, including backfill and correction);
/// * later completions (k ≥ 2, chazara) keep the same k = 1 instant, so they
///   never re-fire;
/// * a stored key whose completion is gone (a void took the siyum away, or
///   a correction moved its first-completion instant) is cleared, so the
///   re-completion celebrates again;
/// * the first evaluation of a profile on a device seeds every current
///   completion without celebrating.
library;

import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// One siyum to celebrate.
final class SiyumToCelebrate {
  /// Creates the value.
  const SiyumToCelebrate({
    required this.curriculumId,
    required this.unit,
    required this.completedAt,
  });

  /// The unit's curriculum.
  final String curriculumId;

  /// The completed unit.
  final NodeEntry unit;

  /// Its `first_completed_at(1)`.
  final DateTime completedAt;

  @override
  bool operator ==(Object other) =>
      other is SiyumToCelebrate &&
      other.curriculumId == curriculumId &&
      other.unit == unit &&
      other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(curriculumId, unit, completedAt);

  @override
  String toString() => 'SiyumToCelebrate($curriculumId, ${unit.ref})';
}

/// The outcome of one evaluation: what to show and how the device's stored
/// keys change.
final class SiyumCelebrationPlan {
  /// Creates the plan.
  const SiyumCelebrationPlan({
    this.celebrate = const [],
    this.keysToAdd = const {},
    this.keysToRemove = const {},
    this.markSeeded = false,
  });

  /// Siyumim to celebrate, in completion order.
  final List<SiyumToCelebrate> celebrate;

  /// Shown keys to store.
  final Set<String> keysToAdd;

  /// Stored keys whose completion is gone.
  final Set<String> keysToRemove;

  /// Whether this evaluation seeds the profile on this device.
  final bool markSeeded;

  /// Whether nothing changes.
  bool get isEmpty =>
      celebrate.isEmpty &&
      keysToAdd.isEmpty &&
      keysToRemove.isEmpty &&
      !markSeeded;
}

/// Plans the celebrations for [profileId] from [state] given the device's
/// [storedKeys] (every stored key, any prefix) and whether the profile is
/// already [seeded] here. [celebrates] filters by the siyum granularity:
/// a unit it rejects is recorded as shown without a celebration.
SiyumCelebrationPlan planSiyumCelebrations({
  required String profileId,
  required LearnerState state,
  required Set<String> storedKeys,
  required bool seeded,
  bool Function(String curriculumId, NodeEntry unit)? celebrates,
}) {
  final prefix = ProfileScopedPreferenceKeys.siyumShownPrefix(profileId);
  final stored = {
    for (final k in storedKeys)
      if (k.startsWith(prefix)) k,
  };
  final current = <String, SiyumToCelebrate>{};
  for (final MapEntry(key: curriculumId, value: curriculum)
      in state.curricula.entries) {
    for (final unit in curriculum.completedUnits) {
      final first = unit.firstCompletedAt[1];
      if (first == null) continue;
      current[ProfileScopedPreferenceKeys.siyumShown(
        profileId,
        curriculumId,
        unit.unit.ref,
        first,
      )] = SiyumToCelebrate(
        curriculumId: curriculumId,
        unit: unit.unit,
        completedAt: first,
      );
    }
  }
  final keysToRemove = stored.difference(current.keys.toSet());
  final fresh = [
    for (final MapEntry(:key, :value) in current.entries)
      if (!stored.contains(key)) (key, value),
  ];
  if (!seeded) {
    return SiyumCelebrationPlan(
      keysToAdd: {for (final (key, _) in fresh) key},
      keysToRemove: keysToRemove,
      markSeeded: true,
    );
  }
  final celebrate = [
    for (final (_, siyum) in fresh)
      if (celebrates == null || celebrates(siyum.curriculumId, siyum.unit))
        siyum,
  ]..sort((a, b) => a.completedAt.compareTo(b.completedAt));
  return SiyumCelebrationPlan(
    celebrate: celebrate,
    keysToAdd: {for (final (key, _) in fresh) key},
    keysToRemove: keysToRemove,
  );
}
