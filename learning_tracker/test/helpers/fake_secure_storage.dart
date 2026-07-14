/// Shared in-memory [FlutterSecureStorage] fake for `PinService` tests
/// (AUD-t-parent_mode-02).
///
/// Before this helper existed, `pin_service_test.dart`,
/// `pin_service_extended_test.dart`, and `pin_service_profile_test.dart`
/// each hand-rolled an identical ~35-line `MockFlutterSecureStorage` +
/// `createMockStorage()` pair. A change to the stubbing (e.g. adding a
/// `deleteAll()` stub) had to be repeated in three places or silently
/// drifted between copies. All `PinService` tests should now call
/// [createMockStorage] from here instead of redeclaring the class.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

/// Mocktail double for [FlutterSecureStorage]. [createMockStorage] wires it
/// up with an in-memory `Map` backing store so it behaves like a real
/// (if non-persistent) secure-storage implementation.
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

/// Returns a [MockFlutterSecureStorage] backed by an in-memory `Map`, so
/// `write`/`read`/`delete` round-trip like a real secure-storage instance
/// without hitting a platform channel.
MockFlutterSecureStorage createMockStorage() {
  final mock = MockFlutterSecureStorage();
  final store = <String, String>{};

  when(
    () => mock.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    final value = invocation.namedArguments[#value] as String?;
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  });

  when(() => mock.read(key: any(named: 'key'))).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    return store[key];
  });

  when(() => mock.delete(key: any(named: 'key'))).thenAnswer((
    invocation,
  ) async {
    final key = invocation.namedArguments[#key] as String;
    store.remove(key);
  });

  return mock;
}
