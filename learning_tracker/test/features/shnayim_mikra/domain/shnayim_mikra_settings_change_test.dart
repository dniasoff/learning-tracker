import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/shnayim_mikra_preferences.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/shnayim_mikra/domain/shnayim_mikra_settings_change.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state/governed_harness.dart';
import '../../../helpers/learner_state_fixtures.dart';

String _key(String field) => 'learner_profiles/$profileUlid.$field';

void main() {
  test('settings editor is parent-only and hidden in tutored sessions', () {
    expect(
      canEditShnayimMikraSettings(
        profileMode: ProfileMode.adult,
        profileId: profileUlid,
        parentPinProfileId: null,
        isTutored: false,
      ),
      isTrue,
    );
    expect(
      canEditShnayimMikraSettings(
        profileMode: ProfileMode.child,
        profileId: profileUlid,
        parentPinProfileId: profileUlid,
        isTutored: false,
      ),
      isTrue,
    );
    expect(
      canEditShnayimMikraSettings(
        profileMode: ProfileMode.child,
        profileId: profileUlid,
        parentPinProfileId: null,
        isTutored: false,
      ),
      isFalse,
    );
    expect(
      canEditShnayimMikraSettings(
        profileMode: ProfileMode.child,
        profileId: profileUlid,
        parentPinProfileId: profileUlid,
        isTutored: true,
      ),
      isFalse,
    );
  });

  test(
    'Shnayim Mikra preferences are one parent-governed learnerSettings edit',
    () async {
      final harness = GovernedHarness()
        ..seedDoc('learner_profiles', profileUlid, {
          'time_zone': 'Asia/Jerusalem',
          'in_israel': true,
          'last_change_id': ulidA,
        });

      final result = await harness.commands.applyGovernedChange(
        shnayimMikraSettingsAction(
          profileUlid,
          const ShnayimMikraSettingsEdit(
            mode: ShnayimMikraMode.parsha,
            pace: ShnayimMikraPace.dailyAliyah,
            source: ShnayimMikraSource.rashi,
            parshaSchedule: ShnayimMikraParshaSchedule.eretzYisrael,
          ),
        ),
      );

      expect(result, isA<CaptureSuccess>());
      final entry = harness.batches.single.entry;
      expect(entry.entity, GovernedEntity.learnerSettings);
      expect(entry.entityId, profileUlid);
      expect(entry.actor, parentActor);
      expect(entry.before, {
        _key('shnayim_mikra_mode'): null,
        _key('shnayim_mikra_pace'): null,
        _key('shnayim_mikra_source'): null,
        _key('shnayim_mikra_parsha_schedule'): null,
      });
      expect(entry.after, {
        _key('shnayim_mikra_mode'): 'parsha',
        _key('shnayim_mikra_pace'): 'daily_aliyah',
        _key('shnayim_mikra_source'): 'rashi',
        _key('shnayim_mikra_parsha_schedule'): 'eretz_yisrael',
      });
      expect(harness.doc('learner_profiles', profileUlid), {
        'time_zone': 'Asia/Jerusalem',
        'in_israel': true,
        'shnayim_mikra_mode': 'parsha',
        'shnayim_mikra_pace': 'daily_aliyah',
        'shnayim_mikra_source': 'rashi',
        'shnayim_mikra_parsha_schedule': 'eretz_yisrael',
        'last_change_id': engineUlid(100),
      });
    },
  );

  test('empty preference edit is rejected', () {
    expect(
      () => shnayimMikraSettingsAction(
        profileUlid,
        const ShnayimMikraSettingsEdit(),
      ),
      throwsArgumentError,
    );
  });

  test(
    'new track schedule is initialized once from the legacy Yom Tov flag',
    () {
      expect(
        initialShnayimMikraSettings(
          yomTovDays: null,
          legacyInIsrael: true,
        ).parshaSchedule,
        ShnayimMikraParshaSchedule.eretzYisrael,
      );
      expect(
        initialShnayimMikraSettings(
          yomTovDays: null,
          legacyInIsrael: false,
        ).parshaSchedule,
        ShnayimMikraParshaSchedule.chutzLaaretz,
      );
      expect(
        initialShnayimMikraSettings(
          yomTovDays: null,
          legacyInIsrael: null,
        ).parshaSchedule,
        ShnayimMikraParshaSchedule.chutzLaaretz,
      );
      expect(
        initialShnayimMikraSettings(
          yomTovDays: 1,
          legacyInIsrael: false,
        ).parshaSchedule,
        ShnayimMikraParshaSchedule.eretzYisrael,
      );
      expect(
        initialShnayimMikraSettings(
          yomTovDays: 2,
          legacyInIsrael: true,
        ).parshaSchedule,
        ShnayimMikraParshaSchedule.chutzLaaretz,
      );
    },
  );
}
