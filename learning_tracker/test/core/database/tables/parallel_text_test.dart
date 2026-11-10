import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';

void main() {
  late ContentDatabase database;

  setUp(() => database = ContentDatabase(NativeDatabase.memory()));
  tearDown(() async => database.close());

  test(
    'english text defaults to empty while source text remains required',
    () async {
      await database
          .into(database.parallelText)
          .insert(
            ParallelTextCompanion.insert(
              sourceKey: 'onkelos',
              sefariaRef: 'Onkelos Genesis 1:1',
              hebrewText: 'בְּרֵאשִׁית',
              versionTitle: 'Onkelos',
              license: 'Public Domain',
            ),
          );

      final row = (await database.select(database.parallelText).get()).single;
      expect(row.sourceKey, 'onkelos');
      expect(row.sefariaRef, 'Onkelos Genesis 1:1');
      expect(row.englishText, isEmpty);
    },
  );
}
