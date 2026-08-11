import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/reward_milestone_icons.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/child_redemption_screen.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_form.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reward_config_controller.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Save-result sealed union
// ─────────────────────────────────────────────────────────────────────────────

/// Returned by [RewardConfigController.saveReward] to let the screen decide
/// which UI feedback (dialog/snackbar) to show.
///
/// AUD-t-gamification-02: this union used to also carry a "no track
/// selected" variant and a "duplicate threshold" variant. The former
/// guarded a per-track branch that [bootstrap] never actually reaches —
/// `tracks` is hardcoded to `const []` per DEC-32/GA-3 (per-track rewards
/// were removed from the spend economy), so `RewardForm.usesGlobalLadder`
/// is always `true` and the "non-global but no track selected" branch was
/// dead. The latter stopped being returned entirely once GA-3 removed the
/// duplicate-threshold uniqueness constraint. Both variants were deleted
/// (and the tests that only exercised them removed/rewritten) rather than
/// kept as speculative generality for a per-track feature that does not
/// exist on any real code path today; reintroduce them alongside a real
/// per-track bootstrap path if per-track rewards come back.
sealed class RewardSaveResult {
  const RewardSaveResult();
}

final class RewardSaved extends RewardSaveResult {
  const RewardSaved({required this.title, required this.wasEditing});
  final String title;
  final bool wasEditing;
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
    state = state.copyWith(loading: false, error: null);
  }

  // ── Field mutations ────────────────────────────────────────────────────────

  void setName(String value) => state = state.copyWith(name: value);
  void setPointsText(String value) => state = state.copyWith(pointsText: value);
  void setIconIndex(int index) => state = state.copyWith(iconIndex: index);

  // ── Form lifecycle ─────────────────────────────────────────────────────────

  void clearForm() {
    state = state.copyWith(
      editingMilestoneId: null,
      iconIndex: 0,
      name: '',
      pointsText: '',
    );
  }

  void applyMilestoneToForm(RewardMilestone m) {
    state = state.copyWith(
      editingMilestoneId: m.id,
      iconIndex: RewardMilestoneIcons.clampIndex(m.iconIndex),
      name: m.title,
      pointsText: '${m.thresholdPoints}',
    );
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  /// Returns every configured reward milestone (DEC-32/GA-3: there is only
  /// ever one, global, ladder now).
  Future<List<RewardMilestone>> milestonesForCurrentLadder() async {
    final svc = ref.read(rewardMilestoneServiceProvider);
    return svc.getMilestones();
  }

  Future<void> _persistAndSync() async {
    // TODO(gamification-settings-sync): the cloud-settings push that used to
    // run here was deleted along with the archived SyncWriteFacade (lib/core/
    // database + lib/features/sync were removed wholesale, task tracker
    // #22) — a saved/toggled/deleted reward is local-only (SharedPreferences)
    // until a real, non-outbox replacement is built. SM-4 (AUD-gamification-01):
    // the screen/notifier can still be torn down between the write above (in
    // the caller) and the invalidate calls below (e.g. a fast back-gesture) —
    // touching `ref` after disposal throws, so this guard stays.
    if (!ref.mounted) return;
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
    // AUD-t-gamification-02: the "non-global but no track selected" guard
    // that used to return a dedicated result variant here was removed —
    // `tracks` is hardcoded empty in [bootstrap], so `usesGlobalLadder` is
    // always `true` and that branch could never run. See the doc comment on
    // [RewardSaveResult] above.
    //
    // GA-3: _hasDuplicateThreshold removed — the spend-economy model allows
    // multiple distinct rewards at the same price (no ladder uniqueness
    // constraint). saveReward() no longer returns a duplicate-threshold
    // result for a same-cost add.

    final svc = ref.read(rewardMilestoneServiceProvider);

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
      final currentMilestones = await svc.getMilestones();
      final isDuplicateName = currentMilestones.any(
        (m) =>
            m.title.trim().toLowerCase() == title.toLowerCase() &&
            m.id != state.editingMilestoneId,
      );
      if (isDuplicateName) return const RewardSaveDuplicateName();

      await svc.upsertMilestone(
        title: title,
        thresholdPoints: pointsParsed,
        milestoneId: state.editingMilestoneId,
        isEnabled: true,
        iconIndex: RewardMilestoneIcons.clampIndex(state.iconIndex),
      );
      await _persistAndSync();
      return RewardSaved(title: title, wasEditing: wasEditing);
    });

    // SM-4 (AUD-gamification-01): the screen/notifier can be disposed while
    // the guarded block above is still awaiting I/O. Report the outcome to
    // whichever caller is still awaiting this Future, but do not touch
    // `state` on a disposed Notifier.
    if (!ref.mounted) {
      return switch (guarded) {
        AsyncData(:final value) => value,
        AsyncError() => const RewardSaveFailed(),
        AsyncLoading() => const RewardSaveFailed(),
      };
    }

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
    final svc = ref.read(rewardMilestoneServiceProvider);

    // SM-5 (AUD-gamification-10): see saveReward's doc comment above.
    state = state.copyWith(loading: true, error: null);
    final guarded = await AsyncValue.guard<void>(() async {
      await svc.upsertMilestone(
        title: m.title,
        thresholdPoints: m.thresholdPoints,
        milestoneId: m.id,
        isEnabled: !m.isEnabled,
        iconIndex: RewardMilestoneIcons.clampIndex(m.iconIndex),
      );
      await _persistAndSync();
    });

    // SM-4 (AUD-gamification-01): see saveReward's mounted check above.
    if (!ref.mounted) return;

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
    final svc = ref.read(rewardMilestoneServiceProvider);

    // SM-5 (AUD-gamification-10): see saveReward's doc comment above.
    state = state.copyWith(loading: true, error: null);
    final guarded = await AsyncValue.guard<void>(() async {
      await svc.removeMilestone(m.id);
      await _persistAndSync();
    });

    // SM-4 (AUD-gamification-01): see saveReward's mounted check above.
    if (!ref.mounted) return;

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
