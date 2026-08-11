import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_scope_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/curriculum_scope_write_repository.dart';

/// Thrown when `firestoreCurriculumScopeRepositoryProvider` resolves to
/// `null` — see `StudyDayWriteRepositoryNotReadyException`'s doc comment
/// for the pattern this mirrors.
class CurriculumScopeWriteRepositoryNotReadyException implements Exception {
  const CurriculumScopeWriteRepositoryNotReadyException();

  @override
  String toString() =>
      'CurriculumScopeWriteRepositoryNotReadyException: '
      'firestoreCurriculumScopeRepositoryProvider resolved to null (no '
      'active account, or no active learner profile, yet) — cannot write a '
      'scope selection until one is active.';
}

/// Firestore-backed [CurriculumScopeWriteRepository] adapter.
class FirestoreCurriculumScopeWriteRepositoryAdapter
    implements CurriculumScopeWriteRepository {
  FirestoreCurriculumScopeWriteRepositoryAdapter({required Ref ref})
    : _ref = ref;

  final Ref _ref;

  Future<FirestoreCurriculumScopeRepository> _resolve() async {
    final repo = await _ref.read(
      firestoreCurriculumScopeRepositoryProvider.future,
    );
    if (repo == null) {
      throw const CurriculumScopeWriteRepositoryNotReadyException();
    }
    return repo;
  }

  @override
  Future<void> clearScopes(CurriculumId curriculumId) async {
    final repo = await _resolve();
    await repo.clearScopes(curriculumId);
  }

  @override
  Future<void> insertScopes({
    required CurriculumId curriculumId,
    required List<({int level, String value})> scopes,
  }) async {
    final repo = await _resolve();
    await repo.insertScopes(curriculumId: curriculumId, scopes: scopes);
  }
}
