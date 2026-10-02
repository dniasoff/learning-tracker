// DNI-496 (Story 2.5) AC-4: the hub copy of a future-start sub-track,
// "Starts {date}" in the active locale (UX-DR-89).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_start_status.dart';

import '../../../../helpers/pump_app.dart';

SubTrack _track({required String start, bool ended = false}) => SubTrack(
  id: '01J00000000000000000000001',
  curriculumId: 'mishnayos',
  name: 'Shiur',
  type: SubTrackType.ongoing,
  windowStart: start,
  ratePerWeek: 5,
  weeksPerYear: 52,
  learnsOnShabbos: false,
  ground: const [],
  lastChangeId: '01J00000000000000000000002',
  endedAt: ended ? DateTime.utc(2026) : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

Future<String?> _label(
  WidgetTester tester,
  SubTrack track, {
  Locale locale = const Locale('en'),
}) async {
  String? label;
  await tester.pumpWidget(
    pumpApp(
      locale: locale,
      child: Builder(
        builder: (context) {
          label = subTrackStartsLabel(context, track, '2026-09-07');
          return const SizedBox();
        },
      ),
    ),
  );
  return label;
}

void main() {
  test('starts later only when live and window_start is after today', () {
    expect(
      subTrackStartsLater(_track(start: '2026-09-08'), '2026-09-07'),
      isTrue,
    );
    expect(
      subTrackStartsLater(_track(start: '2026-09-07'), '2026-09-07'),
      isFalse,
    );
    expect(
      subTrackStartsLater(_track(start: '2026-09-01'), '2026-09-07'),
      isFalse,
    );
    expect(
      subTrackStartsLater(
        _track(start: '2026-09-08', ended: true),
        '2026-09-07',
      ),
      isFalse,
    );
  });

  testWidgets('a future start reads "Starts {date}"', (tester) async {
    expect(
      await _label(tester, _track(start: '2026-12-01')),
      'Starts Dec 1, 2026',
    );
  });

  testWidgets('a started sub-track has no starts label', (tester) async {
    expect(await _label(tester, _track(start: '2026-09-07')), isNull);
  });

  testWidgets('Hebrew formats the date for the Hebrew locale', (tester) async {
    final label = await _label(
      tester,
      _track(start: '2026-12-01'),
      locale: const Locale('he'),
    );
    expect(label, startsWith('מתחיל ב-'));
    expect(label, contains('2026'));
  });
}
