// Story 2.11 (DNI-502) AC-5: one full-width amber shortfall card per
// sub-track with a positive engine shortfall, directly under the on-track
// card, with the exact FR-21 copy; *View {name} →* opens that sub-track's
// detail; the card is gone on the recompute after the shortfall reaches 0;
// overlapping ground shows the engine's de-duplicated amounts.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_forecast_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/parent_on_track_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/shortfall_warning_card.dart';

import '../../../../helpers/dashboard/forecast_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/pump_app.dart';

final _mishnayos = CurriculumLabels.leaf(
  CurriculumId.mishnayos,
).inLanguage(useHebrew: false, plural: true);

const _berachos3 = NodeEntry(level: 'chapter', ref: 'Mishnah Berakhot 3');
const _beitzah = NodeEntry(level: 'masechta', ref: 'Mishnah Beitzah');

const _projection = Projection(
  status: ProjectionStatus.behindPace,
  projectedFinish: '2029-03-14',
  deadline: '2029-09-10',
);

LearnerState _state(Map<String, SubTrackState> subTracks) => forecastState([
  forecastCurriculumState(
    projection: _projection,
    dailyTarget: 3,
    subTracks: subTracks,
  ),
]);

SubTrackState _school(int shortfall) => shortfallSubTrack(
  id: schoolSubTrackId,
  name: 'School',
  shortfall: shortfall,
  lastNode: _berachos3,
  windowEnd: '2027-07-31',
);

SubTrackState _rebbe(int shortfall) => shortfallSubTrack(
  id: rebbeSubTrackId,
  name: 'Rebbe',
  shortfall: shortfall,
  lastNode: _beitzah,
);

Future<void> _pump(
  WidgetTester tester, {
  LearnerState? state,
  Stream<LearnerState>? states,
  List<Override> extra = const [],
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    pumpApp(
      theme: AppTheme.lightTheme(),
      overrides: [
        ...forecastOverrides(
          state: state,
          states: states,
          nodeLabels: const {
            'Mishnah Berakhot 3': 'Berachos perek 3',
            'Mishnah Beitzah': 'Beitzah',
          },
        ),
        ...extra,
      ],
      child: Scaffold(
        body: SingleChildScrollView(
          child: ParentForecastSection(
            belowCard: (f) => ShortfallWarningList(forecast: f),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _message(WidgetTester tester, String subTrackId) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(Key('shortfallCard-$subTrackId')),
        matching: find.byKey(const Key('shortfallCardMessage')),
      ),
    )
    .data!;

void main() {
  testWidgets('one card per positive shortfall, in order, directly under '
      'the on-track card, with the exact copy', (tester) async {
    await _pump(
      tester,
      state: _state({
        schoolSubTrackId: _school(40),
        rebbeSubTrackId: _rebbe(12),
        // A zero shortfall leaves no empty shell.
        '01J6Q2H4A8M7K3P9R5T6V8WXZ3': shortfallSubTrack(
          id: '01J6Q2H4A8M7K3P9R5T6V8WXZ3',
          name: 'Chavrusa',
          shortfall: 0,
        ),
      }),
    );
    expect(find.byType(ShortfallWarningCard), findsNWidgets(2));
    expect(
      _message(tester, schoolSubTrackId),
      'School may not reach Berachos perek 3 before July 2027. '
      'About 40 $_mishnayos will return to home learning.',
    );
    // An open ongoing window names the deadline month.
    expect(
      _message(tester, rebbeSubTrackId),
      'Rebbe may not reach Beitzah before September 2029. '
      'About 12 $_mishnayos will return to home learning.',
    );
    expect(find.textContaining('Chavrusa'), findsNothing);

    // Order: on-track card, then Rebbe, then School (by name), stacked.
    final card = tester.getRect(find.byKey(const Key('onTrackCard-mishnayos')));
    final rebbe = tester.getRect(
      find.byKey(const Key('shortfallCard-$rebbeSubTrackId')),
    );
    final school = tester.getRect(
      find.byKey(const Key('shortfallCard-$schoolSubTrackId')),
    );
    expect(rebbe.top, greaterThan(card.bottom));
    expect(rebbe.top - card.bottom, lessThanOrEqualTo(10));
    expect(school.top, greaterThan(rebbe.bottom));
    // Full width.
    expect(rebbe.width, card.width);
    expect(school.width, card.width);
  });

  testWidgets('View {name} opens that sub-track\'s detail', (tester) async {
    final opened = <String>[];
    await _pump(
      tester,
      state: _state({
        schoolSubTrackId: _school(40),
        rebbeSubTrackId: _rebbe(12),
      }),
      extra: [
        subTrackDetailOpenerProvider.overrideWithValue(
          (context, warning) => opened.add(warning.subTrackId),
        ),
      ],
    );
    await tester.tap(find.text('View School'));
    await tester.tap(find.text('View Rebbe'));
    expect(opened, [schoolSubTrackId, rebbeSubTrackId]);
  });

  testWidgets('without the detail route the action is disabled, never '
      'routed elsewhere', (tester) async {
    await _pump(tester, state: _state({schoolSubTrackId: _school(40)}));
    final button = tester.widget<TextButton>(
      find.byKey(const Key('shortfallCardView')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('the card disappears on the recompute after the shortfall '
      'reaches 0', (tester) async {
    final feed = LearnerStateFeed(_state({schoolSubTrackId: _school(3)}));
    addTearDown(feed.close);
    await _pump(tester, states: feed.stream);
    expect(_message(tester, schoolSubTrackId), contains('About 3 '));

    feed.emit(_state({schoolSubTrackId: _school(1)}));
    await tester.pumpAndSettle();
    final mishna = CurriculumLabels.leaf(
      CurriculumId.mishnayos,
    ).inLanguage(useHebrew: false, plural: false);
    expect(_message(tester, schoolSubTrackId), contains('About 1 $mishna '));

    feed.emit(_state({schoolSubTrackId: _school(0)}));
    await tester.pumpAndSettle();
    expect(find.byType(ShortfallWarningCard), findsNothing);
    expect(find.byKey(const Key('onTrackCard-mishnayos')), findsOneWidget);
  });

  testWidgets('overlapping ground: each card shows the engine\'s '
      'de-duplicated shortfall (real engine)', (tester) async {
    SubTrack sub(String id, String name, List<NodeEntry> ground) => SubTrack(
      id: id,
      curriculumId: engineCurriculum,
      name: name,
      type: SubTrackType.ongoing,
      windowStart: '2026-09-01',
      ratePerWeek: 0.1,
      weeksPerYear: 52,
      learnsOnShabbos: false,
      ground: ground,
      lastChangeId: engineUlid(900),
    );
    // School holds all of Berakhot; Rebbe holds Berakhot 2 (shared) and
    // Peah. At 0.1 a week neither reaches anything by the deadline.
    final state = engineForecastState(
      nowUtc: DateTime.utc(2026, 9, 7, 12),
      trackingStartDate: '2026-09-01',
      deadline: '2026-09-20',
      subTracks: [
        sub(schoolSubTrackId, 'School', const [berakhot]),
        sub(rebbeSubTrackId, 'Rebbe', const [berakhot2, peah]),
      ],
    );
    final curriculum = state[engineCurriculum]!;
    final positive = [
      for (final s in curriculum.subTracks.values)
        if (s.shortfall > 0) s,
    ];
    // The shared Berakhot 2 leaves are counted once: 5 + 2, not 5 + 4.
    expect(curriculum.shortfall, 7);
    expect(positive.fold<int>(0, (sum, s) => sum + s.shortfall), 7);

    await _pump(tester, state: state);
    expect(find.byType(ShortfallWarningCard), findsNWidgets(positive.length));
    for (final s in positive) {
      expect(_message(tester, s.subTrackId), contains('About ${s.shortfall} '));
    }
  });
}
