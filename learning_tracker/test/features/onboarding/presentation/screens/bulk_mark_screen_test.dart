import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';

void main() {
  group('BulkMarkScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filteredContentProvider(
              curriculumId: CurriculumId.mishnayos,
            ).overrideWith((ref) => Future.value([])),
            curriculumHierarchyConfigProvider(
              CurriculumId.mishnayos,
            ).overrideWith(
              (ref) => Future.value(
                const CurriculumHierarchyConfig(
                  curriculumId: 'mishnayos',
                  levelLabels: [],
                  totalItems: 0,
                ),
              ),
            ),
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
