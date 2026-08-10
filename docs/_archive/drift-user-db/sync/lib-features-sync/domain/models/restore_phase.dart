/// Stable, closed set of progress phases for [RestoreStatus.restoring]
/// (AUD-app-02, EH-5/EH-6/AX-2).
///
/// Mirrors [SyncErrorCode]: [DeviceRestoreService] emits one of these values
/// — never a free-text English sentence — and the presentation layer
/// resolves each value to a localized string through an EXHAUSTIVE switch
/// expression (no wildcard `_`/`default` arm, per EH-6). Because the switch
/// is exhaustive, adding a new [RestorePhase] value without also updating
/// the presentation mapping is a **compile error**, not a silent fallback to
/// raw English text for Hebrew-locale users.
enum RestorePhase {
  /// Step 1: pulling the user's data down from Firestore.
  pullingData,

  /// Step 2: deriving the active curricula from the just-pulled local DB.
  loadingCurricula,

  /// Step 3: re-importing bundled content for the active curricula.
  importingContent,
}
