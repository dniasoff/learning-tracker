import 'package:drift/drift.dart';

/// Pre-resolved bilingual text for refs emitted by calendar programs
/// (hebcal + Sefaria). Distinct from [TextCache] which holds atomic
/// curriculum content — `daily_content` is keyed by the *display ref* a
/// calendar program produces (e.g. `Chullin 7` daf-level rather than the
/// `Chullin 7a` / `Chullin 7b` atomic pair).
///
/// Populated at seed-build time by the Python extractor; consumed at
/// runtime by the source viewer as a fallback when text_cache misses.
class DailyContent extends Table {
  TextColumn get sefariaRef => text()();

  /// English text of the reading, ready to display.
  TextColumn get englishText => text().withDefault(const Constant(''))();

  /// Hebrew text of the reading, ready to display.
  TextColumn get hebrewText => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {sefariaRef};
}
