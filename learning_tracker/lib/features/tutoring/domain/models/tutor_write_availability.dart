/// Whether the current session may use a learning write control now
/// (Story 1.24, DNI-486, AC-4 / AC-5 / AC-6).
library;

/// The write availability of the active session, in precedence order:
/// owner sessions are never gated here; a tutor needs the parent's
/// `can_edit_learning` (AD-53), a positive connectivity probe (online-only,
/// deviation #3) and the TARGET learner outside a lock (AD-36).
enum TutorWriteAvailability {
  /// Not a tutored session: the owner's own gates apply.
  owner,

  /// A tutor may write.
  available,

  /// The grant's `can_edit_learning` is false: read-only.
  noEditAccess,

  /// The device is not positively online: tutor writes are disabled.
  offline,

  /// The tutored learner is inside a lock window (or it is not yet known):
  /// that learner's screens are covered.
  locked;

  /// Whether a write control may be enabled.
  bool get allowsWrite => this == owner || this == available;

  /// Whether a tutor write control must be shown visible but disabled.
  bool get blocksTutor => !allowsWrite;
}
