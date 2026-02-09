/// User mode for the learning tracker.
///
/// Determines the UX experience and completion feedback style.
enum UserMode {
  /// Child mode: Shows points popups and celebratory animations.
  child,

  /// Adult mode: Shows subtle confirmations without gamification.
  adult,
}
