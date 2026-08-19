@Tags(['tracks', 'track_learning_order', 'p0_regression'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/tracks/track_order/presentation/providers/track_learning_order_providers.dart';
import 'package:learning_tracker/features/tracks/track_order/presentation/screens/track_learning_order_screen.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart';

import '../../../../helpers/pump_app.dart';

const _curriculumId = CurriculumId.mishnayos;

LearningOrderItem _item(String ref) => LearningOrderItem(
  sefariaRef: ref,
  displayNameHe: ref,
  displayNameEn: ref,
  userSortOrder: 0,
  isCustomOrdered: false,
);

void main() {
  testWidgets('renders reorder content returned by both order queries', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpApp(
        retry: (_, __) => null,
        overrides: [
          trackSedarimOrderProvider(
            _curriculumId,
          ).overrideWith((ref) async => [_item('Seder Zeraim')]),
          trackMasechtosOrderProvider(
            _curriculumId,
          ).overrideWith((ref) async => const []),
        ],
        child: const TrackLearningOrderScreen(curriculumId: _curriculumId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DraggableOrderItem), findsOneWidget);
  });

  testWidgets('renders an error state when an order query fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpApp(
        retry: (_, __) => null,
        overrides: [
          trackSedarimOrderProvider(_curriculumId).overrideWith((ref) async {
            throw StateError('order query failed');
          }),
          trackMasechtosOrderProvider(
            _curriculumId,
          ).overrideWith((ref) async => const []),
        ],
        child: const TrackLearningOrderScreen(curriculumId: _curriculumId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.byType(DraggableOrderItem), findsNothing);
  });
}
