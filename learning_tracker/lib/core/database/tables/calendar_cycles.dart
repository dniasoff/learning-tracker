import 'package:drift/drift.dart';

/// Pre-computed calendar program cycles for fully offline operation.
/// Each row maps a date to a Sefaria ref for one calendar program.
class CalendarCycles extends Table {
  /// API program key matching LearningPrograms.apiProgramKey
  /// e.g., 'Daf Yomi', 'Mishnah Yomit', 'Nach Yomi'
  TextColumn get programKey => text()();

  /// Date in 'YYYY-MM-DD' format (ISO 8601)
  TextColumn get dateKey => text()();

  /// Sefaria ref for this program on this date
  /// e.g., 'Berakhot 2a', 'Mishnah Berakhot 1.1'
  TextColumn get sefariaRef => text()();

  /// Human-readable display name (localized)
  TextColumn get displayName => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {programKey, dateKey};
}
