// L1 widget-behaviour tests for LearningScreen
//
// Covers:
//   1.  Loading state — CircularProgressIndicator while curricula stream loads.
//   2.  Error state   — AppErrorView 'Something went wrong' + Retry button.
//   3.  Retry tap     — does not crash; error view stays (provider still fails).
//   4.  Empty state (adult owner) — 'No active tracks' + Add Track button shown.
//   5.  Empty state (child mode) — 'No active tracks' + 'Ask a grown-up' subtitle;
//       Add Track button must NOT appear (child cannot add tracks).
//   6.  Empty state (tutor session, canEditStages=false) — 'Ask a grown-up';
//       Add Track button absent (tutor without edit-stages permission).
//   7.  Empty state (tutor session, canEditStages=true) — Add Track button IS shown.
//   8.  PRODUCT INVARIANT: tutor canMarkLiveCompletion is always false — the
//       active tutor selection fixture verifies the TutorPermissions VO enforces
//       this at model level (no live-mark gating in LearningScreen itself; the
//       affordance lives in TextDisplayScreen which reads the same provider).
//   9.  Data state — streak card, 'Daily Tasks' header, and Browse section rendered.
//  10.  Daily tasks loading — inner CircularProgressIndicator shown.
//  11.  Daily tasks error — AppErrorView shown inside tasks section.
//  12.  Daily tasks empty — 'All caught up' info card rendered.
//  13.  Daily tasks populated — task cards render WITHOUT a track-label row
//       (Rule-7 no-track-types); 13b: a TrackType storageKey never surfaces.
//  14.  Chazara task icon — scheduledChazara priority → Icons.history_rounded.
//  15.  New-learning task icon — newLearning priority → Icons.auto_stories_rounded.
//  16.  No track-type labels anywhere (no 'Personal'/'Standard'/'Custom'/'אישי').
//  17.  Hebrew (RTL) smoke — screen pumps without error under 'he' locale.
//  17b. AUD-learning-05 regression: task-card + browse-card chevrons swap to
//       chevron_left_rounded in RTL, chevron_right_rounded in LTR (AX-3 /
//       IL-7 defect class).
//  19.  E4 regression: tapping a Browse card pushes ContentHierarchyRoute via
//       context.router — never fires an external URL / launchUrl.
//
// Chazara product rule note:
//   The LearningScreen does not check track.chazaraEnabled directly.
//   The scheduler (allDailyTasksProvider) is the enforcement point — it only
//   emits chazara-priority tasks for tracks where chazaraEnabled is true.
//   Tests 14/15 verify the icon rendering contract for each priority bucket.
@Tags(['learning', 'l1'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/presentation/screens/learning_screen.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mock router ───────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Notifier stubs ────────────────────────────────────────────────────────────

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _HebrewTermsOn extends UseHebrewTerms {
  @override
  bool build() => true;
}

/// Tutor session IS active — selection carries default (all-true except
/// canMarkLiveCompletion which the VO always forces to false).
class _FakeTutorSession extends ActiveTutoredProfileSelection {
  _FakeTutorSession(this._perms);
  final TutorPermissions _perms;

  @override
  TutoredProfileSelection? build() => TutoredProfileSelection(
    profileId: 'child_profile_1',
    ownerUid: 'owner_uid',
    grantId: 'grant_1',
    permissions: _perms,
  );
}

/// No active tutored session (normal / owner mode).
class _FakeNoTutorSession extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

LearnerProfileEntity _childProfile() {
  final now = DateTime.utc(2026, 1, 1);
  return LearnerProfileEntity(
    profileId: 'ulid-1',
    displayName: 'Moshe',
    mode: ProfileMode.child,
    createdAt: now,
    updatedAt: now,
  );
}

LearnerProfileEntity _adultProfile() {
  final now = DateTime.utc(2026, 1, 1);
  return LearnerProfileEntity(
    profileId: 'ulid-2',
    displayName: 'Dad',
    mode: ProfileMode.adult,
    createdAt: now,
    updatedAt: now,
  );
}

DailyTask _task({
  CurriculumId curriculum = CurriculumId.mishnayos,
  String ref = 'Mishnah_Berakhot_1.1',
  DailyTaskPriority priority = DailyTaskPriority.newLearning,
  bool isOverdue = false,
  String? stageName,
}) => DailyTask(
  curriculumId: curriculum,
  contentItemSefariaRef: ref,
  stageOrder: priority == DailyTaskPriority.newLearning ? 1 : 2,
  stageDefinitionId: priority == DailyTaskPriority.newLearning ? 1 : 2,
  priority: priority,
  isOverdue: isOverdue,
  reason: 'test',
  stageName:
      stageName ??
      (priority == DailyTaskPriority.newLearning ? 'Learn' : 'Chazara 1'),
  trackLabel: 'Test Track',
  estimatedEffortMinutes: 5,
);

/// Minimal streak value used across tests.
const _zeroStreak = (currentStreak: 0, maxStreak: 0);

/// Builds [LearningScreen] under a controlled test harness.
///
/// [curricula]      — stream emitted by [dashboardActiveCurriculaStreamProvider].
///                   Pass null to keep the provider in loading state.
/// [curriculaError] — if true, stream emits an error (requires [curricula]=null).
/// [tasks]          — future resolved by [allDailyTasksProvider].
/// [tasksFactory]   — factory called by the provider; errors must be created HERE
///                   (not pre-created) so Riverpod attaches a handler before the
///                   zone reports the error. Overrides [tasks] when provided.
/// [selectedProfile]— drives [selectedProfileProvider] (determines isChildMode).
/// [tutorPerms]     — non-null → active tutor session with these permissions.
/// [locale]         — test locale; defaults to 'en'.
/// [disableRetry]   — pass true so FutureProvider errors surface (not loop).
/// [streakStream]   — AUD-t-learning-04: overrides [dashboardStreakProvider]'s
///                   stream directly (loading/error/custom-controller
///                   scenarios the [tasks]/[curricula] params can't express).
///                   Defaults to an immediate zero-streak value.
/// [router]         — AUD-t-learning-04: when supplied, wraps [LearningScreen]
///                   in a [StackRouterScope] bound to this controller (for
///                   tests that verify navigation calls) instead of a bare
///                   [Scaffold].
Widget _buildScreen({
  List<CurriculumId>? curricula,
  bool curriculaError = false,
  List<DailyTask> tasks = const [],
  Future<List<DailyTask>> Function()? tasksFactory,
  LearnerProfileEntity? selectedProfile,
  TutorPermissions? tutorPerms,
  Locale locale = const Locale('en'),
  bool disableRetry = false,
  Stream<({int currentStreak, int maxStreak})>? streakStream,
  StackRouter? router,
}) {
  final overrides = <Override>[
    useHebrewTermsProvider.overrideWith(
      locale.languageCode == 'he' ? _HebrewTermsOn.new : _HebrewTermsOff.new,
    ),
    currentTransliterationVariantProvider.overrideWithValue(
      TransliterationVariant.ashkenazi,
    ),
    // Curricula stream
    dashboardActiveCurriculaStreamProvider.overrideWith((ref) {
      if (curriculaError) {
        return Stream.error(
          Exception('curricula load failed'),
          StackTrace.empty,
        );
      }
      if (curricula == null) {
        // Never-completing stream → stays in loading state.
        return StreamController<List<CurriculumId>>().stream;
      }
      return Stream.value(curricula);
    }),
    // Streak — defaults to an immediate zero-streak value; pass
    // [streakStream] for loading/error/custom-timing scenarios.
    dashboardStreakProvider.overrideWith(
      (ref) => streakStream ?? Stream.value(_zeroStreak),
    ),
    // Daily tasks — use factory to avoid pre-creating Future.error() in zone.
    allDailyTasksProvider.overrideWith(
      (ref) => tasksFactory != null ? tasksFactory() : Future.value(tasks),
    ),
    // Selected profile → drives isChildMode
    selectedProfileProvider.overrideWith(
      (ref) => Future.value(selectedProfile ?? _adultProfile()),
    ),
    // Tutor session
    activeTutoredProfileSelectionProvider.overrideWith(
      tutorPerms != null
          ? () => _FakeTutorSession(tutorPerms)
          : _FakeNoTutorSession.new,
    ),
    // AUD-t-learning-01: stub the two providers LearningScreen watches that
    // would otherwise reach the real userDatabaseProvider / real content
    // asset scan. No test in this file exercises daf (coarse-pace) grouping
    // or ref-breadcrumb resolution, so an always-empty result is inert and
    // preserves every existing assertion.
    coarsePacedTrackIdsProvider.overrideWith(
      (ref) => Future.value(const <CurriculumId>{}),
    ),
    contentIndexProvider.overrideWith(
      (ref) => Future.value(ContentIndex.fromCurricula(const {})),
    ),
  ];

  return ProviderScope(
    retry: disableRetry ? (_, __) => null : null,
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: router == null
          ? const Scaffold(body: LearningScreen())
          : StackRouterScope(
              controller: router,
              stateHash: 0,
              child: const Scaffold(body: LearningScreen()),
            ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    // E4 regression: register fallback values for mocktail router matchers.
    registerFallbackValue(_FakePageRouteInfo());
  });

  // ── 1. Loading state ────────────────────────────────────────────────────────

  testWidgets('shows CircularProgressIndicator while curricula stream loads', (
    tester,
  ) async {
    await tester.pumpWidget(_buildScreen(curricula: null));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── 2. Error state ──────────────────────────────────────────────────────────

  testWidgets(
    'shows AppErrorView with "Something went wrong" when curricula stream errors',
    (tester) async {
      await tester.pumpWidget(
        _buildScreen(curriculaError: true, disableRetry: true),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── 3. Retry tap ────────────────────────────────────────────────────────────

  testWidgets('tapping Retry on curricula error does not crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScreen(curriculaError: true, disableRetry: true),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Error view remains after retry (provider still fails) — no crash.
    expect(find.text('Something went wrong'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── 4. Empty state (adult owner) ────────────────────────────────────────────

  testWidgets(
    'empty state (adult owner): shows "No active tracks" + Add Track button',
    (tester) async {
      await tester.pumpWidget(
        _buildScreen(curricula: const [], selectedProfile: _adultProfile()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No active tracks'), findsOneWidget);
      // Adult non-tutored owner sees the "Add Track" button.
      expect(find.text('Add Track'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('empty state (adult owner): subtitle prompts to add a track', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScreen(curricula: const [], selectedProfile: _adultProfile()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Add a track to start learning.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── 5. Empty state (child mode) ─────────────────────────────────────────────

  testWidgets(
    'empty state (child mode): shows "Ask a grown-up" subtitle; no Add Track button',
    (tester) async {
      await tester.pumpWidget(
        _buildScreen(curricula: const [], selectedProfile: _childProfile()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No active tracks'), findsOneWidget);
      expect(
        find.text('Ask a grown-up to add a learning track.'),
        findsOneWidget,
      );
      // Add Track button must NOT appear in child mode.
      expect(find.text('Add Track'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── 6. Empty state (tutor session, canEditStages=false) ─────────────────────

  testWidgets(
    'empty state (tutor, canEditStages=false): "Ask a grown-up" shown; no Add Track button',
    (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          curricula: const [],
          // Tutor with NO canEditStages permission.
          tutorPerms: const TutorPermissions(canEditStages: false),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No active tracks'), findsOneWidget);
      // Tutor without canEditStages → child-like message; no add button.
      expect(
        find.text('Ask a grown-up to add a learning track.'),
        findsOneWidget,
      );
      expect(find.text('Add Track'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── 7. Empty state (tutor session, canEditStages=true) ──────────────────────

  testWidgets(
    'empty state (tutor, canEditStages=true): Add Track button IS shown',
    (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          curricula: const [],
          // Tutor WITH canEditStages permission.
          tutorPerms: const TutorPermissions(canEditStages: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No active tracks'), findsOneWidget);
      expect(find.text('Add Track'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── 8. Product invariant: tutor canMarkLiveCompletion is always false ────────

  test(
    'PRODUCT INVARIANT: TutorPermissions VO always enforces canMarkLiveCompletion=false',
    () {
      // TutorPermissions constructor hard-codes canMarkLiveCompletion = false
      // regardless of any other flag combination. The live-mark affordance in
      // TextDisplayScreen gates on activeTutoredProfileSelectionProvider != null,
      // which is the same provider used here. This test verifies the VO-level
      // enforcement that no caller can accidentally set canMarkLiveCompletion=true.
      const perms = TutorPermissions(
        canViewProgress: true,
        canViewContent: true,
        canBulkPriorCompletion: true,
        canResetCompletion: true,
        canEditGoals: true,
        canEditStages: true,
        canEditRewards: true,
        canEditStudyDays: true,
        canEditPoints: true,
      );
      expect(
        perms.canMarkLiveCompletion,
        isFalse,
        reason:
            'TutorPermissions must always hard-code canMarkLiveCompletion=false'
            ' regardless of constructor arguments (tutor product rule).',
      );

      // Defaults factory.
      final defaults = TutorPermissions.defaults();
      expect(defaults.canMarkLiveCompletion, isFalse);

      // Read-only factory.
      final readOnly = TutorPermissions.readOnly();
      expect(readOnly.canMarkLiveCompletion, isFalse);

      // copyWith cannot change the invariant.
      final copied = perms.copyWith(canEditGoals: false);
      expect(copied.canMarkLiveCompletion, isFalse);
    },
  );

  test(
    'PRODUCT INVARIANT: TutoredProfileSelection.permissions always has canMarkLiveCompletion=false',
    () {
      // Simulate the active session that LearningScreen reads. The screen is not
      // the live-mark enforcement point (that's TextDisplayScreen), but the
      // provider is the same — confirmed here at the model level.
      const sel = TutoredProfileSelection(
        profileId: 'child_1',
        ownerUid: 'owner_uid',
        grantId: 'grant_1',
        permissions: TutorPermissions(),
      );
      expect(sel.permissions.canMarkLiveCompletion, isFalse);
    },
  );

  // ── 9. Data state ───────────────────────────────────────────────────────────

  testWidgets('data state: streak card and Daily Tasks header rendered', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScreen(curricula: [CurriculumId.mishnayos], tasks: const []),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Streak hero card header
    expect(find.text('CURRENT ACHIEVEMENT'), findsOneWidget);
    // Daily tasks section header
    expect(find.text('Daily Tasks'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('data state: Browse section is rendered', (tester) async {
    await tester.pumpWidget(
      _buildScreen(curricula: [CurriculumId.mishnayos], tasks: const []),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Browse'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── 10. Daily tasks loading ─────────────────────────────────────────────────

  testWidgets('daily tasks loading: inner progress indicator shown', (
    tester,
  ) async {
    final completer = Completer<List<DailyTask>>();
    await tester.pumpWidget(
      _buildScreen(
        curricula: [CurriculumId.mishnayos],
        tasksFactory: () => completer.future,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The _DailyTasksSection shows a CircularProgressIndicator while loading.
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(const []);
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── 11. Daily tasks error ───────────────────────────────────────────────────

  testWidgets('daily tasks error: AppErrorView shown inside tasks section', (
    tester,
  ) async {
    // Use a factory so the Future is created inside the provider (after Riverpod
    // attaches a handler), not in the test zone where it would be unhandled.
    await tester.pumpWidget(
      _buildScreen(
        curricula: [CurriculumId.mishnayos],
        tasksFactory: () =>
            Future.error(Exception('tasks failed'), StackTrace.empty),
        disableRetry: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // AppErrorView is shown in the tasks section.
    expect(find.text('Something went wrong'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── 12. Daily tasks empty ───────────────────────────────────────────────────

  testWidgets('daily tasks empty: "All caught up" info card rendered', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScreen(curricula: [CurriculumId.mishnayos], tasks: const []),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('All caught up'), findsOneWidget);
    expect(find.text('No tasks remaining for today.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── 13. Daily tasks populated ───────────────────────────────────────────────
  //
  // Rule-7 (no track types): the task card MUST NOT render a track label row.
  // Earlier the card rendered `task.trackLabel` verbatim — which, for the
  // scheduler's projection/fresh-plan tasks, was the literal TrackType storage
  // key "personal" (a track-type label, forbidden by the product rule). The fix
  // removes the label row entirely; the stage chip + title carry all context.

  testWidgets(
    'daily tasks populated: task card renders WITHOUT a track-label row',
    (tester) async {
      final task = _task(
        ref: 'Mishnah_Berakhot_1.1',
        priority: DailyTaskPriority.newLearning,
      );
      await tester.pumpWidget(
        _buildScreen(curricula: [CurriculumId.mishnayos], tasks: [task]),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The trackLabel value must NOT appear anywhere on the card.
      expect(find.text('Test Track'), findsNothing);
      // The stage chip (top row of the card) still renders. IL-5 normalised the
      // stage-0 display name from the legacy DB key "Learn" to the canonical
      // transliteration "Limud" in English mode.
      expect(find.text('Limud'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── 13b. Track-type storage keys must never reach the card ──────────────────
  //
  // Regression for the on-device P1: the scheduler set trackLabel to
  // `'personal'` ("personal"), which rendered verbatim as the
  // card's bottom row. Even if a stray task carried that raw value, the card —
  // having no track-label row — must never surface it.

  testWidgets(
    'task card never renders a TrackType storageKey (e.g. "personal"/"אישי")',
    (tester) async {
      // Simulate the pre-fix data leak: a task still carrying the raw storage
      // key. The card must not render it under any locale.
      final leakyTask = _task(
        ref: 'Mishnah_Berakhot_1.1',
        priority: DailyTaskPriority.newLearning,
      ).copyWith(trackLabel: 'personal');

      await tester.pumpWidget(
        _buildScreen(curricula: [CurriculumId.mishnayos], tasks: [leakyTask]),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No TrackType storage key (raw or display form) may appear on the card.
      expect(find.text('personal'), findsNothing);
      expect(find.textContaining('personal'), findsNothing);
      expect(find.text('Personal'), findsNothing);
      expect(find.text('אישי'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── 14. Chazara task icon ───────────────────────────────────────────────────
  //
  // Product rule: chazara UI must only appear when the track has chazaraEnabled.
  // The LearningScreen does not enforce this directly — the scheduler is the
  // enforcement point. The test verifies that when a chazara-priority task IS
  // present (i.e. the scheduler already approved it), the correct icon renders.

  testWidgets(
    'scheduledChazara priority task renders Icons.history_rounded (review icon)',
    (tester) async {
      final chazaraTask = _task(
        priority: DailyTaskPriority.scheduledChazara,
        stageName: 'Chazara 1',
      );
      await tester.pumpWidget(
        _buildScreen(curricula: [CurriculumId.mishnayos], tasks: [chazaraTask]),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.history_rounded), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'overdueChazara (isOverdue) task renders Icons.priority_high_rounded',
    (tester) async {
      final overdueChazara = _task(
        priority: DailyTaskPriority.overdueChazara,
        isOverdue: true,
        stageName: 'Chazara 1',
      );
      await tester.pumpWidget(
        _buildScreen(
          curricula: [CurriculumId.mishnayos],
          tasks: [overdueChazara],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // An overdue task's circle icon is the priority-high marker (the
      // isOverdue branch in the card precedes the priority-based icon). The
      // decorative history icon that previously lived in the track-label row
      // was removed with that row (Rule-7 no-track-types fix).
      expect(find.byIcon(Icons.priority_high_rounded), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── 15. New-learning task icon ──────────────────────────────────────────────

  testWidgets(
    'newLearning priority task renders Icons.auto_stories_rounded (learn icon)',
    (tester) async {
      final newLearningTask = _task(
        priority: DailyTaskPriority.newLearning,
        stageName: 'Learn',
      );
      await tester.pumpWidget(
        _buildScreen(
          curricula: [CurriculumId.mishnayos],
          tasks: [newLearningTask],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // auto_stories_rounded appears as both the task circle icon (size 24) and
      // the Browse section card icon (size 20).
      expect(find.byIcon(Icons.auto_stories_rounded), findsWidgets);
      // Note: the decorative size-14 history icon that used to sit in the
      // track-label row was removed together with that row (Rule-7 no-track-types
      // fix). The history icon now appears ONLY as a chazara-priority circle icon.

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── 16. No track-type labels ────────────────────────────────────────────────

  testWidgets(
    'no track-type labels ("Personal"/"Standard"/"Custom"/"אישי") anywhere',
    (tester) async {
      await tester.pumpWidget(
        _buildScreen(curricula: [CurriculumId.mishnayos], tasks: [_task()]),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);
      expect(find.text('אישי'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── 17. Hebrew (RTL) smoke ──────────────────────────────────────────────────

  testWidgets(
    'Hebrew locale (RTL): screen renders without crash or overflow — empty state',
    (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          curricula: const [],
          selectedProfile: _childProfile(),
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No active tracks string in Hebrew.
      expect(find.text('אין מסלולים פעילים'), findsOneWidget);
      // No crash / overflow.

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'Hebrew locale (RTL): data state — streak card and tasks rendered without overflow',
    (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          curricula: [CurriculumId.mishnayos],
          tasks: [_task()],
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Browse section must render in Hebrew as 'עיון', NOT English 'Browse'.
      // Regression: _BrowseSection previously used a hardcoded English string
      // instead of the localised learnBrowseSectionTitle key.
      expect(
        find.text('עיון'),
        findsOneWidget,
        reason:
            'Browse section title must be localised: Hebrew locale must show'
            " 'עיון', not hardcoded English 'Browse'.",
      );
      expect(
        find.text('Browse'),
        findsNothing,
        reason:
            'English literal "Browse" must not appear when locale is Hebrew.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── 17b. R8 RTL regression: disclosure chevron mirrors via matchTextDirection ─
  //
  // Icons.chevron_right_rounded sets IconData.matchTextDirection: true, so the
  // Icon widget itself horizontally flips the glyph under RTL (Hebrew): the
  // "go to detail" chevron auto-points left with NO per-locale IconData swap.
  // The pre-R8 code manually selected chevron_left_rounded in RTL, but that
  // glyph ALSO auto-mirrors, so it DOUBLE-flipped and pointed right again
  // (device-audit run-8, device 5564 — "repositioned but not flipped"). The
  // invariant is now: the chevron is chevron_right_rounded in BOTH locales,
  // and chevron_left_rounded never appears (its presence would signal the
  // reintroduced double-flip).

  testWidgets('Hebrew locale (RTL): task-card and browse-card chevrons stay '
      'chevron_right_rounded and auto-mirror (no manual chevron_left swap)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildScreen(
        curricula: [CurriculumId.mishnayos],
        tasks: [_task()],
        locale: const Locale('he'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Ambient direction really is RTL for the Hebrew locale.
    final ctx = tester.element(find.byType(LearningScreen));
    expect(Directionality.of(ctx), TextDirection.rtl);

    // The disclosure chevrons are the auto-mirroring glyph, which the Icon
    // widget flips to point left under RTL (matchTextDirection).
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon && widget.icon == Icons.chevron_right_rounded,
      ),
      findsWidgets,
      reason:
          'RTL disclosure chevrons must remain chevron_right_rounded; the '
          'Icon widget mirrors it (matchTextDirection) so it points left.',
    );
    expect(Icons.chevron_right_rounded.matchTextDirection, isTrue);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == Icons.chevron_left_rounded,
      ),
      findsNothing,
      reason:
          'chevron_left_rounded must NOT appear in RTL — it also auto-mirrors, '
          'so a manual rtl→chevron_left swap double-flips and points the '
          'arrow right again (the R8 device-audit RTL defect, 5564).',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('English locale (LTR): task-card and browse-card chevrons are '
      'chevron_right_rounded', (tester) async {
    await tester.pumpWidget(
      _buildScreen(curricula: [CurriculumId.mishnayos], tasks: [_task()]),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon && widget.icon == Icons.chevron_right_rounded,
      ),
      findsWidgets,
      reason:
          'In LTR the disclosure chevrons point right via '
          'chevron_right_rounded (unmirrored).',
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == Icons.chevron_left_rounded,
      ),
      findsNothing,
      reason: 'chevron_left_rounded is never used for these disclosure rows.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── 18. R6-4 regression: streak provider loading/error states ───────────────
  //
  // When dashboardStreakProvider is in AsyncLoading or AsyncError state,
  // the streak hero owns the state without fabricating a streak value.

  testWidgets(
    'streak provider in AsyncLoading — hero shows loading, not a zero streak',
    (tester) async {
      // Use a StreamController so the stream never emits — provider stays in
      // loading.
      final ctrl = StreamController<({int currentStreak, int maxStreak})>();
      await tester.pumpWidget(
        _buildScreen(
          curricula: [CurriculumId.mishnayos],
          streakStream: ctrl.stream,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Screen must render without throwing.
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('0 Day Streak'), findsNothing);

      await ctrl.close();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'streak provider in AsyncError — hero shows an error affordance, not a zero streak',
    (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          curricula: [CurriculumId.mishnayos],
          // disable retry so the error state persists
          disableRetry: true,
          // Streak provider emits an error.
          streakStream: Stream.error(
            Exception('streak DB error'),
            StackTrace.empty,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Screen must render without throwing.
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('0 Day Streak'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── 19. E4 regression — Browse card tap navigates in-app, never launchUrl ──
  //
  // Root cause: in an earlier version of _CurriculumBrowseCard, the onTap
  // handler incorrectly launched an external URI (triggering Android's
  // "Complete action using" intent chooser with music apps) instead of
  // navigating within the app via context.router.push(ContentHierarchyRoute).
  // The fix is: onTap MUST call context.router.push(ContentHierarchyRoute(
  //   curriculumId: curriculum.storageKey)) — no launchUrl, no external URI.
  // This test locks in that behavior by verifying the mock router receives
  // the correct ContentHierarchyRoute push on card tap.

  testWidgets(
    'E4 regression: tapping a Browse card pushes ContentHierarchyRoute, '
    'never launchUrl',
    (tester) async {
      final router = _MockStackRouter();
      when(() => router.canPop()).thenReturn(false);
      when(
        () => router.maybePop<Object?>(any()),
      ).thenAnswer((_) async => false);
      when(
        () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
      ).thenAnswer((_) async => null);

      // Use a single-curriculum screen so the first Browse card is always
      // chumash (first value in CurriculumId.values).
      await tester.pumpWidget(
        _buildScreen(curricula: [CurriculumId.chumash], router: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The Browse section must be visible with a chumash card.
      expect(find.text('Browse'), findsOneWidget);

      // Tap the first (and only) chumash Browse card InkWell.
      // The card occupies a large area; we find the InkWell by its
      // borderRadius and tap the centre. Because all cards share the same
      // structure we find them by Icon and tap the first card area.
      // Use the auto_stories icon that appears inside _CurriculumBrowseCard
      // as a stable landmark, then tap the parent InkWell's region.
      final cardFinder = find.byIcon(Icons.auto_stories_rounded).first;
      expect(cardFinder, findsOneWidget);
      await tester.tap(cardFinder);
      await tester.pump();

      // Verify router.push was called with ContentHierarchyRoute whose
      // curriculumId matches CurriculumId.chumash.storageKey ('chumash').
      // This is the E4 fix invariant: the tap MUST use in-app navigation,
      // never an external URL/launchUrl.
      final captured = verify(
        () => router.push<Object?>(
          captureAny(),
          onFailure: any(named: 'onFailure'),
        ),
      ).captured;

      expect(
        captured.any(
          (arg) =>
              arg is ContentHierarchyRoute &&
              arg.args?.curriculumId == CurriculumId.chumash.storageKey,
        ),
        isTrue,
        reason:
            'E4 fix: tapping a Browse card MUST push ContentHierarchyRoute('
            "curriculumId: '${CurriculumId.chumash.storageKey}') via "
            'context.router — must never fire launchUrl or an external intent.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
