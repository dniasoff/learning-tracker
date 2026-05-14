import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

/// Coordinates pull-on-launch using the new core/sync/ subsystem.
///
/// Replaces the equivalent method on [SyncEngine] so call-sites can migrate to
/// this leaner interface without depending on the monolithic [SyncEngine].
///
/// Phase 3: pullOnLaunch. Future phases will add pushAllLocalData and remove
/// the internal delegation to [SyncEngine] as individual merge paths are
/// decomposed into [PullPipeline] + [MergeRouter].
abstract class SyncOrchestrator {
  /// Replicate SyncEngine.pullOnLaunch().
  ///
  /// When [triggeredFromResume] is true, the pull is skipped when the last
  /// successful pull was within [SyncEngine.pullOnResumeMinInterval].
  Future<void> pullOnLaunch({bool triggeredFromResume = false});

  /// The current sync status — delegates to the underlying engine.
  ///
  /// Exposed so callers that previously read [SyncEngine.currentStatus] after a
  /// pull (e.g. [DeviceRestoreService]) can switch to this interface without
  /// needing a direct [SyncEngine] reference.
  SyncStatus get currentStatus;
}

/// Concrete implementation that delegates to [SyncEngine].
///
/// The internal delegation to [SyncEngine.pullOnLaunch] is intentional and
/// temporary: the full merge decomposition (goals, ledger entries, notification
/// settings, etc.) is out-of-scope for Phase 3. Once all entity mergers exist
/// in the [MergeRouter], this class will drive [PullPipeline] directly and
/// [SyncEngine] can be retired.
class SyncOrchestratorImpl implements SyncOrchestrator {
  SyncOrchestratorImpl({required SyncEngine engine}) : _engine = engine;

  final SyncEngine _engine;

  @override
  Future<void> pullOnLaunch({bool triggeredFromResume = false}) =>
      _engine.pullOnLaunch(triggeredFromResume: triggeredFromResume);

  @override
  SyncStatus get currentStatus => _engine.currentStatus;
}
