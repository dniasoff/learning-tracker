import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/firestore_gateway_impl.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/providers/firestore_instance_provider.dart';
import 'package:learning_tracker/core/sync/push_pipeline_impl.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';

/// Provider for [FirestoreGatewayImpl].
///
/// Returns null when the user is not cloud-born (matches the tier-gate
/// pattern used in [syncEngineProvider]).
final firestoreGatewayProvider = Provider<FirestoreGatewayImpl?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (!authState.isCloudBorn) return null;

  final firestore = ref.watch(firebaseFirestoreProvider);
  final auth = ref.watch(authRepositoryProvider);

  return FirestoreGatewayImpl(firestore: firestore, authRepository: auth);
});

/// Provider for [OutboxPushPipeline].
///
/// Returns null when the user is not cloud-born or the gateway is unavailable.
final outboxPushPipelineProvider = Provider<OutboxPushPipeline?>((ref) {
  final gateway = ref.watch(firestoreGatewayProvider);
  if (gateway == null) return null;

  return OutboxPushPipeline(gateway: gateway);
});

/// Provider for [OutboxProcessor].
///
/// Returns null when the user is not cloud-born or the pipeline is unavailable.
final outboxProcessorProvider = Provider<OutboxProcessor?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (!authState.isCloudBorn) return null;

  final pipeline = ref.watch(outboxPushPipelineProvider);
  if (pipeline == null) return null;

  final database = ref.watch(userDatabaseProvider);

  final clock = ref.watch(localDayClockProvider);
  // W7.7: inject analytics so OutboxProcessor fires outbox_dead_lettered.
  final analytics = ref.watch(analyticsServiceProvider);
  return OutboxProcessor(
    outboxDao: database.outboxDao,
    pipeline: pipeline,
    clock: clock,
    analytics: analytics,
  );
});
