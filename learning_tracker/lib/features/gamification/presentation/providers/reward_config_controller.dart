import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/reward_milestone_icons.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_form.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reward_config_controller.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Save-result sealed union
// ─────────────────────────────────────────────────────────────────────────────

/// Returned by [RewardConfigController.saveReward] to let the screen decide
/// which UI feedback (dialog/snackbar) to show.
sealed class RewardSaveResult {
  const RewardSaveResult();
}

final class RewardSaved extends RewardSaveResult {
  const RewardSaved({required this.title, required this.wasEditing});
  final String title;
  final bool wasEditing;
}

final class RewardSaveNoTrack extends RewardSaveResult {
  const RewardSaveNoTrack();
}

final class RewardSaveDuplicateThreshold extends RewardSaveResult {
  const RewardSaveDuplicateThreshold();
}

final class RewardSaveInvalidInput extends RewardSaveResult {
  const RewardSaveInvalidInput();
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────

/// Notifier that owns all mutable form state for [RewardConfigurationScreen].
///
/// The screen reads [state] reactively and calls the mutation methods below.
/// Dialog and SnackBar presentation remain in the screen because they require
/// a [BuildContext]; this notifier is pure data + async IO.
@riverpod
class RewardConfigController extends _$RewardConfigController {
  @override
  RewardForm build() => const RewardForm();

  // ── Init ──────────────────────────────────────────────────────────────────

  /// Loads active tracks from the DB and seeds the initial form state.
  Future<void> bootstrap() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final db = ref.read(userDatabaseProvider);
      final profileId = ref.read(activeProfileIdProvider);
      final tracks = await db.trackDao.getActiveTracksForProfile(profileId);
      state = state.copyWith(
        tracks: tracks,
        selectedTrackId: tracks.isNotEmpty ? tracks.first.id : null,
        isGlobalReward: tracks.isEmpty,
        loading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  // ── Field mutations ────────────────────────────────────────────────────────

  void setName(String value) => state = state.copyWith(name: value);
  void setPointsText(String value) => state = state.copyWith(pointsText: value);
  void setIconIndex(int index) => state = state.copyWith(iconIndex: index);

  void setGlobalReward(bool global) {
    if (state.tracks.isEmpty) {
      state = state.copyWith(isGlobalReward: true);
      return;
    }
    state = state.copyWith(isGlobalReward: global);
  }

  void setSelectedTrack(int trackId) =>
      state = state.copyWith(selectedTrackId: trackId);

  // ── Form lifecycle ─────────────────────────────────────────────────────────

  void clearForm() {
    state = state.copyWith(
      editingMilestoneId: null,
      iconIndex: 0,
      name: '',
      pointsText: '',
      isGlobalReward: state.tracks.isEmpty,
    );
  }

  void applyMilestoneToForm(RewardMilestone m) {
    final isGlobal = state.tracks.isEmpty ||
        m.trackId == RewardMilestone.kGlobalTrackSentinel;
    state = state.copyWith(
      editingMilestoneId: m.id,
      isGlobalReward: isGlobal,
      selectedTrackId: isGlobal ? state.selectedTrackId : m.trackId,
      iconIndex: RewardMilestoneIcons.clampIndex(m.iconIndex),
      name: m.title,
      pointsText: '${m.thresholdPoints}',
    );
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  /// Returns all milestones for the currently selected ladder (global or
  /// per-track).
  Future<List<RewardMilestone>> milestonesForCurrentLadder() async {
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final svc = RewardMilestoneService(db, profileId: profileId);
    if (state.usesGlobalLadder) return svc.getGlobalMilestones();
    final tid = state.selectedTrackId;
    if (tid == null) return const [];
    return svc.getMilestonesForTrack(tid);
  }

  Future<bool> _hasDuplicateThreshold(
    int threshold, {
    String? excludeId,
  }) async {
    final list = await milestonesForCurrentLadder();
    for (final m in list) {
      if (excludeId != null && m.id == excludeId) continue;
      if (m.thresholdPoints == threshold) return true;
    }
    return false;
  }

  Future<void> _persistAndSync() async {
    await ref
        .read(syncWriteFacadeProvider)
        ?.pushGamificationSettingsSnapshot();
    ref.invalidate(achievementsOverviewProvider);
    ref.invalidate(dashboardChildNextRewardProvider);
  }

  /// Validates the form and persists the milestone. Returns a [RewardSaveResult]
  /// describing the outcome; the screen shows the appropriate UI feedback.
  Future<RewardSaveResult> saveReward() async {
    final title = state.name.trim();
    final pointsParsed = int.tryParse(state.pointsText.trim()) ?? 0;
    final wasEditing = state.editingMilestoneId != null;

    if (title.isEmpty || pointsParsed <= 0) {
      return const RewardSaveInvalidInput();
    }
    if (!state.usesGlobalLadder && state.selectedTrackId == null) {
      return const RewardSaveNoTrack();
    }
    if (await _hasDuplicateThreshold(
      pointsParsed,
      excludeId: state.editingMilestoneId,
    )) {
      return const RewardSaveDuplicateThreshold();
    }

    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final svc = RewardMilestoneService(db, profileId: profileId);
    final trackId = state.usesGlobalLadder
        ? RewardMilestone.kGlobalTrackSentinel
        : state.selectedTrackId!;

    await svc.upsertMilestone(
      trackId: trackId,
      title: title,
      thresholdPoints: pointsParsed,
      milestoneId: state.editingMilestoneId,
      isEnabled: true,
      iconIndex: RewardMilestoneIcons.clampIndex(state.iconIndex),
    );
    await _persistAndSync();
    clearForm();
    return RewardSaved(title: title, wasEditing: wasEditing);
  }

  /// Toggles the `isEnabled` flag on [m] and syncs.
  Future<void> toggleEnabled(RewardMilestone m) async {
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final svc = RewardMilestoneService(db, profileId: profileId);
    await svc.upsertMilestone(
      trackId: m.trackId,
      title: m.title,
      thresholdPoints: m.thresholdPoints,
      milestoneId: m.id,
      isEnabled: !m.isEnabled,
      iconIndex: RewardMilestoneIcons.clampIndex(m.iconIndex),
    );
    await _persistAndSync();
  }

  /// Deletes [m] from the DB, clears the form if [m] was being edited, and
  /// syncs.
  Future<void> deleteMilestone(RewardMilestone m) async {
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final svc = RewardMilestoneService(db, profileId: profileId);
    await svc.removeMilestone(m.id);
    await _persistAndSync();
    if (state.editingMilestoneId == m.id) clearForm();
  }
}
