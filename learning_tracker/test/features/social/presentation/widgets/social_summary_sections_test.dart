import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/features/social/domain/social_summary.dart';
import 'package:learning_tracker/features/social/domain/social_summary_visibility.dart';
import 'package:learning_tracker/features/social/presentation/widgets/social_summary_sections.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'shows curriculum position and rendered siyum ref like the follower profile',
    (tester) async {
      final summary = SocialSummary(
        displayName: 'Preview',
        avatarId: 0,
        currentTracks: const [
          SocialCurrentTrackSummary(
            curriculumId: 'mishnayos',
            positionRef: 'Berakhot 4',
          ),
        ],
        siyumim: const [
          SocialSiyumSummary(
            curriculumId: 'mishnayos',
            ref: 'Berakhot',
            level: 'masechta',
          ),
        ],
        computedAt: DateTime.utc(2026, 11, 10),
        schemaVersion: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            renderedDisplayForRefProvider(
              'Berakhot 4',
            ).overrideWith((ref) async => 'Rendered position: Berakhot 4'),
            renderedDisplayForRefProvider(
              'Berakhot',
            ).overrideWith((ref) async => 'Rendered siyum: Berakhot'),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SocialSummarySections(
                summary: summary,
                visibility: const SocialSummaryVisibility.allOn(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rendered position: Berakhot 4'), findsOneWidget);
      expect(find.text('Rendered siyum: Berakhot'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(ListTile).first,
          matching: find.byType(Text),
        ),
        findsWidgets,
      );
    },
  );
}
