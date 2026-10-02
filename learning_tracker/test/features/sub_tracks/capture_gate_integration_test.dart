// Story 2.10 (DNI-501) AC-3 / AC-5 / AC-7 integration: the capture lock
// gate and the offline queue for Up to… and +1, through the real
// LearningCommands.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_capture_section.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/pump_app.dart';
import 'helpers/capture_harness.dart';
import 'helpers/up_to_fixtures.dart';

/// Tuesday 2026-09-01 20:00Z: unlocked.
final _evening = engineAt(1200);

/// Saturday 2026-09-05 10:00Z: inside the fixture Shabbos lock.
final _shabbos = DateTime.utc(2026, 9, 5, 10);

Future<CaptureRig> _pump(WidgetTester tester, DateTime now) async {
  final rig = CaptureRig(
    now: now,
    subTracks: [fixtureSubTrack(schoolId, 'School')],
  );
  addTearDown(rig.dispose);
  useSurface(tester, phoneSize);
  await tester.pumpWidget(
    pumpApp(
      overrides: rig.overrides(),
      child: const Scaffold(
        body: SingleChildScrollView(child: SubTrackCaptureSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return rig;
}

String _status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(Key('subTrackRowStatus-$schoolId'))).data!;

Future<void> _recordThrough(WidgetTester tester, String target) async {
  await tester.tap(find.byKey(Key('subTrackUpTo-$schoolId')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(target));
  await tester.pump();
  await tester.tap(find.byKey(const Key('upToRecord')));
}

void main() {
  testWidgets('a locked capture is refused: nothing written, the row does '
      'not move, no Undo', (tester) async {
    final rig = await _pump(tester, _shabbos);
    await _recordThrough(tester, 'Berakhot 1:2');
    await tester.pumpAndSettle();
    expect(rig.port.attempts, isEmpty);
    expect(_status(tester), 'Next: Berakhot 1:1');
    expect(
      find.text('Not recorded — the app is closed for Shabbos and Yom Tov.'),
      findsOneWidget,
    );
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('+1 on a locked day is refused the same way', (tester) async {
    final rig = await _pump(tester, _shabbos);
    await tester.tap(find.byKey(Key('subTrackPlusOne-$schoolId')));
    await tester.pumpAndSettle();
    expect(rig.port.attempts, isEmpty);
    expect(_status(tester), 'Next: Berakhot 1:1');
  });

  testWidgets('offline: the batch queues optimistically as one chunk; a '
      'later server rejection rolls the row back with the Learn not-saved '
      'snackbar and Retry (UX-DR-110)', (tester) async {
    final rig = await _pump(tester, _evening);
    rig.port.holdNext();
    await _recordThrough(tester, 'Berakhot 1:3');
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(rig.port.heldCount, 1);
    expect(rig.port.attempts.single.events.length, 3, reason: 'atomic chunk');
    expect(_status(tester), 'Next: Berakhot 2:1');
    expect(find.text('Recorded 3'), findsOneWidget);

    rig.port.reject(const PermanentWriteRejection('permission-denied'));
    await tester.pumpAndSettle();
    expect(rig.port.chunks, isEmpty, reason: 'no phantom success');
    expect(_status(tester), 'Next: Berakhot 1:1');
    expect(
      find.text('Not saved — your learning was not recorded.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    // Retry re-sends the same chunk; the row moves on again once saved.
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(rig.port.chunks.single.events.length, 3);
    expect(
      {for (final e in rig.port.chunks.single.events) e.id},
      {for (final e in rig.port.attempts.first.events) e.id},
      reason: 'client ULIDs reused on retry (AD-31)',
    );
    expect(_status(tester), 'Next: Berakhot 2:1');
  });

  testWidgets('an immediate permanent rejection never shows success', (
    tester,
  ) async {
    final rig = await _pump(tester, _evening);
    rig.port.failNextWith(const PermanentWriteRejection('permission-denied'));
    await _recordThrough(tester, 'Berakhot 1:2');
    await tester.pumpAndSettle();
    expect(rig.port.chunks, isEmpty);
    expect(find.text('Recorded 2'), findsNothing);
    expect(_status(tester), 'Next: Berakhot 1:1');
  });
}
