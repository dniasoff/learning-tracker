import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/text_display_screen.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTextCacheRepository extends Mock implements TextCacheRepository {}

DailyTask _readerDailyTask({required String ref, int stageOrder = 1}) {
  return DailyTask(
    curriculumId: CurriculumId.mishnayos,
    contentItemSefariaRef: ref,
    stageOrder: stageOrder,
    stageDefinitionId: stageOrder,
    priority: DailyTaskPriority.newLearning,
    isOverdue: false,
    reason: 'test',
    stageName: 'Learn',
    trackId: 1,
    trackLabel: 'Test Track',
    estimatedEffortMinutes: 5,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Reset preferences before each test
    TextDisplayPreferences.instance.reset();
  });

  Widget createTestWidget({required TextCacheRepository repository}) {
    final dailyTasks = [
      _readerDailyTask(ref: 'Mishnah Berakhot 1.1'),
      _readerDailyTask(ref: 'Mishnah Berakhot 1.2'),
    ];
    return ProviderScope(
      overrides: [
        textCacheRepositoryProvider.overrideWithValue(repository),
        allDailyTasksProvider.overrideWith((ref) => Future.value(dailyTasks)),
        trackStorageKeyForTrackIdProvider.overrideWith(
          (ref, trackId) async => TrackType.personal.storageKey,
        ),
        isStageCompletedProvider.overrideWith((ref, params) async => false),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: Size(800, 1200)),
          child: TextDisplayScreen(sefariaRef: 'Mishnah Berakhot 1.1'),
        ),
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
        TextContent.single(
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
        return TextContent.single(
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
      expect(hebrewTextWidget.textAlign, TextAlign.start);
    });

    testWidgets('displays English text below Hebrew text', (tester) async {
      const hebrewText = 'מֵאֵימָתַי';
      const englishText = 'From when may one recite';
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async {
        return TextContent.single(
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

    testWidgets(
      'shows offline message with download button when text is not cached',
      (tester) async {
        final mockRepo = MockTextCacheRepository();
        when(() => mockRepo.getText(any())).thenAnswer((_) async => null);

        await tester.pumpWidget(createTestWidget(repository: mockRepo));
        await tester.pumpAndSettle();

        expect(find.text('Text not available'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      },
    );

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

    testWidgets('displays reader section labels', (tester) async {
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async {
        return TextContent.single(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: 'hebrew',
          englishText: 'english',
        );
      });

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      expect(find.text('Hebrew Text'), findsOneWidget);
      expect(find.text('English Translation'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    });

    testWidgets('displays mark completion section', (tester) async {
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async {
        return TextContent.single(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: 'hebrew',
          englishText: 'english',
        );
      });

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      // Scroll to bottom to ensure completion section is visible
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      // Verify mark completion and optional next-task navigation
      expect(find.text('Mark Complete'), findsOneWidget);
      expect(find.text('Next daily task'), findsOneWidget);
    });

    testWidgets('shows sefariaRef in AppBar title', (tester) async {
      final mockRepo = MockTextCacheRepository();
      when(() => mockRepo.getText(any())).thenAnswer((_) async {
        return TextContent.single(
          sefariaRef: 'Mishnah Berakhot 1.1',
          hebrewText: 'hebrew',
          englishText: 'english',
        );
      });

      await tester.pumpWidget(createTestWidget(repository: mockRepo));
      await tester.pumpAndSettle();

      expect(find.text('Mishnah Berakhot 1.1'), findsOneWidget);
    });
  });
}
