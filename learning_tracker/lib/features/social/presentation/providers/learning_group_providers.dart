import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/account_functions_provider.dart';
import 'package:learning_tracker/features/social/data/learning_group_repository.dart';
import 'package:learning_tracker/features/social/domain/learning_group.dart';

final learningGroupRepositoryProvider = Provider<LearningGroupRepository>((
  ref,
) {
  return firebaseLearningGroupRepository(ref.watch(accountFunctionsProvider));
});

final groupTaskProgressForLearnProvider = FutureProvider.autoDispose
    .family<
      List<({String groupName, LearningGroupTaskCard task})>,
      ({String profileId, String onDate})
    >((ref, query) async {
      final repository = ref.watch(learningGroupRepositoryProvider);
      await repository.reconcileDailyTasks(
        profileId: query.profileId,
        onDate: query.onDate,
      );
      final groups = await repository.listMine(profileId: query.profileId);
      final result = <({String groupName, LearningGroupTaskCard task})>[];
      for (final group in groups) {
        final tasks = await repository.listTasks(
          groupId: group.groupId,
          profileId: query.profileId,
        );
        for (final task in tasks) {
          if (task.status == 'published') {
            result.add((groupName: group.name, task: task));
          }
        }
      }
      return List.unmodifiable(result);
    });

final learningGroupsProvider = FutureProvider.autoDispose
    .family<
      List<LearningGroupSummary>,
      ({String profileId, String? parentSessionId})
    >(
      (ref, query) => ref
          .watch(learningGroupRepositoryProvider)
          .listMine(
            profileId: query.profileId,
            parentSessionId: query.parentSessionId,
          ),
    );

final groupApprovalsProvider = FutureProvider.autoDispose
    .family<
      List<GroupParentApproval>,
      ({String profileId, String parentSessionId})
    >(
      (ref, query) => ref
          .watch(learningGroupRepositoryProvider)
          .listApprovals(
            profileId: query.profileId,
            parentSessionId: query.parentSessionId,
          ),
    );
