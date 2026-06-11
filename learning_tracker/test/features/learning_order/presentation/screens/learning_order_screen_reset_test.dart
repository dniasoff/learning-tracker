import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/repositories/learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/providers/learning_order_providers.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/screens/learning_order_screen.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _custom = [
  LearningOrderItem(
    sefariaRef: 'Custom_C',
    displayNameHe: 'ג',
    displayNameEn: 'C',
    userSortOrder: 0,
    isCustomOrdered: true,
  ),
  LearningOrderItem(
    sefariaRef: 'Custom_A',
    displayNameHe: 'א',
    displayNameEn: 'A',
    userSortOrder: 1,
    isCustomOrdered: true,
  ),
];

const _default = [
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

/// Fake repository where each [getOrder] call returns a future completed by the
/// test, so the test controls *when* and in *what order* reads resolve. This
/// lets us model the documented race: a stale (custom-order) read that is still
/// in flight when the reset happens, resolving *after* the reset's own read.
class _ControlledRepository implements LearningOrderRepository {
  final List<Completer<List<LearningOrderItem>>> pendingReads = [];
  bool wasReset = false;

  @override
  Future<List<LearningOrderItem>> getOrder(CurriculumId curriculumId) {
    final completer = Completer<List<LearningOrderItem>>();
    pendingReads.add(completer);
    return completer.future;
  }

  @override
  Future<void> resetToDefault(CurriculumId curriculumId) async {
    wasReset = true;
  }

  @override
  Future<void> saveOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items, {
    bool isChildRestricted = false,
  }) async {}
}

List<String> _renderedOrder(WidgetTester tester) {
  return tester
      .widgetList<DraggableOrderItem>(find.byType(DraggableOrderItem))
      .map((w) => w.item.sefariaRef)
      .toList();
}

void main() {
  testWidgets(
    'reset → list reliably reflects the default order even when a stale '
    'custom-order read resolves after the reset',
    (tester) async {
      final repo = _ControlledRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learningOrderRepositoryProvider.overrideWithValue(repo),
            orderingRestrictedProvider.overrideWith(
              (ref) => Future.value(false),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LearningOrderScreen(curriculumId: CurriculumId.mishnayos),
          ),
        ),
      );
      await tester.pump();

      // Resolve the initial read with the custom order.
      expect(repo.pendingReads, hasLength(1));
      repo.pendingReads[0].complete(_custom);
      await tester.pumpAndSettle();
      expect(_renderedOrder(tester), const ['Custom_C', 'Custom_A']);

      // Tap reset and confirm. The reset handler invalidates the provider,
      // which kicks off a fresh read (pendingReads[1]).
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pump();

      expect(repo.wasReset, isTrue);
      expect(repo.pendingReads, hasLength(2));

      // The post-reset read resolves with the default order.
      repo.pendingReads[1].complete(_default);
      await tester.pumpAndSettle();

      // The UI must show the default order — deterministically.
      expect(_renderedOrder(tester), const ['Default_A', 'Default_B']);
    },
  );
}
