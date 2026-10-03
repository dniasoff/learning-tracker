// Story 4.2 (DNI-510) AC-1 — a tutor with can_edit_learning, online,
// captures on the talmid's sub-tracks: the Learn row's +1 (and Up to…) is
// enabled and records through TutorWriteService.recordLearning
// (`tutorRecordLearning` with the sub-track ULID as source); the Browse
// free-tick and Mishna-history Correct source choices list only this
// learner's onHome sub-tracks of the curriculum; the "coming soon" note is
// gone. The correction itself (void + record on the sub-track) is pinned in
// tutor_learning_commands_sub_tracks_test.dart.

@Tags(['tutor_mode'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/learner_state_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/sub_tracks/dashboard_harness.dart';
import '../../../helpers/sub_tracks/sub_track_home_fixtures.dart';
import '../../../helpers/sub_tracks/sub_track_test_engine.dart';
import '../../../helpers/tutoring/tutor_learning_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1));
}

/// The Learn rows of the talmid in tutor mode, over the real tutor
/// commands of [h].
List<Override> _tutorRows(SubTrackTestEngine engine, TutorHarness h) => [
  ...subTrackEngineOverrides(
    engine: engine,
    commands: h.commands,
    role: SubTrackViewerRole.tutor,
  ),
  ...tutoredOverrides(selection: h.selection, withScope: false),
];

OnHomeSubTrack _onHome(String id, String name, String curriculumId) =>
    OnHomeSubTrack(
      track: SubTrack(
        id: id,
        curriculumId: curriculumId,
        name: name,
        type: SubTrackType.ongoing,
        windowStart: '2026-09-01',
        ratePerWeek: 5,
        weeksPerYear: 40,
        learnsOnShabbos: false,
        ground: const [],
        lastChangeId: ulidE,
      ),
      state: SubTrackState(
        subTrackId: id,
        holdsGround: true,
        inForecast: true,
        onHome: true,
      ),
    );

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(DashboardFakeRoute());
  });

  testWidgets('+1 on the talmid\'s sub-track row is enabled and records '
      'through tutorRecordLearning with the sub-track as source; no note, no '
      '"coming soon"', (tester) async {
    final engine = SubTrackTestEngine();
    addTearDown(engine.dispose);
    final h = TutorHarness();
    addTearDown(h.dispose);
    await tester.pumpWidget(
      pumpApp(
        overrides: _tutorRows(engine, h),
        child: const Scaffold(
          body: SingleChildScrollView(child: AlsoLearningSection()),
        ),
      ),
    );
    await _settle(tester);

    expect(find.textContaining('coming soon'), findsNothing);
    expect(find.byKey(const Key('tutorWriteNote')), findsNothing);
    final plusOne = find.byKey(const Key('subTrackHomePlusOne-$schoolId'));
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.descendant(
              of: plusOne,
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            ),
          )
          .onPressed,
      isNotNull,
      reason: 'enabled for a permitted, online tutor',
    );

    await tester.tap(plusOne);
    await _settle(tester);

    final call = h.invoker.calls.single;
    expect(call.fn, 'tutorRecordLearning');
    expect(call.args['grantId'], tutorFixtureGrantId);
    final fields = Map<String, Object?>.from(
      ((call.args['events'] as List).single as Map)['fields'] as Map,
    );
    expect(fields['source'], schoolId);
    expect(fields['ref'], berachos14);
    expect(fields['date_state'], 'dated');
    expect(find.text('Recorded 1'), findsOneWidget);
    expect(
      find.text('Undo'),
      findsNothing,
      reason:
          'Story 4.1 voids are '
          'main-only: a tutor sub-track capture offers no Undo',
    );
  });

  test('the free-tick and Correct source choices list only this learner\'s '
      'onHome sub-tracks of the curriculum for a permitted tutor', () async {
    final container = ProviderContainer(
      overrides: [
        ...tutoredOverrides(selection: tutorSelection()),
        onHomeSubTracksProvider.overrideWithValue(
          AsyncData([
            _onHome(schoolId, 'School', mishnayos),
            _onHome(rebbeId, 'Rebbe', mishnayos),
            _onHome(futureId, 'Daf shiur', 'shas_bavli'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      subTrackSourceChoicesProvider(mishnayos),
      (_, _) {},
    );
    addTearDown(sub.close);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(sub.read(), [
      (id: schoolId, name: 'School'),
      (id: rebbeId, name: 'Rebbe'),
    ]);
  });

  test('a tutor who may not write gets no sub-track source', () async {
    final container = ProviderContainer(
      overrides: [
        ...tutoredOverrides(selection: tutorSelection(canEditLearning: false)),
        onHomeSubTracksProvider.overrideWithValue(
          AsyncData([_onHome(schoolId, 'School', mishnayos)]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      subTrackSourceChoicesProvider(mishnayos),
      (_, _) {},
    );
    addTearDown(sub.close);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(sub.read(), isEmpty);
  });
}
