import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/providers/learning_order_providers.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/screens/learning_order_screen.dart';
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
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LearningOrderScreen(curriculumId: CurriculumId.mishnayos),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('AppBar title is fully localized under Hebrew locale — '
        'no hardcoded ASCII "Order" suffix [AUD-tracks-02]', (tester) async {
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
          child: const MaterialApp(
            locale: Locale('he'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LearningOrderScreen(curriculumId: CurriculumId.mishnayos),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleWidget = tester.widget<AppBarTitle>(find.byType(AppBarTitle));
      expect(titleWidget.text, isNotNull);
      expect(
        titleWidget.text,
        isNot(contains('Order')),
        reason:
            'AppBar title must come entirely from AppLocalizations; '
            'the hardcoded English "Order" suffix must not leak into '
            'the Hebrew-locale UI.',
      );
    });
  });
}
