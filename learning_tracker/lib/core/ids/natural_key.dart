/// Typed natural-key value object for sync merger deduplication.
///
/// Each Firestore entity has a "natural key" — the set of columns that
/// uniquely identifies a row independently of the generated integer primary
/// key. [NaturalKey] is an extension type over [String] so it has zero
/// runtime cost but prevents accidental mixing of raw strings with merger
/// identifiers.
///
/// Factory constructors encode the per-entity key shape consistently,
/// replacing ad-hoc `'$a|$b'` string concatenations that were scattered
/// across the merger layer.
///
/// [DriftMergeStore] splits on `|` to decode composite keys, so the
/// separator character must remain `|` throughout.
///
/// ## Usage
/// ```dart
/// final key = NaturalKey.forCompletion(
///   firestoreId: row['firestore_id'] as String?,
///   profileId: profileId,
///   curriculumId: row['curriculum_id'] as String,
///   sefariaRef: row['sefaria_ref'] as String,
///   completedAt: row['completed_at'] as String,
/// );
/// await store.insertIfAbsent(naturalKey: key.value, ...);
/// ```
library;

/// Zero-cost wrapper around a String natural key.
///
/// Use the named factory constructors rather than the raw `NaturalKey(value)`
/// constructor — the factories encode the shape for each entity consistently.
extension type NaturalKey(String value) implements String {
  // ── Completion events ───────────────────────────────────────────────────────

  /// Natural key for a completion event.
  ///
  /// Prefers `firestoreId` (the stable server-assigned doc-id) when available.
  /// Falls back to the 4-col composite when not.
  factory NaturalKey.forCompletion({
    required String? firestoreId,
    required int profileId,
    required String curriculumId,
    required String sefariaRef,
    required String completedAt,
  }) {
    if (firestoreId != null && firestoreId.isNotEmpty) {
      return NaturalKey(firestoreId);
    }
    return NaturalKey('$profileId|$curriculumId|$sefariaRef|$completedAt');
  }

  // ── Track config ────────────────────────────────────────────────────────────

  /// Natural key for a curriculum track: `(curriculumId, trackType)`.
  factory NaturalKey.forTrackConfig({
    required String curriculumId,
    required String trackType,
  }) => NaturalKey('$curriculumId|$trackType');

  // ── Stage definition ────────────────────────────────────────────────────────

  /// Natural key for a stage definition: `(curriculumId, trackId, stageOrder)`.
  factory NaturalKey.forStageDefinition({
    required String curriculumId,
    required Object trackId,
    required Object stageOrder,
  }) => NaturalKey('$curriculumId|$trackId|$stageOrder');

  // ── Settings ────────────────────────────────────────────────────────────────

  /// Natural key for curriculum settings: `(curriculumId)`.
  factory NaturalKey.forSettings({required String curriculumId}) =>
      NaturalKey(curriculumId);

  // ── Bookmark ────────────────────────────────────────────────────────────────

  /// Natural key for a bookmark: `(curriculumId, trackType)`.
  factory NaturalKey.forBookmark({
    required String curriculumId,
    required String trackType,
  }) => NaturalKey('$curriculumId|$trackType');

  // ── Learner profile ─────────────────────────────────────────────────────────

  /// Natural key for a learner profile: the profile id as a string.
  factory NaturalKey.forLearnerProfile({
    required Object profileIdOrRow,
    required int fallbackProfileId,
  }) => NaturalKey(profileIdOrRow.toString().isNotEmpty
      ? profileIdOrRow.toString()
      : fallbackProfileId.toString());

  // ── Learning order ──────────────────────────────────────────────────────────

  /// Natural key for a learning order item: `(curriculumId, sefariaRef)`.
  factory NaturalKey.forLearningOrder({
    required String curriculumId,
    required String sefariaRef,
  }) => NaturalKey('$curriculumId|$sefariaRef');

  // ── Generic single-column key ────────────────────────────────────────────────

  /// Convenience factory for entities whose natural key is a single string.
  factory NaturalKey.fromSingle(String value) => NaturalKey(value);
}
