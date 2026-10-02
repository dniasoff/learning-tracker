// Mirror test for
// `lib/features/learning/domain/commands/governed_action_commands.dart`
// (DNI-470). The AC tables live in learning_commands_governed_change_test
// and learning_commands_undo_test; this covers the collaborator's own
// helpers.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/governed_action_commands.dart';

import '../../../../helpers/learner_state/governed_harness.dart';
import '../../../../helpers/learner_state_fixtures.dart';

ChangeLogEntry _settings(Map<String, Object?> before) => ChangeLogEntry(
  id: ulidA,
  entity: GovernedEntity.learnerSettings,
  entityId: profileUlid,
  actionId: ulidA,
  before: {
    for (final e in before.entries)
      'learner_profiles/$profileUlid.${e.key}': e.value,
  },
  after: {
    for (final k in before.keys) 'learner_profiles/$profileUlid.$k': 'UTC',
  },
  at: t0,
  actor: parentActor,
);

void main() {
  test('isSettingsSeed: only an all-null-before learnerSettings entry', () {
    expect(
      DefaultGovernedLearningCommands.isSettingsSeed(
        _settings({'time_zone': null}),
      ),
      isTrue,
    );
    expect(
      DefaultGovernedLearningCommands.isSettingsSeed(
        _settings({'time_zone': 'Asia/Jerusalem'}),
      ),
      isFalse,
    );
  });

  test('the unknown changed-since actor is an owner role with no uid', () {
    expect(unknownChangeActor.uid, isEmpty);
    expect(unknownChangeActor.displayName, isEmpty);
  });

  test('instants, lists and maps are storage values; other objects are '
      'not', () async {
    final h = GovernedHarness();
    GovernedAction action(Object? value) =>
        oneEntity(GovernedEntity.goal, 'g', [
          patch(GovernedEntity.goal, 'g', {'v': value}),
        ]);
    for (final ok in [
      DateTime.utc(2026),
      [1, 'a', null],
      {'k': true},
    ]) {
      expect(
        await h.commands.applyGovernedChange(action(ok)),
        isA<CaptureSuccess>(),
        reason: '$ok',
      );
    }
    for (final bad in [
      Object(),
      [Object()],
      {'k': Object()},
    ]) {
      expect(
        await h.commands.applyGovernedChange(action(bad)),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
    }
  });
}
