import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/reward_milestone_icons.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/child_redemption_screen.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_form.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
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

final class RewardSaveDuplicateName extends RewardSaveResult {
  const RewardSaveDuplicateName();
}

final class RewardSaveInvalidInput extends RewardSaveResult {
  const RewardSaveInvalidInput();
}

/// SM-5 (AUD-gamification-10): returned when [RewardConfigController.saveReward]'s
/// underlying I/O (the milestone write or the sync push inside
/// `_persistAndSync`) threw anything other than [TutorWriteException]. The
/// screen doesn't switch on this result for its own feedback — `state.error`
/// (set by [RewardConfigController._handleMutationError] before this is
/// returned) is what drives the full-screen error UI — but keeping
/// [RewardSaveResult] a total sealed union means the switch in
/// `reward_configuration_screen.dart` stays exhaustive.
final class RewardSaveFailed extends RewardSaveResult {
  const RewardSaveFailed();
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

  /// Seeds the initial form state.
  ///
  /// R4o-H2 / DEC-32: per-track rewards were removed from the spend economy —
  /// every reward is now a single global priced spend-item redeemed against the
  /// one debitable balance. The per-track vs Total split is gone, so the form
  /// is always global and no track list is loaded.
  Future<void> bootstrap() async {
    state = state.copyWith(
      tracks: const [],
      selectedTrackId: null,
      isGlobalReward: true,
      loading: false,
      error: null,
    );
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
    final isGlobal =
        state.tracks.isEmpty ||
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

  Future<void> _persistAndSync() async {
    await ref.read(syncWriteFacadeProvider)?.pushGamificationSettingsSnapshot();
    ref.invalidate(achievementsOverviewProvider);
    ref.invalidate(dashboardChildNextRewardProvider);
    // DG-RDMP-02: invalidate the child-facing reward list so that
    // ChildRedemptionScreen immediately reflects any reward the parent just
    // saved, toggled, or deleted — without requiring the child to navigate
    // away and back.
    ref.invalidate(childRedemptionRewardsProvider);
  }

  /// Validates the form and persists the milestone. Returns a [RewardSaveResult]
  /// describing the outcome; the screen shows the appropriate UI feedback.
  Future<RewardSaveResult> saveReward() async {
    final title = state.name.trim();
    final pointsParsed = int.tryParse(state.pointsText.trim()) ?? 0;
    final wasEditing = state.editingMilestoneId != null;

    // GA-2: enforce sane max caps alongside the existing >0 guard.
    if (title.isEmpty ||
        title.length > RewardForm.kMaxNameLength ||
        pointsParsed <= 0 ||
        pointsParsed > RewardForm.kMaxPointsCost) {
      return const RewardSaveInvalidInput();
    }
    if (!state.usesGlobalLadder && state.selectedTrackId == null) {
      return const RewardSaveNoTrack();
    }
    // GA-3: _hasDuplicateThreshold removed — the spend-economy model allows
    // multiple distinct rewards at the same price (no ladder uniqueness
    // constraint).  The RewardSaveDuplicateThreshold result class is kept for
    // any callers that still reference it, but saveReward() no longer returns
    // it for a same-cost add.

    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final svc = RewardMilestoneService(db, profileId: profileId);
    final trackId = state.usesGlobalLadder
        ? RewardMilestone.kGlobalTrackSentinel
        : state.selectedTrackId!;

    // SM-5 (AUD-gamification-10): the DB/network calls below can throw
    // (a corrupted SharedPreferences write, a failed sync push) -- previously
    // unhandled beyond the screen's own TutorWriteException-only try/catch,
    // silently dropping the operation with no spinner and no error shown
    // (an unhandled Future rejection). AsyncValue.guard captures any
    // failure (with its stack trace) rather than a hand-rolled try/catch
    // that assigns `state` directly.
    state = state.copyWith(loading: true, error: null);
    final guarded = await AsyncValue.guard<RewardSaveResult>(() async {
      // Guard against duplicate names within the same reward ladder
      // (Fix #21). When editing, allow the existing reward to keep its own
      // name.
      final currentMilestones = state.usesGlobalLadder
          ? await svc.getGlobalMilestones()
          : await svc.getMilestonesForTrack(trackId);
      final isDuplicateName = currentMilestones.any(
        (m) =>
            m.title.trim().toLowerCase() == title.toLowerCase() &&
            m.id != state.editingMilestoneId,
      );
      if (isDuplicateName) return const RewardSaveDuplicateName();

      await svc.upsertMilestone(
        trackId: trackId,
        title: title,
        thresholdPoints: pointsParsed,
        milestoneId: state.editingMilestoneId,
        isEnabled: true,
        iconIndex: RewardMilestoneIcons.clampIndex(state.iconIndex),
      );
      await _persistAndSync();
      return RewardSaved(title: title, wasEditing: wasEditing);
    });

    switch (guarded) {
      case AsyncData(:final value):
        // Always clear `loading` on the happy path first -- clearForm()
        // does not touch loading/error, so leaving this out would strand
        // the spinner at true forever after a successful save.
        state = state.copyWith(loading: false);
        if (value is RewardSaved) clearForm();
        return value;
      case AsyncError(:final error, :final stackTrace):
        return _handleMutationError(error, stackTrace);
      case AsyncLoading():
        // Unreachable: AsyncValue.guard only ever resolves to data or error.
        state = state.copyWith(loading: false);
        return const RewardSaveFailed();
    }
  }

  /// Toggles the `isEnabled` flag on [m] and syncs.
  Future<void> toggleEnabled(RewardMilestone m) async {
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final svc = RewardMilestoneService(db, profileId: profileId);

    // SM-5 (AUD-gamification-10): see saveReward's doc comment above.
    state = state.copyWith(loading: true, error: null);
    final guarded = await AsyncValue.guard<void>(() async {
      await svc.upsertMilestone(
        trackId: m.trackId,
        title: m.title,
        thresholdPoints: m.thresholdPoints,
        milestoneId: m.id,
        isEnabled: !m.isEnabled,
        iconIndex: RewardMilestoneIcons.clampIndex(m.iconIndex),
      );
      await _persistAndSync();
    });

    switch (guarded) {
      case AsyncData():
        state = state.copyWith(loading: false);
      case AsyncError(:final error, :final stackTrace):
        _handleMutationError(error, stackTrace);
      case AsyncLoading():
        state = state.copyWith(loading: false);
    }
  }

  /// Deletes [m] from the DB, clears the form if [m] was being edited, and
  /// syncs.
  Future<void> deleteMilestone(RewardMilestone m) async {
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final svc = RewardMilestoneService(db, profileId: profileId);

    // SM-5 (AUD-gamification-10): see saveReward's doc comment above.
    state = state.copyWith(loading: true, error: null);
    final guarded = await AsyncValue.guard<void>(() async {
      await svc.removeMilestone(m.id);
      await _persistAndSync();
    });

    switch (guarded) {
      case AsyncData():
        state = state.copyWith(loading: false);
        if (state.editingMilestoneId == m.id) clearForm();
      case AsyncError(:final error, :final stackTrace):
        _handleMutationError(error, stackTrace);
      case AsyncLoading():
        state = state.copyWith(loading: false);
    }
  }

  /// Shared failure handling for the 3 mutation methods above (SM-5,
  /// AUD-gamification-10).
  ///
  /// [TutorWriteException] is rethrown, NOT surfaced through `state.error`
  /// -- the screen's own `on TutorWriteException catch` around every call
  /// site already shows the permission-denied snackbar; surfacing it here
  /// too would additionally replace the whole screen with the full-screen
  /// error state for what is a normal, expected outcome of a restricted
  /// tutor session. Any OTHER exception (a corrupted SharedPreferences
  /// write, a failed sync push) sets `state.error` so the screen's dead
  /// error branch (now wired) shows real feedback instead of a silent
  /// no-op.
  ///
  /// Returns [RewardSaveFailed] so [saveReward] can use this as its
  /// `AsyncError` case body via `return _handleMutationError(...)`; the
  /// void-returning mutation methods simply discard the return value.
  RewardSaveFailed _handleMutationError(Object error, StackTrace stackTrace) {
    if (error is TutorWriteException) {
      state = state.copyWith(loading: false);
      Error.throwWithStackTrace(error, stackTrace);
    }
    state = state.copyWith(loading: false, error: error.toString());
    return const RewardSaveFailed();
  }
}
