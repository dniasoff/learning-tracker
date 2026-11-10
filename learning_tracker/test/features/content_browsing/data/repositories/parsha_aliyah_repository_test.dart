import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/parsha_aliyah_repository.dart';

void main() {
  late ContentDatabase database;

  setUp(() => database = ContentDatabase(NativeDatabase.memory()));
  tearDown(() async => database.close());

  test(
    'lookup combines any-region and matching festival aliyot in order',
    () async {
      for (final (region, aliyah) in [
        ('any', 1),
        ('israel', 7),
        ('diaspora', 7),
      ]) {
        await database.customInsert(
          'INSERT INTO parsha_aliyot VALUES (?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString('VEZOT_HABERACHA'),
            Variable.withString('Vezot Haberachah'),
            Variable.withString(region),
            Variable.withInt(aliyah),
            Variable.withString('Deuteronomy 34:$aliyah'),
            Variable.withString('Deuteronomy 34:12'),
          ],
        );
      }

      final repository = ParshaAliyahRepository(database);
      final israel = await repository.getForPortion(
        'VEZOT_HABERACHA',
        inIsrael: true,
      );
      final diaspora = await repository.getForPortion(
        'VEZOT_HABERACHA',
        inIsrael: false,
      );
      expect(israel.map((row) => row.aliyahNumber), [1, 7]);
      expect(diaspora.map((row) => row.aliyahNumber), [1, 7]);
      expect(israel.last.startRef, 'Deuteronomy 34:7');
      expect(diaspora.last.startRef, 'Deuteronomy 34:7');
    },
  );
}
