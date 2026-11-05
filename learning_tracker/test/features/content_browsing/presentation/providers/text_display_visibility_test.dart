import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late ContentDatabase database;

  setUp(() => database = createTestContentDatabase());
  tearDown(() => database.close());

  test('a direct reader deep link cannot load a hidden cached ref', () async {
    const hiddenRef = 'Mishnah Hidden 1:1';
    await database
        .into(database.textCache)
        .insert(
          TextCacheCompanion.insert(
            sefariaRef: hiddenRef,
            hebrewText: 'טקסט מוסתר',
            englishText: 'hidden text',
            fetchedAt: DateTime.utc(2026, 11, 5),
          ),
        );
    final textRepository = TextCacheRepository(
      textCacheDao: database.contentTextCacheDao,
      dailyContentDao: database.dailyContentDao,
    );
    final visibleIndex = ContentIndex.fromCurricula({
      CurriculumId.mishnayos: [
        ContentItem(
          curriculumId: CurriculumId.mishnayos.storageKey,
          level1: 'Seder',
          level2: 'Visible',
          displayNameHe: 'גלוי',
          displayNameEn: 'Visible',
          sefariaRef: 'Mishnah Visible 1:1',
          sortOrder: 0,
          isLeaf: true,
        ),
      ],
    });
    final container = ProviderContainer.test(
      overrides: [
        contentIndexProvider.overrideWith((ref) async => visibleIndex),
        textCacheRepositoryProvider.overrideWith((ref) async => textRepository),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(textContentProvider(hiddenRef).future), isNull);
  });
}
