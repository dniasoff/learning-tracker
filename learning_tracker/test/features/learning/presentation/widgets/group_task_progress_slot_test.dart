import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/learn_slots/group_task_progress_slot.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/social/domain/learning_group.dart';
import 'package:learning_tracker/features/social/presentation/providers/learning_group_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class _TestSelectedProfileId extends SelectedProfileId {
  @override
  String? build() => 'profile-a';
}

void main() {
  testWidgets('shows group task progress in Learn for visible member shares', (
    tester,
  ) async {
    const profileId = 'profile-a';
    const onDate = '2026-11-11';
    final task = LearningGroupTaskCard(
      taskId: 'task-1',
      taskName: 'Tamid',
      curriculumId: 'mishnayos',
      status: 'published',
      memberState: 'accepted',
      scopeUnits: const [],
      allocationMembers: const [
        {
          'memberId': 'member-1',
          'displayName': 'Ari',
          'units': [],
          'dailyTasks': [],
          'progress': {'completed': 2, 'total': 5},
        },
      ],
      joinRequests: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedProfileIdProvider.overrideWith(_TestSelectedProfileId.new),
          localDayClockProvider.overrideWithValue(
            FakeLocalDayClock(DateTime(2026, 11, 11)),
          ),
          groupTaskProgressForLearnProvider((
            profileId: profileId,
            onDate: onDate,
          )).overrideWith(
            (ref) async => [(groupName: 'Family study', task: task)],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: GroupTaskProgressSlot()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Group task progress'), findsOneWidget);
    expect(find.text('Family study · Tamid'), findsOneWidget);
    expect(find.text('Ari: 2 of 5 units complete'), findsOneWidget);
  });

  testWidgets('keeps the Learn slot empty when there are no group tasks', (
    tester,
  ) async {
    const profileId = 'profile-a';
    const onDate = '2026-11-11';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedProfileIdProvider.overrideWith(_TestSelectedProfileId.new),
          localDayClockProvider.overrideWithValue(
            FakeLocalDayClock(DateTime(2026, 11, 11)),
          ),
          groupTaskProgressForLearnProvider((
            profileId: profileId,
            onDate: onDate,
          )).overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: GroupTaskProgressSlot()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Group task progress'), findsNothing);
  });
}
