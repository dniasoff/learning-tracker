import 'package:drift/drift.dart';

/// Persisted Sacred Time block windows (DNI-367, Story 26.24).
///
/// Stores the pre-computed output of [ZmanimWindowService.computeWindows]
/// so that background notification fire-time checks can consult the DB
/// without starting the Flutter engine. The table is fully replaced on
/// every recompute — [SacredWindowDao.clearAll] then [SacredWindowDao.insertAll].
///
/// lat/lng are nullable: a null pair means "Israel, coordinates not available".
class SacredWindowEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get startUtc => dateTime()();
  DateTimeColumn get endUtc => dateTime()();

  /// 'shabbos' | 'yomTov' | 'shabbosYomTov' | 'yomKippur'
  TextColumn get kind => text()();

  /// Device latitude — null when coordinates are not available.
  RealColumn get lat => real().nullable()();

  /// Device longitude — null when coordinates are not available.
  RealColumn get lng => real().nullable()();

  BoolColumn get inIsrael => boolean()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
