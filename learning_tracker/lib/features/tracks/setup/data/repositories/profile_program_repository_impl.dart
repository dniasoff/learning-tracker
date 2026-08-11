import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';

/// Thrown by [FirestoreProfileProgramRepositoryAdapter.setProgram] when
/// `firestoreProfileProgramRepositoryProvider` resolves to `null` -- see
/// `StageDefinitionRepositoryNotReadyException`'s doc comment
/// (stage_definition_repository_impl.dart) for the read-vs-write split this
/// mirrors: [getProgram] reuses the interface's own `null` "no program yet"
/// value, [setProgram] has no such value and throws instead.
class ProfileProgramRepositoryNotReadyException implements Exception {
  const ProfileProgramRepositoryNotReadyException();

  @override
  String toString() =>
      'ProfileProgramRepositoryNotReadyException: '
      'firestoreProfileProgramRepositoryProvider resolved to null (no '
      'active account, or no active learner profile, yet) — cannot assign '
      'a program until one is active.';
}

/// Firestore-backed [ProfileProgramRepository] adapter -- write-capable
/// sibling of `FirestoreProfileProgramReaderAdapter`
/// (features/dashboard/data/repositories/, read-only). Lives under
/// features/tracks/setup/ rather than features/dashboard/ because
/// [setProgram] is a tracks/setup-owned mutation (track creation, track
/// edit, and the Clear Overdue recovery action all call it), not a
/// dashboard read.
class FirestoreProfileProgramRepositoryAdapter
    implements ProfileProgramRepository {
  FirestoreProfileProgramRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  @override
  Future<ProfileProgramEntity?> getProgram(CurriculumId curriculumId) async {
    final repo = await _ref.read(firestoreProfileProgramRepositoryProvider.future);
    if (repo == null) return null;
    return repo.getProgram(curriculumId);
  }

  @override
  Future<void> setProgram({
    required CurriculumId curriculumId,
    required int programId,
    DateTime? trackingStartDate,
    String? trackingStartRef,
  }) async {
    final repo = await _ref.read(firestoreProfileProgramRepositoryProvider.future);
    if (repo == null) {
      throw const ProfileProgramRepositoryNotReadyException();
    }
    await repo.setProgram(
      curriculumId: curriculumId,
      programId: programId,
      trackingStartDate: trackingStartDate,
      trackingStartRef: trackingStartRef,
    );
  }
}
