// Error-handling regression for LearningOrderScreen (AUD-tracks-08, P1):
// none of the reorder/reset persist call paths in this screen had a
// try/catch — a save/reset failure (DB busy, disk full, offline outbox push)
// left the optimistic reorder showing as "saved" with zero error affordance
// and no rollback. This file proves:
//   1. a reorder whose saveOrder throws surfaces a visible error affordance
//      and reverts the local list to the pre-reorder order.
//   2. a reset whose resetToDefault throws surfaces a visible error
//      affordance.

@Tags(['tracks', 'learning_order'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/repositories/learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/providers/learning_order_providers.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/screens/learning_order_screen.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _initialOrder = [
  LearningOrderItem(
    sefariaRef: 'Default_A',
    displayNameHe: 'א',
    displayNameEn: 'A',
    userSortOrder: 0,
  ),
  LearningOrderItem(
    sefariaRef: 'Default_B',
    displayNameHe: 'ב',
    displayNameEn: 'B',
    userSortOrder: 1,
  ),
];

/// Fake repository whose [saveOrder] / [resetToDefault] can be configured to
/// throw, so the test can exercise the failure path without a mocking
/// framework.
class _ThrowingRepository implements LearningOrderRepository {
  _ThrowingRepository({this.throwOnSave = false, this.throwOnReset = false});

  final bool throwOnSave;
  final bool throwOnReset;

  int saveCallCount = 0;
  int resetCallCount = 0;

  @override
  Future<List<LearningOrderItem>> getOrder(CurriculumId curriculumId) async =>
      _initialOrder;

  @override
  Future<void> saveOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items, {
    bool isChildRestricted = false,
  }) async {
    saveCallCount++;
    if (throwOnSave) {
      throw Exception('disk full');
    }
  }

  @override
  Future<void> resetToDefault(CurriculumId curriculumId) async {
    resetCallCount++;
    if (throwOnReset) {
      throw Exception('offline — cannot reach outbox');
    }
  }
}

List<String> _renderedOrder(WidgetTester tester) {
  return tester
      .widgetList<DraggableOrderItem>(find.byType(DraggableOrderItem))
      .map((w) => w.item.sefariaRef)
      .toList();
}

Widget _buildApp(LearningOrderRepository repo) {
  return ProviderScope(
    overrides: [
      learningOrderRepositoryProvider.overrideWithValue(repo),
      orderingRestrictedProvider.overrideWith((ref) => Future.value(false)),
      overdueCountForCurriculumProvider(
        CurriculumId.mishnayos,
      ).overrideWith((ref) async => 0),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LearningOrderScreen(curriculumId: CurriculumId.mishnayos),
    ),
  );
}

void main() {
  testWidgets(
    'reorder whose saveOrder throws surfaces a visible error and reverts '
    'the local order to its pre-reorder value',
    (tester) async {
      final repo = _ThrowingRepository(throwOnSave: true);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      expect(_renderedOrder(tester), const ['Default_A', 'Default_B']);

      final listWidget = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      listWidget.onReorderItem?.call(0, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repo.saveCallCount, 1);

      // A visible error affordance appears — the failure is not silently
      // swallowed.
      expect(find.byType(SnackBar), findsOneWidget);

      // The optimistic reorder is rolled back to what is actually persisted.
      expect(_renderedOrder(tester), const ['Default_A', 'Default_B']);
    },
  );

  testWidgets(
    'reset whose resetToDefault throws surfaces a visible error affordance '
    'and leaves the pre-reset order untouched',
    (tester) async {
      final repo = _ThrowingRepository(throwOnReset: true);

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      expect(_renderedOrder(tester), const ['Default_A', 'Default_B']);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repo.resetCallCount, 1);
      expect(find.byType(SnackBar), findsOneWidget);

      // Local state is left as-is — no clobbering by a failed reset.
      expect(_renderedOrder(tester), const ['Default_A', 'Default_B']);
    },
  );
}
