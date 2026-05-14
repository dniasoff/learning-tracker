import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_search_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  group('ContentSearchScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ContentSearchScreen(curriculumId: 'mishnayos'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
