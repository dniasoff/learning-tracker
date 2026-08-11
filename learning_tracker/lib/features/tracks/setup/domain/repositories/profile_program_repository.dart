import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';

/// Abstract repository for a curriculum's programmed-enrollment assignment
/// (e.g. "this Daf Yomi track follows the standard cycle, anchored at
/// 2026-01-01").
///
/// `null` from [getProgram] means self-paced -- no program assigned -- the
/// same convention `FirestoreProfileProgramRepository.getProgram` (and its
/// Drift-era predecessor, `ProfileProgramDao.getProgramForProfileAndCurriculum`)
/// already use. Configuration-shaped (D-E): a not-ready backend and a
/// genuinely self-paced curriculum collapse to the same `null` here, since
/// there is no distinct "programmed" state being hidden by treating them
/// alike -- see `FirestoreProfileProgramReaderAdapter`'s doc comment
/// (features/dashboard/data/repositories/) for the read-only sibling this
/// mirrors.
abstract class ProfileProgramRepository {
  Future<ProfileProgramEntity?> getProgram(CurriculumId curriculumId);

  /// Assigns [curriculumId] to [programId], optionally anchoring tracking at
  /// [trackingStartDate]/[trackingStartRef] (e.g. "start counting from
  /// today's calendar unit" -- used by the Clear Overdue recovery action).
  Future<void> setProgram({
    required CurriculumId curriculumId,
    required int programId,
    DateTime? trackingStartDate,
    String? trackingStartRef,
  });
}
