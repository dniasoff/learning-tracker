/// Shared E2E journey fixture helpers.
///
/// Extracted from `profiles_p0_test.dart`, `profiles_p1_test.dart`,
/// `profiles_tutoring_p2_test.dart`, `progress_p0_test.dart` and
/// `progress_p1_test.dart`, which each independently redefined the same
/// `_EmptyContentRepository` stub, `_navigateTo` helper and provider
/// "silence" one-liners (AUD-t-cross-20). Import this file instead of
/// copy-pasting a local copy — a provider's override shape only needs to be
/// updated in one place.
///
/// ```dart
/// import '../helpers/e2e_overrides.dart';
///
/// await h.pumpApp(
///   path: '/dashboard',
///   extraOverrides: [
///     ...h.dashboardSilenceOverrides,
///     incomingGrantsEmptyOverride(),
///     pendingInvitesEmptyOverride(),
///   ],
/// );
/// await navigateTo(h, const ProfilePickerRoute());
/// ```
library;

import 'dart:async' show unawaited;

import 'package:auto_route/auto_route.dart' show PageRouteInfo;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show connectivityStreamProvider;
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/parent_settings_screen.dart'
    show activeProfilePointsBalanceProvider, pendingRedemptionsCountProvider;
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart'
    show currentSacredWindowProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show incomingTutorGrantsProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;

import '../harness/e2e_harness.dart';

// ── Navigation ───────────────────────────────────────────────────────────────

/// Navigates to [route] by firing [E2EHarness.router]`.push` without
/// awaiting it and then pumping frames so the async guard chain (auth /
/// profile / restore / PIN guards) can complete.
Future<void> navigateTo(E2EHarness h, PageRouteInfo route) async {
  unawaited(h.router.push(route));
  await h.pump();
  await h.pump(const Duration(milliseconds: 500));
  await h.pump();
}

// ── Silence overrides ────────────────────────────────────────────────────────
//
// Each of these silences a provider that otherwise schedules a timer or
// Drift stream subscription that survives past `h.dispose()` and trips the
// `_verifyInvariants` "no pending timers" assertion in headless
// `testWidgets` runs.

/// Overrides [currentSacredWindowProvider] to return null (no sacred window
/// active), bypassing the notifier's `build()` which schedules a 30-second
/// repeating timer.
Override sacredWindowNullOverride() {
  return currentSacredWindowProvider.overrideWithValue(null);
}

/// Overrides [connectivityStreamProvider] with a static online stream so the
/// connectivity plugin's debounce timer and recovery-probe timer
/// (`Timer.periodic`) are never created.
Override connectivitySilenceOverride() {
  return connectivityStreamProvider.overrideWith((ref) => Stream.value(true));
}

/// One-shot override for [incomingTutorGrantsProvider]. The real
/// implementation calls a Cloud Function; overriding it with an empty list
/// prevents network calls in headless tests.
///
/// Note: [incomingTutorGrantsProvider] here is from `manage_tutors_providers`
/// — the same symbol used by `ProfilePickerScreen` and `SettingsScreen`. A
/// generated provider with the same name in `tutor_grant_providers` is a
/// different object.
Override incomingGrantsEmptyOverride() {
  return incomingTutorGrantsProvider.overrideWith((ref) => Future.value([]));
}

/// One-shot override for [pendingTutorInvitesProvider]. Prevents the
/// generated provider from calling Cloud Functions in headless tests; emits
/// an empty list so no invite cards appear.
Override pendingInvitesEmptyOverride() {
  return pendingTutorInvitesProvider.overrideWith((ref) => Future.value([]));
}

/// Overrides [pendingRedemptionsCountProvider] (Drift stream) with a static
/// zero-stream so `ProviderScope` disposal doesn't leak a Drift cleanup
/// timer.
Override pendingRedemptionsZeroOverride() {
  return pendingRedemptionsCountProvider.overrideWith((ref) => Stream.value(0));
}

/// Overrides [activeProfilePointsBalanceProvider] with a static zero-future
/// so the provider does not perform a live data read in headless tests.
Override pointsBalanceZeroOverride() {
  return activeProfilePointsBalanceProvider.overrideWith(
    (ref) => Future.value(0),
  );
}

// ── Content repository stub ──────────────────────────────────────────────────

/// Minimal [ContentRepository] stub that returns an empty list / no-op
/// response for every member. Prevents the real asset-backed implementation
/// from trying to load JSON bundles in a headless test environment.
///
/// Journeys relying on `curriculumProgressProvider` / `lifetimeDataProvider`
/// pull the content repository under the hood (R-PG8 mitigation) — override
/// `contentRepositoryProvider` with `const EmptyContentRepository()` when
/// those providers are reachable but not under test.
class EmptyContentRepository implements ContentRepository {
  const EmptyContentRepository();

  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId _) async =>
      const [];

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async => CurriculumHierarchyConfig(
    curriculumId: curriculumId.storageKey,
    levelLabels: const ['Seder', 'Masechta', 'Perek', 'Mishna'],
    totalItems: 0,
  );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => const [];

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => const [];

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => const [];

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => null;
}
