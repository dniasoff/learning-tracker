// PinFlowMode / PinFlowStep — shared PIN-flow vocabulary.
//
// This file carries no Flutter or Riverpod dependencies — only Dart core.
//
// AUD-profiles-07: this file previously also hosted a pure Dart PIN-flow
// state-machine class (plus its snapshot/event support types) that no
// production code path ever called — the Riverpod adapter (PinFlowController,
// in `features/profiles/presentation/providers/pin_flow_controller.dart`)
// independently reimplements the same transitions rather than wrapping that
// machine, despite an earlier version of this comment claiming otherwise.
// That ~200-line dead implementation has been removed; the enums below
// remain because PinFlowController and PinFlowScreen both import them from
// here (single source of truth, AG-4 dedup).
//
// Export [PinService] so callers can import the whole domain layer from
// this single library entry point.

library pin_flow_machine;

export 'pin_service.dart';

// ── PIN flow vocabulary ─────────────────────────────────────────────────────

/// Which PIN task the user is performing.
enum PinFlowMode {
  /// First-time or post-wipe PIN creation. Two steps: enter → confirm.
  setup,

  /// Change an existing PIN. Three steps: verify current → enter new → confirm.
  change,

  /// Verify the existing PIN to unlock a guarded route.
  verify,
}

/// Internal progress through the PIN flow.
enum PinFlowStep {
  /// Verifying the current PIN (change/verify modes).
  verifyCurrent,

  /// Entering the new PIN (setup and change modes).
  enterNew,

  /// Confirming the new PIN (setup and change modes).
  confirm,

  /// Terminal state — the flow is complete.
  done,
}
