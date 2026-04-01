import 'package:drift/drift.dart';

/// Metadata about the seed database itself.
/// Single-row table (one entry per seed build).
class SeedMetadata extends Table {
  /// Monotonically increasing version number set at build time
  IntColumn get version => integer()();

  /// ISO 8601 timestamp of when the seed DB was built
  TextColumn get builtAt => text()();

  /// Git SHA or build identifier of the content pipeline run
  TextColumn get buildId => text()();

  /// Number of TextCache rows in this seed
  IntColumn get textCacheCount => integer()();

  /// Number of CalendarCycles rows in this seed
  IntColumn get calendarCycleCount => integer()();

  @override
  Set<Column> get primaryKey => {version};
}
