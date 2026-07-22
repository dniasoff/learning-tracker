/// Test fixtures for ContentItem
/// Factory methods for creating test data with sensible defaults
library;

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

/// Factory for creating test ContentItem instances
class ContentItemFixtures {
  /// Creates a generic leaf [ContentItem] for ANY curriculum.
  ///
  /// This is the superset factory the per-curriculum hand-rolled `_leaf()`
  /// helpers scattered across the progress/content tests collapse onto. Unlike
  /// [mishna] / [daf] / [pasuk] it hard-codes no hierarchy values, so a caller
  /// drives the exact `level1..level4` path it needs — which is what the
  /// collision fixtures rely on to place two parents that share a level-N id.
  ///
  /// [curriculumId] MUST be a real `CurriculumId.storageKey` (the raw string
  /// stored on `ContentItem.curriculumId`), not an arbitrary label.
  ///
  /// [sefariaRef] defaults to the space-joined non-empty level path, which is
  /// unique enough for most single-parent fixtures; pass an explicit ref when
  /// two leaves share the same level path (the collision case) so their
  /// identities stay distinct.
  static ContentItem leaf({
    required String curriculumId,
    required String level1,
    String? level2,
    String? level3,
    String? level4,
    String? sefariaRef,
    int sortOrder = 0,
    String displayNameHe = '',
    String displayNameEn = '',
    bool isLeaf = true,
  }) {
    final path = [
      level1,
      level2,
      level3,
      level4,
    ].where((s) => s != null && s.isNotEmpty).join(' ');
    return ContentItem(
      curriculumId: curriculumId,
      level1: level1,
      level2: level2,
      level3: level3,
      level4: level4,
      displayNameHe: displayNameHe,
      displayNameEn: displayNameEn,
      sefariaRef: sefariaRef ?? path,
      sortOrder: sortOrder,
      isLeaf: isLeaf,
    );
  }

  /// Creates a test mishna (Mishnayos curriculum, leaf item)
  static ContentItem mishna({
    String? curriculumId,
    String level1 = 'Seder Zeraim',
    String level2 = 'Berachos',
    String level3 = '1',
    String level4 = '1',
    String? displayNameHe,
    String? displayNameEn,
    String? sefariaRef,
    int sortOrder = 1,
    bool isLeaf = true,
  }) {
    return ContentItem(
      curriculumId: curriculumId ?? CurriculumId.mishnayos.storageKey,
      level1: level1,
      level2: level2,
      level3: level3,
      level4: level4,
      displayNameHe: displayNameHe ?? 'ברכות $level3:$level4',
      displayNameEn: displayNameEn ?? '$level2 $level3:$level4',
      sefariaRef: sefariaRef ?? 'Mishnah $level2 $level3.$level4',
      sortOrder: sortOrder,
      isLeaf: isLeaf,
    );
  }

  /// Creates a test daf (Bavli curriculum, leaf item)
  static ContentItem daf({
    String? curriculumId,
    String level1 = 'Seder Zeraim',
    String level2 = 'Berachos',
    String level3 = '2a',
    String? level4,
    String? displayNameHe,
    String? displayNameEn,
    String? sefariaRef,
    int sortOrder = 1,
    bool isLeaf = true,
  }) {
    return ContentItem(
      curriculumId: curriculumId ?? CurriculumId.bavli.storageKey,
      level1: level1,
      level2: level2,
      level3: level3,
      level4: level4,
      displayNameHe: displayNameHe ?? '$level2 $level3',
      displayNameEn: displayNameEn ?? '$level2 $level3',
      sefariaRef: sefariaRef ?? '$level2 $level3',
      sortOrder: sortOrder,
      isLeaf: isLeaf,
    );
  }

  /// Creates a test pasuk (Chumash curriculum, leaf item)
  static ContentItem pasuk({
    String? curriculumId,
    String level1 = 'Torah',
    String level2 = 'Bereishis',
    String level3 = 'Bereishis',
    String level4 = '1:1',
    String? displayNameHe,
    String? displayNameEn,
    String? sefariaRef,
    int sortOrder = 1,
    bool isLeaf = true,
  }) {
    return ContentItem(
      curriculumId: curriculumId ?? CurriculumId.chumash.storageKey,
      level1: level1,
      level2: level2,
      level3: level3,
      level4: level4,
      displayNameHe: displayNameHe ?? 'בראשית $level4',
      displayNameEn: displayNameEn ?? '$level3 $level4',
      sefariaRef: sefariaRef ?? 'Genesis $level4',
      sortOrder: sortOrder,
      isLeaf: isLeaf,
    );
  }

  /// Creates a test container (non-leaf item like a seder or masechta)
  static ContentItem container({
    String? curriculumId,
    required String level1,
    String? level2,
    String? level3,
    String? level4,
    String? displayNameHe,
    String? displayNameEn,
    String? sefariaRef,
    int sortOrder = 0,
  }) {
    return ContentItem(
      curriculumId: curriculumId ?? CurriculumId.mishnayos.storageKey,
      level1: level1,
      level2: level2,
      level3: level3,
      level4: level4,
      displayNameHe: displayNameHe ?? level2 ?? level1,
      displayNameEn: displayNameEn ?? level2 ?? level1,
      sefariaRef: sefariaRef ?? level2 ?? level1,
      sortOrder: sortOrder,
      isLeaf: false,
    );
  }
}

/// Factory for creating test [LearningLedgerData] rows.
///
/// Consolidates the 15-field `LearningLedgerData(...)` constructor that was
/// hand-copied (with slightly different defaults) in the collision, composite,
/// and siyumim tree-builder tests. All lifetime SCOPE marks and un-marks are
/// built through here so a single place owns the ledger row shape.
class LedgerFixtures {
  const LedgerFixtures._();

  /// A positive lifetime SCOPE-mark ledger row.
  ///
  /// [entryScope] is the raw scope string the read-side switch in
  /// `LifetimeTreeBuilder.computeLearnedLeafRefs` buckets on — either the
  /// generic `'level1'..'level4'` form or a curriculum-native alias
  /// (`'seder'`/`'masechta'`/`'daf'`/`'perek'`/`'mishna'`/`'amud'`/…). Both map
  /// to the same bucket.
  ///
  /// [unitIdentifier] MUST be the ancestor-qualified id produced by
  /// `scopeUnitIdentifier` for a level>=2 mark (bare `level1` value for a
  /// level1 mark). Building it through the real seam — not a hardcoded literal
  /// — is what lets a revert of that seam collapse both the stored id and the
  /// read-time lookup key at once.
  ///
  /// [completedAt] is exposed so a caller mixing positive marks and un-marks
  /// can order rows newest-first (the precondition `computeLearnedLeafRefs`
  /// relies on for its first-write-wins tie-break).
  static LearningLedgerData scopeMark({
    required String curriculumId,
    required String entryScope,
    required String unitIdentifier,
    int id = 0,
    int profileId = 1,
    String ulid = '',
    String unitDisplayNameHe = '',
    String unitDisplayNameEn = '',
    String trackType = 'personal',
    int? trackId,
    DateTime? completedAt,
    int completionNumber = 1,
    int markedBy = 1,
    bool isManual = false,
    DateTime? createdAt,
  }) {
    final ts = completedAt ?? DateTime.utc(2026, 1, 1);
    return LearningLedgerData(
      id: id,
      profileId: profileId,
      ulid: ulid,
      curriculumId: curriculumId,
      entryScope: entryScope,
      unitIdentifier: unitIdentifier,
      unitDisplayNameHe: unitDisplayNameHe,
      unitDisplayNameEn: unitDisplayNameEn,
      trackType: trackType,
      trackId: trackId,
      completedAt: ts,
      completionNumber: completionNumber,
      markedBy: markedBy,
      isManual: isManual,
      createdAt: createdAt ?? ts,
    );
  }

  /// An UN-mark ledger row: identical to [scopeMark] but with the
  /// `'unmark_'` prefix the read-side switch strips to flip the action bool.
  /// Pass the BARE [entryScope] (e.g. `'level3'`) — the prefix is applied here.
  static LearningLedgerData unmark({
    required String curriculumId,
    required String entryScope,
    required String unitIdentifier,
    int id = 0,
    int profileId = 1,
    String ulid = '',
    String unitDisplayNameHe = '',
    String unitDisplayNameEn = '',
    String trackType = 'personal',
    int? trackId,
    DateTime? completedAt,
    int completionNumber = 1,
    int markedBy = 1,
    bool isManual = false,
    DateTime? createdAt,
  }) => scopeMark(
    curriculumId: curriculumId,
    entryScope: 'unmark_$entryScope',
    unitIdentifier: unitIdentifier,
    id: id,
    profileId: profileId,
    ulid: ulid,
    unitDisplayNameHe: unitDisplayNameHe,
    unitDisplayNameEn: unitDisplayNameEn,
    trackType: trackType,
    trackId: trackId,
    completedAt: completedAt,
    completionNumber: completionNumber,
    markedBy: markedBy,
    isManual: isManual,
    createdAt: createdAt,
  );
}
