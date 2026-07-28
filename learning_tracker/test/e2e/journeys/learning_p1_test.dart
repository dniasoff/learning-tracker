/// E2E Wave 2 P1 journeys — Learning + Content Browsing area.
///
/// Journeys implemented:
///   E2E-306  Content search — find and open item
///   E2E-307  Stage breakdown bottom sheet for reviewed item
///   E2E-308  Offline text display — no cached text
///   E2E-309  Empty learn screen — no active tracks, adult
///   E2E-310  Idempotent re-mark — duplicate completion not re-enqueued
///   E2E-311  Prev/Next navigation between sibling text refs
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 3 / §7 R-LC*
@Tags(['e2e', 'journey'])
library;

import 'package:flutter/material.dart'
    show Key, ListTile, MaterialApp, TextField;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../fakes/e2e_fakes.dart';
import '../harness/e2e_harness.dart';

// ── Stubs and fakes ──────────────────────────────────────────────────────────
//
// FakeCompletionRepository and FakeContentRepository were extracted to the
// shared ../fakes/e2e_fakes.dart module (AUD-t-cross-10) — this file's copy
// of filterByLevel used to silently ignore every level argument instead of
// filtering; the shared implementation filters correctly and is exercised
// directly by test/e2e/fakes/e2e_fakes_test.dart.

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Standard overrides for any test rooted on /learn or using the learning
/// screen providers. Mirrors the pattern from learning_p0_test.dart.
List<Override> _learningScreenOverrides({
  required List<CurriculumId> curricula,
  required List<DailyTask> tasks,
}) => [
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
  coarsePacedTrackIdsProvider.overrideWith((ref) => Future.value({})),
  completionCommittedProvider,
  useHebrewTermsProvider.overrideWithValue(false),
  effectiveUseHebrewTermsProvider.overrideWithValue(false),
  dashboardActiveTracksStreamProvider.overrideWith(
    (ref) => Stream.value(const []),
  ),
];

/// Overrides required for tests rooted on /text/<ref>. Keeps the streak
/// providers silent and forces English mode (same as learning_p0_test.dart).
List<Override> _textDisplayBaseOverrides() => [
  dashboardStreakProvider.overrideWith(
    (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
  ),
  dashboardStreakRecoveryProvider.overrideWith(
    (ref) => Future.value(
      const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
    ),
  ),
  useHebrewTermsProvider.overrideWithValue(false),
  effectiveUseHebrewTermsProvider.overrideWithValue(false),
  dashboardActiveTracksStreamProvider.overrideWith(
    (ref) => Stream.value(const []),
  ),
];

/// Stubs [textContentProvider] for [sefariaRef] so TextDisplayScreen renders
/// the reader view (not the _OfflineMessage).
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

/// Builds a minimal fake [ContentIndex] containing [refsInOrder] as
/// sequential leaves of one fake curriculum, so `contentIndex.adjacent(ref)`
/// resolves prev/next exactly as that reading order implies.
///
/// READER CHEVRON TAP-SWALLOW FIX: the reader's chevrons now read adjacency
/// synchronously off [contentIndexProvider] instead of the async
/// `adjacentContentRefsProvider` (see text_display_screen.dart's fix note),
/// so E2E-311 wires the fake chain through here rather than stubbing
/// `adjacentContentRefsProvider` per-ref as before.
ContentIndex _fakeContentIndex(List<String> refsInOrder) {
  final items = [
    for (var i = 0; i < refsInOrder.length; i++)
      ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Fake Chapter',
        level4: 'Item $i',
        displayNameHe: refsInOrder[i],
        displayNameEn: refsInOrder[i],
        sefariaRef: refsInOrder[i],
        sortOrder: i,
        isLeaf: true,
      ),
  ];
  return ContentIndex.fromCurricula({CurriculumId.mishnayos: items});
}

/// A minimal daily task on the fine-paced (non-coarse) Mishnayos curriculum.
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

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-306 ──────────────────────────────────────────────────────────────

  group('E2E-306 — Content search — find and open item', () {
    // Risk R-LC1: CurriculumListScreen search button is decorative, but
    // ContentSearchScreen itself IS navigable — verified here.
    //
    // Drive via h.router.push(ContentSearchRoute) to avoid relying on the
    // decorative search button in CurriculumListScreen.

    testWidgets('ContentSearchScreen renders with a search field', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(displayName: 'Avi');
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      final fakeRepo = FakeContentRepository([]);

      await h.pumpApp(
        path: '/curriculum/mishnayos/search',
        extraOverrides: [
          ..._textDisplayBaseOverrides(),
          contentRepositoryProvider.overrideWithValue(fakeRepo),
          anyActiveTrackHasChazaraProvider.overrideWith(
            (ref) => Future.value(false),
          ),
        ],
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Key assertion: the hint text for an empty query is always visible.
      h.expectOnScreen('Enter a search term above');
    });

    testWidgets(
      'typing a query shows matching results; tapping a leaf navigates to '
      'TextDisplayScreen',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Avi');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        const matchRef = 'Mishnah_Berachot.1.1';
        // Use the real data shape: level1=Seder name, level2=Masechta name,
        // level3=ordinal perek number, level4=ordinal mishna number.
        // In English mode (useHebrew=false), levels 1+2 are named (no prefix),
        // levels 3+4 are ordinal with prefixes.
        // Level 2 'Mishnah Berakhot' maps → 'Berakhos' in Ashkenazi.
        final matchItem = ContentItem(
          curriculumId: CurriculumId.mishnayos.storageKey,
          level1: 'Zeraim',
          level2: 'Mishnah Berakhot',
          level3: '1',
          level4: '1',
          displayNameHe: 'ברכות א׳:א׳',
          displayNameEn: 'Berakhos 1:1',
          sefariaRef: matchRef,
          sortOrder: 1,
          isLeaf: true,
        );

        final fakeRepo = FakeContentRepository([matchItem]);

        await h.pumpApp(
          path: '/curriculum/mishnayos/search',
          extraOverrides: [
            ..._textDisplayBaseOverrides(),
            contentRepositoryProvider.overrideWithValue(fakeRepo),
            anyActiveTrackHasChazaraProvider.overrideWith(
              (ref) => Future.value(false),
            ),
            // Stub adjacent refs to avoid curriculum content scan in reader.
            adjacentContentRefsProvider(
              matchRef,
            ).overrideWith((ref) => Future.value((prev: null, next: null))),
            // Stub text content for the reader page.
            ..._textContentOverrides(matchRef),
          ],
        );

        await tester.pump(const Duration(milliseconds: 300));

        // Enter the query that matches displayNameEn ('Berakhos 1:1').
        await h.enterText(find.byType(TextField).first, 'Berakhos');

        // Fire the 300ms debounce timer: advance fake time past the 300ms
        // threshold. The timer callback calls setState.
        await tester.pump(const Duration(milliseconds: 350));
        // Flush the setState-triggered frame rebuild.
        await tester.pump();
        // Let the FutureProvider for search results resolve (microtask + frame).
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        // Key assertion: the result list is non-empty (a ListTile appeared).
        // Use find.byType(ListTile) to avoid false matches with the AppBar
        // hint text ("Search Mishnayos…").
        expect(
          find.byType(ListTile),
          findsWidgets,
          reason: 'search result list must show at least one item after query',
        );

        // Tap the first ListTile result (the onTap opens TextDisplayRoute for
        // a leaf item).
        await h.tapWidget(
          find.byType(ListTile).first,
          settle: const Duration(milliseconds: 500),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Key assertion: the reader renders the text (not the offline message).
        h.expectOnScreen('In the beginning');
      },
    );
  });

  // ── E2E-307 ──────────────────────────────────────────────────────────────

  group('E2E-307 — Stage breakdown bottom sheet for reviewed item', () {
    // Risk R-LC6: onLongPress on ContentItemTile is null when count=0 —
    // so the test MUST seed a completion for the item beforehand, otherwise
    // the long-press is a no-op and the sheet never appears.
    //
    // Risk R-LC9: _StageBreakdownSheet uses FutureBuilder — first frame shows
    // fallback labels. Await pumpAndSettle before asserting stage names.

    testWidgets(
      'long-pressing a leaf ContentItemTile (count>0) shows _StageBreakdownSheet',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Batya');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        // Use a SINGLE-LEVEL item (no level2/3/4) so the ContentHierarchyScreen
        // renders it directly as a leaf tile at the top level view.
        // Level 1 in Mishnayos is "named" so it renders the raw value.
        const reviewRef = 'Mishnah_Berachot.1.1';
        final reviewItem = ContentItem(
          curriculumId: CurriculumId.mishnayos.storageKey,
          level1: 'BerakhotSeder', // single-level: no level2/3/4
          displayNameHe: 'ברכות',
          displayNameEn: 'BerakhotSeder',
          sefariaRef: reviewRef,
          sortOrder: 1,
          isLeaf: true,
        );

        final fakeRepo = FakeContentRepository([reviewItem]);

        await h.pumpApp(
          // ContentSearchScreen shows all results in a flat list; use a query
          // that matches our item so the ContentItemTile is visible.
          path: '/curriculum/mishnayos/search',
          extraOverrides: [
            ..._textDisplayBaseOverrides(),
            contentRepositoryProvider.overrideWithValue(fakeRepo),
            anyActiveTrackHasChazaraProvider.overrideWith(
              (ref) => Future.value(true),
            ),
            // Override completionCountProvider so the tile reads count=1 and
            // activates the onLongPress (R-LC6: null when count=0).
            completionCountProvider(
              curriculumId: CurriculumId.mishnayos.storageKey,
              sefariaRef: reviewRef,
            ).overrideWith((ref) => Future.value(1)),
            // Override itemStageBreakdownProvider to return {stageId:1, count:1}.
            itemStageBreakdownProvider((
              curriculumId: CurriculumId.mishnayos.storageKey,
              sefariaRef: reviewRef,
            )).overrideWith((ref) => Future.value({1: 1})),
          ],
        );

        await tester.pump(const Duration(milliseconds: 300));

        // Type query to trigger search results (debounce 300 ms).
        await h.enterText(find.byType(TextField).first, 'Berakhot');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 300));

        // Key assertion: a result tile appeared.
        // Level 1 "named" in Mishnayos — renders the transliterated raw value
        // 'BerakhotSeder' unchanged (it's not in the transliteration map).
        expect(
          find.textContaining('BerakhotSeder'),
          findsWidgets,
          reason: 'ContentItemTile must be visible after search',
        );

        // Extra pumps to ensure completionCountProvider and
        // anyActiveTrackHasChazaraProvider async values resolve (so count=1
        // and showReviewBadge=true are reflected in the ListTile.onLongPress).
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));

        // Long-press the ListTile widget directly (reliable hit-test target).
        // The ListTile is the gesture-handling ancestor of the text label.
        await tester.longPress(find.byType(ListTile).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // R-LC9: _StageBreakdownSheet uses FutureBuilder; await settle so the
        // inner FutureBuilder completes and stage names are available.
        await tester.pumpAndSettle();

        // Key assertion: the bottom sheet header "Review History" is visible.
        h.expectOnScreen('Review History');
      },
    );
  });

  // ── E2E-308 ──────────────────────────────────────────────────────────────

  group('E2E-308 — Offline text display — no cached text', () {
    // When textContentProvider returns null (no cached text and offline),
    // TextDisplayScreen shows the _OfflineMessage widget.
    // Key l10n strings: textReaderTextUnavailableTitle / textReaderCheckConnection.

    testWidgets(
      'TextDisplayScreen shows "Text not available" message when cache is empty',
      (tester) async {
        const offlineRef = 'Mishnah_Shabbat.1.1';

        final identity = E2EIdentity.localBorn(displayName: 'Chana');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/text/$offlineRef',
          extraOverrides: [
            ..._textDisplayBaseOverrides(),
            // No cached text — textContentProvider returns null.
            textContentProvider(
              offlineRef,
            ).overrideWith((ref) => Future<TextContent?>.value(null)),
            // No adjacent siblings needed (screen never reaches the reader view).
            adjacentContentRefsProvider(
              offlineRef,
            ).overrideWith((ref) => Future.value((prev: null, next: null))),
            // No tasks — not needed for the offline display test.
            allDailyTasksProvider.overrideWith((ref) => Future.value([])),
            coarsePacedTrackIdsProvider.overrideWith((ref) => Future.value({})),
          ],
        );

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Key assertion: the offline/not-available message is shown.
        h.expectOnScreen('Text not available');
        h.expectOnScreen('Check your internet connection and try again.');

        // Key assertion: no crash — the widget tree is still mounted.
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ── E2E-309 ──────────────────────────────────────────────────────────────

  group('E2E-309 — Empty learn screen — no active tracks, adult', () {
    // When the active-curricula stream returns [] the LearningScreen renders
    // an EmptyState with message=noActiveTracks and an "Add Track" CTA.
    // This is adult mode: canAddTrack=true, isTutoredSession=false.

    testWidgets(
      'LearningScreen shows empty state with Add Track CTA when no active tracks',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Devorah');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        await h.pumpApp(
          path: '/learn',
          extraOverrides: [
            ..._learningScreenOverrides(curricula: [], tasks: []),
            activeTutoredProfileSelectionProvider.overrideWith(
              () => NullTutoredSelection(),
            ),
          ],
        );

        await tester.pump(const Duration(milliseconds: 300));

        // Key assertion: empty state message visible.
        h.expectOnScreen('No active tracks');

        // Key assertion: CTA subtitle visible.
        h.expectOnScreen('Add a track to start learning.');

        // Key assertion: "Add Track" button visible (adult, not tutored).
        h.expectOnScreen('Add Track');
      },
    );
  });

  // ── E2E-310 ──────────────────────────────────────────────────────────────

  group('E2E-310 — Idempotent re-mark — duplicate completion not re-enqueued', () {
    // When a task is already marked (isStageCompletedProvider returns true)
    // the Mark Complete button shows "Completed (…)" and its onPressed is null —
    // so a second tap does nothing and the fake repo receives 0 mark calls.
    //
    // We assert:
    //   • Button label changes to the "Completed (stageName)" form.
    //   • completionCommittedProvider does NOT increment on a second tap.
    //   • fakeRepo.markedRequests is empty (button was disabled).

    testWidgets(
      'already-completed item shows "Completed (Limud)" label and disables '
      'the button (preventing duplicate enqueue)',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Eliyahu');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        const alreadyDoneRef = 'Mishnah_Berachot.1.1';
        final task = _finePacedTask(sefariaRef: alreadyDoneRef);
        final fakeRepo = FakeCompletionRepository();

        await h.pumpApp(
          path: '/text/$alreadyDoneRef',
          extraOverrides: [
            ..._textDisplayBaseOverrides(),
            allDailyTasksProvider.overrideWith((ref) => Future.value([task])),
            coarsePacedTrackIdsProvider.overrideWith((ref) => Future.value({})),
            completionRepositoryProvider.overrideWithValue(fakeRepo),
            ..._textContentOverrides(alreadyDoneRef),
            adjacentContentRefsProvider(
              alreadyDoneRef,
            ).overrideWith((ref) => Future.value((prev: null, next: null))),
            // Override isStageCompletedProvider globally so every params
            // combination returns true — simulates an already-completed item.
            isStageCompletedProvider.overrideWith(
              (ref, params) => Future.value(true),
            ),
          ],
        );

        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 200));

        // Key assertion: the button shows the "Completed (Limud)" label.
        // IL-5: stored name 'Learn' is normalised to 'Limud' in English mode.
        expect(
          find.textContaining('Completed'),
          findsWidgets,
          reason:
              'already-completed item must show "Completed" label on button',
        );

        // Key assertion: the normal "Mark complete" label must be absent
        // (button is in the already-done state).
        h.expectNotOnScreen('Mark complete');

        // Attempt to tap — button is disabled (onPressed == null); framework
        // silently ignores the tap.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp).first),
        );
        final counterBefore = container.read(completionCommittedProvider);

        // Use tester.tap directly — h.tapText would find the disabled button
        // and tap it but expect it to navigate; we just want to confirm nothing
        // was re-enqueued.
        await tester.tap(find.textContaining('Completed').first);
        await tester.pump(const Duration(milliseconds: 300));

        // Key assertion: counter did not change (button onPressed was null).
        expect(
          container.read(completionCommittedProvider),
          equals(counterBefore),
          reason:
              'completionCommittedProvider must NOT increment when button is '
              'disabled for an already-completed item',
        );

        // Key assertion: the fake repo received zero mark calls.
        expect(
          fakeRepo.markedRequests,
          isEmpty,
          reason:
              'no completion must be written when the button is already-done',
        );
      },
    );
  });

  // ── E2E-311 ──────────────────────────────────────────────────────────────

  group('E2E-311 — Prev/Next navigation between sibling text refs', () {
    // Risk R-LC4: contentIndexProvider does a full curriculum scan when
    // backed by the real ContentRepository. Stub it (via _fakeContentIndex)
    // with a fixed list of two items so it resolves instantly.
    //
    // The TextDisplayScreen renders:
    //   • a chevron_left IconButton (Previous) — enabled when adj.prev != null
    //   • a chevron_right IconButton (Next)    — enabled when adj.next != null
    //
    // READER CHEVRON TAP-SWALLOW FIX: both chevrons now update the displayed
    // ref via in-widget state (a synchronous ContentIndex.adjacent() lookup)
    // instead of context.router.replace — see text_display_screen.dart's
    // fix note. After tapping Next the SAME TextDisplayScreen instance shows
    // the sibling's content; no new route is pushed/replaced.

    testWidgets(
      'Next chevron is enabled when adjacentContentRefsProvider has a next ref',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Frida');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        const currentRef = 'Mishnah_Berachot.1.1';
        const nextRef = 'Mishnah_Berachot.1.2';

        await h.pumpApp(
          path: '/text/$currentRef',
          extraOverrides: [
            ..._textDisplayBaseOverrides(),
            allDailyTasksProvider.overrideWith((ref) => Future.value([])),
            coarsePacedTrackIdsProvider.overrideWith((ref) => Future.value({})),
            ..._textContentOverrides(currentRef),
            // Risk R-LC4: stub a fixed 2-item chain so the chevron's
            // synchronous ContentIndex.adjacent() lookup resolves instantly.
            contentIndexProvider.overrideWith(
              (ref) async => _fakeContentIndex([currentRef, nextRef]),
            ),
          ],
        );

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // The AppBar is visible.
        h.expectOnScreen('In the beginning');

        // Key assertion: the chevron_right button (Next) is present.
        // We cannot easily assert enabled/disabled without inspecting the
        // IconButton widget; instead we assert the tooltip is visible and
        // can be tapped.
        expect(
          find.byTooltip('Next'),
          findsOneWidget,
          reason: 'TextDisplayScreen must have a Next (chevron_right) action',
        );
      },
    );

    testWidgets(
      'tapping the Next chevron navigates to the adjacent sibling ref',
      (tester) async {
        final identity = E2EIdentity.localBorn(displayName: 'Frida');
        final h = E2EHarness(tester, identity: identity);
        addTearDown(h.dispose);

        const currentRef = 'Mishnah_Berachot.1.1';
        const nextRef = 'Mishnah_Berachot.1.2';

        const currentText = 'In the beginning';
        const nextText = 'And it was evening';

        await h.pumpApp(
          path: '/text/$currentRef',
          extraOverrides: [
            ..._textDisplayBaseOverrides(),
            allDailyTasksProvider.overrideWith((ref) => Future.value([])),
            coarsePacedTrackIdsProvider.overrideWith((ref) => Future.value({})),
            // Stub text for both the current and the next ref.
            textContentProvider(currentRef).overrideWith(
              (ref) => Future.value(
                TextContent.single(
                  sefariaRef: currentRef,
                  hebrewText: 'בְּרֵאשִׁית',
                  englishText: currentText,
                ),
              ),
            ),
            textContentProvider(nextRef).overrideWith(
              (ref) => Future.value(
                TextContent.single(
                  sefariaRef: nextRef,
                  hebrewText: 'וַיְהִי עֶרֶב',
                  englishText: nextText,
                ),
              ),
            ),
            // Fake chain covering both pages' adjacency.
            contentIndexProvider.overrideWith(
              (ref) async => _fakeContentIndex([currentRef, nextRef]),
            ),
          ],
        );

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Current page is visible.
        h.expectOnScreen(currentText);

        // Tap the Next (chevron_right) button.
        await h.tapByKey(const Key('text_display_next_button'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Key assertion: we are now on the sibling page.
        h.expectOnScreen(nextText);
      },
    );

    testWidgets('Back chevron navigates to previous ref from second item', (
      tester,
    ) async {
      // Start on the second item so prev is non-null.
      final identity = E2EIdentity.localBorn(displayName: 'Frida');
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      const prevRef = 'Mishnah_Berachot.1.1';
      const currentRef = 'Mishnah_Berachot.1.2';

      const prevText = 'In the beginning';
      const currentText = 'And it was evening';

      await h.pumpApp(
        path: '/text/$currentRef',
        extraOverrides: [
          ..._textDisplayBaseOverrides(),
          allDailyTasksProvider.overrideWith((ref) => Future.value([])),
          coarsePacedTrackIdsProvider.overrideWith((ref) => Future.value({})),
          textContentProvider(currentRef).overrideWith(
            (ref) => Future.value(
              TextContent.single(
                sefariaRef: currentRef,
                hebrewText: 'וַיְהִי עֶרֶב',
                englishText: currentText,
              ),
            ),
          ),
          textContentProvider(prevRef).overrideWith(
            (ref) => Future.value(
              TextContent.single(
                sefariaRef: prevRef,
                hebrewText: 'בְּרֵאשִׁית',
                englishText: prevText,
              ),
            ),
          ),
          // Fake chain covering both pages' adjacency.
          contentIndexProvider.overrideWith(
            (ref) async => _fakeContentIndex([prevRef, currentRef]),
          ),
        ],
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Current page (second item) is visible.
      h.expectOnScreen(currentText);

      // Tap the Back (chevron_left / Previous) button.
      await h.tapByKey(const Key('text_display_prev_button'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Key assertion: navigated back to the previous item.
      h.expectOnScreen(prevText);
    });
  });
}
