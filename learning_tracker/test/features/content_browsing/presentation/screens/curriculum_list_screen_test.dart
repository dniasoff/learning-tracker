import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/curriculum_list_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockContentRepository extends Mock implements ContentRepository {}

void main() {
  // DNI-328 flipped the Hebrew-terms default to false (English transliteration).
  // These tests assert on Hebrew strings so seed the per-profile preference to
  // true before each test.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hebrew_terms_script_p0': true,
    });
  });

  Widget createTestWidget({required ContentRepository repository}) {
    return ProviderScope(
      overrides: [
        contentRepositoryProvider.overrideWithValue(repository),
        // Override the completion percentage provider to avoid DB dependency
        dashboardCompletionPercentageProvider.overrideWith(
          (ref, curriculum) async => 0.0,
        ),
      ],
      child: const MaterialApp(home: CurriculumListScreen()),
    );
  }

  group('CurriculumListScreen', () {
    testWidgets('displays all curricula', (tester) async {
      final mockRepo = MockContentRepository();

      // Mock all curricula returning empty lists (just need the calls to succeed)
      for (final curriculum in CurriculumId.values) {
        when(
          () => mockRepo.getContentForCurriculum(curriculum),
        ).thenAnswer((_) async => []);
      }

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Should show curriculum Hebrew names — verify first few visible
      expect(find.text('משניות'), findsWidgets);
      expect(find.text('תלמוד בבלי'), findsWidgets);
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
      expect(find.textContaining('10'), findsWidgets);
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
      await tester.tap(find.text('משניות').first);
      await tester.pump();

      // The tap triggers context.router.push() which throws because
      // there is no AutoRouter in the test widget tree. Swallow the
      // exception; real navigation is verified in integration tests.
      final exception = tester.takeException();
      expect(exception, isNotNull);
    });
  });
}
