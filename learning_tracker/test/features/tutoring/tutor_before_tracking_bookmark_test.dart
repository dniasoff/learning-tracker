// Story 1.24 (DNI-486) — a tutor's before-tracking marking is the tutor
// callable's write alone. The talmid's reading-order bookmark is owner-only
// by the Firestore rules, so the recorder must not follow a committed
// tutorRecordLearning with a bookmark write: a refused bookmark write after
// the events committed would report a failed save, and the retry would
// write the learning events a second time.

@Tags(['tutor_mode'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/hierarchy_selection.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';

import '../../helpers/tutoring/tutor_learning_harness.dart';

ContentItem _item(String ref, int order, {String? l2, bool leaf = false}) =>
    ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      level2: l2,
      level3: leaf ? '1' : null,
      displayNameHe: ref,
      displayNameEn: ref,
      sefariaRef: ref,
      sortOrder: order,
      isLeaf: leaf,
    );

final _items = [
  _item('Seder Zeraim', 0),
  _item('Mishnah Berakhot', 1, l2: 'Berakhot'),
  _item('Mishnah Berakhot 1', 2, l2: 'Berakhot', leaf: true),
  _item('Mishnah Peah', 3, l2: 'Peah'),
  _item('Mishnah Peah 1', 4, l2: 'Peah', leaf: true),
];

class _Content extends Fake implements ContentRepository {
  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId id) async =>
      _items;
}

/// The talmid's bookmark from the tutor's session: the rules refuse every
/// write (owner-only).
class _OwnerOnlyBookmarks extends Fake implements BookmarkRepository {
  var attempts = 0;

  @override
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    attempts++;
    throw StateError('permission-denied: bookmarks are owner-only');
  }
}

void main() {
  test('a tutored before-tracking mark succeeds on the callable alone: no '
      'bookmark write follows the committed capture', () async {
    final h = TutorHarness();
    addTearDown(h.dispose);
    final bookmarks = _OwnerOnlyBookmarks();
    final container = ProviderContainer(
      overrides: [
        ...tutoredOverrides(selection: h.selection),
        contentRepositoryProvider.overrideWithValue(_Content()),
        bookmarkRepositoryProvider.overrideWithValue(bookmarks),
        learningCommandsProvider.overrideWith((ref) async => h.commands),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(beforeTrackingRecorderProvider)
        .record(
          curriculumId: CurriculumId.mishnayos,
          selections: const [
            HierarchySelection(level1: 'Zeraim', level2: 'Berakhot'),
          ],
        );

    expect(result.capture, isA<CaptureSuccess>());
    expect(result.eventCount, 1);
    expect(result.bookmarkSefariaRef, isNull);
    expect(bookmarks.attempts, 0);
    expect(h.invoker.calls.single.fn, 'tutorRecordLearning');
  });

  test('outside a tutored session the legacy bookmark co-write is still '
      'attempted (DNI-478 retires it)', () async {
    final h = TutorHarness();
    addTearDown(h.dispose);
    final container = ProviderContainer(
      overrides: [
        ...tutoredOverrides(),
        contentRepositoryProvider.overrideWithValue(_Content()),
        bookmarkRepositoryProvider.overrideWithValue(_OwnerOnlyBookmarks()),
        learningCommandsProvider.overrideWith((ref) async => h.commands),
        learningEventRepositoryProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(beforeTrackingRecorderProvider)
          .record(
            curriculumId: CurriculumId.mishnayos,
            selections: const [
              HierarchySelection(level1: 'Zeraim', level2: 'Berakhot'),
            ],
          ),
      throwsA(isA<StateError>()),
      reason: 'outside a tutored session the co-write is attempted',
    );
  });
}
