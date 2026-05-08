import 'package:drift/drift.dart';

class TrackLearningOrder extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId => integer()();
  TextColumn get sefariaRef => text()();
  IntColumn get sortOrder => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {trackId, sefariaRef},
  ];
}
