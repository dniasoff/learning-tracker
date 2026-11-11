import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/domain/social_summary.dart';
import 'package:learning_tracker/features/social/presentation/providers/social_providers.dart';
import 'package:learning_tracker/features/social/presentation/screens/social_summary_profile_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  testWidgets('renders only the sanitized summary fields', (tester) async {
    final summaryId = List.filled(64, 'a').join();
    final summary = SocialSummary(
      displayName: 'Learner',
      avatarId: 1,
      streak: const SocialStreakProjection(byCurriculum: []),
      currentTracks: const [],
      weeklyLearning: const SocialWeeklyLearningProjection(
        weekStart: '2026-11-08',
        byCurriculum: [],
      ),
      siyumim: const [],
      computedAt: DateTime.utc(2026, 11, 10),
      schemaVersion: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          socialSummaryProvider(summaryId).overrideWith((ref) async => summary),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SocialSummaryProfileScreen(summaryId: summaryId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learner'), findsOneWidget);
    expect(find.textContaining('Week of'), findsOneWidget);
    expect(find.text('Siyumim'), findsOneWidget);
    expect(find.textContaining('points'), findsNothing);
  });
}
