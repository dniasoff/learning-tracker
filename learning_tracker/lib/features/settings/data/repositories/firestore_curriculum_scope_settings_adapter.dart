import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_scope.dart';

/// Thrown by [FirestoreCurriculumScopeSettingsAdapter]'s write methods when
/// `firestoreCurriculumScopeRepositoryProvider` resolves to `null` — see
/// `FirestoreCurriculumScopeWriteRepositoryAdapter`'s doc comment (tracks/
/// setup) for the resolve/throw pattern this mirrors.
class CurriculumScopeSettingsNotReadyException implements Exception {
  const CurriculumScopeSettingsNotReadyException();

  @override
  String toString() =>
      'CurriculumScopeSettingsNotReadyException: '
      'firestoreCurriculumScopeRepositoryProvider resolved to null (no '
      'active account, or no active learner profile, yet) — cannot read or '
      'write a scope selection until one is active.';
}

/// Feature-scoped adapter over [FirestoreCurriculumScopeRepository] for the
/// Settings feature's own curriculum-scope screens — presentation/**
/// (curriculum_scope_providers.dart, scope_selection_screen.dart) cannot
/// reach `lib/data/firestore/repository_providers.dart` directly
/// (AD-23/AD-28); this file's own path (`.../data/repositories/`) is the
/// sanctioned seam. Distinct from `features/tracks/setup`'s
/// `FirestoreCurriculumScopeWriteRepositoryAdapter` (write-only, no reads)
/// because AD-23/AD-28 forbids cross-feature imports outside a barrel file —
/// each feature that touches this collection gets its own thin adapter over
/// the same underlying repository.
///
/// Reads are configuration-shaped (D-E): "which parts of a curriculum are
/// tracked" legitimately defaults to "the whole curriculum" (empty scope
/// list) rather than throwing, matching `CurriculumScopeDao`'s own
/// backward-compatible "no rows = track everything" default. Writes throw on
/// not-ready — a save the user explicitly triggered must not silently no-op.
class FirestoreCurriculumScopeSettingsAdapter {
  FirestoreCurriculumScopeSettingsAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Scope values for [curriculumId], or `[]` if not ready / none selected
  /// (= whole curriculum tracked).
  Future<List<String>> getScopeValues(CurriculumId curriculumId) async {
    final repo = await _ref.read(
      firestoreCurriculumScopeRepositoryProvider.future,
    );
    if (repo == null) return const [];
    return repo.getScopeValues(curriculumId);
  }

  /// Every scope selection for [curriculumId], or `[]` if not ready / none
  /// selected.
  Future<List<CurriculumScopeEntity>> getScopes(
    CurriculumId curriculumId,
  ) async {
    final repo = await _ref.read(
      firestoreCurriculumScopeRepositoryProvider.future,
    );
    if (repo == null) return const [];
    return repo.getScopes(curriculumId);
  }

  /// Replaces every scope selection for [curriculumId] with [scopeValues]
  /// at [scopeLevel]. Throws [CurriculumScopeSettingsNotReadyException] if
  /// not ready.
  Future<void> setScopes({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async {
    final repo = await _ref.read(
      firestoreCurriculumScopeRepositoryProvider.future,
    );
    if (repo == null) {
      throw const CurriculumScopeSettingsNotReadyException();
    }
    await repo.setScopes(
      curriculumId: curriculumId,
      scopeLevel: scopeLevel,
      scopeValues: scopeValues,
    );
  }

  /// Clears every scope selection for [curriculumId] (= track the entire
  /// curriculum). Throws [CurriculumScopeSettingsNotReadyException] if not
  /// ready.
  Future<void> clearScopes(CurriculumId curriculumId) async {
    final repo = await _ref.read(
      firestoreCurriculumScopeRepositoryProvider.future,
    );
    if (repo == null) {
      throw const CurriculumScopeSettingsNotReadyException();
    }
    await repo.clearScopes(curriculumId);
  }
}
