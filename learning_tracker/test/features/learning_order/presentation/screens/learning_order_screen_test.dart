import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning_order/presentation/providers/learning_order_providers.dart';
import 'package:learning_tracker/features/learning_order/presentation/screens/learning_order_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  group('LearningOrderScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learningOrderProvider(
              CurriculumId.mishnayos,
            ).overrideWith((ref) => Future.value([])),
            orderingRestrictedProvider.overrideWith(
              (ref) => Future.value(false),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LearningOrderScreen(
              curriculumId: CurriculumId.mishnayos,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
