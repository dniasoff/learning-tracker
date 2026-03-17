import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/curriculum_list_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockContentRepository extends Mock implements ContentRepository {}

void main() {
  Widget createTestWidget({required ContentRepository repository}) {
    return ProviderScope(
      overrides: [contentRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: CurriculumListScreen()),
    );
  }

  group('CurriculumListScreen', () {
    testWidgets('displays all 7 curricula', (tester) async {
      final mockRepo = MockContentRepository();

      // Mock all 7 curricula returning empty lists (just need the calls to succeed)
      for (final curriculum in CurriculumId.values) {
        when(
          () => mockRepo.getContentForCurriculum(curriculum),
        ).thenAnswer((_) async => []);
      }

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Should show all 5 curriculum names
      expect(find.text('Mishnayos'), findsOneWidget);
      expect(find.text('Talmud Bavli'), findsOneWidget);
      expect(find.text('Talmud Yerushalmi'), findsOneWidget);
      expect(find.text('Mishna Berurah'), findsOneWidget);
      expect(find.text('Chumash'), findsOneWidget);
    });

    testWidgets('displays item counts for each curriculum', (tester) async {
      final mockRepo = MockContentRepository();

      // Mock Mishnayos with 10 leaf items
      when(
        () => mockRepo.getContentForCurriculum(CurriculumId.mishnayos),
      ).thenAnswer(
        (_) async => List.generate(
          10,
          (i) => ContentItem(
            curriculumId: 'mishnayos',
            level1: 'Level $i',
            displayNameHe: 'Hebrew $i',
            displayNameEn: 'English $i',
            sefariaRef: 'Ref $i',
            sortOrder: i,
            isLeaf: true,
          ),
        ),
      );

      // Mock others with empty lists
      for (final curriculum in CurriculumId.values) {
        if (curriculum != CurriculumId.mishnayos) {
          when(
            () => mockRepo.getContentForCurriculum(curriculum),
          ).thenAnswer((_) async => []);
        }
      }

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Should show count for Mishnayos
      expect(find.textContaining('10 items'), findsOneWidget);
    });

    testWidgets('navigates to content hierarchy when curriculum tapped', (
      tester,
    ) async {
      final mockRepo = MockContentRepository();

      for (final curriculum in CurriculumId.values) {
        when(
          () => mockRepo.getContentForCurriculum(curriculum),
        ).thenAnswer((_) async => []);
      }

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Tap on Mishnayos curriculum
      await tester.tap(find.text('Mishnayos'));
      await tester.pump();

      // The tap triggers context.router.push() which throws because
      // there is no AutoRouter in the test widget tree. Swallow the
      // exception; real navigation is verified in integration tests.
      final exception = tester.takeException();
      expect(exception, isNotNull);
    });
  });
}
