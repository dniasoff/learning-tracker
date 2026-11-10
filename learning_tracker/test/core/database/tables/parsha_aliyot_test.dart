import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';

void main() {
  late ContentDatabase database;

  setUp(() => database = ContentDatabase(NativeDatabase.memory()));
  tearDown(() async => database.close());

  test(
    'region defaults to any and region distinguishes festival rows',
    () async {
      await database.customInsert(
        'INSERT INTO parsha_aliyot '
        '(portion_key, portion_name, aliyah_number, start_ref, end_ref) '
        'VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('NOACH'),
          Variable.withString('Noach'),
          Variable.withInt(1),
          Variable.withString('Genesis 6:9'),
          Variable.withString('Genesis 6:22'),
        ],
      );
      await database.customInsert(
        'INSERT INTO parsha_aliyot VALUES (?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('VEZOT_HABERACHA'),
          Variable.withString('Vezot Haberachah'),
          Variable.withString('israel'),
          Variable.withInt(7),
          Variable.withString('Deuteronomy 34:1'),
          Variable.withString('Deuteronomy 34:12'),
        ],
      );

      final rows = await database
          .customSelect(
            'SELECT region, aliyah_number FROM parsha_aliyot '
            'ORDER BY portion_key',
          )
          .get();
      expect(rows.map((row) => row.read<String>('region')), ['any', 'israel']);
      expect(rows.map((row) => row.read<int>('aliyah_number')), [1, 7]);
    },
  );
}
