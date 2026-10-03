/// DNI-481 AC-3: a Sacred Time settings edit is ONE logged `learnerSettings`
/// change written through `LearningCommands.applyGovernedChange` (DNI-470):
/// only the changed fields, their before values, the actor, and the
/// profile's `last_change_id`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/sacred_time/domain/learner_settings_change.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state/governed_harness.dart';
import '../../helpers/learner_state_fixtures.dart';

String _key(String field) => 'learner_profiles/$profileUlid.$field';

void main() {
  test('a city choice logs one learnerSettings entry with the changed '
      'fields, their before values and the parent actor', () async {
    final h = GovernedHarness()
      ..seedDoc('learner_profiles', profileUlid, {
        'display_name': 'Avi',
        'time_zone': 'America/New_York',
        'in_israel': false,
        'last_change_id': ulidA,
      });

    final result = await h.commands.applyGovernedChange(
      learnerSettingsAction(
        profileUlid,
        const LearnerSettingsEdit(
          latitude: 31.778,
          longitude: 35.235,
          timeZone: 'Asia/Jerusalem',
          inIsrael: true,
        ),
      ),
    );

    expect(result, isA<CaptureSuccess>());
    final entry = h.batches.single.entry;
    expect(entry.entity, GovernedEntity.learnerSettings);
    expect(entry.entityId, profileUlid);
    expect(entry.actor, parentActor);
    expect(entry.at, governedNow);
    expect(entry.before, {
      _key('latitude'): null,
      _key('longitude'): null,
      _key('time_zone'): 'America/New_York',
      _key('in_israel'): false,
    });
    expect(entry.after, {
      _key('latitude'): 31.778,
      _key('longitude'): 35.235,
      _key('time_zone'): 'Asia/Jerusalem',
      _key('in_israel'): true,
    });
    // Only settings fields change: the display name is untouched.
    expect(h.doc('learner_profiles', profileUlid), {
      'display_name': 'Avi',
      'latitude': 31.778,
      'longitude': 35.235,
      'time_zone': 'Asia/Jerusalem',
      'in_israel': true,
      'last_change_id': engineUlid(100),
    });
  });

  test('an unchanged value writes nothing', () async {
    final h = GovernedHarness()
      ..seedDoc('learner_profiles', profileUlid, {
        'time_zone': 'UTC',
        'in_israel': true,
      });
    await h.commands.applyGovernedChange(
      learnerSettingsAction(
        profileUlid,
        const LearnerSettingsEdit(inIsrael: true),
      ),
    );
    expect(h.batches, isEmpty);
  });

  test('a missing profile doc is not created by a settings edit', () async {
    final h = GovernedHarness();
    final result = await h.commands.applyGovernedChange(
      learnerSettingsAction(
        profileUlid,
        const LearnerSettingsEdit(inIsrael: true),
      ),
    );
    expect(
      result,
      const CaptureResult.rejected(CaptureRejection.targetNotFound),
    );
    expect(h.batches, isEmpty);
  });
}
