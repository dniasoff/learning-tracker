import 'package:drift_flutter/drift_flutter.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'registry_provider.g.dart';

/// Opens and owns the device registry database. Lives for the entire
/// app lifetime — opened once at startup, never closed until the
/// process exits.
@Riverpod(keepAlive: true)
DeviceRegistryDatabase deviceRegistry(Ref ref) {
  final database = DeviceRegistryDatabase(
    driftDatabase(name: 'device_registry'),
  );
  ref.onDispose(database.close);
  return database;
}
