/// DNI-476 (Story 1.14): the owner governed-write port — the lazy
/// `LearningCommands` writer and [applyOwnerAction]'s success-or-throw.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';

import '../../../../helpers/learner_state/fake_learning_commands.dart';

final _action = GovernedAction([
  const GovernedEntityChange(
    entity: GovernedEntity.mainTrack,
    entityId: 'mishnayos',
    docs: [
      GovernedDocPatch(
        collection: 'curriculum_tracks',
        docId: 'mishnayos',
        fields: {'state': 'active', 'curriculum_id': 'mishnayos'},
      ),
    ],
  ),
]);

void main() {
  group('LearningCommandsOwnerWriter', () {
    test('resolves the commands on every write and delegates', () async {
      final commands = FakeLearningCommands();
      var resolved = 0;
      final writer = LearningCommandsOwnerWriter(() async {
        resolved++;
        return commands;
      });

      await writer.applyGovernedChange(_action);
      await writer.applyGovernedChange(_action);

      expect(resolved, 2);
      expect(commands.calls.map((c) => c.name), [
        'applyGovernedChange',
        'applyGovernedChange',
      ]);
    });

    test('with no commands it throws and writes nothing', () async {
      final writer = LearningCommandsOwnerWriter(() async => null);
      await expectLater(
        writer.applyGovernedChange(_action),
        throwsA(isA<GovernedWriterNotReadyException>()),
      );
    });
  });

  group('applyOwnerAction', () {
    test('returns the success (a queued success included)', () async {
      final commands = FakeLearningCommands()
        ..nextResult = const CaptureResult.success(queued: true);
      final result = await applyOwnerAction(
        LearningCommandsOwnerWriter(() async => commands),
        _action,
      );
      expect(result.queued, isTrue);
    });

    for (final failure in const <CaptureResult>[
      CaptureResult.onlineRequired(),
      CaptureResult.rejected(CaptureRejection.invalid),
      CaptureResult.rejected(CaptureRejection.notSaved),
    ]) {
      test('throws GovernedWriteRejectedException for $failure', () async {
        final commands = FakeLearningCommands()..nextResult = failure;
        await expectLater(
          applyOwnerAction(
            LearningCommandsOwnerWriter(() async => commands),
            _action,
          ),
          throwsA(
            isA<GovernedWriteRejectedException>().having(
              (e) => e.result,
              'result',
              failure,
            ),
          ),
        );
      });
    }
  });
}
