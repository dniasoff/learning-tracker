/// Unit tests for [RewardConfigController] via ProviderContainer + in-memory DB.
///
/// Coverage:
///   1. Initial state — default RewardForm values.
///   2. bootstrap() — sets isGlobalReward=true, clears tracks/error/loading.
///   3. setName / setPointsText / setIconIndex — field mutations.
///   4. setGlobalReward — forces global when tracks is empty.
///   5. setSelectedTrack — updates selectedTrackId.
///   6. clearForm — resets all mutable fields.
///   7. applyMilestoneToForm — populates form from an existing milestone.
///   8. saveReward — invalid (empty name) → RewardSaveInvalidInput.
///   9. saveReward — invalid (zero points) → RewardSaveInvalidInput.
///  10. saveReward — invalid (negative text) → RewardSaveInvalidInput.
///  11. saveReward — valid add → RewardSaved(wasEditing=false), clears form.
///  12. saveReward — valid edit → RewardSaved(wasEditing=true).
///  13. saveReward — duplicate threshold (GA-3: constraint removed) — two
///      rewards at the same cost both save.
///  14. saveReward — edit same milestone (exclude own id) → not a duplicate.
///  15. deleteMilestone — removes from SharedPreferences.
///  16. deleteMilestone — if editing that milestone, clears form.
///  17. toggleEnabled — flips isEnabled flag.
///  18. milestonesForCurrentLadder — global ladder.
///  19. milestonesForCurrentLadder — no milestones seeded → empty list.
///  20. Product rule: adults have no points — adult profile, controller works fine.
///  21. usesGlobalLadder computed property: true when tracks empty.
///  22. SM-5 (AUD-gamification-10) — saveReward/toggleEnabled/deleteMilestone
///      set state.error (and clear state.loading) when the underlying call
///      throws anything other than TutorWriteException; a TutorWriteException
///      is rethrown and does NOT set state.error.
///  23. SM-4 (AUD-gamification-01) — disposing the container while
///      saveReward()'s sync push is in flight must not throw an uncaught
///      disposed-ref exception; the notifier checks `ref.mounted` before
///      touching `state`/`ref` again after the await.
///
/// AUD-t-gamification-02: two items formerly in this list are gone.
/// "setGlobalReward — allows non-global when tracks is non-empty" was a
/// byte-for-byte duplicate of item 4's assertions (no real bootstrap path
/// ever populates `tracks`, so the two tests exercised the identical
/// tracks-empty branch under different names). "RewardSaveNoTrack — per-track
/// ladder selected but no track chosen" never called `saveReward()` at all —
/// it asserted directly on a hand-built `RewardForm`, and the result variant
/// it claimed to produce could never be returned by the real controller (see
/// reward_config_controller.dart's `RewardSaveResult` doc comment). Both
/// were deleted rather than kept as dead-branch coverage.

@Tags(['gamification', 'reward_config_controller'])
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_config_controller.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_form.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/test_database.dart';

// ── Container factory ──────────────────────────────────────────────────────────

/// Creates a [ProviderContainer] with:
///  - in-memory UserDatabase
///  - activeProfileIdProvider fixed to [profileId]
///  - syncWriteFacadeProvider → null (local-born, no sync)
///  - achievementsOverviewProvider stubbed to a dummy value
///
/// AUD-t-gamification-09: this factory used to also accept a `profileMode`
/// parameter whose doc comment claimed it drove "profile-type branching",
/// but the body never read it — [RewardConfigController] itself has no
/// profile-mode branch to wire up (child-vs-adult gating happens in the
/// screen/widget layer, e.g. `gamification_route_push_guard.dart`, never
/// inside this controller). Wiring a stub override that nothing downstream
/// consumes would have fabricated a behavioral distinction that doesn't
/// exist, so the dead parameter was removed instead. Callers that need a
/// specific profile mode seed a real profile row via [seedProfileWithIds]
/// (see the "product rule: adults have no points" group below).
ProviderContainer _makeContainer({int profileId = 1}) {
  final db = inMemoryDb();
  // AUD-t-gamification-04: ProviderContainer.dispose() (called via
  // addTearDown(c.dispose) at each call site) disposes Riverpod's
  // providers, not this raw UserDatabase handed to overrideWithValue below
  // -- close it explicitly or the native sqlite3 connection stays open
  // until the test file's isolate exits (test/helpers/drift_memory.dart's
  // inMemoryDb() doc comment).
  addTearDown(db.close);
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWithValue(profileId),
      syncWriteFacadeProvider.overrideWithValue(null),
      achievementsOverviewProvider.overrideWith(
        (ref) async => const AchievementsOverview(
          rows: [],
          unlockedCount: 0,
          totalMilestones: 0,
          trackFilterOptions: [],
        ),
      ),
    ],
  );
}

RewardConfigController _notifier(ProviderContainer c) =>
    c.read(rewardConfigControllerProvider.notifier);

RewardForm _state(ProviderContainer c) =>
    c.read(rewardConfigControllerProvider);

// ── Helpers ────────────────────────────────────────────────────────────────────

/// Seeds a global milestone directly via the service, bypassing the controller.
Future<void> _seedGlobalMilestone(
  ProviderContainer c, {
  required String id,
  required String title,
  required int thresholdPoints,
}) async {
  final db = c.read(userDatabaseProvider);
  final profileId = c.read(activeProfileIdProvider);
  final svc = RewardMilestoneService(db, profileId: profileId);
  await svc.upsertMilestone(
    trackId: RewardMilestone.kGlobalTrackSentinel,
    title: title,
    thresholdPoints: thresholdPoints,
    milestoneId: id,
  );
}

// ── SM-5 error-visibility fake ──────────────────────────────────────────────

/// [SyncWriteFacade] whose [pushGamificationSettingsSnapshot] always throws
/// [error] — used to exercise the "any OTHER DB/sync failure" branch of
/// _handleMutationError (AUD-gamification-10). All other members are unused
/// no-ops.
class _ThrowingSyncFacade implements SyncWriteFacade {
  _ThrowingSyncFacade(this.error);
  final Exception error;

  @override
  Future<void> pushGamificationSettingsSnapshot() async {
    throw error;
  }

  @override
  Future<void> pushUiPreferencesSnapshot() async {}
  @override
  Future<void> pushBookmark(Map<String, dynamic> bookmark) async {}
  @override
  Future<void> pushSettings(Map<String, dynamic> settings) async {}
  @override
  Future<void> pushGoal(Map<String, dynamic> goal) async {}
  @override
  Future<void> deleteGoal(Map<String, dynamic> payload) async {}
  @override
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async {}
  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async {}
  @override
  Future<void> deleteLearnerProfile(String profileUlid) async {}
  @override
  Future<void> pushStageDefinitions({
    required int trackId,
    required String curriculumId,
    required List<Map<String, dynamic>> stages,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushStudyDayConfig(Map<String, dynamic> payload) async {}
  @override
  Future<void> deleteCompletion(String completionId) async {}
  @override
  Future<void> pushProfileProgram(Map<String, dynamic> payload) async {}
}

// ── SM-4 disposal-mid-await fake (AUD-gamification-01) ──────────────────────

/// [SyncWriteFacade] whose [pushGamificationSettingsSnapshot] blocks on
/// [gate] until the test completes it -- lets a test dispose the
/// [ProviderContainer] while a mutation method's `await` is in flight, then
/// resume it and observe whether the notifier throws touching a disposed
/// `ref`/`state`.
class _GatedSyncFacade implements SyncWriteFacade {
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> pushGamificationSettingsSnapshot() => gate.future;

  @override
  Future<void> pushUiPreferencesSnapshot() async {}
  @override
  Future<void> pushBookmark(Map<String, dynamic> bookmark) async {}
  @override
  Future<void> pushSettings(Map<String, dynamic> settings) async {}
  @override
  Future<void> pushGoal(Map<String, dynamic> goal) async {}
  @override
  Future<void> deleteGoal(Map<String, dynamic> payload) async {}
  @override
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async {}
  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async {}
  @override
  Future<void> deleteLearnerProfile(String profileUlid) async {}
  @override
  Future<void> pushStageDefinitions({
    required int trackId,
    required String curriculumId,
    required List<Map<String, dynamic>> stages,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushStudyDayConfig(Map<String, dynamic> payload) async {}
  @override
  Future<void> deleteCompletion(String completionId) async {}
  @override
  Future<void> pushProfileProgram(Map<String, dynamic> payload) async {}
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── 1. Initial state ─────────────────────────────────────────────────────────

  group('initial state', () {
    test('default RewardForm has empty name and pointsText', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      final form = _state(c);
      expect(form.name, isEmpty);
      expect(form.pointsText, isEmpty);
      expect(form.iconIndex, 0);
      expect(form.editingMilestoneId, isNull);
      expect(form.selectedTrackId, isNull);
      expect(form.loading, isFalse);
      expect(form.error, isNull);
    });

    test('usesGlobalLadder is true when tracks is empty', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      expect(_state(c).usesGlobalLadder, isTrue);
    });

    test('previewPoints is 0 for empty pointsText', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      expect(_state(c).previewPoints, 0);
    });
  });

  // ── 2. bootstrap() ───────────────────────────────────────────────────────────

  group('bootstrap()', () {
    test(
      'sets isGlobalReward=true, clears loading/error, empties tracks',
      () async {
        final c = _makeContainer();
        addTearDown(c.dispose);

        await _notifier(c).bootstrap();
        final form = _state(c);

        expect(form.isGlobalReward, isTrue);
        expect(form.tracks, isEmpty);
        expect(form.loading, isFalse);
        expect(form.error, isNull);
      },
    );

    test('selectedTrackId is null after bootstrap', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);

      await _notifier(c).bootstrap();
      expect(_state(c).selectedTrackId, isNull);
    });
  });

  // ── 3. Field mutations ───────────────────────────────────────────────────────

  group('setName / setPointsText / setIconIndex', () {
    test('setName updates form.name', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).setName('Gold Star');
      expect(_state(c).name, 'Gold Star');
    });

    test('setPointsText updates form.pointsText', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).setPointsText('500');
      expect(_state(c).pointsText, '500');
    });

    test('setPointsText updates previewPoints computed value', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).setPointsText('250');
      expect(_state(c).previewPoints, 250);
    });

    test('setIconIndex updates form.iconIndex', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).setIconIndex(5);
      expect(_state(c).iconIndex, 5);
    });

    test('mutations do not affect unrelated fields', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).setName('Test');
      expect(_state(c).pointsText, isEmpty);
      expect(_state(c).iconIndex, 0);
    });
  });

  // ── 4. setGlobalReward ────────────────────────────────────────────────────────

  group('setGlobalReward', () {
    test('forces global when tracks is empty, regardless of parameter', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).setGlobalReward(false);
      // tracks is empty so it must stay global
      expect(_state(c).isGlobalReward, isTrue);
    });

    // AUD-t-gamification-02: a second test here ("allows non-global when
    // tracks is non-empty") called this same `setGlobalReward(false)` on a
    // freshly-bootstrapped (tracks-empty) container and asserted
    // `usesGlobalLadder` is `true` — the identical assertion as the test
    // above, under a name claiming the opposite outcome. No real bootstrap
    // path ever populates `tracks`, so there was no way to exercise a
    // genuine non-global branch; removed as a duplicate rather than kept as
    // misleading dead-branch coverage.
  });

  // ── 5. setSelectedTrack ──────────────────────────────────────────────────────

  group('setSelectedTrack', () {
    test('updates selectedTrackId', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).setSelectedTrack(42);
      expect(_state(c).selectedTrackId, 42);
    });

    test('can change selectedTrackId multiple times', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).setSelectedTrack(1);
      _notifier(c).setSelectedTrack(2);
      expect(_state(c).selectedTrackId, 2);
    });
  });

  // ── 6. clearForm ─────────────────────────────────────────────────────────────

  group('clearForm()', () {
    test('resets name, pointsText, iconIndex, and editingMilestoneId', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).setName('Bronze');
      _notifier(c).setPointsText('300');
      _notifier(c).setIconIndex(3);
      _notifier(c).clearForm();

      final form = _state(c);
      expect(form.name, isEmpty);
      expect(form.pointsText, isEmpty);
      expect(form.iconIndex, 0);
      expect(form.editingMilestoneId, isNull);
    });

    test('clearForm keeps isGlobalReward=true when tracks is empty', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).clearForm();
      expect(_state(c).isGlobalReward, isTrue);
    });
  });

  // ── 7. applyMilestoneToForm ────────────────────────────────────────────────

  group('applyMilestoneToForm()', () {
    test('populates form from a global milestone', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      final ms = RewardMilestone(
        id: 'ms-global-1',
        profileId: 1,
        trackId: RewardMilestone.kGlobalTrackSentinel,
        title: 'Gold Star',
        thresholdPoints: 1000,
        isEnabled: true,
        iconIndex: 4,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      _notifier(c).applyMilestoneToForm(ms);
      final form = _state(c);

      expect(form.editingMilestoneId, 'ms-global-1');
      expect(form.name, 'Gold Star');
      expect(form.pointsText, '1000');
      expect(form.iconIndex, 4);
      expect(form.isGlobalReward, isTrue);
    });

    test('populates form from a per-track milestone (clamps iconIndex)', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      final ms = RewardMilestone(
        id: 'ms-track-1',
        profileId: 1,
        trackId: 5,
        title: 'Silver Star',
        thresholdPoints: 500,
        isEnabled: true,
        iconIndex: 999, // out-of-bounds; should be clamped
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      _notifier(c).applyMilestoneToForm(ms);
      final form = _state(c);

      // iconIndex is clamped to valid range
      expect(form.iconIndex, lessThan(20));
      expect(form.name, 'Silver Star');
      expect(form.pointsText, '500');
    });

    test('applyMilestoneToForm sets editingMilestoneId', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      final ms = RewardMilestone(
        id: 'edit-id',
        profileId: 1,
        trackId: RewardMilestone.kGlobalTrackSentinel,
        title: 'Reward',
        thresholdPoints: 200,
        isEnabled: true,
        iconIndex: 0,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      _notifier(c).applyMilestoneToForm(ms);
      expect(_state(c).editingMilestoneId, 'edit-id');
    });
  });

  // ── 8. saveReward — empty name ──────────────────────────────────────────────

  group('saveReward() — validation', () {
    test('empty name → RewardSaveInvalidInput', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).setName('');
      _notifier(c).setPointsText('100');

      final result = await _notifier(c).saveReward();
      expect(result, isA<RewardSaveInvalidInput>());
    });

    test('whitespace-only name → RewardSaveInvalidInput', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).setName('   ');
      _notifier(c).setPointsText('100');

      final result = await _notifier(c).saveReward();
      expect(result, isA<RewardSaveInvalidInput>());
    });

    // ── 9. Zero points
    test('zero points → RewardSaveInvalidInput', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).setName('Gold Star');
      _notifier(c).setPointsText('0');

      final result = await _notifier(c).saveReward();
      expect(result, isA<RewardSaveInvalidInput>());
    });

    // ── 10. Non-numeric / negative points text
    test(
      'non-numeric pointsText → parsed as 0 → RewardSaveInvalidInput',
      () async {
        final c = _makeContainer();
        addTearDown(c.dispose);

        _notifier(c).setName('Gold Star');
        _notifier(c).setPointsText('abc');

        final result = await _notifier(c).saveReward();
        expect(result, isA<RewardSaveInvalidInput>());
      },
    );

    test('empty pointsText → parsed as 0 → RewardSaveInvalidInput', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).setName('Gold Star');
      _notifier(c).setPointsText('');

      final result = await _notifier(c).saveReward();
      expect(result, isA<RewardSaveInvalidInput>());
    });
  });

  // ── 11. saveReward — valid add ───────────────────────────────────────────────

  group('saveReward() — valid add', () {
    test('valid global reward → RewardSaved(wasEditing=false)', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      _notifier(c).setName('Gold Star');
      _notifier(c).setPointsText('500');

      final result = await _notifier(c).saveReward();

      expect(result, isA<RewardSaved>());
      final saved = result as RewardSaved;
      expect(saved.title, 'Gold Star');
      expect(saved.wasEditing, isFalse);
    });

    test('saveReward clears form after success', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      _notifier(c).setName('Silver Star');
      _notifier(c).setPointsText('300');

      await _notifier(c).saveReward();

      final form = _state(c);
      expect(form.name, isEmpty);
      expect(form.pointsText, isEmpty);
      expect(form.editingMilestoneId, isNull);
    });

    test('reward is persisted in SharedPreferences after save', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      _notifier(c).setName('Diamond Star');
      _notifier(c).setPointsText('1000');

      await _notifier(c).saveReward();

      // Verify persistence by reading via service directly
      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      final milestones = await svc.getGlobalMilestones();
      expect(milestones, hasLength(1));
      expect(milestones.first.title, 'Diamond Star');
      expect(milestones.first.thresholdPoints, 1000);
    });

    test('saved milestone uses kGlobalTrackSentinel when global', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      _notifier(c).setName('Bronze Star');
      _notifier(c).setPointsText('200');

      await _notifier(c).saveReward();

      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      final milestones = await svc.getGlobalMilestones();
      expect(milestones.first.trackId, RewardMilestone.kGlobalTrackSentinel);
    });
  });

  // ── 12. saveReward — valid edit ──────────────────────────────────────────────

  group('saveReward() — valid edit', () {
    test('editing existing milestone → RewardSaved(wasEditing=true)', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      // Seed original milestone
      await _seedGlobalMilestone(
        c,
        id: 'ms-edit',
        title: 'Old Title',
        thresholdPoints: 100,
      );

      // Apply the existing milestone to the form
      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      final all = await svc.getAllMilestones();
      _notifier(c).applyMilestoneToForm(all.first);

      // Change name + points
      _notifier(c).setName('New Title');
      _notifier(c).setPointsText('200');

      final result = await _notifier(c).saveReward();

      expect(result, isA<RewardSaved>());
      final saved = result as RewardSaved;
      expect(saved.title, 'New Title');
      expect(saved.wasEditing, isTrue);
    });

    test('edit updates the milestone in place (no duplicates)', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      await _seedGlobalMilestone(
        c,
        id: 'ms-only',
        title: 'Original',
        thresholdPoints: 50,
      );

      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      final all = await svc.getAllMilestones();
      _notifier(c).applyMilestoneToForm(all.first);
      _notifier(c).setName('Updated');
      _notifier(c).setPointsText('75');

      await _notifier(c).saveReward();

      final updated = await svc.getAllMilestones();
      expect(updated, hasLength(1));
      expect(updated.first.title, 'Updated');
      expect(updated.first.thresholdPoints, 75);
    });
  });

  // ── 13. saveReward — duplicate threshold (GA-3: check removed) ─────────────
  //
  // GA-3 fix: the spend-economy model allows multiple distinct rewards at the
  // same price. The _hasDuplicateThreshold check has been removed. Two rewards
  // with the same cost both save successfully — the old RewardSaveDuplicateThreshold
  // result is no longer returned for this case.

  group('saveReward() — duplicate threshold (GA-3: allowed)', () {
    test(
      'duplicate threshold on global ladder → both save (no ladder constraint)',
      () async {
        final c = _makeContainer();
        addTearDown(c.dispose);
        await seedProfileWithIds(
          c.read(userDatabaseProvider),
          accountId: 1,
          profileId: 1,
        );

        // Seed a milestone with threshold 500
        await _seedGlobalMilestone(
          c,
          id: 'ms-a',
          title: 'Alpha',
          thresholdPoints: 500,
        );

        // GA-3: a second reward at the same cost should now SUCCEED (spend-economy
        // allows duplicate prices — the old ladder uniqueness constraint was removed).
        _notifier(c).setName('Beta');
        _notifier(c).setPointsText('500');

        final result = await _notifier(c).saveReward();
        expect(
          result,
          isA<RewardSaved>(),
          reason:
              'GA-3: duplicate price is allowed in the spend-economy model; '
              'two distinct rewards can share the same cost',
        );
      },
    );
  });

  // ── 14. Edit own milestone — not a duplicate ─────────────────────────────────

  group('saveReward() — edit does not flag self as duplicate', () {
    test('editing milestone with same threshold is not a duplicate', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      await _seedGlobalMilestone(
        c,
        id: 'ms-self',
        title: 'Star',
        thresholdPoints: 300,
      );

      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      final all = await svc.getAllMilestones();
      _notifier(c).applyMilestoneToForm(all.first);
      // Keep same threshold but change name
      _notifier(c).setName('Renamed Star');
      _notifier(c).setPointsText('300');

      final result = await _notifier(c).saveReward();
      // Should succeed since we exclude own id from duplicate check
      expect(result, isA<RewardSaved>());
    });
  });

  // ── 15. deleteMilestone ──────────────────────────────────────────────────────

  group('deleteMilestone()', () {
    test('removes the milestone from SharedPreferences', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      await _seedGlobalMilestone(
        c,
        id: 'ms-del',
        title: 'Delete Me',
        thresholdPoints: 100,
      );

      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      final before = await svc.getAllMilestones();
      expect(before, hasLength(1));

      await _notifier(c).deleteMilestone(before.first);

      final after = await svc.getAllMilestones();
      expect(after, isEmpty);
    });

    test('does not clear form when deleting a different milestone', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      await _seedGlobalMilestone(
        c,
        id: 'ms-other',
        title: 'Other',
        thresholdPoints: 100,
      );

      _notifier(c).setName('Currently editing');
      // We are not editing ms-other (editingMilestoneId stays null)
      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      final milestones = await svc.getAllMilestones();

      await _notifier(c).deleteMilestone(milestones.first);

      // Form name should be unchanged since we were not editing that milestone
      expect(_state(c).name, 'Currently editing');
    });
  });

  // ── 16. deleteMilestone clears form when editing that milestone ──────────────

  group('deleteMilestone() — clears form when editing', () {
    test('clears form if deleted milestone was being edited', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      await _seedGlobalMilestone(
        c,
        id: 'ms-edited',
        title: 'Editing Me',
        thresholdPoints: 200,
      );

      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      final milestones = await svc.getAllMilestones();
      // Apply to form so editingMilestoneId = 'ms-edited'
      _notifier(c).applyMilestoneToForm(milestones.first);
      expect(_state(c).editingMilestoneId, 'ms-edited');

      await _notifier(c).deleteMilestone(milestones.first);

      // Form should be cleared
      expect(_state(c).editingMilestoneId, isNull);
      expect(_state(c).name, isEmpty);
    });
  });

  // ── 17. toggleEnabled ────────────────────────────────────────────────────────

  group('toggleEnabled()', () {
    test('flips isEnabled from true to false', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      await _seedGlobalMilestone(
        c,
        id: 'ms-toggle',
        title: 'Toggle Me',
        thresholdPoints: 100,
      );

      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      final before = (await svc.getAllMilestones()).first;
      expect(before.isEnabled, isTrue);

      await _notifier(c).toggleEnabled(before);

      final after = (await svc.getAllMilestones()).first;
      expect(after.isEnabled, isFalse);
    });

    test('flips isEnabled from false to true', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      await svc.upsertMilestone(
        trackId: RewardMilestone.kGlobalTrackSentinel,
        title: 'Disabled',
        thresholdPoints: 150,
        milestoneId: 'ms-disabled',
        isEnabled: false,
      );

      final before = (await svc.getAllMilestones()).first;
      expect(before.isEnabled, isFalse);

      await _notifier(c).toggleEnabled(before);

      final after = (await svc.getAllMilestones()).first;
      expect(after.isEnabled, isTrue);
    });
  });

  // ── 18. milestonesForCurrentLadder — global ──────────────────────────────────

  group('milestonesForCurrentLadder()', () {
    test('returns global milestones when usesGlobalLadder', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      await _seedGlobalMilestone(
        c,
        id: 'ms-g1',
        title: 'Global One',
        thresholdPoints: 100,
      );
      await _seedGlobalMilestone(
        c,
        id: 'ms-g2',
        title: 'Global Two',
        thresholdPoints: 200,
      );

      // Default state has empty tracks → usesGlobalLadder = true
      expect(_state(c).usesGlobalLadder, isTrue);

      final milestones = await _notifier(c).milestonesForCurrentLadder();
      expect(milestones, hasLength(2));
      expect(milestones.map((m) => m.id), containsAll(['ms-g1', 'ms-g2']));
    });

    // ── 19. No milestones seeded → empty ──────────────────────────────────────

    // AUD-t-gamification-02: this test used to be named "returns empty list
    // when per-track mode but no track selected", claiming to cover the
    // `tid == null` branch inside `milestonesForCurrentLadder()`. It does
    // not: `tracks` is always empty (no real bootstrap path populates it —
    // DEC-32/GA-3), so `usesGlobalLadder` is always `true` and that method
    // always takes the `svc.getGlobalMilestones()` branch, never the
    // per-track one. What this test actually exercises — and legitimately —
    // is the global-ladder branch when no milestones have been seeded.
    // Renamed to match reality instead of deleted, since the empty-list
    // assertion for a real, reachable case is still real coverage.
    test(
      'returns empty list on the global ladder when nothing is seeded',
      () async {
        final c = _makeContainer();
        addTearDown(c.dispose);

        final milestones = await _notifier(c).milestonesForCurrentLadder();
        expect(milestones, isEmpty);
      },
    );

    // AUD-gamification-11 (SM-7): milestonesForCurrentLadder() used to
    // construct its own `RewardMilestoneService(db, profileId: profileId)`
    // ad hoc — a test (or caller) could only fake the service by faking the
    // whole `UserDatabase`, never by a single `ProviderScope` override. It
    // must now read through the shared `rewardMilestoneServiceProvider` seam.
    test('AUD-gamification-11: reads through an overridden '
        'rewardMilestoneServiceProvider instead of constructing its own '
        'RewardMilestoneService(db, profileId: ...)', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfileWithIds(db, accountId: 1, profileId: 1);

      // A service scoped to a DIFFERENT profileId (999), pre-seeded with a
      // global milestone. The active profile (1) has nothing seeded.
      final overrideService = RewardMilestoneService(db, profileId: 999);
      await overrideService.upsertMilestone(
        trackId: RewardMilestone.kGlobalTrackSentinel,
        title: 'Override Reward',
        thresholdPoints: 42,
        milestoneId: 'ms-override',
      );

      final c = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(1),
          syncWriteFacadeProvider.overrideWithValue(null),
          achievementsOverviewProvider.overrideWith(
            (ref) async => const AchievementsOverview(
              rows: [],
              unlockedCount: 0,
              totalMilestones: 0,
              trackFilterOptions: [],
            ),
          ),
          rewardMilestoneServiceProvider.overrideWithValue(overrideService),
        ],
      );
      addTearDown(c.dispose);

      final milestones = await _notifier(c).milestonesForCurrentLadder();
      expect(
        milestones.map((m) => m.id),
        contains('ms-override'),
        reason:
            'the active profile (1) has no milestones seeded — a result '
            'containing the profile-999 milestone proves '
            'milestonesForCurrentLadder() read the OVERRIDDEN '
            'rewardMilestoneServiceProvider rather than constructing its '
            'own RewardMilestoneService(db, profileId: activeProfileId).',
      );
    });
  });

  // ── 20. Product rule: adults have no points ──────────────────────────────────

  group('product rule: adults have no points', () {
    test('controller works for adult profile (seeded mode=adult)', () async {
      // Adults have no points — but the RewardConfigController is used by
      // parents/admins to configure the reward catalogue for children.
      // The product rule is: child profiles earn points; adults do not.
      // The controller itself is not responsible for blocking adult use —
      // that gating happens at the UI/gamification screen layer.
      // This test verifies the controller functions for an adult profile ID
      // (which is the typical use case: an adult configures child rewards).
      // The 'adult' mode comes from the real profile row seeded below via
      // seedProfileWithIds — _makeContainer itself has no profile-mode
      // parameter (AUD-t-gamification-09: it never drove any behavior).
      final c = _makeContainer(profileId: 1);
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
        mode: 'adult',
      );

      _notifier(c).setName('Child Reward');
      _notifier(c).setPointsText('500');

      final result = await _notifier(c).saveReward();
      // Controller saves successfully — access control is enforced by UI layer
      expect(result, isA<RewardSaved>());
    });

    test(
      'saved milestone has profile_id matching activeProfileIdProvider',
      () async {
        final c = _makeContainer(profileId: 1);
        addTearDown(c.dispose);
        await seedProfileWithIds(
          c.read(userDatabaseProvider),
          accountId: 1,
          profileId: 1,
        );

        _notifier(c).setName('Test Reward');
        _notifier(c).setPointsText('100');
        await _notifier(c).saveReward();

        final db = c.read(userDatabaseProvider);
        final svc = RewardMilestoneService(db, profileId: 1);
        final milestones = await svc.getAllMilestones();
        expect(milestones.first.profileId, 1);
      },
    );
  });

  // ── 21. usesGlobalLadder computed property ───────────────────────────────────

  group('usesGlobalLadder computed property', () {
    test('true when tracks is empty', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      expect(_state(c).usesGlobalLadder, isTrue);
    });

    test('true when tracks is empty regardless of isGlobalReward', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      // Even if someone sets isGlobalReward=false (the guard prevents it when
      // empty, but this tests the computed value directly).
      const form = RewardForm(tracks: [], isGlobalReward: false);
      expect(form.usesGlobalLadder, isTrue);
    });
  });

  // AUD-t-gamification-02: a group here ("saveReward() — RewardSaveNoTrack")
  // was removed. It never called `saveReward()` — its only assertion was
  // `expect(form.usesGlobalLadder, isTrue)` on a hand-built `RewardForm`,
  // which is the same assertion as "true when tracks is empty regardless of
  // isGlobalReward" directly above, and the result variant it claimed to
  // cover no longer exists (see reward_config_controller.dart's
  // `RewardSaveResult` doc comment). TQ-8: a test must exercise the branch
  // it claims to cover; this one exercised no branch of `saveReward()` at
  // all.

  // ── Miscellaneous ────────────────────────────────────────────────────────────

  group('miscellaneous', () {
    test('multiple saves produce multiple milestones', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      _notifier(c).setName('Bronze Star');
      _notifier(c).setPointsText('100');
      await _notifier(c).saveReward();

      _notifier(c).setName('Silver Star');
      _notifier(c).setPointsText('300');
      await _notifier(c).saveReward();

      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      final milestones = await svc.getGlobalMilestones();
      expect(milestones, hasLength(2));
    });

    test('iconIndex is clamped to valid range on save', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      _notifier(c).setName('Icon Test');
      _notifier(c).setPointsText('100');
      _notifier(c).setIconIndex(9999); // out of bounds

      await _notifier(c).saveReward();

      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      final milestones = await svc.getGlobalMilestones();
      // iconIndex must have been clamped by RewardMilestoneIcons.clampIndex
      expect(milestones.first.iconIndex, lessThan(20));
    });

    test('title is trimmed on save', () async {
      final c = _makeContainer();
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      _notifier(c).setName('  Padded Star  ');
      _notifier(c).setPointsText('100');

      final result = await _notifier(c).saveReward();
      expect(result, isA<RewardSaved>());
      expect((result as RewardSaved).title, 'Padded Star');

      final db = c.read(userDatabaseProvider);
      final svc = RewardMilestoneService(db, profileId: 1);
      final milestones = await svc.getGlobalMilestones();
      expect(milestones.first.title, 'Padded Star');
    });
  });

  // ── 23. SM-5 — error visibility on mutation failure (AUD-gamification-10) ──

  group('SM-5: error visibility on mutation failure (AUD-gamification-10)', () {
    test('saveReward leaves state.error non-null (not an unhandled Future '
        'rejection) when the underlying call throws anything other than '
        'TutorWriteException', () async {
      final c = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(inMemoryDb()),
          activeProfileIdProvider.overrideWithValue(1),
          syncWriteFacadeProvider.overrideWithValue(
            _ThrowingSyncFacade(Exception('simulated_sync_failure')),
          ),
          achievementsOverviewProvider.overrideWith(
            (ref) async => const AchievementsOverview(
              rows: [],
              unlockedCount: 0,
              totalMilestones: 0,
              trackFilterOptions: [],
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      _notifier(c).setName('Gold Star');
      _notifier(c).setPointsText('500');

      final result = await _notifier(c).saveReward();

      expect(result, isA<RewardSaveFailed>());
      expect(_state(c).error, isNotNull);
      expect(_state(c).loading, isFalse);
    });

    test(
      'toggleEnabled leaves state.error non-null on a generic failure',
      () async {
        final c = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(inMemoryDb()),
            activeProfileIdProvider.overrideWithValue(1),
            syncWriteFacadeProvider.overrideWithValue(
              _ThrowingSyncFacade(Exception('simulated_sync_failure')),
            ),
            achievementsOverviewProvider.overrideWith(
              (ref) async => const AchievementsOverview(
                rows: [],
                unlockedCount: 0,
                totalMilestones: 0,
                trackFilterOptions: [],
              ),
            ),
          ],
        );
        addTearDown(c.dispose);
        await seedProfileWithIds(
          c.read(userDatabaseProvider),
          accountId: 1,
          profileId: 1,
        );
        await _seedGlobalMilestone(
          c,
          id: 'ms-toggle',
          title: 'Toggle Me',
          thresholdPoints: 100,
        );
        final milestone = (await RewardMilestoneService(
          c.read(userDatabaseProvider),
          profileId: 1,
        ).getAllMilestones()).first;

        await _notifier(c).toggleEnabled(milestone);

        expect(_state(c).error, isNotNull);
        expect(_state(c).loading, isFalse);
      },
    );

    test(
      'deleteMilestone leaves state.error non-null on a generic failure',
      () async {
        final c = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(inMemoryDb()),
            activeProfileIdProvider.overrideWithValue(1),
            syncWriteFacadeProvider.overrideWithValue(
              _ThrowingSyncFacade(Exception('simulated_sync_failure')),
            ),
            achievementsOverviewProvider.overrideWith(
              (ref) async => const AchievementsOverview(
                rows: [],
                unlockedCount: 0,
                totalMilestones: 0,
                trackFilterOptions: [],
              ),
            ),
          ],
        );
        addTearDown(c.dispose);
        await seedProfileWithIds(
          c.read(userDatabaseProvider),
          accountId: 1,
          profileId: 1,
        );
        await _seedGlobalMilestone(
          c,
          id: 'ms-delete',
          title: 'Delete Me',
          thresholdPoints: 100,
        );
        final milestone = (await RewardMilestoneService(
          c.read(userDatabaseProvider),
          profileId: 1,
        ).getAllMilestones()).first;

        await _notifier(c).deleteMilestone(milestone);

        expect(_state(c).error, isNotNull);
        expect(_state(c).loading, isFalse);
      },
    );

    test(
      'saveReward rethrows TutorWriteException and does NOT set state.error '
      '(the screen\'s own try/catch handles the permission-denied snackbar)',
      () async {
        final c = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(inMemoryDb()),
            activeProfileIdProvider.overrideWithValue(1),
            syncWriteFacadeProvider.overrideWithValue(
              _ThrowingSyncFacade(
                const TutorWriteException(
                  'permission denied',
                  code: 'permission-denied',
                ),
              ),
            ),
            achievementsOverviewProvider.overrideWith(
              (ref) async => const AchievementsOverview(
                rows: [],
                unlockedCount: 0,
                totalMilestones: 0,
                trackFilterOptions: [],
              ),
            ),
          ],
        );
        addTearDown(c.dispose);
        await seedProfileWithIds(
          c.read(userDatabaseProvider),
          accountId: 1,
          profileId: 1,
        );

        _notifier(c).setName('Gold Star');
        _notifier(c).setPointsText('500');

        await expectLater(
          _notifier(c).saveReward(),
          throwsA(isA<TutorWriteException>()),
        );

        // Not surfaced through form.error -- the screen's own
        // `on TutorWriteException catch` already shows the
        // permission-denied snackbar; the spinner must still clear.
        expect(_state(c).error, isNull);
        expect(_state(c).loading, isFalse);
      },
    );
  });

  // ── 24. SM-4 — disposal mid-await (AUD-gamification-01) ────────────────────

  group('SM-4: disposal mid-await does not throw on the disposed ref '
      '(AUD-gamification-01)', () {
    test('disposing the container while saveReward()\'s sync push is in '
        'flight completes the returned Future without an uncaught '
        'disposed-ref exception', () async {
      final gated = _GatedSyncFacade();
      final c = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(inMemoryDb()),
          activeProfileIdProvider.overrideWithValue(1),
          syncWriteFacadeProvider.overrideWithValue(gated),
          achievementsOverviewProvider.overrideWith(
            (ref) async => const AchievementsOverview(
              rows: [],
              unlockedCount: 0,
              totalMilestones: 0,
              trackFilterOptions: [],
            ),
          ),
        ],
      );
      await seedProfileWithIds(
        c.read(userDatabaseProvider),
        accountId: 1,
        profileId: 1,
      );

      _notifier(c).setName('Gold Star');
      _notifier(c).setPointsText('500');

      final future = _notifier(c).saveReward();

      // Let the milestone-lookup + upsert (in-memory DB, sub-millisecond)
      // run to completion so execution parks on `await gated.future`
      // inside _persistAndSync -- this is the await the finding says is
      // unguarded.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Screen/notifier torn down (e.g. a fast back-gesture) while the
      // sync push is still pending.
      c.dispose();

      // Resume the pending push; _persistAndSync's `ref.invalidate(...)`
      // calls and the outer switch's `state = ...` now run against a
      // disposed container. Before the SM-4 fix this threw a
      // "used after dispose" StateError that surfaced on `future`,
      // failing this test instead of completing normally.
      gated.gate.complete();

      await expectLater(future, completes);
    });
  });
}
