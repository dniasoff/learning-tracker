/// DNI-475 T1: [ProfileHistoryLog] keeps every event id and names sources
/// from the stored sub-track rows only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/features/learning/domain/models/profile_history_log.dart';

import '../../../../helpers/learner_state/mishna_history_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

void main() {
  test('indexes live and ended sub-tracks by id; an unknown id has no '
      'name (never the ULID)', () {
    final log = ProfileHistoryLog(
      events: [historyLearn(1), historyVoid(2, eid(1))],
      subTracks: [endedSubTrack()],
    );
    expect(log.events.map((e) => e.id), [eid(1), eid(2)]);
    expect(log.subTrackName(ulidB), 'Cheder shiur');
    expect(log.subTrackName(ulidE), isNull);
  });

  test('UnreadableHistoryException keeps every rejected id and error for '
      'diagnostics', () {
    final error = UnreadableHistoryException(
      eventRows: const [RejectedRow(ulidD, 'bad kind')],
      subTrackRows: const [RejectedRow(ulidB, 'bad name')],
    );
    expect(error.eventRows.single.docId, ulidD);
    expect(error.subTrackRows.single.docId, ulidB);
    expect(error.toString(), allOf(contains(ulidD), contains('bad kind')));
    expect(error.toString(), allOf(contains(ulidB), contains('bad name')));
  });
}
