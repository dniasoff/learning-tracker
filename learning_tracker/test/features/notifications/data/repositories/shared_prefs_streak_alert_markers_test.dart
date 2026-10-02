// Mirror test for `shared_prefs_streak_alert_markers.dart` (DNI-479).
@Tags(['notifications', 'unit'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/data/repositories/shared_prefs_streak_alert_markers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';
const _b = '01JQ8M9Y7V3K2N6P4R5T8W0X2A';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('markers are kept per profile and curriculum', () async {
    final markers = SharedPrefsStreakAlertMarkers();
    await markers.write(_a, 'mishnayos', '2026-03-25@21:0');
    await markers.write(_a, 'bavli', '2026-03-25@21:0');
    await markers.write(_b, 'mishnayos', '2026-03-24@20:0');

    expect(await markers.read(_a, 'mishnayos'), '2026-03-25@21:0');
    expect(await markers.read(_b, 'mishnayos'), '2026-03-24@20:0');
    expect(await markers.read(_b, 'bavli'), isNull);

    await markers.clear(_a, 'bavli');
    expect(await markers.read(_a, 'bavli'), isNull);
    expect(await markers.read(_a, 'mishnayos'), isNotNull);
  });

  test('clearAll forgets only that profile', () async {
    final markers = SharedPrefsStreakAlertMarkers();
    await markers.write(_a, 'mishnayos', 'x');
    await markers.write(_a, 'bavli', 'x');
    await markers.write(_b, 'mishnayos', 'y');

    await markers.clearAll(_a);
    expect(await markers.read(_a, 'mishnayos'), isNull);
    expect(await markers.read(_a, 'bavli'), isNull);
    expect(await markers.read(_b, 'mishnayos'), 'y');
  });
}
