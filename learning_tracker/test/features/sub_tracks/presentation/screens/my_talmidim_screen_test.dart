// Story 4.3 (DNI-511) T3/T4: My talmidim screen states not covered by the
// story's acceptance file (test/features/sub_tracks/presentation/
// my_talmidim_screen_test.dart): the first-load spinner, an inline row
// retry that recovers one row only, and an unaddressable learner's row.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_row_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/my_talmidim_screen.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

import '../../talmidim_fixtures.dart';

final class _NeverRoster implements TutorRosterRepository {
  @override
  Future<List<TalmidRosterEntry>> loadActiveTalmidim() =>
      Completer<List<TalmidRosterEntry>>().future;
}

void main() {
  late FakeTalmidInputs inputs;

  setUp(() => inputs = FakeTalmidInputs());

  testWidgets('the first load shows a spinner, not the empty copy', (
    tester,
  ) async {
    await pumpTalmidim(tester, repo: _NeverRoster(), inputs: inputs);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('talmidimEmpty')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a timed-out row retries alone and recovers', (tester) async {
    inputs.states[talmidScope(2)] = AsyncData(talmidState(sub: rebbeTrack()));
    await pumpTalmidim(
      tester,
      repo: ScriptedTutorRosterRepository([
        [talmidEntry(1, name: 'Slow Row'), talmidEntry(2, name: 'Fast Row')],
      ]),
      inputs: inputs,
      extra: [
        talmidRowLoadTimeoutProvider.overrideWithValue(
          const Duration(milliseconds: 50),
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byKey(const Key('talmidRowRetry-grant-1')), findsOneWidget);
    expect(find.byKey(const Key('talmidRowRetry-grant-2')), findsNothing);
    expect(find.text('On track'), findsOneWidget);

    inputs.states[talmidScope(1)] = AsyncData(talmidState(sub: rebbeTrack()));
    await tester.tap(find.byKey(const Key('talmidRowRetry-grant-1')));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const Key('talmidRowRetry-grant-1')), findsNothing);
    expect(find.text('On track'), findsNWidgets(2));
  });

  testWidgets('a grant naming no addressable learner shows a failed row', (
    tester,
  ) async {
    await pumpTalmidim(
      tester,
      repo: ScriptedTutorRosterRepository([
        [
          const TalmidRosterEntry(
            grantId: 'legacy',
            ownerUid: 'owner',
            profileId: 'not-a-ulid',
            displayName: 'Legacy Talmid',
            permissions: TutorPermissions(),
          ),
        ],
      ]),
      inputs: inputs,
    );
    expect(find.text('Legacy Talmid'), findsOneWidget);
    expect(find.text("Couldn't load this talmid's standing."), findsOneWidget);
    expect(find.byKey(const Key('talmidRowRetry-legacy')), findsNothing);
    expect(find.byType(MyTalmidimScreen), findsOneWidget);
  });
}
