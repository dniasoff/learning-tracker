/// CH-01 regression: ContentHierarchyScreen UI strings must be localized.
///
/// Before the fix, three strings were hard-coded English literals:
///   "Browse Content"       — AppBar title
///   "Unknown Curriculum"   — AppBar title for an invalid curriculumId
///   "No content available" — empty-state body text
///
/// In Hebrew locale these rendered in English, breaking the Hebrew UI.
/// This test was RED before l10n keys were added + wired up.
@Tags(['content_browsing', 'i18n', 'ch01'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_hierarchy_screen.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

void main() {
  late _MockContentRepository mockRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    mockRepo = _MockContentRepository();
    // Stub with exact enum values — avoids Fake issues for enums.
    when(
      () => mockRepo.getContentForCurriculum(CurriculumId.mishnayos),
    ).thenAnswer((_) async => <ContentItem>[]);
    when(() => mockRepo.getHierarchyConfig(CurriculumId.mishnayos)).thenAnswer(
      (_) async => const CurriculumHierarchyConfig(
        curriculumId: 'mishnayos',
        levelLabels: ['Seder', 'Masechta'],
        totalItems: 0,
      ),
    );
    when(
      () => mockRepo.filterByLevel(
        curriculumId: CurriculumId.mishnayos,
        level1: null,
        level2: null,
        level3: null,
        level4: null,
      ),
    ).thenAnswer((_) async => <ContentItem>[]);
  });

  Widget buildHost(String curriculumId, {Locale? locale}) {
    return ProviderScope(
      overrides: [
        contentRepositoryProvider.overrideWithValue(mockRepo),
        completionCountProvider.overrideWith(
          (ref, ({String curriculumId, String sefariaRef}) arg) async => 0,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: ContentHierarchyScreen(curriculumId: curriculumId),
      ),
    );
  }

  group(
    'ContentHierarchyScreen — CH-01: UI strings must be localized, not hard-coded',
    () {
      testWidgets(
        'Hebrew locale: AppBar title "Browse Content" renders in Hebrew',
        (tester) async {
          await tester.pumpWidget(
            buildHost('mishnayos', locale: const Locale('he')),
          );
          await tester.pumpAndSettle();

          // After the fix: Hebrew translation must appear; English must NOT.
          expect(
            find.text('עיון בתוכן'),
            findsOneWidget,
            reason:
                'CH-01: AppBar title must use l10n so Hebrew locale shows '
                '"עיון בתוכן" not the hard-coded English "Browse Content"',
          );
          expect(
            find.text('Browse Content'),
            findsNothing,
            reason: 'Hard-coded English must not leak in Hebrew locale',
          );
        },
      );

      testWidgets(
        'Hebrew locale: unknown curriculumId AppBar title renders in Hebrew',
        (tester) async {
          // An invalid curriculumId triggers the "Unknown Curriculum" early-exit branch.
          // No mock setup is needed — the screen returns before reading the repo.
          await tester.pumpWidget(
            buildHost('nonexistent_id', locale: const Locale('he')),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('קורס לא ידוע'),
            findsOneWidget,
            reason:
                'CH-01: Unknown curriculum AppBar title must be localized '
                'in Hebrew, not hard-coded as "Unknown Curriculum"',
          );
          expect(find.text('Unknown Curriculum'), findsNothing);
        },
      );

      testWidgets('Hebrew locale: empty content state renders in Hebrew', (
        tester,
      ) async {
        // Mock returns empty list → triggers the empty-state Text widget.
        await tester.pumpWidget(
          buildHost('mishnayos', locale: const Locale('he')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('אין תוכן זמין'),
          findsOneWidget,
          reason:
              'CH-01: empty-state text must be localized in Hebrew, not '
              'hard-coded as "No content available"',
        );
        expect(find.text('No content available'), findsNothing);
      });

      testWidgets(
        'English locale: UI strings still render in English after fix',
        (tester) async {
          await tester.pumpWidget(
            buildHost('mishnayos', locale: const Locale('en')),
          );
          await tester.pumpAndSettle();

          expect(find.text('Browse Content'), findsOneWidget);
          expect(find.text('No content available'), findsOneWidget);
        },
      );
    },
  );
}
