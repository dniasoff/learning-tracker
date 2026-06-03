// Overflow guard for the full-screen Sacred Time lock overlay.
//
// `_LockScreen` (sacred_time_lock_overlay.dart) centres a 96px icon + a large
// `displaySmall` greeting + a `titleMedium` subtitle in a non-scrolling Column.
// On a small viewport at large text scales that content is taller than the
// screen → vertical RenderFlex overflow. The fix wraps the Column in
// `LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight) +
// IntrinsicHeight` so it stays centred + full-screen on normal devices but
// scrolls (instead of overflowing) when the content can't fit.
//
// Unlike the Row guards, this renders the REAL [SacredTimeLockOverlay] with the
// active-window provider overridden, exercising all four greeting variants.

@Tags(['overflow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';

import '../../helpers/overflow_harness.dart';

SacredWindow _windowOf(SacredWindowKind kind) => SacredWindow(
  startUtc: DateTime.utc(2026, 5, 15, 18, 0),
  endUtc: DateTime.utc(2026, 5, 16, 20, 0),
  kind: kind,
);

List<Override> _activeWindow(SacredWindowKind kind) => [
  // `overrideWithValue` supplies a fixed window, bypassing the notifier's
  // `build()` (and its 30s Timer), so `pumpAndSettle` won't hang.
  currentSacredWindowProvider.overrideWithValue(_windowOf(kind)),
];

void main() {
  for (final kind in SacredWindowKind.values) {
    testWidgets(
      'Sacred Time lock overlay (${kind.name}) does not overflow across the '
      'matrix incl. small×2.0',
      (tester) async {
        await expectNoOverflowAcrossDevices(
          tester,
          () => const SacredTimeLockOverlay(child: SizedBox.expand()),
          overrides: _activeWindow(kind),
        );
      },
    );
  }
}
