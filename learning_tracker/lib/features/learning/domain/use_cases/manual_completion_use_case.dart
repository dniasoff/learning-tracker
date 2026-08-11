import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
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
  final String? _activeProfileId;
  final ProfileMode _activeProfileMode;
  final bool _parentPinSessionMatchesActiveProfile;

  ManualCompletionUseCase({
    required LearningLedgerRepository repository,
    required String? activeProfileId,
    required ProfileMode activeProfileMode,
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
  Future<LearningLedgerEntry> call({
    required CurriculumId curriculumId,
    required String entryScope,
    required String unitIdentifier,
    required String unitDisplayNameHe,
    required String unitDisplayNameEn,
    required String trackType,
  }) async {
    // Permission check: child cannot self-mark without parent PIN session
    if (_activeProfileMode.isChild && !_parentPinSessionMatchesActiveProfile) {
      throw const ChildSelfMarkException();
    }

    return _repository.recordCompletion(
      curriculumId: curriculumId,
      entryScope: entryScope,
      unitIdentifier: unitIdentifier,
      unitDisplayNameHe: unitDisplayNameHe,
      unitDisplayNameEn: unitDisplayNameEn,
      trackType: trackType,
      // markedBy omitted when null — LearningLedgerRepository.recordCompletion
      // stamps the active profile itself in that case (see its own doc
      // comment). _activeProfileId is only ever passed explicitly to
      // preserve today's behaviour for the (unusual) case a caller already
      // resolved a specific ULID.
      markedBy: _activeProfileId,
      isManual: true,
    );
  }
}
