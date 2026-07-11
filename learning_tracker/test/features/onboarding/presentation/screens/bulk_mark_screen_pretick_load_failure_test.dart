// AUD-onboarding-11 regression test.
//
// BulkMarkScreen._loadPreExistingCompletions's catch block swallowed any
// exception from the B7 pre-tick load (getContentForCurriculum /
// getCompletionsByCurriculum) completely silently -- a comment-only catch
// body that dodges the analyzer's `empty_catches` lint (which is satisfied
// by a comment) but leaves zero diagnostic trail. If pre-ticking breaks in
// production, users would see every item unticked with no log line to
// diagnose why.
//
// This test forces getContentForCurriculum to throw, then asserts the
// failure is logged via AppLogger (matching the pattern already used in
// _expungeRefs's catch a few lines below in the same file).
@Tags(['onboarding', 'bulk_mark'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart'
    show Completion;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockCompletionRepository extends Mock implements CompletionRepository {}

class _MockContentRepository extends Mock implements ContentRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  testWidgets(
    'a getContentForCurriculum failure during pre-tick load is logged via '
    'AppLogger, not swallowed silently (AUD-onboarding-11)',
    (tester) async {
      final contentRepo = _MockContentRepository();
      final completionRepo = _MockCompletionRepository();

      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenThrow(Exception('DB error'));
      when(
        () => contentRepo.search(
          curriculumId: any(named: 'curriculumId'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => completionRepo.getCompletionsByCurriculum(any()),
      ).thenAnswer((_) async => <Completion>[]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRepositoryProvider.overrideWithValue(contentRepo),
            curriculumContentProvider.overrideWith(
              (ref, curriculumId) =>
                  contentRepo.getContentForCurriculum(curriculumId),
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
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Non-fatal: the screen must still render (unticked fallback state).
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);

      final history = AppLogger.instance.talker.history
          .map((e) => e.generateTextMessage())
          .toList();
      expect(
        history.any((m) => m.contains('bulk mark pre-tick load failed')),
        isTrue,
        reason:
            'Expected the swallowed getContentForCurriculum failure to be '
            'logged via AppLogger (event: "bulk mark pre-tick load failed") '
            'instead of the catch block silently falling through to the '
            'unticked-state fallback with no diagnostic trail. '
            'Talker history: $history',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
