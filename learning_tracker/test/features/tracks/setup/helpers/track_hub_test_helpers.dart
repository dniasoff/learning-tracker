/// Shared L1 widget-test scaffolding for the track-management-hub test
/// suite (AUD-t-tracks-02).
///
/// Before this file existed, [HebrewTermsOff], [buildTrack],
/// [perTrackOverrides], [MockStackRouter], [FakePageRouteInfo], [settle],
/// and [teardown] were independently redeclared — byte-for-byte, except for
/// drift — in each of:
///   - test/features/tracks/setup/track_management_hub_last_curriculum_guard_test.dart
///   - test/features/tracks/setup/track_management_hub_screen_l1_test.dart
///   - test/features/tracks/track_management_body_and_order_l1_test.dart
///
/// A future change to `CurriculumTrack`'s shape, or to the per-track
/// override set, required editing all three files in lockstep — easy to
/// miss one (classic shotgun surgery). Centralising here means a change is
/// made once and every call site picks it up.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class MockStackRouter extends Mock implements StackRouter {}

class FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ─── Pin UseHebrewTerms to English ────────────────────────────────────────────

class HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

// ─── Fixture ──────────────────────────────────────────────────────────────────

/// Builds a minimal active [CurriculumTrack] fixture for hub/body/order
/// widget tests.
CurriculumTrack buildTrack({
  int id = 1,
  int profileId = 1,
  String curriculumId = 'mishnayos',
}) => CurriculumTrack(
  id: id,
  profileId: profileId,
  curriculumId: curriculumId,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

// ─── Provider override helpers ────────────────────────────────────────────────

/// Build all per-track provider overrides so [LearningTrackCard] (and
/// similar per-track summary widgets) resolve synchronously without hanging
/// on futures.
List<Override> perTrackOverrides(
  List<CurriculumTrack> tracks, {
  bool chazaraEnabled = false,
}) {
  final overrides = <Override>[];
  for (final t in tracks) {
    overrides.add(
      dashboardTrackCompletionPercentageProvider(
        t.id,
      ).overrideWith((ref) async => 0.0),
    );
    overrides.add(
      trackHasChazaraProvider(t.id).overrideWith((ref) async => chazaraEnabled),
    );
  }
  // The program-enrollment provider is keyed by CurriculumId. Stub mishnayos
  // (our fixture curriculum) to false so the progress row is shown.
  overrides.add(
    dashboardHasProgramEnrollmentProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => false),
  );
  return overrides;
}

// ─── Pump helpers ─────────────────────────────────────────────────────────────

/// Pump until async providers resolve (avoids pumpAndSettle with open
/// streams).
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Dispose widgets cleanly to prevent "deactivated" errors from open
/// streams.
Future<void> teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}
