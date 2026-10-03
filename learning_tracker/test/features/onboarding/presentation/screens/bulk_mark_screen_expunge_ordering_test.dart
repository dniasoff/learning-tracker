// AUD-onboarding-07 regression guard.
//
// BulkMarkScreen._expungeRefs fires the recorder's unrecord (unlearn) for
// the unticked pre-ticked refs WITHOUT awaiting it, then immediately calls
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
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/before_tracking_recorder.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

class _MockBeforeTrackingRecorder extends Mock
    implements BeforeTrackingRecorder {}

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
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(<HierarchySelection>[]);
  });

  testWidgets(
    'dashboard listener reflects the post-unlearn count after the selected '
    'refs are removed, not the stale pre-unlearn count '
    '(AUD-onboarding-07)',
    (tester) async {
      final contentRepo = _MockContentRepository();
      final service = _MockBeforeTrackingRecorder();

      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => _twoLeaves);
      when(
        () => contentRepo.search(
          curriculumId: any(named: 'curriculumId'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => <ContentItem>[]);
      when(
        () => service.recordedRefs(any()),
      ).thenAnswer((_) async => {_leafA.sefariaRef});

      // Stand-in "database" for the dashboard percentage: 1.0 while leafA is
      // still counted, flipped to 0.0 only once unlearn resolves.
      var dashboardValue = 1.0;
      final unlearnGate = Completer<void>();
      addTearDown(() {
        if (!unlearnGate.isCompleted) unlearnGate.complete();
      });

      when(
        () => service.unrecord(
          curriculumId: any(named: 'curriculumId'),
          sefariaRefs: any(named: 'sefariaRefs'),
        ),
      ).thenAnswer((_) async {
        await unlearnGate.future;
        dashboardValue = 0.0;
        return const CaptureResult.success();
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
            beforeTrackingRecorderProvider.overrideWithValue(service),
            activeProfileIdProvider.overrideWithValue(_profileId),
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
      // second tap full->none (deselects, triggering unlearn for leafA).
      final checkboxFinder = find.byType(Checkbox);
      await tester.tap(checkboxFinder.first);
      await tester.pump();
      await tester.tap(checkboxFinder.first);
      await tester.pump();

      // The unlearn write is still gated — nothing should have landed yet.
      await tester.pump(const Duration(milliseconds: 50));

      verify(
        () => service.unrecord(
          curriculumId: CurriculumId.mishnayos,
          sefariaRefs: ['Mishnah Berakhot 1:1'],
        ),
      ).called(1);

      // Resolve the delayed unlearn write.
      unlearnGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('pct:0.0'),
        findsOneWidget,
        reason:
            'Once unlearn actually resolves, the dashboard '
            'listener must reflect the post-expunge count — not remain '
            'stuck at the pre-expunge value from an invalidate() that fired '
            'before the write landed.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
