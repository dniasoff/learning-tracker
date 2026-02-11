import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/text_display_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTextCacheRepository extends Mock implements TextCacheRepository {}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Reset preferences before each test
    TextDisplayPreferences.instance.reset();
  });

  Widget createTestWidget({required TextCacheRepository repository}) {
    return ProviderScope(
      overrides: [textCacheRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
        home: TextDisplayScreen(sefariaRef: 'Mishnah Berakhot 1.1'),
      ),
    );
  }

  group('TextDisplayScreen', () {
    testWidgets('shows loading state while fetching text', (tester) async {
      final completer = Completer<TextContent?>();
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) => completer.future);

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading text...'), findsOneWidget);

      // Complete the future to avoid pending timers
      completer.complete(
        TextContent(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: 'hebrew',
          englishText: 'english',
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('displays Hebrew text with RTL directionality', (tester) async {
      const hebrewText = 'מֵאֵימָתַי קוֹרִין אֶת שְׁמַע';
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async {
        return TextContent(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: hebrewText,
          englishText: 'English text',
        );
      });

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Find Hebrew text widget
      final hebrewTextWidget = tester.widget<Text>(find.text(hebrewText));

      // Verify RTL directionality
      expect(hebrewTextWidget.textDirection, TextDirection.rtl);
      expect(hebrewTextWidget.textAlign, TextAlign.right);
    });

    testWidgets('displays English text below Hebrew text', (tester) async {
      const hebrewText = 'מֵאֵימָתַי';
      const englishText = 'From when may one recite';
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async {
        return TextContent(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: hebrewText,
          englishText: englishText,
        );
      });

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Both texts should be visible
      expect(find.text(hebrewText), findsOneWidget);
      expect(find.text(englishText), findsOneWidget);

      // Hebrew should appear before English (higher in the tree)
      final hebrewPos = tester.getTopLeft(find.text(hebrewText));
      final englishPos = tester.getTopLeft(find.text(englishText));
      expect(hebrewPos.dy, lessThan(englishPos.dy));
    });

    testWidgets('shows offline message when text is not cached', (
      tester,
    ) async {
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      expect(find.text('Text content not yet downloaded'), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);
    });

    testWidgets('shows error view when provider throws', (tester) async {
      final mockRepo = MockTextCacheRepository();
      when(
        () => mockRepo.getText(any()),
      ).thenThrow(Exception('Database corrupted'));

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load text'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('displays Sefaria attribution', (tester) async {
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async {
        return TextContent(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: 'hebrew',
          englishText: 'english',
        );
      });

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      expect(find.text('Content from Sefaria'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book), findsOneWidget);
    });

    testWidgets('displays mark completion buttons', (tester) async {
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async {
        return TextContent(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: 'hebrew',
          englishText: 'english',
        );
      });

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Scroll to bottom to ensure buttons are visible
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      // Verify button texts are present
      expect(find.text('Mark as Reviewed'), findsOneWidget);
      expect(find.text('Mark Complete'), findsOneWidget);
    });

    testWidgets('font size selector opens popup menu', (tester) async {
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async {
        return TextContent(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: 'hebrew',
          englishText: 'english',
        );
      });

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Tap font size icon
      await tester.tap(find.byIcon(Icons.text_fields));
      await tester.pumpAndSettle();

      // Should show all font size options
      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);
    });

    testWidgets('font size selector updates text size', (tester) async {
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async {
        return TextContent(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: 'hebrew',
          englishText: 'english',
        );
      });

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Get initial font size
      final initialHebrew = tester.widget<Text>(find.text('hebrew'));
      final initialSize = initialHebrew.style!.fontSize!;

      // Open menu and select Large
      await tester.tap(find.byIcon(Icons.text_fields));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();

      // Font size should increase
      final updatedHebrew = tester.widget<Text>(find.text('hebrew'));
      final updatedSize = updatedHebrew.style!.fontSize!;
      expect(updatedSize, greaterThan(initialSize));
    });

    testWidgets('shows sefariaRef in AppBar title', (tester) async {
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async {
        return TextContent(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: 'hebrew',
          englishText: 'english',
        );
      });

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      expect(find.text('Mishnah Berakhot 1.1'), findsOneWidget);
    });

    testWidgets('shows nikud toggle button in app bar', (tester) async {
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async {
        return TextContent(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: 'hebrew',
          englishText: 'english',
        );
      });

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Default is nikud ON, so toggle shows format_clear icon
      expect(find.byIcon(Icons.format_clear), findsOneWidget);

      // When nikud is ON (default), the font size button uses text_fields
      // and the nikud toggle uses format_clear, so there's exactly one
      // text_fields widget (the font size selector)
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
    });

    testWidgets('nikud toggle strips vowel marks from Hebrew text', (
      tester,
    ) async {
      const hebrewWithNikud =
          '\u05DE\u05B5\u05D0\u05B5\u05D9\u05DE\u05B8\u05EA\u05B7\u05D9';
      const hebrewWithoutNikud = '\u05DE\u05D0\u05D9\u05DE\u05EA\u05D9';

      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async {
        return TextContent(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: hebrewWithNikud,
          englishText: 'From when',
        );
      });

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Default: nikud is ON, text shown with vowel marks
      expect(find.text(hebrewWithNikud), findsOneWidget);

      // Tap the nikud toggle (format_clear when nikud is ON)
      await tester.tap(find.byIcon(Icons.format_clear));
      await tester.pumpAndSettle();

      // After toggle: nikud stripped, showing text without vowel marks
      expect(find.text(hebrewWithoutNikud), findsOneWidget);
      expect(find.text(hebrewWithNikud), findsNothing);
    });
  });
}
