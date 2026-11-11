import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/account_functions_provider.dart';
import 'package:learning_tracker/core/providers/active_account_firebase_provider.dart';
import 'package:learning_tracker/data/repositories/firestore_social_summary_repository.dart';
import 'package:learning_tracker/features/social/data/social_graph_repository.dart';
import 'package:learning_tracker/features/social/domain/social_graph.dart';
import 'package:learning_tracker/features/social/domain/social_summary.dart';

final socialGraphRepositoryProvider = Provider<SocialGraphRepository>((ref) {
  final resolveFunctions = ref.watch(accountFunctionsProvider);
  return SocialGraphRepository(firebaseSocialCallableInvoker(resolveFunctions));
});

final socialConnectionsProvider = FutureProvider.autoDispose
    .family<SocialConnections, ({String profileId, String? parentSessionId})>(
      (ref, query) => ref
          .watch(socialGraphRepositoryProvider)
          .listConnections(
            query.profileId,
            parentSessionId: query.parentSessionId,
          ),
    );

final socialChildControlsProvider = FutureProvider.autoDispose
    .family<SocialChildControls, ({String profileId, String parentSessionId})>(
      (ref, query) => ref
          .watch(socialGraphRepositoryProvider)
          .getChildControls(
            profileId: query.profileId,
            parentSessionId: query.parentSessionId,
          ),
    );

final socialSummaryProvider = FutureProvider.autoDispose
    .family<SocialSummary?, String>((ref, summaryId) async {
      // Recheck server-side grants while a profile stays open so remote
      // revocation clears the local value without serving Firestore cache.
      final refresh = Timer(const Duration(seconds: 20), ref.invalidateSelf);
      ref.onDispose(refresh.cancel);
      final handles = await ref.watch(activeAccountFirebaseProvider.future);
      if (handles == null) return null;
      return FirestoreSocialSummaryRepository(
        handles.firestore,
      ).read(summaryId);
    });
