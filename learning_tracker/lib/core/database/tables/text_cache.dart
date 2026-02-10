import 'package:drift/drift.dart';

/// TextCache table for storing fetched Sefaria text content.
/// Enables offline access to previously viewed texts.
class TextCache extends Table {
  TextColumn get sefariaRef => text()();
  TextColumn get hebrewText => text()();
  TextColumn get englishText => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sefariaRef};
}
