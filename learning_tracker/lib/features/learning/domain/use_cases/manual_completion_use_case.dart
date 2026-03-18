import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';

/// Use case for manually marking a unit complete (siyum override).
///
/// Permission rules:
/// - Adult profile → can self-mark (markedBy = own profileId)
/// - Child profile → CANNOT self-mark (rejected with error)
/// - Parent/tutor mode → can mark for any child profile
class ManualCompletionUseCase {
  final LearningLedgerRepository _repository;
  final int _activeProfileId;
  final String _activeProfileMode;

  ManualCompletionUseCase({
    required LearningLedgerRepository repository,
    required int activeProfileId,
    required String activeProfileMode,
  }) : _repository = repository,
       _activeProfileId = activeProfileId,
       _activeProfileMode = activeProfileMode;

  /// Mark a unit as manually complete (siyum).
  ///
  /// Throws [ChildSelfMarkException] if a child tries to self-mark.
  Future<LearningLedgerData> call({
    required String curriculumId,
    required String unitType,
    required String unitIdentifier,
    required String unitDisplayNameHe,
    required String unitDisplayNameEn,
    required String trackType,
    int? trackId,
    int? targetProfileId,
  }) async {
    // Determine who is being marked
    final markedBy = _activeProfileId;

    // Permission check: child cannot self-mark
    if (_activeProfileMode == 'child') {
      throw const ChildSelfMarkException();
    }

    return _repository.recordCompletion(
      curriculumId: curriculumId,
      unitType: unitType,
      unitIdentifier: unitIdentifier,
      unitDisplayNameHe: unitDisplayNameHe,
      unitDisplayNameEn: unitDisplayNameEn,
      trackType: trackType,
      trackId: trackId,
      markedBy: markedBy,
      isManual: true,
    );
  }
}
