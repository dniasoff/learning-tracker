// AUD-t-profiles-06: a narrowly-scoped FlutterError.onError overflow filter.
//
// PROBLEM: `profile_picker_screen_l1_test.dart`'s he-RTL smoke test and
// `rpr2_picker_offline_delete_test.dart`'s delete-flow harness both install
//
//   FlutterError.onError = (details) {
//     if (details.exceptionAsString().contains('overflowed')) return;
//     originalOnError?.call(details);
//   };
//
// to silence ONE known, tracked "residual small profile-grid" RenderFlex
// overflow (ProfileCard's Column overflows by a few pixels at the tight
// 360×780-logical Hebrew viewport — tracked for the Phase 8 RTL/visual
// sweep). A blanket substring match swallows EVERY overflow anywhere in the
// pumped tree for the rest of the test, however large and however
// unrelated — a regression introduced later (in ProfilePickerScreen, its
// manage-sheet, or its confirm dialog) would pass silently instead of
// failing CI, on an RTL app where directional-layout overflow is a named
// risk (AX-1).
//
// FIX: [isKnownSmallOverflow] narrows the match to overflow errors of at
// MOST [maxPixels] logical pixels — the actual, observed magnitude of the
// tracked defect (~3.6px in profile_picker_screen_l1_test.dart's he-RTL
// smoke test). Matching by widget IDENTITY (the recommendation's other
// option) was tried first and rejected: Flutter's overflow diagnostics only
// expose the offending RenderObject's creator chain via
// `DebugCreator.toString()`, which is HARD-CAPPED at 12 ancestor elements
// (`Element.debugGetCreatorChain(12)`) — for ProfileCard's Ink/InkWell/
// GestureDetector/Semantics wrapper stack the chain is exhausted before it
// reaches the `ProfileCard` StatelessElement itself, so no app-specific
// widget name is ever visible to match against. The overflow MAGNITUDE is
// the only stable, testable signal available; any future overflow that is
// NOT this tracked few-pixel defect (e.g. a large layout regression, or an
// entirely different widget's overflow) will exceed [maxPixels] and
// propagate to the real handler, failing the test.
library;

import 'package:flutter/foundation.dart';

/// Matches Flutter's "A RenderFlex overflowed by N pixels on the <edge>."
/// message (see `debug_overflow_indicator.dart`'s `_reportOverflow`) and
/// captures the magnitude.
final RegExp _overflowPattern = RegExp(r'overflowed by ([\d.]+) pixels');

/// True if [details] is a RenderFlex/layout overflow of AT MOST [maxPixels]
/// logical pixels — the KNOWN, tracked "residual small profile-grid"
/// overflow this test suite intentionally silences (AUD-t-profiles-06).
///
/// Returns false for: non-overflow errors, overflow errors that don't match
/// the expected message shape, and — critically — overflow errors LARGER
/// than [maxPixels], which are treated as an unrelated (and therefore
/// test-failing) defect rather than the tracked one.
///
/// [maxPixels] defaults to 15 — comfortably above the ~3.6px observed for
/// the tracked defect (allowing for minor CI font-metric variance) but far
/// below any overflow a genuinely broken/unrelated layout would produce.
bool isKnownSmallOverflow(
  FlutterErrorDetails details, {
  double maxPixels = 15,
}) {
  final match = _overflowPattern.firstMatch(details.exceptionAsString());
  if (match == null) return false;
  final pixels = double.tryParse(match.group(1)!);
  if (pixels == null) return false;
  return pixels <= maxPixels;
}
