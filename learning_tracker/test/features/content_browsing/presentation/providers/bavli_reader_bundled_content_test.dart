import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';
import 'package:learning_tracker/features/content_browsing/domain/profile_visible_content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/services/sefaria_ref_matcher.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ContentDatabase database;
  late ProviderContainer container;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('bavli-reader-');
    final dbFile = File('${tempDir.path}/content.db');
    final process = await Process.start('xz', [
      '--decompress',
      '--stdout',
      'assets/db/content.db.xz',
    ]);
    await process.stdout.pipe(dbFile.openWrite());
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw StateError('xz could not extract bundled content.db.xz');
    }
    database = ContentDatabase.openReadOnly(dbFile);
    container = ProviderContainer(
      overrides: [
        contentDatabaseProvider.overrideWith((ref) async => database),
        visibleContentRepositoryProvider.overrideWith(
          (ref) async => ProfileVisibleContentRepository(
            ContentRepositoryImpl(),
            const {},
          ),
        ),
      ],
    );
  });

  tearDownAll(() async {
    container.dispose();
    await database.close();
    await tempDir.delete(recursive: true);
  });

  test(
    'bundled Bavli texts resolve through profile, Learn, and Browse paths',
    () async {
      // This is the same profile-visible index watched by textContentProvider.
      final index = await container.read(contentIndexProvider.future);
      final bavli = await container.read(
        curriculumContentProvider(CurriculumId.bavli).future,
      );
      final firstAmudByMasechta = <String, String>{};
      for (final item in bavli.where((item) => item.isLeaf)) {
        firstAmudByMasechta.putIfAbsent(
          item.level1 ?? '',
          () => item.sefariaRef,
        );
      }
      expect(firstAmudByMasechta.length, greaterThan(30));
      expect(bavli.where((item) => item.isLeaf), hasLength(5349));
      expect(
        bavli.where((item) => item.level1?.startsWith('Seder ') ?? false),
        isEmpty,
        reason: 'Bavli browser roots must be masechtos, not Mishnah sedarim',
      );
      expect(
        bavli.where((item) => item.level1 != null && item.level2 == null),
        hasLength(greaterThan(30)),
        reason: 'Bavli top-level rows should be masechtos',
      );
      expect(
        bavli.where((item) => item.level4 != null),
        isEmpty,
        reason: 'Bavli should use only Masechta/Daf/Amud levels',
      );

      Future<void> expectReaderText(
        String sefariaRef, {
        required String path,
      }) async {
        expect(
          index.lookup(sefariaRef),
          isNotNull,
          reason: '$path index: $sefariaRef',
        );
        final text = await container.read(
          textContentProvider(sefariaRef).future,
        );
        expect(
          text,
          isNotNull,
          reason: '$path reader returned no text for $sefariaRef',
        );
        expect(
          text!.segments.any((segment) => segment.hebrewText.isNotEmpty),
          isTrue,
          reason: '$path has no Hebrew text for $sefariaRef',
        );
        expect(
          text.segments.any((segment) => segment.englishText.isNotEmpty),
          isTrue,
          reason: '$path has no English text for $sefariaRef',
        );
      }

      // Browse opens the canonical first amud from each masechta's hierarchy.
      for (final ref in firstAmudByMasechta.values) {
        await expectReaderText(ref, path: 'content browser');
        await expectReaderText(ref, path: 'Learn row');
      }

      // Daf-level refs are parents in the browse hierarchy and are also emitted
      // by calendar-linked Learn rows. They must aggregate their a/b amud rows.
      await expectReaderText('Berakhot 2', path: 'content browser daf');
      await expectReaderText('Chullin 7', path: 'content browser daf');

      // Exercise the actual local calendar engine used by today's Learn rows,
      // then follow the same provider path as the row's reader navigation.
      final today = await LocalCalendarEngine(
        database,
      ).getEntry('daf_yomi', DateTimeFactory.nowLocal());
      expect(
        today,
        isNotNull,
        reason: 'bundled calendar has no Daf Yomi row today',
      );
      final calendarText = await (await container.read(
        textCacheRepositoryProvider.future,
      )).getText(today!.todayRef);
      expect(
        calendarText?.segments.single.sefariaRef,
        today.todayRef,
        reason: 'Daf Yomi should use its daily_content row as the fallback',
      );
      await expectReaderText(today.todayRef, path: 'Learn Daf Yomi row');
      final learnLeafRefs = resolveProgramTodayRefs(today.todayRef, bavli);
      expect(learnLeafRefs, isNotEmpty);
      for (final ref in learnLeafRefs) {
        await expectReaderText(ref, path: 'Learn Daf Yomi resolved row');
      }

      // The visible index and reader above are profile-scoped. A profile with a
      // Bavli track sees the same Bavli hierarchy refs through that seam.
      expect(
        bavli.where(
          (item) => item.curriculumId == CurriculumId.bavli.storageKey,
        ),
        isNotEmpty,
        reason: 'profile-visible content omitted its Bavli track',
      );
    },
  );
}
