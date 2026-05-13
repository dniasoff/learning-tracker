import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';

/// Use case for manually marking a unit complete (siyum override).
///
/// Permission rules:
/// - Adult profile → can self-mark (markedBy = own profileId)
/// - Child profile → CANNOT self-mark (rejected with error), unless a parent
///   PIN session is active for this profile (same device session as
///   [PinGuard] with `PinScope.parent`).
/// - Parent acting on child (adult profile active) → can mark for child via
///   repository target semantics where applicable.
class ManualCompletionUseCase {
  final LearningLedgerRepository _repository;
  final int _activeProfileId;
  final String _activeProfileMode;
  final bool _parentPinSessionMatchesActiveProfile;

  ManualCompletionUseCase({
    required LearningLedgerRepository repository,
    required int activeProfileId,
    required String activeProfileMode,
    bool parentPinSessionMatchesActiveProfile = false,
  }) : _repository = repository,
       _activeProfileId = activeProfileId,
       _activeProfileMode = activeProfileMode,
       _parentPinSessionMatchesActiveProfile =
           parentPinSessionMatchesActiveProfile;

  /// Mark a unit as manually complete (siyum).
  ///
  /// Throws [ChildSelfMarkException] if a child tries to self-mark without a
  /// parent PIN session for this profile.
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

    // Permission check: child cannot self-mark without parent PIN session
    if (_activeProfileMode == 'child' &&
        !_parentPinSessionMatchesActiveProfile) {
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
