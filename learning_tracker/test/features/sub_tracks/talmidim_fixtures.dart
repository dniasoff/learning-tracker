/// Shared fixtures for the My talmidim tests (Story 4.3, DNI-511).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is only re-exported from `misc.dart` (as test/helpers/pump_app).
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_context_opener.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_roster_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_row_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/my_talmidim_screen.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

import '../../helpers/dashboard/forecast_fixtures.dart';
import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/pump_app.dart';

/// The owner uid of the [n]th test parent.
String talmidOwner(int n) => 'parent-uid-$n';

/// The learner profile ULID of the [n]th talmid.
String talmidProfile(int n) => engineUlid(7000 + n);

/// A `listTutorGrants` grant in [state] for talmid [n].
TutorGrant talmidGrant(
  int n, {
  TutorGrantState state = TutorGrantState.active,
  String? name,
  bool canEditLearning = true,
  int owner = 1,
}) {
  final at = DateTime.utc(2026, 9, 1);
  return TutorGrant.fromDoc(
    TutorGrantDoc(
      grantId: 'grant-$n',
      parentUid: talmidOwner(owner),
      childProfileId: talmidProfile(n),
      tutorEmail: 'rebbe@example.com',
      tutorUid: 'tutor-uid',
      state: state,
      invitedAt: at,
      updatedAt: at,
      childName: name,
    ),
    permissions: TutorPermissions(canEditLearning: canEditLearning),
  );
}

/// The roster entry of talmid [n].
TalmidRosterEntry talmidEntry(
  int n, {
  String? name,
  bool canEditLearning = true,
  int owner = 1,
}) => TalmidRosterEntry(
  grantId: 'grant-$n',
  ownerUid: talmidOwner(owner),
  profileId: talmidProfile(n),
  displayName: name,
  permissions: TutorPermissions(canEditLearning: canEditLearning),
);

/// A roster repository answering from a script: each load pops the next
/// answer (a list, or an error to throw); the last one repeats.
final class ScriptedTutorRosterRepository implements TutorRosterRepository {
  /// Creates the repository.
  ScriptedTutorRosterRepository(this.answers);

  /// The scripted answers.
  final List<Object> answers;

  /// Loads so far.
  int loads = 0;

  @override
  Future<List<TalmidRosterEntry>> loadActiveTalmidim() async {
    final answer = answers[loads < answers.length ? loads : answers.length - 1];
    loads++;
    if (answer is List<TalmidRosterEntry>) return answer;
    if (answer is Exception) throw answer;
    throw StateError('unscripted answer: $answer');
  }
}

/// The scope of talmid [n].
LearnerScope talmidScope(int n, {int owner = 1}) =>
    LearnerScope(ownerUid: talmidOwner(owner), profileId: talmidProfile(n));

/// Per-scope inputs for the row providers: engine states and lock states
/// (loading when absent), and how often each was read.
final class FakeTalmidInputs {
  /// The engine state of each scope.
  final Map<LearnerScope, AsyncValue<LearnerState>> states = {};

  /// The lock state of each scope; open by default.
  final Map<LearnerScope, AsyncValue<bool>> locks = {};

  /// Scopes without an entry in [locks] are this.
  AsyncValue<bool> defaultLock = const AsyncData(false);

  /// Engine-state reads per scope (one per row evaluation).
  final Map<LearnerScope, int> stateReads = {};

  /// The overrides feeding the row providers from this object.
  List<Override> get overrides => [stateOverride, lockOverride];

  /// The engine-state seam alone (a test may keep the real lock path).
  Override get stateOverride =>
      talmidLearnerStateProvider.overrideWith((ref, scope) {
        stateReads[scope] = (stateReads[scope] ?? 0) + 1;
        return states[scope] ?? const AsyncLoading<LearnerState>();
      });

  /// The lock seam alone.
  Override get lockOverride => talmidLockProvider.overrideWith(
    (ref, scope) => locks[scope] ?? defaultLock,
  );
}

/// Records every row timeout diagnostic.
final class RecordingTalmidRowDiagnostics implements TalmidRowDiagnostics {
  /// The stages reported, in order.
  final List<TalmidLoadStage> timeouts = [];

  @override
  void engineLoadTimedOut(TalmidLoadStage stage) => timeouts.add(stage);
}

/// The fixture position of the Rebbe track ("Beitzah 3:1" once rendered).
const talmidRebbePosition = 'Mishnah Beitzah 3:1';

/// A live "Rebbe" sub-track state; groundless without [position].
SubTrackState rebbeTrack({String? position = talmidRebbePosition}) =>
    SubTrackState(
      subTrackId: rebbeSubTrackId,
      name: 'Rebbe',
      holdsGround: true,
      inForecast: true,
      onHome: true,
      position: position,
    );

/// A talmid's engine state: [status] (with a deadline unless
/// [ProjectionStatus.noDeadline]) and an optional live [sub]-track.
LearnerState talmidState({
  ProjectionStatus status = ProjectionStatus.onTrack,
  SubTrackState? sub,
}) => forecastState([
  forecastCurriculumState(
    projection: Projection(status: status),
    dailyTarget: status == ProjectionStatus.noDeadline ? null : 3,
    subTracks: {if (sub != null) sub.subTrackId: sub},
  ),
]);

/// Records every open request; answers [result].
final class RecordingTalmidOpener implements TalmidContextOpener {
  /// `(grantId, groundSubTrackId)` of every open, in order.
  final List<(String, String?)> calls = [];

  /// What [open] answers.
  bool result = true;

  @override
  Future<bool> open(
    BuildContext context,
    TalmidRosterEntry entry, {
    String? groundSubTrackId,
  }) async {
    calls.add((entry.grantId, groundSubTrackId));
    return result;
  }
}

/// Renders a leaf ref the way the content index would ("Moed › Beitzah
/// 3:1" → the row shows "Beitzah 3:1").
String talmidRenderedRef(String ref) =>
    'Moed › ${ref.replaceFirst('Mishnah ', '')}';

/// The overrides of a My talmidim screen over [repo] and [inputs].
List<Override> talmidimOverrides({
  required TutorRosterRepository repo,
  required FakeTalmidInputs inputs,
  TalmidContextOpener? opener,
  bool online = true,
  TalmidRowDiagnostics? diagnostics,
  bool realLock = false,
}) => [
  tutorRosterRepositoryProvider.overrideWithValue(repo),
  talmidRosterAccountKeyProvider.overrideWithValue('tutor-uid'),
  inputs.stateOverride,
  if (!realLock) inputs.lockOverride,
  connectivityStreamProvider.overrideWith((ref) => Stream.value(online)),
  renderedDisplayForRefProvider.overrideWith(
    (ref, sefariaRef) async => talmidRenderedRef(sefariaRef),
  ),
  talmidContextOpenerProvider.overrideWithValue(
    opener ?? RecordingTalmidOpener(),
  ),
  talmidRowDiagnosticsProvider.overrideWithValue(
    diagnostics ?? RecordingTalmidRowDiagnostics(),
  ),
];

/// Pumps [MyTalmidimScreen] at [size] (logical pixels) and settles its
/// first frames.
Future<void> pumpTalmidim(
  WidgetTester tester, {
  required TutorRosterRepository repo,
  required FakeTalmidInputs inputs,
  TalmidContextOpener? opener,
  bool online = true,
  Size size = const Size(400, 800),
  ThemeData? theme,
  Locale locale = const Locale('en'),
  List<Override> extra = const [],
  bool realLock = false,
  Widget Function(Widget screen)? wrap,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      child: wrap == null
          ? const MyTalmidimScreen()
          : wrap(const MyTalmidimScreen()),
      theme: theme,
      locale: locale,
      overrides: [
        ...talmidimOverrides(
          repo: repo,
          inputs: inputs,
          opener: opener,
          online: online,
          realLock: realLock,
        ),
        ...extra,
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
}
