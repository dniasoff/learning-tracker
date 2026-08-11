import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';

/// Whether the active profile has a programmed (parent-guided) enrollment
/// for a curriculum, vs. self-paced.
///
/// `FirestoreProfileProgramRepository`'s own class doc comment confirms
/// nothing under `lib/features/` reads it yet — this is the first reader.
/// Configuration-shaped (D-E): "no program" is [FirestoreProfileProgramRepository
/// .getProgram]'s own documented `null` case for a genuinely self-paced
/// curriculum, and a not-ready backend collapses to the same `false` a
/// brand-new profile with no programs at all would show — there is no
/// distinct "programmed" state being hidden by treating them alike.
class FirestoreProfileProgramReaderAdapter {
  FirestoreProfileProgramReaderAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  Future<bool> hasProgram(CurriculumId curriculumId) async {
    final repo = await _ref.read(firestoreProfileProgramRepositoryProvider.future);
    if (repo == null) return false;
    final program = await repo.getProgram(curriculumId);
    return program != null;
  }
}
