import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/parent_session_persistence.dart';

void main() {
  test('namespaces the opaque lease by account uid', () async {
    final storage = _MemorySecureStorage();
    final persistence = ParentSessionPersistence(storage);

    await persistence.write('uid-a', 'a' * 64);
    await persistence.write('uid-b', 'b' * 64);

    expect(await persistence.read('uid-a'), 'a' * 64);
    expect(await persistence.read('uid-b'), 'b' * 64);
    await persistence.clear('uid-a');
    expect(await persistence.read('uid-a'), isNull);
    expect(await persistence.read('uid-b'), 'b' * 64);
  });
}

final class _MemorySecureStorage extends FlutterSecureStorage {
  final _values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values.remove(key);
}
