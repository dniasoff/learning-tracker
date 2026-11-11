import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/account_functions_provider.dart';
import 'package:learning_tracker/features/social/data/school_repository.dart';
import 'package:learning_tracker/features/social/domain/school.dart';

final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  return SchoolRepository(
    firebaseSchoolCallableInvoker(ref.watch(accountFunctionsProvider)),
  );
});

final schoolProfileProvider = FutureProvider.autoDispose
    .family<SchoolProfile, String>(
      (ref, schoolId) =>
          ref.watch(schoolRepositoryProvider).getProfile(schoolId),
    );

final schoolMembershipsProvider = FutureProvider.autoDispose
    .family<
      List<SchoolMembership>,
      ({String profileId, String? parentSessionId})
    >(
      (ref, query) => ref
          .watch(schoolRepositoryProvider)
          .listMine(
            profileId: query.profileId,
            parentSessionId: query.parentSessionId,
          ),
    );

final schoolRosterProvider = FutureProvider.autoDispose
    .family<List<SchoolRosterEntry>, ({String schoolId, int limit})>(
      (ref, query) => ref
          .watch(schoolRepositoryProvider)
          .listRoster(schoolId: query.schoolId, limit: query.limit),
    );
