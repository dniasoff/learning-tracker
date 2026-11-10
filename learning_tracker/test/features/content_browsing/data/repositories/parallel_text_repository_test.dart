import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/parallel_text_repository.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/parsha_aliyah_repository.dart';

void main() {
  late ContentDatabase database;

  setUp(() {
    database = ContentDatabase(NativeDatabase.memory());
  });

  tearDown(() async => database.close());

  test(
    'checked-in seed has complete Onkelos and comment-grained Rashi data',
    () {
      final data =
          jsonDecode(
                File('tool/data/shnayim_mikra_seed.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final rows = data['rows'] as List<dynamic>;
      expect(rows, hasLength(13662));
      expect(
        rows.where(
          (row) => (row as Map<String, dynamic>)['source'] == 'onkelos',
        ),
        hasLength(5846),
      );
      expect(
        rows.where((row) => (row as Map<String, dynamic>)['source'] == 'rashi'),
        hasLength(7816),
      );
      for (final versions
          in (data['versionsByBook'] as Map<String, dynamic>).values) {
        for (final source in (versions as Map<String, dynamic>).values) {
          expect((source as Map<String, dynamic>)['license'], 'Public Domain');
        }
      }
    },
  );

  test('Onkelos is verse keyed and Rashi comments sort numerically', () async {
    await database
        .into(database.parallelText)
        .insert(
          ParallelTextCompanion.insert(
            sourceKey: 'onkelos',
            sefariaRef: 'Onkelos Genesis 1:1',
            hebrewText: 'אוֹנְקְלוֹס',
            versionTitle: 'Onkelos Genesis',
            license: 'Public Domain',
          ),
        );
    for (final suffix in [10, 2, 1]) {
      await database
          .into(database.parallelText)
          .insert(
            ParallelTextCompanion.insert(
              sourceKey: 'rashi',
              sefariaRef: 'Rashi on Genesis 1:1:$suffix',
              hebrewText: '<b>פירוש</b> $suffix',
              versionTitle: 'Rashi Genesis',
              license: 'Public Domain',
            ),
          );
    }

    final repository = ParallelTextRepository(database);
    final onkelos = await repository.getForVerse(
      sourceKey: 'onkelos',
      chumashVerseRef: 'Genesis 1:1',
    );
    expect(onkelos, hasLength(1));
    expect(onkelos.single.sefariaRef, 'Onkelos Genesis 1:1');

    final rashi = await repository.getForVerse(
      sourceKey: 'rashi',
      chumashVerseRef: 'Genesis 1:1',
    );
    expect(rashi.map((comment) => comment.sefariaRef).toList(), [
      'Rashi on Genesis 1:1:1',
      'Rashi on Genesis 1:1:2',
      'Rashi on Genesis 1:1:10',
    ]);
    expect(rashi.first.hebrewText, 'פירוש 1');
    expect(
      await repository.getForVerse(
        sourceKey: 'rashi',
        chumashVerseRef: 'Genesis 1:2',
      ),
      isEmpty,
    );
  });

  test(
    'aliyah lookup resolves kosher_dart keys and region-specific readings',
    () async {
    await database.customInsert(
      'INSERT INTO parsha_aliyot VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('NOACH'),
        Variable.withString('Noach'),
        Variable.withString('any'),
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

      final repository = ParshaAliyahRepository(database);
      expect(
        (await repository.getForPortion(
          'NOACH',
          inIsrael: false,
        )).single.startRef,
        'Genesis 6:9',
      );
      expect(
        await repository.getForPortion('VEZOT_HABERACHA', inIsrael: false),
        isEmpty,
      );
      expect(
        (await repository.getForPortion(
          'VEZOT_HABERACHA',
          inIsrael: true,
        )).single.endRef,
        'Deuteronomy 34:12',
      );
    },
  );
}
