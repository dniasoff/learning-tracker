import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart'
    show Completion;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockCompletionRepository extends Mock implements CompletionRepository {}

void main() {
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
  });
}
