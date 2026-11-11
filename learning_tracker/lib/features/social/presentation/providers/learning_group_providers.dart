import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/account_functions_provider.dart';
import 'package:learning_tracker/features/social/data/learning_group_repository.dart';
import 'package:learning_tracker/features/social/domain/learning_group.dart';

final learningGroupRepositoryProvider = Provider<LearningGroupRepository>((
  ref,
) {
  return firebaseLearningGroupRepository(ref.watch(accountFunctionsProvider));
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
