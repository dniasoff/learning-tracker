import 'package:drift/drift.dart';

/// Cache for calendar API responses to avoid redundant network calls.
class CalendarCache extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// API source: 'sefaria' or 'hebcal'
  TextColumn get source => text()();

  /// Date key in 'YYYY-MM-DD' format
  TextColumn get dateKey => text()();

  /// Full JSON response body
  TextColumn get responseJson => text()();

  /// When the response was cached
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {source, dateKey},
  ];
}
