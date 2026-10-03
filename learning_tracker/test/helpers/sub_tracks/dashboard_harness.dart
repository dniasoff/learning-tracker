/// A deterministic DashboardBody harness for the Story 2.9 (DNI-500)
/// Dashboard sub-track tests (same seams as
/// dashboard_todays_missions_heading_test.dart).
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_body.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:mocktail/mocktail.dart';

import '../pump_app.dart';

/// A mock router that accepts every push.
class DashboardMockRouter extends Mock implements StackRouter {}

/// Fallback for mocktail `any()` on routes.
class DashboardFakeRoute extends Fake implements PageRouteInfo {}

class _ActiveProfileIdOverride extends ActiveProfileId {
  @override
  String build() => '01J6Q2H4A8M7K3P9R5T6V8WXYB';
}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _NoTutorSession extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

CurriculumTrackEntity _track() => CurriculumTrackEntity(
  curriculumId: CurriculumId.mishnayos,
  state: 'active',
  activatedAt: DateTime.utc(2026, 1, 1),
);

/// The non-sub-track dashboard seams, all deterministic.
List<Override> dashboardBaseOverrides() => [
  activeProfileIdProvider.overrideWith(_ActiveProfileIdOverride.new),
  useHebrewTermsProvider.overrideWith(_HebrewTermsOff.new),
  currentTransliterationVariantProvider.overrideWithValue(
    TransliterationVariant.ashkenazi,
  ),
  activeTutoredProfileSelectionProvider.overrideWith(_NoTutorSession.new),
  selectedProfileProvider.overrideWith((ref) => Future.value(null)),
  dashboardActiveCurriculaStreamProvider.overrideWith(
    (ref) => Stream.value([CurriculumId.mishnayos]),
  ),
  dashboardActiveTracksStreamProvider.overrideWith(
    (ref) => Stream.value([_track()]),
  ),
  dashboardUserModeProvider.overrideWith(
    (ref) => Future.value(ProfileMode.adult),
  ),
  dashboardGlobalPointsProvider.overrideWith((ref) => Future.value(0)),
  dashboardStreakProvider.overrideWith(
    (ref) => Stream.value((currentStreak: 7, maxStreak: 7)),
  ),
  allDailyTasksProvider.overrideWith((ref) => Future.value(const [])),
  journeyViewModelProvider.overrideWith(
    (ref) => Future.value(
      const JourneyViewModel(
        curricula: [],
        totalCompletions: 0,
        totalUniqueUnits: 0,
        unitLevelSiyumimCount: 0,
        aggregateLevelSiyumimCount: 0,
        curriculumLevelSiyumimCount: 0,
      ),
    ),
  ),
  lifetimeTotalsAcrossAllCurriculaProvider.overrideWith(
    (ref) => Future.value(
      LifetimeTotals(
        learnedSections: 0,
        totalSections: 100,
        totalCurricula: CurriculumId.values.length,
      ),
    ),
  ),
  trackDualProgressMetricsProvider.overrideWith(
    (ref) => Future.value(const []),
  ),
  anyActiveTrackHasChazaraProvider.overrideWith((ref) => Future.value(false)),
  trackHasChazaraProvider(
    CurriculumId.mishnayos,
  ).overrideWith((ref) => Future.value(false)),
  for (final c in CurriculumId.values)
    dashboardHasProgramEnrollmentProvider(
      c,
    ).overrideWith((ref) => Future.value(false)),
];

/// DashboardBody for an adult with one active Mishnayos track, plus
/// [subTracks] overrides.
Widget dashboardApp({
  required StackRouter router,
  List<Override> subTracks = const [],
  ProfileMode userMode = ProfileMode.adult,
}) => pumpApp(
  overrides: [...dashboardBaseOverrides(), ...subTracks],
  child: StackRouterScope(
    controller: router,
    stateHash: 0,
    child: Scaffold(
      body: DashboardBody(
        activeTracks: [_track()],
        userMode: userMode,
        currentStreak: 7,
      ),
    ),
  ),
);

/// A [DashboardMockRouter] that accepts pushes.
DashboardMockRouter acceptingRouter() {
  final router = DashboardMockRouter();
  when(() => router.canPop()).thenReturn(false);
  when(
    () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
  ).thenAnswer((_) async => null);
  return router;
}
