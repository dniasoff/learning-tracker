/// Pump harnesses for the Epic 2 Dashboard and Learn surfaces with a fake
/// learner state (Story 2.11, DNI-502): the role-visibility sweep (AC-6)
/// and the zero-target copy on both surfaces (AC-4).
///
/// Every legacy provider the two screens read is stubbed with an inert
/// value (no database, no Firebase), so only the forecast surfaces vary.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_body.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/learning/presentation/screens/learning_screen.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../pump_app.dart';
import 'forecast_fixtures.dart';

/// A router stub for surfaces that read `context.router`.
class Epic2MockRouter extends Mock implements StackRouter {}

class _ActiveProfileId extends ActiveProfileId {
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

LearnerProfileEntity _profile(ProfileMode mode) => LearnerProfileEntity(
  profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYB',
  displayName: mode == ProfileMode.child ? 'Yehuda' : 'Dad',
  mode: mode,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

CurriculumTrackEntity _track() => CurriculumTrackEntity(
  curriculumId: CurriculumId.mishnayos,
  state: 'active',
  activatedAt: DateTime.utc(2026),
);

/// Inert legacy providers shared by the Dashboard and Learn surfaces, for a
/// session whose role is [parent] and whose profile mode is [mode].
List<Override> epic2SurfaceOverrides({
  required bool parent,
  required LearnerState state,
  ProfileMode mode = ProfileMode.child,
}) => [
  ...forecastOverrides(parent: parent, state: state),
  activeProfileIdProvider.overrideWith(_ActiveProfileId.new),
  useHebrewTermsProvider.overrideWith(_HebrewTermsOff.new),
  currentTransliterationVariantProvider.overrideWithValue(
    TransliterationVariant.ashkenazi,
  ),
  activeTutoredProfileSelectionProvider.overrideWith(_NoTutorSession.new),
  selectedProfileProvider.overrideWith((ref) async => _profile(mode)),
  dashboardActiveCurriculaStreamProvider.overrideWith(
    (ref) => Stream.value([CurriculumId.mishnayos]),
  ),
  dashboardActiveTracksStreamProvider.overrideWith(
    (ref) => Stream.value([_track()]),
  ),
  dashboardUserModeProvider.overrideWith((ref) async => mode),
  dashboardStreakProvider.overrideWith(
    (ref) => Stream.value((currentStreak: 6, maxStreak: 9)),
  ),
  dashboardGlobalPointsProvider.overrideWith((ref) async => 0),
  dashboardStreakRecoveryProvider.overrideWith(
    (ref) async =>
        const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
  ),
  allDailyTasksProvider.overrideWith((ref) async => const []),
  journeyViewModelProvider.overrideWith(
    (ref) async => const JourneyViewModel(
      curricula: [],
      totalCompletions: 0,
      totalUniqueUnits: 0,
      unitLevelSiyumimCount: 0,
      aggregateLevelSiyumimCount: 0,
      curriculumLevelSiyumimCount: 0,
    ),
  ),
  lifetimeTotalsAcrossAllCurriculaProvider.overrideWith(
    (ref) async => LifetimeTotals(
      learnedSections: 0,
      totalSections: 100,
      totalCurricula: CurriculumId.values.length,
    ),
  ),
  trackDualProgressMetricsProvider.overrideWith((ref) async => const []),
  anyActiveTrackHasChazaraProvider.overrideWith((ref) async => false),
  for (final c in CurriculumId.values)
    dashboardHasProgramEnrollmentProvider(c).overrideWith((ref) async => false),
  coarsePacedTrackIdsProvider.overrideWith(
    (ref) async => const <CurriculumId>{},
  ),
  contentIndexProvider.overrideWith(
    (ref) async => ContentIndex.fromCurricula(const {}),
  ),
];

Widget _routed(StackRouter router, Widget child) =>
    StackRouterScope(controller: router, stateHash: 0, child: child);

/// The Dashboard body for a session whose role is [parent]; [extra]
/// overrides come last (e.g. the learner's sub-tracks).
Widget dashboardSurface({
  required StackRouter router,
  required bool parent,
  required LearnerState state,
  ProfileMode mode = ProfileMode.child,
  ThemeData? theme,
  List<Override> extra = const [],
}) => pumpApp(
  theme: theme ?? AppTheme.lightTheme(),
  overrides: [
    ...epic2SurfaceOverrides(parent: parent, state: state, mode: mode),
    ...extra,
  ],
  child: _routed(
    router,
    Scaffold(
      body: DashboardBody(
        activeTracks: [_track()],
        userMode: mode,
        currentStreak: 6,
      ),
    ),
  ),
);

/// The Learn tab for a session whose role is [parent]; [extra] overrides
/// come last.
Widget learnSurface({
  required StackRouter router,
  required bool parent,
  required LearnerState state,
  ProfileMode mode = ProfileMode.child,
  List<Override> extra = const [],
}) => pumpApp(
  theme: AppTheme.lightTheme(),
  overrides: [
    ...epic2SurfaceOverrides(parent: parent, state: state, mode: mode),
    ...extra,
  ],
  child: _routed(router, const LearningScreen()),
);
