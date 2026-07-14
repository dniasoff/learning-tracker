// Regression test for BUG-#35 — the dashboard OVERDUE / TODAY DUE / CHAZARA
// stat tiles must resolve to concrete counts for a CHILD profile, even when the
// "initial sync complete" flag was never set.
//
// Root cause: the count tiles were gated on
//   `dailyTasksAsync.hasValue && initialSyncComplete`.
// A CHILD profile / tutored session never runs `pullOnLaunch`, so
// `initialSyncCompleteProvider` stays `false` forever and the tiles were
// stranded on the "…" placeholder permanently — even though the local Drift
// query had already resolved.  Per the offline-first rule the local DB is the
// source of truth and sync is informational only, so the tiles must resolve
// from the resolved local query alone.
@Tags(['dashboard'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/sync/initial_sync_state.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_body.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mocks ───────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Notifier stubs ────────────────────────────────────────────────────────────

class _ActiveProfileIdOverride extends ActiveProfileId {
  @override
  int build() => 1;
}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _NoTutorSession extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

CurriculumTrack _track() => CurriculumTrack(
  id: 1,
  profileId: 1,
  curriculumId: CurriculumId.mishnayos.storageKey,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

LifetimeTotals _lifetimeTotals() => LifetimeTotals(
  learnedSections: 0,
  totalSections: 100,
  totalCurricula: CurriculumId.values.length,
);

JourneyViewModel _journey() => const JourneyViewModel(
  curricula: [],
  totalCompletions: 0,
  totalUniqueUnits: 0,
  unitLevelSiyumimCount: 0,
  aggregateLevelSiyumimCount: 0,
  curriculumLevelSiyumimCount: 0,
);

DailyTask _task(DailyTaskPriority priority, {required bool isOverdue}) =>
    DailyTask(
      curriculumId: CurriculumId.mishnayos,
      contentItemSefariaRef: 'Mishnah_Berakhot.1.1',
      stageOrder: 1,
      stageDefinitionId: 1,
      priority: priority,
      isOverdue: isOverdue,
      reason: 'test',
      stageName: 'learn',
      trackId: 1,
      trackLabel: 'Mishnayos',
    );

// One overdue program task, two today program tasks → overdue=1, today=2.
final _tasks = <DailyTask>[
  _task(DailyTaskPriority.overdueProgram, isOverdue: true),
  _task(DailyTaskPriority.todayProgram, isOverdue: false),
  _task(DailyTaskPriority.todayProgram, isOverdue: false),
];

// ── Build helper ──────────────────────────────────────────────────────────────

Widget _buildApp({required _MockStackRouter router}) {
  final track = _track();
  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWith(() => _ActiveProfileIdOverride()),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
      currentTransliterationVariantProvider.overrideWithValue(
        TransliterationVariant.ashkenazi,
      ),
      activeTutoredProfileSelectionProvider.overrideWith(
        () => _NoTutorSession(),
      ),
      selectedProfileProvider.overrideWith((ref) => Future.value(null)),
      dashboardActiveCurriculaStreamProvider.overrideWith(
        (ref) => Stream.value([CurriculumId.mishnayos]),
      ),
      dashboardActiveTracksStreamProvider.overrideWith(
        (ref) => Stream.value([track]),
      ),
      dashboardUserModeProvider.overrideWith(
        (ref) => Future.value(ProfileMode.child),
      ),
      dashboardStreakProvider.overrideWith(
        (ref) => Stream.value((currentStreak: 7, maxStreak: 7)),
      ),
      dashboardGlobalPointsProvider.overrideWith((ref) => Stream.value(72)),
      dashboardStreakRecoveryProvider.overrideWith(
        (ref) => Future.value(
          const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
        ),
      ),
      // Local Drift query HAS resolved with real tasks…
      allDailyTasksProvider.overrideWith((ref) => Future.value(_tasks)),
      // …but the initial-sync flag was NEVER set (the CHILD-profile scenario
      // that never runs pullOnLaunch). Pre-#35 this stranded the tiles on "…".
      initialSyncCompleteProvider.overrideWith((ref) => Future.value(false)),
      journeyViewModelProvider(
        1,
      ).overrideWith((ref) => Future.value(_journey())),
      lifetimeTotalsAcrossAllCurriculaProvider(
        1,
      ).overrideWith((ref) => Future.value(_lifetimeTotals())),
      trackDualProgressMetricsProvider(
        1,
      ).overrideWith((ref) => Future.value(const [])),
      anyActiveTrackHasChazaraProvider.overrideWith(
        (ref) => Future.value(false),
      ),
      for (final c in CurriculumId.values)
        dashboardHasProgramEnrollmentProvider(
          c,
        ).overrideWith((ref) => Future.value(false)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: Scaffold(
          body: DashboardBody(
            activeTracks: [_track()],
            userMode: ProfileMode.child,
            currentStreak: 7,
          ),
        ),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
    SharedPreferences.setMockInitialValues({});
  });

  late _MockStackRouter router;

  setUp(() {
    router = _MockStackRouter();
    when(() => router.canPop()).thenReturn(false);
    when(() => router.maybePop<Object?>(any())).thenAnswer((_) async => false);
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
    when(
      () => router.navigate(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async {});
  });

  testWidgets(
    'BUG-#35: CHILD-mode stat tiles resolve to concrete counts even when '
    'initialSyncComplete is false (offline-first: local DB is authoritative)',
    (tester) async {
      await tester.pumpWidget(_buildApp(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The ellipsis placeholder must NOT be present anywhere — the tiles
      // resolved from the local query rather than being stranded on "…".
      expect(
        find.text('…'),
        findsNothing,
        reason: 'Tiles must not be stuck on the loading placeholder.',
      );

      // OVERDUE = 1, TODAY DUE = 2 → the bubble values resolve to these counts.
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
