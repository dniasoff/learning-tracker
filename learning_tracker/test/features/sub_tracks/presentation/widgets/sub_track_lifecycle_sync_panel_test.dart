// Mirror test for `lib/features/sub_tracks/presentation/widgets/
// sub_track_lifecycle_sync_panel.dart` (Story 2.8 / DNI-499, AD-54): a
// queued End, Delete or Add next year shows as waiting to sync, its
// confirmation shows once the server accepts it, and a refused one offers
// Retry and Close.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_sources.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_lifecycle_sync_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_lifecycle_sync_panel.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/pump_app.dart';

const _changeId = '01JWXDGT000000000000000777';

void main() {
  late FakeLearningCommands commands;

  setUp(() => commands = FakeLearningCommands());
  tearDown(() => commands.dispose());

  Future<ProviderContainer> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          learningCommandsProvider.overrideWith((ref) async => commands),
        ],
        child: const Scaffold(body: SubTrackLifecycleSyncPanel()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(SubTrackLifecycleSyncPanel)),
    );
  }

  Future<void> track(WidgetTester tester, ProviderContainer c) async {
    final origin = await tester.runAsync(
      () => resolveSubTrackLifecycleOrigin(c.read),
    );
    c
        .read(subTrackLifecycleSyncProvider.notifier)
        .track(
          const SubTrackLifecycleSync(
            changeId: _changeId,
            write: SubTrackLifecycleWrite.addNextYear,
            name: 'School',
            yearLabel: '2027–28',
          ),
          origin!,
        );
    await tester.pumpAndSettle();
  }

  testWidgets('nothing while no write is pending', (tester) async {
    await pump(tester);
    expect(
      find.byKey(const ValueKey('subTrackLifecycleSyncPanel')),
      findsNothing,
    );
  });

  testWidgets('waiting, then the saved confirmation once on the ack', (
    tester,
  ) async {
    final verdict = Completer<bool>();
    commands.subTrackConfirmations[_changeId] = verdict;
    final c = await pump(tester);
    await track(tester, c);
    expect(
      find.text('Adding School for 2027–28: waiting to sync'),
      findsOneWidget,
    );

    verdict.complete(true);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('subTrackLifecycleSyncPanel')),
      findsNothing,
    );
    expect(find.text('School added for 2027–28'), findsOneWidget);
  });

  testWidgets('refused: not saved, with Retry and Close', (tester) async {
    final verdict = Completer<bool>();
    commands.subTrackConfirmations[_changeId] = verdict;
    final c = await pump(tester);
    await track(tester, c);
    verdict.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Adding School for 2027–28: not saved'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('subTrackSyncRetry:$_changeId')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('subTrackSyncClose:$_changeId')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('subTrackLifecycleSyncPanel')),
      findsNothing,
    );
    expect(find.text('School added for 2027–28'), findsNothing);
  });
}
