/// Stable error codes for DAO-layer invariant violations (EH-5,
/// AUD-core-database-14).
///
/// This app ships EN + Hebrew — an English sentence baked into a thrown
/// error renders raw and un-RTL-shaped if it ever reaches a bilingual
/// support/crash-report flow. Domain/data errors must never carry a
/// pre-formatted human-readable message; presentation resolves the
/// user-facing string for each code through `AppLocalizations`/ARB (see
/// `SyncErrorCode` / `SyncStatus.error` for the reference EH-5 fix this
/// mirrors).
enum DaoErrorCode {
  /// [ActiveCurriculumDao.deactivateByProfile] was called for a profile
  /// with only one active curriculum (minimum-1 invariant). In practice
  /// this is a defensive backstop — the service layer
  /// (`CurriculumActivationService.deactivate`/`.archive`) already guards
  /// this business rule with a presentable
  /// `LastActiveCurriculumException` before reaching the DAO.
  lastActiveCurriculum,

  /// [LearningLedgerDao.insertEntry]'s `INSERT OR IGNORE` collided with an
  /// existing row, but the companion carried no `ulid` to resolve which
  /// row — the dedup key the DAO relies on to find the existing row id.
  ledgerInsertCollisionUnresolvable,

  /// [StudyDayConfigDao.seedDefaultsForTrack] was called for a
  /// `curriculum_tracks` row id that does not exist.
  studyDayTrackNotFound,

  /// An `accounts.tier` column value did not match any known [UserTier].
  unknownAccountTier,
}

/// Thrown by DAO-layer methods for an internal invariant violation —
/// local DB corruption, a missed migration, or a should-never-happen
/// defensive backstop. Carries a stable [code] (EH-5) plus an optional
/// non-user-facing [debugDetail] for logging — never a pre-formatted
/// human message. An [Error] subtype (matching the [StateError] semantics
/// these sites previously used): these signal a programming error and
/// should crash loudly, not be caught as normal control flow (EH-4).
class DaoInvariantError extends Error {
  DaoInvariantError(this.code, [this.debugDetail]);

  /// Stable, localizable category — never construct a message from this
  /// directly; resolve it through `AppLocalizations`/ARB if it must ever
  /// be shown to a user.
  final DaoErrorCode code;

  /// Optional non-user-facing detail (e.g. an id, a raw stored value) for
  /// logs/crash reports only.
  final Object? debugDetail;

  @override
  String toString() {
    final suffix = debugDetail == null ? '' : ' (debugDetail: $debugDetail)';
    return 'DaoInvariantError.${code.name}$suffix';
  }
}
