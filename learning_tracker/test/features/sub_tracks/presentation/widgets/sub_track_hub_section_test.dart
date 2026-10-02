/// Widget-level checks of [SubTrackHubSection], [SubTrackHubRow] and
/// [SubTrackSyncRejectionListener]; the hub ACs live in
/// `../manage_tracks_hub_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_hub_section.dart';

import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/sub_track_harness.dart';

void main() {
  testWidgets('a row shows the name, window months and weekly rate', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpApp(
        child: Scaffold(
          body: SubTrackHubRow(
            track: storedSchoolYear(
              '01JHARN0000000000000000001',
              name: 'Cheder',
              windowStart: '2026-10-01',
              windowEnd: '2027-06-30',
              rate: 2.5,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Cheder'), findsOneWidget);
    expect(find.text('School year · Oct–Jun · 2.5/week'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('the section renders nothing for a non-parent session', (
    tester,
  ) async {
    final h = SubTrackHarness();
    addTearDown(h.dispose);
    await tester.pumpWidget(
      pumpApp(
        overrides: h.overrides(parentSession: false),
        retry: (_, _) => null,
        child: const Scaffold(
          body: SubTrackHubSection(curriculumId: subTrackTestCurriculum),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('the section stays inert until the commands are live', (
    tester,
  ) async {
    final h = SubTrackHarness();
    addTearDown(h.dispose);
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          ...h.overrides(commands: false),
          learningCommandsProvider.overrideWith((ref) async => null),
        ],
        retry: (_, _) => null,
        child: const Scaffold(
          body: SubTrackHubSection(curriculumId: subTrackTestCurriculum),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.textContaining('Sub-tracks'), findsNothing);
  });

  testWidgets('the listener reports each refused batch once', (tester) async {
    final commands = FakeLearningCommands();
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          learningCommandsProvider.overrideWith((ref) async => commands),
        ],
        retry: (_, _) => null,
        child: const Scaffold(body: SubTrackSyncRejectionListener()),
      ),
    );
    await tester.pumpAndSettle();
    const failure = PendingFailure(
      id: 'entry-1',
      eventIds: [],
      changeIds: ['entry-1'],
      reason: PendingFailureReason.permissionDenied,
    );
    commands.pendingFailures.add(const [failure]);
    await tester.pump();
    await tester.pump();
    expect(find.text("Your change couldn't be saved."), findsOneWidget);

    // Let the first snackbar finish entering, time out and leave.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text("Your change couldn't be saved."), findsNothing);
    commands.pendingFailures.add(const [failure]);
    await tester.pump();
    await tester.pump();
    expect(find.text("Your change couldn't be saved."), findsNothing);
  });
}
