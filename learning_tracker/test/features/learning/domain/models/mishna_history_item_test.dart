/// DNI-475 T2: [MishnaHistory] projection details not covered by the
/// provider tests — overlays and the unknown-source label.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/domain/models/mishna_history_item.dart';
import 'package:learning_tracker/features/learning/domain/models/profile_history_log.dart';

import '../../../../helpers/learner_state/mishna_history_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

void main() {
  MishnaHistory project() => MishnaHistory.project(
    curriculumId: historyCurriculum,
    leafRef: historyLeaf,
    log: ProfileHistoryLog(
      events: [
        historyLearn(1, source: ulidD),
        historyLearn(2, day: 3),
      ],
      subTracks: const [],
    ),
    state: historyState(counted: {eid(1), eid(2)}),
  );

  test('a source missing from the log is an unknown sub-track', () {
    final item = project().items.last;
    expect(item.eventId, eid(1));
    expect(item.sourceKind, MishnaHistorySourceKind.unknownSubTrack);
  });

  test('without a corpus, only the leaf itself counts and no place choice '
      'is offered', () {
    expect(project().placeChoices, isEmpty);
  });

  test('withOverlays replaces rows by id and keeps the engine numbers', () {
    final history = project();
    final overlay = history.items.first.copyWith(
      status: MishnaHistoryStatus.voided,
      pending: true,
    );
    final shown = history.withOverlays({overlay.eventId: overlay});
    expect(shown.items.first, same(overlay));
    expect(shown.eventCount, history.eventCount);
    expect(shown.learnt, history.learnt);
  });
}
