import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  group('BulkMarkScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            curriculumContentProvider.overrideWith(
              (ref, curriculumId) => Future.value([]),
            ),
            contentSearchProvider.overrideWith((ref, args) => Future.value([])),
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
  });
}
