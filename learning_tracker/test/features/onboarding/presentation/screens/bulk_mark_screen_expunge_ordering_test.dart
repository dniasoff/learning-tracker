// AUD-onboarding-07 regression guard.
//
// BulkMarkScreen._expungeRefs fires service.expungePriorCompletions(...) for
// each unticked pre-ticked ref WITHOUT awaiting it, then immediately calls
// ref.invalidate(...) on the dashboard/progress providers. Because those
// providers are manually invalidated (not reactively derived from the write
// itself), an active listener refetches before the un-awaited expunge write
// has actually landed — and since nothing re-invalidates once the write
// later completes, the listener is left showing the stale (pre-expunge)
// value forever.
//
// This test drives a REAL active listener (a Consumer watching a stand-in
// for dashboardCompletionPercentageProvider, backed by a value the fake
// service mutates only once its own delayed write resolves) through the
// untick flow and asserts the FINAL settled value reflects the post-expunge
// state, not the pre-expunge one.
@Tags(['onboarding', 'bulk_mark'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart'
    show Completion;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/learning/completion_constants.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
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

const _leafA = ContentItem(
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
const _leafB = ContentItem(
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
const _twoLeaves = [_leafA, _leafB];

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(<HierarchySelection>[]);
  });

  testWidgets(
    'dashboard listener reflects the post-expunge count once the delayed '
    'expunge write resolves, not the stale pre-expunge count '
    '(AUD-onboarding-07)',
    (tester) async {
      final contentRepo = _MockContentRepository();
      final completionRepo = _MockCompletionRepository();
      final service = _MockBulkPriorCompletionService();

      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => _twoLeaves);
      when(
        () => contentRepo.search(
          curriculumId: any(named: 'curriculumId'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => <ContentItem>[]);
      when(() => completionRepo.getCompletionsByCurriculum(any())).thenAnswer(
        (_) async => [
          Completion(
            id: 1,
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: _leafA.sefariaRef,
            stageId: 1,
            trackType: 'daily',
            trackId: 1,
            completedAt: kBulkPriorSentinelDate,
            points: 0,
          ),
        ],
      );

      // Stand-in "database" for the dashboard percentage: 1.0 while leafA's
      // completion is still present, flipped to 0.0 only once the fake
      // service's delayed expunge write actually resolves.
      var dashboardValue = 1.0;
      final expungeGate = Completer<void>();
      addTearDown(() {
        if (!expungeGate.isCompleted) expungeGate.complete();
      });

      when(
        () => service.expungePriorCompletions(
          profileId: any(named: 'profileId'),
          sefariaRef: any(named: 'sefariaRef'),
          curriculumId: any(named: 'curriculumId'),
        ),
      ).thenAnswer((_) async {
        await expungeGate.future;
        dashboardValue = 0.0;
      });

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
            bulkPriorCompletionServiceProvider.overrideWithValue(service),
            activeProfileIdProvider.overrideWithValue(1),
            // Mirrors the real dashboardCompletionPercentageProvider's own
            // `ref.watch<int>(completionCommittedProvider)` (dashboard_providers
            // .dart) — the bulk-mark staleness fix replaced this screen's
            // hand-picked `ref.invalidate(...)` calls with a single
            // `completionCommittedProvider.notifier.increment()` signal, so the
            // fake override must react to that same signal to keep exercising
            // the AUD-onboarding-07 await-before-signal ordering below.
            dashboardCompletionPercentageProvider.overrideWith((
              ref,
              curriculum,
            ) async {
              ref.watch<int>(completionCommittedProvider);
              return dashboardValue;
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Column(
              children: [
                // Active listener — mirrors a dashboard screen elsewhere in
                // the app that watches this provider reactively.
                Consumer(
                  builder: (context, ref, _) {
                    final pct = ref.watch(
                      dashboardCompletionPercentageProvider(
                        CurriculumId.mishnayos,
                      ),
                    );
                    return Text(
                      pct.hasValue ? 'pct:${pct.value}' : 'pct:loading',
                    );
                  },
                ),
                const Expanded(
                  child: BulkMarkScreen(curriculumId: CurriculumId.mishnayos),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Baseline: the dashboard listener shows the pre-expunge count.
      expect(find.text('pct:1.0'), findsOneWidget);

      // Untick the pre-ticked leaf: first tap partial->full (selects all),
      // second tap full->none (deselects, triggers the expunge path for the
      // pre-ticked leaf) — same sequence as the existing B8 expunge test.
      final checkboxFinder = find.byType(Checkbox);
      await tester.tap(checkboxFinder.first);
      await tester.pump();
      await tester.tap(checkboxFinder.first);
      await tester.pump();

      // The expunge write is still gated — nothing should have landed yet.
      await tester.pump(const Duration(milliseconds: 50));

      // Resolve the delayed expunge write.
      expungeGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('pct:0.0'),
        findsOneWidget,
        reason:
            'Once the expunge write actually resolves, the dashboard '
            'listener must reflect the post-expunge count — not remain '
            'stuck at the pre-expunge value from an invalidate() that fired '
            'before the write landed.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
