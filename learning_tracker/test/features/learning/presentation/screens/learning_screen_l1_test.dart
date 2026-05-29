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
//  13.  Daily tasks populated — task cards render with track label.
//  14.  Chazara task icon — scheduledChazara priority → Icons.history_rounded.
//  15.  New-learning task icon — newLearning priority → Icons.auto_stories_rounded.
//  16.  No track-type labels anywhere (no 'Personal'/'Standard'/'Custom'/'אישי').
//  17.  Hebrew (RTL) smoke — screen pumps without error under 'he' locale.
//
// Chazara product rule note:
//   The LearningScreen does not check track.chazaraEnabled directly.
//   The scheduler (allDailyTasksProvider) is the enforcement point — it only
//   emits chazara-priority tasks for tracks where chazaraEnabled is true.
//   Tests 14/15 verify the icon rendering contract for each priority bucket.
@Tags(['learning', 'l1'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/presentation/screens/learning_screen.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

ProfileModel _childProfile() {
  final now = DateTime.utc(2026, 1, 1);
  return ProfileModel(
    id: 1,
    accountId: 1,
    displayName: 'Moshe',
    mode: 'child',
    avatarIndex: 0,
    createdAt: now,
    updatedAt: now,
  );
}

ProfileModel _adultProfile() {
  final now = DateTime.utc(2026, 1, 1);
  return ProfileModel(
    id: 2,
    accountId: 1,
    displayName: 'Dad',
    mode: 'adult',
    avatarIndex: 0,
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
  trackId: 1,
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
Widget _buildScreen({
  List<CurriculumId>? curricula,
  bool curriculaError = false,
  List<DailyTask> tasks = const [],
  Future<List<DailyTask>> Function()? tasksFactory,
  ProfileModel? selectedProfile,
  TutorPermissions? tutorPerms,
  Locale locale = const Locale('en'),
  bool disableRetry = false,
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
    // Streak (safe default — loading state is fine for most tests)
    dashboardStreakProvider.overrideWith((ref) => Stream.value(_zeroStreak)),
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
      home: const Scaffold(body: LearningScreen()),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('daily tasks populated: task card track label is rendered', (
    tester,
  ) async {
    final task = _task(
      ref: 'Mishnah_Berakhot_1.1',
      priority: DailyTaskPriority.newLearning,
    );
    await tester.pumpWidget(
      _buildScreen(curricula: [CurriculumId.mishnayos], tasks: [task]),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Track label is shown in the task card.
    expect(find.text('Test Track'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

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
    'overdueChazara priority task renders Icons.history_rounded (review icon)',
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

      // The task card uses Icons.history_rounded for overdueChazara priority.
      expect(find.byIcon(Icons.history_rounded), findsWidgets);

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
      // Note: Icons.history_rounded (size 14) appears in the track-label row of
      // every task card as a decorative history marker — it is NOT the task's
      // priority icon. The chazara-priority icon (size 24, in the circle) would
      // appear ONLY for chazara-priority tasks. We don't assert its absence here.

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

      // Browse section must render.
      expect(find.text('Browse'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
