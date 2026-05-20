import 'package:drift/drift.dart';

/// Pre-computed calendar program cycles for fully offline operation.
/// Each row maps a date to a Sefaria ref for one calendar program.
class CalendarCycles extends Table {
  /// Program key matching CalendarProgramRegistry IDs
  /// e.g., 'daf_yomi', 'mishna_yomit', 'nach_yomi'
  TextColumn get programKey => text()();

  /// Date in 'YYYY-MM-DD' format (ISO 8601)
  TextColumn get dateKey => text()();

  /// Sefaria ref for this program on this date (English).
  /// e.g., 'Berakhot 2a', 'Mishnah Berakhot 1.1'
  TextColumn get sefariaRef => text()();

  /// Sefaria ref for this program on this date (Hebrew, `heRef` from
  /// /api/calendars). Null when the API didn't return one.
  /// e.g., 'ברכות ב׳', 'משנה ברכות א׳:א׳'
  TextColumn get sefariaRefHe => text().nullable()();

  /// Human-readable display name (localized)
  TextColumn get displayName => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {programKey, dateKey};
}
