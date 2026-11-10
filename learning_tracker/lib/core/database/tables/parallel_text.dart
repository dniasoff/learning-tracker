import 'package:drift/drift.dart';

/// Offline third-reading text for Shnayim Mikra.
///
/// Onkelos rows are keyed by verse; Rashi rows are keyed by individual
/// comment ref, so a verse may have zero, one, or many rows.
class ParallelText extends Table {
  TextColumn get sourceKey => text()();
  TextColumn get sefariaRef => text()();
  TextColumn get hebrewText => text()();
  TextColumn get englishText => text().withDefault(const Constant(''))();
  TextColumn get versionTitle => text()();
  TextColumn get license => text()();

  @override
  Set<Column> get primaryKey => {sourceKey, sefariaRef};
}
