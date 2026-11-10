import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/shnayim_mikra_preferences.dart';

void main() {
  test('workflow preferences retain their governed storage keys', () {
    expect(ShnayimMikraMode.values.map((value) => value.storageKey), [
      'pasuk',
      'aliyah',
      'parsha',
    ]);
    expect(ShnayimMikraPace.dailyAliyah.storageKey, 'daily_aliyah');
    expect(ShnayimMikraSource.rashi.storageKey, 'rashi');
    expect(ShnayimMikraSource.onkelos.storageKey, 'onkelos');
  });

  test('explicit Yom Tov schedule takes precedence over legacy location', () {
    expect(
      shnayimMikraScheduleFromLegacyYomTovFlag(
        yomTovDays: 1,
        legacyInIsrael: false,
      ),
      ShnayimMikraParshaSchedule.eretzYisrael,
    );
    expect(
      shnayimMikraScheduleFromLegacyYomTovFlag(
        yomTovDays: 2,
        legacyInIsrael: true,
      ),
      ShnayimMikraParshaSchedule.chutzLaaretz,
    );
  });
}
