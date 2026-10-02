// DNI-520 AC-4 — `pathUidResolverProvider` is the app's single
// PathUidResolver, over the device registry: the persisted path uid is read
// from (and bound into) the registry row, never taken from live Auth.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/providers/path_uid_resolver_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';

void main() {
  late DeviceRegistryDatabase registry;
  late ProviderContainer container;

  Future<void> seed(String accountId, String? uid) => registry.addAccount(
    DeviceAccountsCompanion.insert(
      accountId: accountId,
      email: '$accountId@example.com',
      displayName: accountId,
      tier: 'cloudBorn',
      firebaseUid: Value(uid),
      dbFileName: 'user_acc_$accountId.db',
      createdAt: DateTime.utc(2026),
      lastUsedAt: DateTime.utc(2026),
    ),
  );

  setUp(() {
    registry = DeviceRegistryDatabase(NativeDatabase.memory());
    addTearDown(registry.close);
    container = ProviderContainer(
      overrides: [deviceRegistryProvider.overrideWithValue(registry)],
    );
    addTearDown(container.dispose);
  });

  test('reads the persisted path uid from the device registry row', () async {
    await seed('acc-1', 'persisted-uid');

    final resolver = container.read(pathUidResolverProvider);

    expect(await resolver.pathUidFor('acc-1'), 'persisted-uid');
  });

  test('binds a live uid into a row that has none, then reads it back from '
      'the registry', () async {
    await seed('acc-anon', null);
    final resolver = container.read(pathUidResolverProvider);

    final bound = await resolver.reconcileLiveUid(
      accountId: 'acc-anon',
      liveUid: 'anon-uid',
    );

    expect(bound.newUid, 'anon-uid');
    expect(await resolver.pathUidFor('acc-anon'), 'anon-uid');
    expect((await registry.findById('acc-anon'))!.firebaseUid, 'anon-uid');
  });

  test('is one resolver per container (a single source of path uids)', () {
    expect(
      container.read(pathUidResolverProvider),
      same(container.read(pathUidResolverProvider)),
    );
  });
}
