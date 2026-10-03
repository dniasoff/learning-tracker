/// DNI-481 AC-3: a logged learner-settings edit moves only the lock
/// windows after it. Windows before the edit's `original_at ?? at` keep the
/// settings in force then; windows after it use the new settings.
///
/// Wires the real governed command path (`applyGovernedChange` over the
/// in-memory ports) to the real `LearnerSettingsHistory.reconstruct` and
/// `lockWindows`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/sacred_time/domain/learner_settings_change.dart';

import '../helpers/learner_state/governed_harness.dart';
import '../helpers/learner_state_fixtures.dart';

String _key(String field) => 'learner_profiles/$profileUlid.$field';

/// The creation seed entry (AD-37: an ordinary entry with `before`
/// all-null) of a New York learner with no location.
final _seed = ChangeLogEntry(
  id: ulidA,
  entity: GovernedEntity.learnerSettings,
  entityId: profileUlid,
  actionId: ulidA,
  before: {_key('time_zone'): null, _key('in_israel'): null},
  after: {_key('time_zone'): 'America/New_York', _key('in_israel'): false},
  at: DateTime.utc(2026, 8, 1),
  actor: parentActor,
);

LearnerSettingsHistory _history(GovernedHarness h) =>
    LearnerSettingsHistory.reconstruct(
      current: LearnerSettings.fromProfileDoc(
        profileUlid,
        h.doc('learner_profiles', profileUlid)!,
      ),
      entries: h.store.entriesOf(h.scope),
    );

void main() {
  test('a move to Jerusalem changes the windows after the edit only', () async {
    final h = GovernedHarness()
      ..seedDoc('learner_profiles', profileUlid, {
        'display_name': 'Avi',
        'time_zone': 'America/New_York',
        'in_israel': false,
        'last_change_id': ulidA,
      });
    h.store.seed(h.scope, [_seed]);

    final pastShabbos = DateTime.utc(2026, 9, 5, 12);
    final nextShabbos = DateTime.utc(2026, 9, 12, 12);
    final before = _history(h);
    final pastBefore = lockWindows(before, pastShabbos, pastShabbos);

    // The edit lands on Thursday 2026-09-10 (governedNow).
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

    final after = _history(h);
    // The past Shabbos is still the New York no-location fallback
    // (Fri 12:00 EDT → Sun 01:00 EDT), unchanged by the edit.
    expect(lockWindows(after, pastShabbos, pastShabbos), pastBefore);
    expect(
      pastBefore.single,
      LockWindow(DateTime.utc(2026, 9, 4, 16), DateTime.utc(2026, 9, 6, 5)),
    );

    // The next Shabbos uses the Jerusalem zmanim.
    final jerusalem = LearnerSettingsHistory.constant(
      const LearnerSettings(
        profileId: profileUlid,
        timeZone: 'Asia/Jerusalem',
        latitude: 31.778,
        longitude: 35.235,
        inIsrael: true,
      ),
    );
    expect(
      lockWindows(after, nextShabbos, nextShabbos),
      lockWindows(jerusalem, nextShabbos, nextShabbos),
    );
    expect(
      lockWindows(before, nextShabbos, nextShabbos),
      isNot(lockWindows(after, nextShabbos, nextShabbos)),
    );
  });

  test(
    'a later Israel switch keeps the earlier move and its windows',
    () async {
      final h = GovernedHarness()
        ..seedDoc('learner_profiles', profileUlid, {
          'time_zone': 'Asia/Jerusalem',
          'in_israel': true,
          'last_change_id': ulidA,
        });
      h.store.seed(h.scope, [
        ChangeLogEntry(
          id: ulidA,
          entity: GovernedEntity.learnerSettings,
          entityId: profileUlid,
          actionId: ulidA,
          before: {_key('time_zone'): null, _key('in_israel'): null},
          after: {_key('time_zone'): 'Asia/Jerusalem', _key('in_israel'): true},
          at: DateTime.utc(2026, 8, 1),
          actor: parentActor,
        ),
      ]);
      // Sukkot 5787 starts on Shabbos 2026-09-26: one day in Israel.
      final sukkot = DateTime.utc(2026, 9, 26, 12);
      final israelLock = lockWindows(_history(h), sukkot, sukkot).single;

      await h.commands.applyGovernedChange(
        learnerSettingsAction(
          profileUlid,
          const LearnerSettingsEdit(inIsrael: false),
        ),
      );
      final diasporaLock = lockWindows(_history(h), sukkot, sukkot).single;
      // After the switch (2026-09-10), the second day chains on.
      expect(diasporaLock.startUtc, israelLock.startUtc);
      expect(diasporaLock.endUtc.isAfter(israelLock.endUtc), isTrue);
    },
  );
}
