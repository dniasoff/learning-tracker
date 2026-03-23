import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';

void main() {
  group('BulkMarkScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scopedFilteredContentProvider.overrideWith(
              (ref, params) => Future.value([]),
            ),
            curriculumHierarchyConfigProvider.overrideWith(
              (ref, curriculumId) => Future.value(
                const CurriculumHierarchyConfig(
                  curriculumId: 'mishnayos',
                  levelLabels: [],
                  totalItems: 0,
                ),
              ),
            ),
            contentSearchProvider.overrideWith((ref, args) => Future.value([])),
          ],
          child: const MaterialApp(
            home: BulkMarkScreen(curriculumId: CurriculumId.mishnayos),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
