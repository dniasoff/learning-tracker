import 'package:drift/drift.dart';

/// Offline Chumash aliyah boundaries by kosher_dart parsha enum name.
///
/// `region` is `any`, `israel`, or `diaspora`; weekly readings use `any`,
/// while the two Simchas Torah Vezot Haberachah readings are region-specific.
class ParshaAliyot extends Table {
  TextColumn get portionKey => text()();
  TextColumn get portionName => text()();
  TextColumn get region => text().withDefault(const Constant('any'))();
  IntColumn get aliyahNumber => integer()();
  TextColumn get startRef => text()();
  TextColumn get endRef => text()();

  @override
  Set<Column> get primaryKey => {portionKey, region, aliyahNumber};
}
