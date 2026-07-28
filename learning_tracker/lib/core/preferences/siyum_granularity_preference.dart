import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-(profile, curriculum) preference for siyum (milestone) granularity.
///
/// The stored value is the **finest** [MilestoneLevel] a family wants
/// celebrated for this curriculum. Milestones are nested — `unit` ⊂
/// `aggregate` ⊂ `curriculum` — and the journey layer keeps a milestone iff
/// its level is at or above the chosen one (see `filterMilestonesByGranularity`
/// in `features/progress/domain/siyum_granularity_filter.dart`). Because the
/// gate only ever **suppresses** already-emitted milestones it can never
/// fabricate one.
///
/// Default is [MilestoneLevel.unit] — the finest tier — so an unset preference
/// reproduces the current shipped behaviour (every tier fires).
///
/// One instance is created per curriculum (the value is per-curriculum); the
/// [ProfileScopedPreference] base still scopes reads/writes by `profileId`, and
/// the curriculum is folded into the storage key.
class SiyumGranularityPreference
    extends ProfileScopedPreference<MilestoneLevel> {
  SiyumGranularityPreference(this.curriculum);

  /// The curriculum this preference instance is scoped to.
  final CurriculumId curriculum;

  @override
  MilestoneLevel get defaultValue => MilestoneLevel.unit;

  @override
  MilestoneLevel readFromPrefs(SharedPreferences prefs, int profileId) {
    final raw = prefs.getString(
      ProfileScopedPreferenceKeys.siyumGranularity(
        profileId,
        curriculum.storageKey,
      ),
    );
    return _parse(raw);
  }

  @override
  Future<void> writeToPrefs(
    SharedPreferences prefs,
    int profileId,
    MilestoneLevel value,
  ) async {
    await prefs.setString(
      ProfileScopedPreferenceKeys.siyumGranularity(
        profileId,
        curriculum.storageKey,
      ),
      value.name,
    );
  }

  /// Parse the persisted enum-name string back to a [MilestoneLevel], falling
  /// back to [defaultValue] for a missing or unrecognised value.
  MilestoneLevel _parse(String? raw) {
    for (final level in MilestoneLevel.values) {
      if (level.name == raw) return level;
    }
    return defaultValue;
  }
}
