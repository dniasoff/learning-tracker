// AUD-onboarding-01 (SM-4) regression guard for BulkMarkScreen.
//
// _proceedToConfirmation and both branches of _executeBulkMark touch
// `setState`/context after an `await` with no `mounted` guard in between. If
// the screen is popped while that awaited service call is still in flight
// (backgrounding the app, hitting back mid-write), resuming and touching
// State after dispose throws. These tests dispose the widget mid-await via a
// gated fake service and assert the resumed continuation is a clean no-op.
@Tags(['onboarding', 'bulk_mark'])
library;

import 'dart:async';

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

/// Hosts [BulkMarkScreen] behind a [ValueNotifier]<bool> so a test can
/// unmount just the screen (not the whole ProviderScope) mid-await, mirroring
/// the wizard popping this route while a service call is still in flight.
Widget _toggleableHost({
  required ValueNotifier<bool> show,
  required _MockContentRepository contentRepo,
  required _MockCompletionRepository completionRepo,
  required _MockBulkPriorCompletionService service,
}) {
  return ProviderScope(
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
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ValueListenableBuilder<bool>(
        valueListenable: show,
        builder: (context, visible, _) => visible
            ? const BulkMarkScreen(curriculumId: CurriculumId.mishnayos)
            : const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(<HierarchySelection>[]);
  });

  late _MockContentRepository contentRepo;
  late _MockCompletionRepository completionRepo;
  late _MockBulkPriorCompletionService service;
  late ValueNotifier<bool> show;

  setUp(() {
    contentRepo = _MockContentRepository();
    completionRepo = _MockCompletionRepository();
    service = _MockBulkPriorCompletionService();

    when(
      () => contentRepo.getContentForCurriculum(any()),
    ).thenAnswer((_) async => _twoLeaves);
    when(
      () => contentRepo.search(
        curriculumId: any(named: 'curriculumId'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async => <ContentItem>[]);
    // leafA pre-ticked via a sentinel prior-completion so "Next" is live
    // without needing to drive the hierarchy panel.
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

    show = ValueNotifier<bool>(true);
  });

  tearDown(() {
    show.dispose();
  });

  testWidgets('_proceedToConfirmation does not throw when popped mid-await '
      '(AUD-onboarding-01)', (tester) async {
    final resolveGate = Completer<List<ContentItem>>();
    addTearDown(() {
      if (!resolveGate.isCompleted) resolveGate.complete([_leafA]);
    });
    when(
      () => service.resolveSelections(
        curriculumId: any(named: 'curriculumId'),
        selections: any(named: 'selections'),
      ),
    ).thenAnswer((_) => resolveGate.future);

    await tester.pumpWidget(
      _toggleableHost(
        show: show,
        contentRepo: contentRepo,
        completionRepo: completionRepo,
        service: service,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump(); // starts _proceedToConfirmation, suspends on gate

    show.value = false; // pop the screen while resolveSelections is pending
    await tester.pump();

    resolveGate.complete([_leafA]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '_executeBulkMark success path does not throw when popped mid-await '
    '(AUD-onboarding-01)',
    (tester) async {
      when(
        () => service.resolveSelections(
          curriculumId: any(named: 'curriculumId'),
          selections: any(named: 'selections'),
        ),
      ).thenAnswer((_) async => [_leafA]);

      final executeGate = Completer<BulkPriorCompletionResult>();
      addTearDown(() {
        if (!executeGate.isCompleted) {
          executeGate.complete(
            const BulkPriorCompletionResult(itemCount: 1, completionCount: 1),
          );
        }
      });
      when(
        () => service.execute(
          curriculumId: any(named: 'curriculumId'),
          resolvedItems: any(named: 'resolvedItems'),
          stageIds: any(named: 'stageIds'),
        ),
      ).thenAnswer((_) => executeGate.future);

      await tester.pumpWidget(
        _toggleableHost(
          show: show,
          contentRepo: contentRepo,
          completionRepo: completionRepo,
          service: service,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump(); // starts _executeBulkMark, suspends on gate

      show.value = false; // pop the screen while execute() is pending
      await tester.pump();

      executeGate.complete(
        const BulkPriorCompletionResult(itemCount: 1, completionCount: 1),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '_executeBulkMark error path does not throw when popped mid-await '
    '(AUD-onboarding-01)',
    (tester) async {
      when(
        () => service.resolveSelections(
          curriculumId: any(named: 'curriculumId'),
          selections: any(named: 'selections'),
        ),
      ).thenAnswer((_) async => [_leafA]);

      final executeGate = Completer<BulkPriorCompletionResult>();
      addTearDown(() {
        if (!executeGate.isCompleted) {
          executeGate.completeError(Exception('Network error'));
        }
      });
      when(
        () => service.execute(
          curriculumId: any(named: 'curriculumId'),
          resolvedItems: any(named: 'resolvedItems'),
          stageIds: any(named: 'stageIds'),
        ),
      ).thenAnswer((_) => executeGate.future);

      await tester.pumpWidget(
        _toggleableHost(
          show: show,
          contentRepo: contentRepo,
          completionRepo: completionRepo,
          service: service,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump(); // starts _executeBulkMark, suspends on gate

      show.value = false; // pop the screen while execute() is pending
      await tester.pump();

      executeGate.completeError(Exception('Network error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    },
  );
}
