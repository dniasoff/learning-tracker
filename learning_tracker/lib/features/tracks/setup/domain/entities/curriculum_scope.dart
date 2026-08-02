import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Domain entity for one curriculum-scope selection.
///
/// **New for the Firestore rewrite** (`docs/firestore-rewrite-map.md`) — no
/// non-Drift domain model existed for `curriculum_scopes` before this file.
/// The Drift `CurriculumScopes` row (`lib/core/database/tables/
/// curriculum_scopes.dart`) is NOT reused: it carries a `profileId` FK (now
/// implicit in the Firestore path) and a `trackId` FK that AD-25 retires for
/// this collection (`curriculum_id` is the sole canonical stable track key —
/// see `docs/firestore-rewrite-map.md`). This entity keeps only the fields
/// that survive that retirement.
///
/// One instance = one selected scope VALUE at one hierarchy LEVEL within a
/// curriculum (e.g. `(mishnayos, level: 1, value: "Seder Zeraim")`).
/// Multiple instances for the same [curriculumId] = multiple scopes (mixed
/// levels allowed — a user can drill level 1 → 2 → 3 while breadcrumbing).
/// No instances for a curriculum = the entire curriculum is tracked
/// (backward-compatible default, same as Drift).
class CurriculumScopeEntity {
  const CurriculumScopeEntity({
    required this.curriculumId,
    required this.scopeLevel,
    required this.scopeValue,
    required this.createdAt,
    this.updatedAt,
  });

  final CurriculumId curriculumId;

  /// Which hierarchy level this scope applies to (1-4, matching
  /// level1-level4 in the bundled content hierarchy).
  final int scopeLevel;

  /// The value at [scopeLevel] (e.g. `"Seder Zeraim"`, `"Berachos"`).
  final String scopeValue;

  final DateTime createdAt;

  /// `null` for a scope that has never been touched since creation — this
  /// collection has no tutor-proxy `.hasOnly()` field whitelist
  /// (`firestore.rules`: "No `.hasOnly()` counterpart for curriculum_scopes
  /// — it's intentionally open-ended"), so unlike `profile_programs` there
  /// is no rules-enforced requirement to always stamp this.
  final DateTime? updatedAt;

  /// Encodes this scope for a Firestore write.
  ///
  /// `profile_id` is deliberately NOT included — same reasoning as
  /// `BookmarkEntity.toFirestore`/`StageDefinitionFirestoreCodec.toFirestore`:
  /// the document already lives at `.../learner_profiles/{profileId}/
  /// curriculum_scopes/{scopeId}`, so profile identity is carried by the
  /// path, not duplicated into the body.
  Map<String, dynamic> toFirestore({required DateTime updatedAt}) => {
    'curriculum_id': curriculumId.storageKey,
    'scope_level': scopeLevel,
    'scope_value': scopeValue,
    'created_at': FirestoreCodec.encodeDateTime(createdAt),
    'updated_at': FirestoreCodec.encodeDateTime(updatedAt),
  };
}

/// Decodes a `curriculum_scopes/{scopeId}` document into a
/// [CurriculumScopeEntity].
///
/// Throws [ArgumentError] for an unrecognised `curriculum_id` and
/// [FormatException] for a missing `scope_level`/`scope_value`/
/// `created_at` — both are caller-visible decode failures by design (mirrors
/// `stageDefinitionFromFirestore`), surfaced via `resilientQueryStream`'s
/// per-document error handling (skips just that document) rather than
/// silently defaulted.
CurriculumScopeEntity curriculumScopeFromFirestore(Map<String, dynamic> data) {
  final curriculumId = CurriculumId.fromStorageKey(
    data['curriculum_id'] as String? ?? '',
  );
  if (curriculumId == null) {
    throw ArgumentError('Unknown curriculumId: ${data['curriculum_id']}');
  }

  final scopeLevel = FirestoreCodec.parseInt(data['scope_level']);
  final scopeValue = data['scope_value'] as String?;
  final createdAt = FirestoreCodec.parseDateTime(data['created_at']);
  if (scopeLevel == null || scopeValue == null || createdAt == null) {
    throw FormatException(
      'curriculum_scopes document missing scope_level/scope_value/'
      'created_at: $data',
    );
  }

  return CurriculumScopeEntity(
    curriculumId: curriculumId,
    scopeLevel: scopeLevel,
    scopeValue: scopeValue,
    createdAt: createdAt,
    updatedAt: FirestoreCodec.parseDateTime(data['updated_at']),
  );
}
