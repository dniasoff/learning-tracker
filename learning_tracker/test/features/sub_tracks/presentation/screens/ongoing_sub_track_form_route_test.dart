// DNI-496 (Story 2.5): the ongoing form's navigation entry.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ongoing_sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/ongoing_sub_track_form_route.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/ongoing_sub_track_form_screen.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  testWidgets('openOngoingSubTrackForm pushes the form and pops null on back', (
    tester,
  ) async {
    OngoingSubTrackSaved? result = const OngoingSubTrackSaved(queued: true);
    var done = false;
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          ongoingSubTrackContextProvider('mishnayos').overrideWith(
            (ref) async => OngoingSubTrackContext(
              curriculumId: 'mishnayos',
              today: '2026-09-07',
              timeZone: 'UTC',
              subTracks: const [],
              calendarProgram: false,
            ),
          ),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await openOngoingSubTrackForm(
                context,
                curriculumId: 'mishnayos',
              );
              done = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(OngoingSubTrackFormScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(result, isNull);
  });
}
