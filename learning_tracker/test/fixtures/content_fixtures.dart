/// Test fixtures for ContentItem and LearningLedgerData
/// Factory methods for creating test data with sensible defaults
library;

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

/// Factory for creating test ContentItem instances
class ContentItemFixtures {
  /// Generic leaf builder — the shared superset of every hand-rolled `_leaf`
  /// factory that previously lived in individual test files.
  ///
  /// Callers supply the real `curriculumId` (a [CurriculumId.storageKey]) and
  /// the level path; the collision-safe scope-id keying in production depends
  /// on sibling ids being able to REPEAT across parents, so this factory does
  /// NOT invent globally-unique ids — pass exactly the level values the
  /// scenario needs.
  ///
  /// [displayNameHe] / [displayNameEn] default to empty (most pure-logic tests
  /// never read them). [sefariaRef] falls back to the space-joined level path
  /// when omitted, but every collision/credit scenario should pass an explicit
  /// ref since that is the identity the builder returns.
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
    return ContentItem(
      curriculumId: curriculumId,
      level1: level1,
      level2: level2,
      level3: level3,
      level4: level4,
      displayNameHe: displayNameHe,
      displayNameEn: displayNameEn,
      sefariaRef:
          sefariaRef ??
          [
            level1,
            level2,
            level3,
            level4,
          ].where((s) => s != null && s.isNotEmpty).join(' '),
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

/// Factory for creating test [LearningLedgerData] rows without touching the
/// database. Consolidates the 15-field data-class constructor that was
/// hand-copied across the collision, composite, and siyumim provider tests.
///
/// [scopeMark] builds a positive lifetime scope-mark row. To exercise the
/// production write→read seam faithfully, callers should build the
/// [unitIdentifier] via `scopeUnitIdentifier(...)` (content_grouping.dart) so
/// the stored id carries the same ancestor-qualified path the read side keys
/// on — a bare, hand-written id would not reproduce the collision guard.
class LedgerFixtures {
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
      completedAt: completedAt ?? DateTime.utc(2026, 1, 1),
      completionNumber: completionNumber,
      markedBy: markedBy,
      isManual: isManual,
      createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
    );
  }

  /// An unmark row — identical to [scopeMark] but with the `entryScope`
  /// prefixed `unmark_`, which flips the credit action in
  /// `computeLearnedLeafRefs`. Pass the bare scope (e.g. 'seder'); the prefix
  /// is applied here.
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
  }) {
    return scopeMark(
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
}
