// A `SharedPreferencesStorePlatform` whose writes always fail — the
// AUD-core-preferences-04 regression-test fixture.
//
// `shared_preferences`'s legacy `SharedPreferences.setBool/setInt/setString/
// setStringList` all route through `SharedPreferencesStorePlatform.instance
// .setValue(...)`, and `.remove(...)` through `.remove(...)` — see
// `shared_preferences-2.5.5/lib/src/shared_preferences_legacy.dart`. Reads
// (`getAll`) still succeed so provider `build()`/load methods behave
// normally; only the write path fails, exactly the "SharedPreferences write
// fails" scenario the finding's regression tests exercise.
//
// Mirrors `scheduler_providers_test.dart`'s `_SlowSharedPreferencesStore`
// (which overrides `getAll()` to delay) — same
// `InMemorySharedPreferencesStore` extension shape, but overriding the
// WRITE side to throw instead of the read side to delay.
library;

import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class ThrowingSharedPreferencesStore extends InMemorySharedPreferencesStore {
  ThrowingSharedPreferencesStore(super.data) : super.withData();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    throw Exception('simulated SharedPreferences write failure');
  }

  @override
  Future<bool> remove(String key) async {
    throw Exception('simulated SharedPreferences write failure');
  }
}
