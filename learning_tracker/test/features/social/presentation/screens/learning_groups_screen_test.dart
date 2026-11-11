import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/domain/learning_group.dart';
import 'package:learning_tracker/features/social/presentation/providers/learning_group_providers.dart';
import 'package:learning_tracker/features/social/presentation/screens/learning_groups_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  testWidgets('lists groups for the selected adult profile', (tester) async {
    const groupQuery = (profileId: 'adult-profile', parentSessionId: null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learningGroupsProvider(groupQuery).overrideWith(
            (ref) async => const [
              LearningGroupSummary(
                groupId: 'group-12345678',
                name: 'Family study',
                groupType: 'private',
                role: 'member',
                memberCount: 3,
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LearningGroupsScreen(profileId: 'adult-profile', isAdult: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Family study'), findsOneWidget);
  });
}
