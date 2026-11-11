import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/data/learning_group_repository.dart';
import 'package:learning_tracker/features/social/domain/learning_group.dart';
import 'package:learning_tracker/features/social/presentation/widgets/group_tasks_section.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  testWidgets('shows an empty state when the group has no tasks', (
    tester,
  ) async {
    final repository = LearningGroupRepository(
      (name, data) async => <Object?>[],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GroupTasksSection(
              group: const LearningGroupDetails(
                groupId: 'group-1',
                name: 'Family study',
                groupType: 'private',
                role: 'member',
                members: [],
              ),
              profileId: 'profile-1',
              parentSessionId: null,
              repository: repository,
              onError: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Group tasks'), findsOneWidget);
    expect(find.text('No group tasks yet'), findsOneWidget);
  });
}
