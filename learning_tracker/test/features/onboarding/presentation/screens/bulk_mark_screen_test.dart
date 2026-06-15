import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart'
    show Completion;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockCompletionRepository extends Mock implements CompletionRepository {}

class _MockContentRepository extends Mock implements ContentRepository {}

class _MockBulkPriorCompletionService extends Mock
    implements BulkPriorCompletionService {}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  group('BulkMarkScreen', () {
    late _MockCompletionRepository completionRepo;

    setUp(() {
      completionRepo = _MockCompletionRepository();
      when(
        () => completionRepo.getCompletionsByCurriculum(any()),
      ).thenAnswer((_) async => <Completion>[]);
    });

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            curriculumContentProvider.overrideWith(
              (ref, curriculumId) => Future.value([]),
            ),
            contentSearchProvider.overrideWith((ref, args) => Future.value([])),
            completionRepositoryProvider.overrideWithValue(completionRepo),
            activeProfileIdProvider.overrideWithValue(1),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BulkMarkScreen(curriculumId: CurriculumId.mishnayos),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('stage-picker screen is absent — only selection phase shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            curriculumContentProvider.overrideWith(
              (ref, curriculumId) => Future.value([]),
            ),
            contentSearchProvider.overrideWith((ref, args) => Future.value([])),
            completionRepositoryProvider.overrideWithValue(completionRepo),
            activeProfileIdProvider.overrideWithValue(1),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BulkMarkScreen(curriculumId: CurriculumId.mishnayos),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // B5: the stage-picker question must never appear.
      expect(
        find.text('Which stages have you completed?'),
        findsNothing,
        reason: 'Stage-picker screen must be removed (B5)',
      );
      // Selection phase is visible.
      expect(
        find.text('Select content you\'ve already completed'),
        findsOneWidget,
      );
    });

    // Wave 5 Task #17: the wizard MUST explain the B1 tier-credit policy so
    // users understand why streak and points are not impacted.
    testWidgets('shows B1 tier-credit subtitle below the selection header', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            curriculumContentProvider.overrideWith(
              (ref, curriculumId) => Future.value([]),
            ),
            contentSearchProvider.overrideWith((ref, args) => Future.value([])),
            completionRepositoryProvider.overrideWithValue(completionRepo),
            activeProfileIdProvider.overrideWithValue(1),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BulkMarkScreen(curriculumId: CurriculumId.mishnayos),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The subtitle uses the W2 l10n key `bulkMarkWizardSubtitle` whose en
      // copy clarifies the tier policy.
      expect(
        find.textContaining(
          'These count toward siyumim and lifetime knowledge',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('not toward your streak or points'),
        findsOneWidget,
      );
    });

    // Wave 5 Task #17: after the bulk-mark commits, the screen MUST surface a
    // confirmation toast that names the count and points to Lifetime Knowledge.
    testWidgets(
      'shows confirmation toast naming the count after bulk-mark commits',
      (tester) async {
        final contentRepo = _MockContentRepository();
        final service = _MockBulkPriorCompletionService();

        // Two leaves, only one is pre-ticked — needed so the "can't mark
        // everything" guard in _proceedToConfirmation doesn't bail out.
        const leafA = ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Zeraim',
          level2: 'Berakhot',
          level3: '1',
          level4: '1',
          displayNameHe: 'ברכות א:א',
          displayNameEn: 'Berakhot 1:1',
          sefariaRef: 'Mishnah Berakhot 1:1',
          sortOrder: 1,
          isLeaf: true,
        );
        const leafB = ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Zeraim',
          level2: 'Berakhot',
          level3: '1',
          level4: '2',
          displayNameHe: 'ברכות א:ב',
          displayNameEn: 'Berakhot 1:2',
          sefariaRef: 'Mishnah Berakhot 1:2',
          sortOrder: 2,
          isLeaf: true,
        );
        const allItems = [leafA, leafB];

        when(
          () => contentRepo.getContentForCurriculum(any()),
        ).thenAnswer((_) async => allItems);

        // Pre-tick leafA via a sentinel completion so we don't need to drive
        // the hierarchy panel UI to add a selection.
        when(() => completionRepo.getCompletionsByCurriculum(any())).thenAnswer(
          (_) async => [
            Completion(
              id: 1,
              profileId: 1,
              curriculumId: 'mishnayos',
              sefariaRef: leafA.sefariaRef,
              stageId: 1,
              trackType: 'daily',
              trackId: 1,
              completedAt: kBulkPriorSentinelDate,
              points: 0,
            ),
          ],
        );

        when(
          () => service.resolveSelections(
            curriculumId: any(named: 'curriculumId'),
            selections: any(named: 'selections'),
          ),
        ).thenAnswer((_) async => [leafA]);

        when(
          () => service.execute(
            curriculumId: any(named: 'curriculumId'),
            resolvedItems: any(named: 'resolvedItems'),
            stageIds: any(named: 'stageIds'),
          ),
        ).thenAnswer(
          (_) async =>
              const BulkPriorCompletionResult(itemCount: 7, completionCount: 7),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contentRepositoryProvider.overrideWithValue(contentRepo),
              curriculumContentProvider.overrideWith(
                (ref, curriculumId) => Future.value(allItems),
              ),
              contentSearchProvider.overrideWith(
                (ref, args) => Future.value([]),
              ),
              completionRepositoryProvider.overrideWithValue(completionRepo),
              bulkPriorCompletionServiceProvider.overrideWithValue(service),
              activeProfileIdProvider.overrideWithValue(1),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BulkMarkScreen(curriculumId: CurriculumId.mishnayos),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // leafA is pre-ticked from the sentinel completion, so "Next" is live.
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Confirmation phase → tap Confirm to trigger _executeBulkMark.
        await tester.tap(find.text('Confirm'));
        await tester.pump(); // start the future
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(); // allow SnackBar to appear

        // The toast carries the count and routes the user to Lifetime Knowledge.
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('7 items marked as previously learned'),
          findsOneWidget,
        );
        expect(find.textContaining('Lifetime Knowledge'), findsOneWidget);
      },
    );

    // Hebrew locale: the AppBar title and selection heading must be localized
    // (no leftover hardcoded English "Mark Prior Completions" / "Select content
    // you've already completed").
    testWidgets('title and heading are localized in Hebrew locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            curriculumContentProvider.overrideWith(
              (ref, curriculumId) => Future.value([]),
            ),
            contentSearchProvider.overrideWith((ref, args) => Future.value([])),
            completionRepositoryProvider.overrideWithValue(completionRepo),
            activeProfileIdProvider.overrideWithValue(1),
          ],
          child: const MaterialApp(
            locale: Locale('he'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BulkMarkScreen(curriculumId: CurriculumId.mishnayos),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // English source strings must NOT appear.
      expect(find.textContaining('Mark Prior Completions'), findsNothing);
      expect(
        find.text('Select content you\'ve already completed'),
        findsNothing,
      );
      // Localized Hebrew heading is present.
      expect(find.text('בחרו תוכן שכבר למדתם'), findsOneWidget);
    });
  });
}
