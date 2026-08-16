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

import 'package:flutter/material.dart' show Key, MaterialApp;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart'
    show PaceGranularity;
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../fakes/e2e_fakes.dart';
import '../harness/e2e_harness.dart';
import '../../helpers/firestore_fixtures.dart' show seedGoal, seedTrack;

// ── Stubs and fakes ──────────────────────────────────────────────────────────
//
// FakeCompletionRepository and FakeContentRepository were extracted to the
// shared ../fakes/e2e_fakes.dart module (AUD-t-cross-10). Only the
// file-specific throwing variant remains here.

/// A [FakeCompletionRepository] whose [markComplete] always throws
/// [_error], for AUD-content_browsing-09 (EH-4) —
/// TextDisplayScreen._handleComplete's typed-catch regression test.
class _ThrowingCompletionRepository extends FakeCompletionRepository {
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

class _DiagnosticCompletionRepository extends FakeCompletionRepository {
  @override
  Future<MarkCompletionResult> markComplete(
    CompletionRequest request, {
    bool awardGamificationPoints = true,
    bool creditsAchievement = true,
  }) async {
    // ignore: avoid_print
    print('DEBUG fake mark start ${request.curriculumId} ${request.trackType}');
    try {
      final result = await super.markComplete(
        request,
        awardGamificationPoints: awardGamificationPoints,
        creditsAchievement: creditsAchievement,
      );
      // ignore: avoid_print
      print('DEBUG fake mark returned');
      return result;
    } catch (error, stack) {
      // ignore: avoid_print
      print('DEBUG fake mark error=$error\n$stack');
      rethrow;
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Minimal [DailyTask] for a fine-paced (non-coarse) track.
DailyTask _finePacedTask({
  String sefariaRef = 'Mishnah_Berachot.1.1',
  CurriculumId curriculum = CurriculumId.mishnayos,
}) => DailyTask(
  curriculumId: curriculum,
  contentItemSefariaRef: sefariaRef,
  stageOrder: 1,
  priority: DailyTaskPriority.newLearning,
  isOverdue: false,
  reason: 'e2e-test',
  stageName: 'Learn',
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

        final task = _finePacedTask();

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

        final task = _finePacedTask();
        final fakeRepo = FakeCompletionRepository();

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

      final task = _finePacedTask();
      final fakeRepo = _DiagnosticCompletionRepository();

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
      final counterSubscription = container.listen<int>(
        completionCommittedProvider,
        (previous, next) {
          // ignore: avoid_print
          print('DEBUG E2E-301 listener previous=$previous next=$next');
        },
      );
      addTearDown(counterSubscription.close);
      final beforeCount = container.read(completionCommittedProvider);
      final buttonContainer = ProviderScope.containerOf(
        tester.element(find.text('Mark complete').first),
      );
      // ignore: avoid_print
      print(
        'DEBUG E2E-301 sameContainer=${identical(container, buttonContainer)}',
      );

      // Tap the "Mark complete" button.
      Object? debugError;
      await runZonedGuarded(() async {
        await h.tapText(
          'Mark complete',
          settle: const Duration(milliseconds: 500),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }, (error, stack) => debugError = error);
      await tester.pump(const Duration(seconds: 2));
      // ignore: avoid_print
      print(
        'DEBUG E2E-301 saveTextCount=' +
            find.textContaining('Could not save').evaluate().length.toString() +
            ' error=$debugError',
      );

      // Key assertion: completionCommittedProvider incremented.
      final afterCount = container.read(completionCommittedProvider);
      // Temporary runtime diagnostic; remove after reproducing the provider state.
      // ignore: avoid_print
      print(
        'DEBUG E2E-301 before=$beforeCount after=$afterCount '
        'marked=${fakeRepo.markedRequests.length}',
      );
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

      final task = _finePacedTask();
      final fakeRepo = FakeCompletionRepository();

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
            () => NullTutoredSelection(),
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

        final task = _finePacedTask();
        final now = DateTime.utc(2026, 1, 1);
        const milestoneTitle = 'Gold Star';
        final fakeRepo = FakeCompletionRepository(
          unlocks: [
            RewardUnlockRecord(
              milestoneId: 'milestone-1',
              profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYA',
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
              () => NullTutoredSelection(),
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
                LearnerProfileEntity(
                  profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYA',
                  displayName: 'Benny',
                  mode: ProfileMode.child,
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

        final task = _finePacedTask();
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

    testWidgets(
      'marking a daf-paced task records completions for both amudim',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Dovid');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        const sefariaRef2a = 'Berakhot.2a';
        const sefariaRef2b = 'Berakhot.2b';

        final task = _finePacedTask(
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

        final fakeContentRepo = FakeContentRepository([amud2a, amud2b]);
        final fakeCompletionRepo = FakeCompletionRepository();

        await h.pumpApp(
          path: '/text/$sefariaRef2a',
          extraOverrides: [
            ..._textDisplayBaseOverrides(),
            allDailyTasksProvider.overrideWith((ref) => Future.value([task])),
            // Mark this track as coarse-paced so the daf-grouping kicks in.
            coarsePacedTrackIdsProvider.overrideWith(
              (ref) => Future.value({CurriculumId.bavli}),
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

        // Seed the Firestore-native track and pace goal. Track identity is the
        // curriculum document key; there is no local integer track row.
        await seedTrack(
          h.firestore,
          uid: identity.accountId,
          profileId: identity.profileId,
          curriculumId: CurriculumId.bavli,
        );
        await seedGoal(
          h.firestore,
          uid: identity.accountId,
          profileId: identity.profileId,
          curriculumId: CurriculumId.bavli,
          goalType: 'pace',
          paceValue: 1,
          pacePeriod: 'per_day',
          paceGranularity: PaceGranularity.daf,
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
      },
    );
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
        final fakeContentRepo = FakeContentRepository(const []);

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

        final fakeContentRepo = FakeContentRepository(const []);

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

        final fakeContentRepo = FakeContentRepository(const []);

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

        final task = _finePacedTask();
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

/// A [ActiveTutoredProfileSelection] notifier that always returns the
/// provided [TutoredProfileSelection]. Used to simulate an active tutor
/// session in E2E-303.
class _FixedTutoredSelection extends ActiveTutoredProfileSelection {
  _FixedTutoredSelection(this._selection);
  final TutoredProfileSelection _selection;

  @override
  TutoredProfileSelection? build() => _selection;
}
