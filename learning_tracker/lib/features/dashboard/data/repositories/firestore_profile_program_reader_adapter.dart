import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/profile_program_repository_impl.dart'
    show ProfileProgramRepositoryNotReadyException;

/// Whether the active profile has a programmed (parent-guided) enrollment
/// for a curriculum, vs. self-paced.
///
/// `FirestoreProfileProgramRepository`'s own class doc comment confirms
/// nothing under `lib/features/` reads it yet — this is the first reader.
/// A missing program is a valid result once ready; a not-ready backend throws
/// so it cannot be mistaken for a genuinely self-paced curriculum.
class FirestoreProfileProgramReaderAdapter {
  FirestoreProfileProgramReaderAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  Future<bool> hasProgram(CurriculumId curriculumId) async {
    final repo = await _ref.read(
      firestoreProfileProgramRepositoryProvider.future,
    );
    if (repo == null) {
      throw const ProfileProgramRepositoryNotReadyException();
    }
    final program = await repo.getProgram(curriculumId);
    return program != null;
  }
}
