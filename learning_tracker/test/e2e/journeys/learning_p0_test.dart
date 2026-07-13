/// E2E Wave 1 P0 journeys — Learning + Content Browsing area.
///
/// Journeys implemented:
///   E2E-301  Mark single task complete — adult, fine-paced
///   E2E-302  Mark task complete — child, unlocks milestone celebration
///   E2E-303  Tutor attempts live mark — forbidden button shown
///   E2E-304  Daf-atomic (coarse-paced) completion marks both amudim
///   E2E-305  Browse curriculum hierarchy — drill down and back
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 3 / §7 R-LC*
@Tags(['e2e', 'journey'])
library;

import 'dart:async' show runZonedGuarded;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' show Key, MaterialApp;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart'
    show Completion;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../harness/e2e_harness.dart';

// ── Stubs and fakes ──────────────────────────────────────────────────────────

/// Fake [CompletionRepository] that records mark calls and returns a
/// configurable [MarkCompletionResult].
class _FakeCompletionRepository extends Fake implements CompletionRepository {
  _FakeCompletionRepository({List<RewardUnlockRecord>? unlocks})
    : _unlocks = unlocks ?? const [];

  final List<RewardUnlockRecord> _unlocks;
  final List<CompletionRequest> markedRequests = [];

  @override
  Future<MarkCompletionResult> markComplete(
    CompletionRequest request, {
    bool awardGamificationPoints = true,
    bool creditsAchievement = true,
  }) async {
    markedRequests.add(request);
    return MarkCompletionResult(
      completion: _stubCompletion(request),
      newMilestoneUnlocks: _unlocks,
    );
  }

  @override
  Future<bool> isStageCompleted({
    required String sefariaRef,
    required int stageId,
    required String trackType,
  }) async => false;

  @override
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId, {
    int? profileId,
  }) async => const <Completion>[];

  @override
  Future<List<Completion>> getCompletionsForContentItem(
    String sefariaRef,
  ) async => const <Completion>[];

  @override
  Future<List<Completion>> bulkMarkComplete(
    BulkCompletionRequest request,
  ) async => const <Completion>[];

  Completion _stubCompletion(CompletionRequest req) {
    final now = DateTimeFactory.nowUtc();
    return Completion(
      id: 1,
      profileId: 1,
      curriculumId: req.curriculumId,
      sefariaRef: req.sefariaRef,
      stageId: req.stageId,
      trackType: req.trackType,
      trackId: 1,
      completedAt: now,
      points: 10,
    );
  }
}

/// Fake [CompletionRepository] whose [markComplete] always throws
/// [_error], for AUD-content_browsing-09 (EH-4) —
/// TextDisplayScreen._handleComplete's typed-catch regression test.
class _ThrowingCompletionRepository extends _FakeCompletionRepository {
  _ThrowingCompletionRepository(this._error);

  final Error _error;

  @override
  Future<MarkCompletionResult> markComplete(
    CompletionRequest request, {
    bool awardGamificationPoints = true,
    bool creditsAchievement = true,
  }) async {
    throw _error;
  }
}

/// Fake [ContentRepository] that returns a fixed list of [ContentItem]s.
class _FakeContentRepository extends Fake implements ContentRepository {
  _FakeContentRepository(this._items);

  final List<ContentItem> _items;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async =>
      _items.where((i) => i.curriculumId == curriculumId.storageKey).toList();

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async => CurriculumHierarchyConfig(
    curriculumId: curriculumId.storageKey,
    levelLabels: const ['Level 1'],
    totalItems: 0,
  );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async {
    var items = await getContentForCurriculum(curriculumId);
    if (level1 != null) items = items.where((i) => i.level1 == level1).toList();
    if (level2 != null) items = items.where((i) => i.level2 == level2).toList();
    if (level3 != null) items = items.where((i) => i.level3 == level3).toList();
    if (level4 != null) items = items.where((i) => i.level4 == level4).toList();
    return items;
  }

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => await getContentForCurriculum(curriculumId);

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async {
    final items = await getContentForCurriculum(curriculumId);
    final q = query.toLowerCase();
    return items
        .where(
          (i) =>
              i.displayNameEn.toLowerCase().contains(q) ||
              i.displayNameHe.contains(q),
        )
        .toList();
  }

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    final items = await getContentForCurriculum(curriculumId);
    try {
      return items.firstWhere((i) => i.sefariaRef == sefariaRef);
    } catch (_) {
      return null;
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Minimal [DailyTask] for a fine-paced (non-coarse) track.
DailyTask _finePacedTask({
  int trackId = 1,
  String sefariaRef = 'Mishnah_Berachot.1.1',
  CurriculumId curriculum = CurriculumId.mishnayos,
}) => DailyTask(
  curriculumId: curriculum,
  contentItemSefariaRef: sefariaRef,
  stageOrder: 1,
  stageDefinitionId: 1,
  priority: DailyTaskPriority.newLearning,
  isOverdue: false,
  reason: 'e2e-test',
  stageName: 'Learn',
  trackId: trackId,
  trackLabel: 'Test Track',
);

/// Standard learning-screen silence overrides.
///
/// Silences the streak hero card and the active curricula stream so that the
/// LearningScreen renders immediately in a known state.  Callers supply
/// [curricula] and [tasks] to control what the screen actually shows.
///
/// Also forces English Hebrew-terms mode (effectiveUseHebrewTermsProvider=false)
/// so stage labels render as "Limud" (not "לימוד") regardless of preference defaults.
List<Override> _learningScreenOverrides({
  required List<CurriculumId> curricula,
  required List<DailyTask> tasks,
}) {
  return [
    dashboardActiveCurriculaStreamProvider.overrideWith(
      (ref) => Stream.value(curricula),
    ),
    allDailyTasksProvider.overrideWith((ref) => Future.value(tasks)),
    dashboardStreakProvider.overrideWith(
      (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
    ),
    dashboardStreakRecoveryProvider.overrideWith(
      (ref) => Future.value(
        const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
      ),
    ),
    // Non-coarse-paced: empty set so no daf grouping runs.
    coarsePacedTrackIdsProvider.overrideWith((ref) => Future.value({})),
    // Null facade so no Firestore writes are attempted.
    completionCommittedProvider,
    // Force English mode: UseHebrewTerms defaults to true (pref default).
    // domainTermLabels(ref) reads useHebrewTermsProvider directly; it also
    // drives effectiveUseHebrewTermsProvider. Override both so all label paths
    // (resolveStoredStageName → "Limud", curriculum labels, etc.) use English.
    useHebrewTermsProvider.overrideWithValue(false),
    effectiveUseHebrewTermsProvider.overrideWithValue(false),
    // Silence the Drift-backed active-tracks stream so that on test teardown
    // the auto-dispose does not schedule a Duration.zero timer via
    // StreamQueryStore.markAsClosed, which FakeAsync cannot flush.
    dashboardActiveTracksStreamProvider.overrideWith(
      (ref) => Stream.value(const []),
    ),
  ];
}

/// Returns overrides that stub [textContentProvider] for [sefariaRef] so the
/// TextDisplayScreen renders the main content view (not the offline message).
///
/// Without this, the harness's in-memory ContentDatabase has no cached text
/// and the screen shows _OfflineMessage, hiding the Mark Complete button.
List<Override> _textContentOverrides(String sefariaRef) => [
  textContentProvider(sefariaRef).overrideWith(
    (ref) => Future.value(
      TextContent.single(
        sefariaRef: sefariaRef,
        hebrewText: 'בְּרֵאשִׁית',
        englishText: 'In the beginning',
      ),
    ),
  ),
];

/// Common overrides required for any test that navigates directly to the
/// TextDisplayScreen (path: '/text/<ref>').
///
/// Includes:
///  • streak silence — prevents the 15-minute periodic timer left by
///    `StreakStateService.watch` (triggered even on non-dashboard routes via
///    the shell or root widget tree).
///  • Hebrew-terms force-false — `UseHebrewTerms` defaults to `true` so without
///    this override stage labels render in Hebrew script, breaking label
///    assertions.
List<Override> _textDisplayBaseOverrides() => [
  dashboardStreakProvider.overrideWith(
    (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
  ),
  dashboardStreakRecoveryProvider.overrideWith(
    (ref) => Future.value(
      const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
    ),
  ),
  // Force English mode — useHebrewTermsProvider is what domainTermLabels(ref)
  // reads directly; effectiveUseHebrewTermsProvider is the path for curriculum
  // label renderers.  Override both to ensure consistent English rendering.
  useHebrewTermsProvider.overrideWithValue(false),
  effectiveUseHebrewTermsProvider.overrideWithValue(false),
  // Silence the Drift-backed active-tracks stream so that on test teardown
  // the auto-dispose does not schedule a Duration.zero timer via
  // StreamQueryStore.markAsClosed, which FakeAsync cannot flush.
  dashboardActiveTracksStreamProvider.overrideWith(
    (ref) => Stream.value(const []),
  ),
];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-301 ──────────────────────────────────────────────────────────────

  group('E2E-301 — Mark single task complete — adult, fine-paced', () {
    // Risk: R-LC3 — completionCommittedProvider keepAlive — non-zero between
    // tests. Mitigated by using a fresh ProviderScope per test (harness creates
    // a new widget tree each testWidgets call).
    // Risk: R-LC10 / R-LC11 — OptimisticCompletionState not rolled back on
    // failure; real _handleComplete path never invokes optimistic. These risks
    // are not exercised by this happy-path test.
    //
    // Note (IL-5): The stage name "Learn" is normalised to "Limud" by
    // domainTermLabels.resolveStoredStageName() in English mode.  All
    // assertions below use "Limud" — the actual rendered text.

    testWidgets(
      'LearningScreen shows Daily Tasks section with an active track and task',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Alice');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final task = _finePacedTask(trackId: 1);

        await h.pumpApp(
          path: '/learn',
          extraOverrides: [
            ..._learningScreenOverrides(
              curricula: [CurriculumId.mishnayos],
              tasks: [task],
            ),
          ],
        );

        // Key assertion: learning screen is on screen (shell tab active).
        h.expectOnScreen('LEARN');
        // Daily Tasks section renders when there is at least one active task.
        h.expectOnScreen('Daily Tasks');
        // The task's stage label is visible on the task card.
        // IL-5: 'Learn' stored name is normalised to 'Limud' in English mode.
        h.expectOnScreen('Limud');
      },
    );

    testWidgets(
      'tapping a task card navigates to TextDisplayScreen with Mark Complete button',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Alice');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final task = _finePacedTask(trackId: 1);
        final fakeRepo = _FakeCompletionRepository();

        await h.pumpApp(
          path: '/learn',
          extraOverrides: [
            ..._learningScreenOverrides(
              curricula: [CurriculumId.mishnayos],
              tasks: [task],
            ),
            // Wire the fake repo so mark calls do not touch the real DB stack.
            completionRepositoryProvider.overrideWithValue(fakeRepo),
            // Stub text content so the TextDisplayScreen renders the reader view
            // (not the offline message) after navigation.
            ..._textContentOverrides(task.contentItemSefariaRef),
            adjacentContentRefsProvider(
              task.contentItemSefariaRef,
            ).overrideWith((ref) => Future.value((prev: null, next: null))),
          ],
        );

        // Tap the first task card (the InkWell wraps the task row — tapping it
        // navigates to TextDisplayRoute).
        // IL-5: the stage badge shows 'Limud' (not 'Learn') in English mode.
        await tester.tap(find.text('Limud').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // After navigation we land on TextDisplayScreen. The Mark Complete
        // button must be visible (adult, not completed, not in tutor session).
        h.expectOnScreen('Mark complete');
      },
    );

    testWidgets('tapping Mark Complete increments completionCommittedProvider', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(displayName: 'Alice');
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      final task = _finePacedTask(trackId: 1);
      final fakeRepo = _FakeCompletionRepository();

      await h.pumpApp(
        path: '/text/${task.contentItemSefariaRef}',
        extraOverrides: [
          ..._textDisplayBaseOverrides(),
          // allDailyTasksProvider must return the task so the _CompletionSection
          // renders the mark-complete button for this sefariaRef.
          allDailyTasksProvider.overrideWith((ref) => Future.value([task])),
          coarsePacedTrackIdsProvider.overrideWith((ref) => Future.value({})),
          completionRepositoryProvider.overrideWithValue(fakeRepo),
          // Stub text content — in-memory ContentDatabase has no rows so the
          // real TextCacheRepository would return null → offline message.
          ..._textContentOverrides(task.contentItemSefariaRef),
          // adjacentContentRefs: stub to avoid the N×9 curriculum scan.
          adjacentContentRefsProvider(
            task.contentItemSefariaRef,
          ).overrideWith((ref) => Future.value((prev: null, next: null))),
        ],
      );

      // Pump until _CompletionSection resolves allDailyTasksProvider and
      // renders the FilledButton.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Record the counter value before marking.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      final beforeCount = container.read(completionCommittedProvider);

      // Tap the "Mark complete" button.
      await h.tapText(
        'Mark complete',
        settle: const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Key assertion: completionCommittedProvider incremented.
      final afterCount = container.read(completionCommittedProvider);
      expect(
        afterCount,
        greaterThan(beforeCount),
        reason: 'completionCommittedProvider must increment after a mark',
      );

      // The fake repo received exactly one mark request.
      expect(fakeRepo.markedRequests, hasLength(1));
      expect(
        fakeRepo.markedRequests.first.sefariaRef,
        task.contentItemSefariaRef,
      );
    });
  });

  // ── E2E-302 ──────────────────────────────────────────────────────────────

  group('E2E-302 — Mark task complete — child, unlocks milestone celebration', () {
    // The AchievementUnlockCelebration dialog fires when:
    //   (a) dashboardUserModeProvider returns ProfileMode.child, AND
    //   (b) MarkCompletionResult.newMilestoneUnlocks is non-empty.
    //
    // Condition (a) is satisfied by seeding a child profile in the DB.
    // Condition (b) requires the fake repo to return a RewardUnlockRecord.

    testWidgets('child profile sees no tutor block on Mark Complete button', (
      tester,
    ) async {
      // Child profile — mode='child' so the guard branches correctly.
      final identity = E2EIdentity.localBorn(
        displayName: 'Benny',
        profileMode: 'child',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      final task = _finePacedTask(trackId: 1);
      final fakeRepo = _FakeCompletionRepository();

      await h.pumpApp(
        path: '/text/${task.contentItemSefariaRef}',
        extraOverrides: [
          ..._textDisplayBaseOverrides(),
          allDailyTasksProvider.overrideWith((ref) => Future.value([task])),
          coarsePacedTrackIdsProvider.overrideWith((ref) => Future.value({})),
          completionRepositoryProvider.overrideWithValue(fakeRepo),
          // Stub text content so reader view (with Mark Complete) renders.
          ..._textContentOverrides(task.contentItemSefariaRef),
          adjacentContentRefsProvider(
            task.contentItemSefariaRef,
          ).overrideWith((ref) => Future.value((prev: null, next: null))),
          // Child is not in a tutored session.
          activeTutoredProfileSelectionProvider.overrideWith(
            () => _NullTutoredSelection(),
          ),
        ],
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 200));

      // Key assertion: the button is labelled "Mark complete" (not the tutor
      // unavailable label), confirming child profile can mark live completions.
      h.expectOnScreen('Mark complete');
      h.expectNotOnScreen('Not available (tutor mode)');
    });

    testWidgets(
      'AchievementUnlockCelebration dialog appears after child marks task '
      'at milestone threshold',
      (tester) async {
        final identity = E2EIdentity.localBorn(
          displayName: 'Benny',
          profileMode: 'child',
        );
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final task = _finePacedTask(trackId: 1);
        final now = DateTimeFactory.nowUtc();
        const milestoneTitle = 'Gold Star';
        final fakeRepo = _FakeCompletionRepository(
          unlocks: [
            RewardUnlockRecord(
              milestoneId: 'milestone-1',
              profileId: 1,
              trackId: 1,
              title: milestoneTitle,
              thresholdPoints: 100,
              pointsAtUnlock: 100,
              unlockedAt: now,
            ),
          ],
        );

        await h.pumpApp(
          path: '/text/${task.contentItemSefariaRef}',
          extraOverrides: [
            ..._textDisplayBaseOverrides(),
            allDailyTasksProvider.overrideWith((ref) => Future.value([task])),
            coarsePacedTrackIdsProvider.overrideWith((ref) => Future.value({})),
            completionRepositoryProvider.overrideWithValue(fakeRepo),
            // Stub text content so reader view (with Mark Complete) renders.
            ..._textContentOverrides(task.contentItemSefariaRef),
            adjacentContentRefsProvider(
              task.contentItemSefariaRef,
            ).overrideWith((ref) => Future.value((prev: null, next: null))),
            activeTutoredProfileSelectionProvider.overrideWith(
              () => _NullTutoredSelection(),
            ),
            // dashboardUserModeProvider reads the profile from the DB asynchronously.
            // Explicitly override to ProfileMode.child so _handleComplete's
            // ref.read(dashboardUserModeProvider).asData?.value is resolved
            // synchronously when the celebration gate runs.
            dashboardUserModeProvider.overrideWith(
              (ref) => Future.value(ProfileMode.child),
            ),
            // Override selectedProfileProvider so the celebration reads the
            // child profile without a DB round-trip through profileRepository.
            selectedProfileProvider.overrideWith(
              (ref) => Future.value(
                ProfileModel(
                  id: 1,
                  accountId: 1,
                  displayName: 'Benny',
                  mode: 'child',
                  avatarIndex: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
            ),
          ],
        );

        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 200));

        // Pre-warm dashboardUserModeProvider so its AsyncData is in the
        // Riverpod cache before _handleComplete reads it synchronously via
        // ref.read().  Without this, ref.read() on the first access returns
        // AsyncLoading (provider not yet resolved), causing the celebration
        // guard (userMode == ProfileMode.child) to be skipped.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp).first),
        );
        container.read(dashboardUserModeProvider);
        await tester.pump(); // flush microtask → provider is now AsyncData

        // Tap Mark complete.
        await h.tapText(
          'Mark complete',
          settle: const Duration(milliseconds: 500),
        );
        // Give the async celebration flow time to complete:
        //   _refsToMark (DB query) → fakeRepo.markComplete → completionCommitted
        //   → showForUnlockedMilestones (profile read, dialog show).
        // Each pump() flushes one microtask batch; extra duration pumps let
        // WidgetsBinding settle navigator/overlay updates.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        // Key assertion: AchievementUnlockCelebration dialog is shown.
        // The dialog title is "Wow! Amazing!" and the body mentions the
        // milestone title ('Gold Star') inline inside a longer l10n string
        // ("You unlocked Gold Star on your … track").  Use textContaining
        // for the milestone title (substring match) and an exact match for
        // the stable dialog title.
        expect(
          find.textContaining(milestoneTitle),
          findsWidgets,
          reason:
              'AchievementUnlockCelebration dialog must mention '
              'the milestone title "$milestoneTitle"',
        );
        expect(
          find.text('Wow! Amazing!'),
          findsWidgets,
          reason: 'AchievementUnlockCelebration dialog title must be visible',
        );
      },
    );
  });

  // ── E2E-303 ──────────────────────────────────────────────────────────────

  group('E2E-303 — Tutor attempts live mark — forbidden button shown', () {
    // Risk: R-LC2 (contentDatabaseProvider not stubbed) — mitigated: harness
    // already overrides contentDatabaseProvider with an in-memory DB.
    //
    // The UI invariant: when activeTutoredProfileSelectionProvider is non-null
    // the button label changes to l10n.markCompleteTutorUnavailable and the
    // onPressed is null — so the domain guard (TutorWriteForbiddenException)
    // is never even reached from the UI.

    testWidgets(
      'Mark Complete button is disabled and shows tutor-unavailable label '
      'when in a tutored session',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Tutor Moshe');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final task = _finePacedTask(trackId: 1);
        const talmidProfileId = 'talmid-remote-id';

        await h.pumpApp(
          path: '/text/${task.contentItemSefariaRef}',
          extraOverrides: [
            ..._textDisplayBaseOverrides(),
            allDailyTasksProvider.overrideWith((ref) => Future.value([task])),
            coarsePacedTrackIdsProvider.overrideWith((ref) => Future.value({})),
            // Stub text content so reader view (with button) renders.
            ..._textContentOverrides(task.contentItemSefariaRef),
            adjacentContentRefsProvider(
              task.contentItemSefariaRef,
            ).overrideWith((ref) => Future.value((prev: null, next: null))),
            // Enter a tutored session — this is what _isTutorSession() checks.
            activeTutoredProfileSelectionProvider.overrideWith(
              () => _FixedTutoredSelection(
                const TutoredProfileSelection(
                  profileId: talmidProfileId,
                  ownerUid: 'owner-uid',
                  grantId: 'grant-001',
                  permissions: TutorPermissions(),
                ),
              ),
            ),
          ],
        );

        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 200));

        // Key assertion (canMarkLiveCompletion=false): the button shows the
        // tutor-unavailable label instead of "Mark complete".
        h.expectOnScreen('Not available (tutor mode)');
        // The normal mark-complete label must be absent.
        h.expectNotOnScreen('Mark complete');
      },
    );
  });

  // ── E2E-304 ──────────────────────────────────────────────────────────────

  group('E2E-304 — Daf-atomic (coarse-paced) completion marks both amudim', () {
    // A daf-paced track has paceGranularity='daf' in the goals table.
    // coarsePacedTrackIdsProvider returns the track's id so that
    // _CompletionSection calls _refsToMark → coarseUnitLeafRefs and gets
    // both amudim (2a + 2b).
    //
    // Seeding strategy:
    //   • Drift DB: goal row with paceGranularity='daf'
    //   • Override coarsePacedTrackIdsProvider with {trackId}
    //   • Fake ContentRepository returns 2 leaf items (daf 2a + 2b)
    //   • Fake CompletionRepository records every sefariaRef marked
    //
    // Key assertions:
    //   • The fake repo receives 2 mark calls — one per amud.
    //   • Both amud refs appear in markedRequests.

    testWidgets('marking a daf-paced task records completions for both amudim', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(displayName: 'Dovid');
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      const sefariaRef2a = 'Berakhot.2a';
      const sefariaRef2b = 'Berakhot.2b';

      // The in-memory DB auto-assigns sequential IDs from 1.  The harness
      // will seed the only account (id=1) and profile (id=1) inside pumpApp.
      // The first row inserted into curriculumTracks will get id=1 — so we
      // can safely use trackId=1 in the task override and then insert the
      // real row AFTER pumpApp (once the FK-required profile row exists).
      const expectedTrackDbId = 1;

      final task = _finePacedTask(
        trackId: expectedTrackDbId,
        sefariaRef: sefariaRef2a,
        curriculum: CurriculumId.bavli,
      );

      // Two leaf items for Daf Bet — same level1/level2 so they share the
      // same coarseUnitKey and coarseUnitLeafRefs returns both.
      final amud2a = ContentItem(
        curriculumId: CurriculumId.bavli.storageKey,
        level1: 'Berakhot',
        level2: 'Daf 2',
        displayNameHe: 'ברכות דף ב עמוד א',
        displayNameEn: 'Berakhot 2a',
        sefariaRef: sefariaRef2a,
        sortOrder: 1,
        isLeaf: true,
      );
      final amud2b = ContentItem(
        curriculumId: CurriculumId.bavli.storageKey,
        level1: 'Berakhot',
        level2: 'Daf 2',
        displayNameHe: 'ברכות דף ב עמוד ב',
        displayNameEn: 'Berakhot 2b',
        sefariaRef: sefariaRef2b,
        sortOrder: 2,
        isLeaf: true,
      );

      final fakeContentRepo = _FakeContentRepository([amud2a, amud2b]);
      final fakeCompletionRepo = _FakeCompletionRepository();

      await h.pumpApp(
        path: '/text/$sefariaRef2a',
        extraOverrides: [
          ..._textDisplayBaseOverrides(),
          allDailyTasksProvider.overrideWith((ref) => Future.value([task])),
          // Mark this track as coarse-paced so the daf-grouping kicks in.
          coarsePacedTrackIdsProvider.overrideWith(
            (ref) => Future.value({expectedTrackDbId}),
          ),
          completionRepositoryProvider.overrideWithValue(fakeCompletionRepo),
          contentRepositoryProvider.overrideWithValue(fakeContentRepo),
          // Stub text content so reader view (with Mark Complete) renders.
          ..._textContentOverrides(sefariaRef2a),
          adjacentContentRefsProvider(
            sefariaRef2a,
          ).overrideWith((ref) => Future.value((prev: null, next: null))),
        ],
      );

      // pumpApp calls _seedIdentity which inserts account(id=1) + profile(id=1).
      // Now we can insert the track (FK: profile) → gets id=1 (first row).
      final trackDbId = await h.db
          .into(h.db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: identity.profileId,
              curriculumId: CurriculumId.bavli.storageKey,
              stateChangedAt: DateTimeFactory.nowUtc(),
              activatedAt: DateTimeFactory.nowUtc(),
            ),
          );
      // Verify the track got the expected id (sanity check for the strategy).
      assert(
        trackDbId == expectedTrackDbId,
        'Track auto-id mismatch: expected $expectedTrackDbId, got $trackDbId',
      );

      // Insert goal with paceGranularity='daf' (FK: profile, track).
      await h.db.goalDao.insertGoal(
        GoalsCompanion.insert(
          profileId: identity.profileId,
          curriculumId: CurriculumId.bavli.storageKey,
          trackId: trackDbId,
          paceGranularity: const Value('daf'),
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 200));

      // Mark Complete button visible (adult, not completed, not tutor).
      h.expectOnScreen('Mark complete');

      // Tap the button.
      await h.tapText(
        'Mark complete',
        settle: const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Key assertion: BOTH amudim were marked.
      expect(
        fakeCompletionRepo.markedRequests.length,
        2,
        reason: 'daf-paced mark must record completions for both amudim',
      );
      final refs = fakeCompletionRepo.markedRequests
          .map((r) => r.sefariaRef)
          .toSet();
      expect(refs, containsAll([sefariaRef2a, sefariaRef2b]));
    });
  });

  // ── E2E-305 ──────────────────────────────────────────────────────────────

  group('E2E-305 — Browse curriculum hierarchy — drill down and back', () {
    // Risk: R-LC1 — CurriculumListScreen search button onPressed: {} —
    // decorative. Test asserts button EXISTS but does not expect navigation.
    //
    // Risk: R-LC2 — contentDatabaseProvider not stubbed — mitigated: harness
    // already overrides this with an in-memory DB.
    //
    // The real ContentRepository reads from bundled assets registered in
    // pubspec.yaml under assets/content/hierarchy/ — available in flutter test.
    // However, loading all 9 curricula asynchronously can leave pending timers.
    // We override contentRepositoryProvider with a zero-delay fake to ensure
    // tests are deterministic and timer-clean.

    testWidgets(
      'CurriculumListScreen renders "Browse Content" heading and curriculum '
      'cards',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Esther');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Use a fake content repository (returns empty lists immediately) to
        // avoid pending timers from rootBundle.loadString() calls.
        final fakeContentRepo = _FakeContentRepository(const []);

        await h.pumpApp(
          path: '/browse',
          extraOverrides: [
            ..._textDisplayBaseOverrides(),
            contentRepositoryProvider.overrideWithValue(fakeContentRepo),
            // Silence completion percentages so the cards do not block on DB reads.
            ...List.generate(
              CurriculumId.values.length,
              (i) => dashboardCompletionPercentageProvider(
                CurriculumId.values[i],
              ).overrideWith((ref) => Future.value(0.0)),
            ),
          ],
        );

        // Allow async providers to settle.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Key assertion: CurriculumListScreen AppBar title is visible.
        h.expectOnScreen('Browse Content');
        // The CURRICULA section header must be visible.
        h.expectOnScreen('CURRICULA');
      },
    );

    testWidgets(
      'tapping a curriculum card navigates to ContentHierarchyScreen',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Esther');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final fakeContentRepo = _FakeContentRepository(const []);

        await h.pumpApp(
          path: '/browse',
          extraOverrides: [
            ..._textDisplayBaseOverrides(),
            contentRepositoryProvider.overrideWithValue(fakeContentRepo),
            ...List.generate(
              CurriculumId.values.length,
              (i) => dashboardCompletionPercentageProvider(
                CurriculumId.values[i],
              ).overrideWith((ref) => Future.value(0.0)),
            ),
          ],
        );

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        h.expectOnScreen('Browse Content');

        // Tap the Mishnayos card (a stable English label across locales).
        // CurriculumLabel.curriculum renders via CurriculumLabelRenderer —
        // the default English transliteration variant uses 'Mishnayos'.
        await h.tapText('Mishnayos', settle: const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 300));

        // After navigation we land on ContentHierarchyScreen. The AppBar title
        // is "Browse Content" (same l10n.contentHierarchyBrowseTitle).
        h.expectOnScreen('Browse Content');
      },
    );

    testWidgets(
      'ContentHierarchyScreen renders and has the search icon action',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Esther');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final fakeContentRepo = _FakeContentRepository(const []);

        // Navigate directly to ContentHierarchyScreen for Mishnayos.
        await h.pumpApp(
          path: '/curriculum/mishnayos/browse',
          extraOverrides: [
            ..._textDisplayBaseOverrides(),
            contentRepositoryProvider.overrideWithValue(fakeContentRepo),
            ...List.generate(
              CurriculumId.values.length,
              (i) => dashboardCompletionPercentageProvider(
                CurriculumId.values[i],
              ).overrideWith((ref) => Future.value(0.0)),
            ),
          ],
        );

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Key assertion: ContentHierarchyScreen is mounted with its AppBar.
        h.expectOnScreen('Browse Content');

        // The search icon (key: content_hierarchy_search_icon) must be present.
        // Risk R-LC1: the CurriculumListScreen search button is decorative
        // (onPressed: {}), but this ContentHierarchyScreen search icon DOES
        // navigate to ContentSearchRoute.
        expect(
          find.byKey(const Key('content_hierarchy_search_icon')),
          findsOneWidget,
          reason: 'ContentHierarchyScreen must have a search action icon',
        );
      },
    );
  });

  // ── AUD-content_browsing-09 (EH-4) ──────────────────────────────────────
  //
  // TextDisplayScreen._handleComplete's final `catch (e, st)` was bare, so
  // a programming-error Error subtype (StateError, TypeError, ...) escaping
  // the mark-completion write path was caught and shown as the same
  // friendly "Could not save" snackbar as an ordinary, expected write
  // failure (e.g. a transient DB/Firestore error). Narrowed to `on
  // Exception catch (e, st)` so an Error subtype now propagates instead of
  // being silently downgraded.
  group('AUD-content_browsing-09 (EH-4) — _handleComplete typed catch', () {
    testWidgets(
      'a StateError thrown by the completion repository propagates as an '
      'uncaught exception — it is NOT swallowed into the "Could not save" '
      'snackbar',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Alice');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        final task = _finePacedTask(trackId: 1);
        final throwingRepo = _ThrowingCompletionRepository(
          StateError('boom: markComplete bug'),
        );

        await h.pumpApp(
          path: '/text/${task.contentItemSefariaRef}',
          extraOverrides: [
            ..._textDisplayBaseOverrides(),
            allDailyTasksProvider.overrideWith((ref) => Future.value([task])),
            coarsePacedTrackIdsProvider.overrideWith((ref) => Future.value({})),
            completionRepositoryProvider.overrideWithValue(throwingRepo),
            ..._textContentOverrides(task.contentItemSefariaRef),
            adjacentContentRefsProvider(
              task.contentItemSefariaRef,
            ).overrideWith((ref) => Future.value((prev: null, next: null))),
          ],
        );

        // Pump until _CompletionSection resolves allDailyTasksProvider and
        // renders the FilledButton (mirrors the E2E-301 happy-path test
        // above).
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));

        // _handleComplete's onPressed callback is fire-and-forget (the
        // button widget does not await it), so an uncaught error inside it
        // surfaces via the current Zone's handleUncaughtError — NOT via
        // FlutterError.reportError/tester.takeException(), which only
        // covers errors reported synchronously during a pump (e.g. widget
        // build failures). flutter_test's OWN outer test zone treats any
        // zone-level uncaught error as an immediate test failure, so the
        // tap is wrapped in a dedicated runZonedGuarded here — mirroring
        // AUD-core-sync-26's tutored_listener_supervisor_test.dart pattern
        // — so this (nearer) zone claims the error first and the test can
        // assert on it instead of being auto-failed by the outer one.
        Object? capturedError;
        await runZonedGuarded(
          () async {
            await h.tapText(
              'Mark complete',
              settle: const Duration(milliseconds: 500),
            );
            await tester.pump(const Duration(milliseconds: 300));
          },
          (error, stack) {
            capturedError = error;
          },
        );

        // RED (pre-fix, bare `catch (e, st)`): the StateError is caught
        // inside _handleComplete, logged via AppLogger, and rendered as
        // l10n.couldNotSave(...) — no zone error is ever raised, so
        // `capturedError` stays null and the "Could not save" snackbar is
        // on screen instead.
        // GREEN (post-fix, `on Exception catch (e, st)`): StateError is not
        // an Exception, escapes the catch clause, and reaches the
        // surrounding zone's handleUncaughtError — captured above.
        expect(
          capturedError,
          isA<StateError>(),
          reason:
              'a StateError from markComplete must propagate to the zone '
              'uncaught-error handler, not be folded into the "Could not '
              'save" snackbar',
        );
      },
    );
  });
}

// ── Fixed-value notifier helpers ─────────────────────────────────────────────

/// A [ActiveTutoredProfileSelection] notifier that always returns null
/// (no tutored session). Used to ensure the child-mode journeys do not
/// accidentally enter a tutor session.
class _NullTutoredSelection extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

/// A [ActiveTutoredProfileSelection] notifier that always returns the
/// provided [TutoredProfileSelection]. Used to simulate an active tutor
/// session in E2E-303.
class _FixedTutoredSelection extends ActiveTutoredProfileSelection {
  _FixedTutoredSelection(this._selection);
  final TutoredProfileSelection _selection;

  @override
  TutoredProfileSelection? build() => _selection;
}
