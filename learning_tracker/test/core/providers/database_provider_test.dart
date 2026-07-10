/// Regression test for AUD-app-07.
///
/// `contentDbPathProvider` (lib/core/providers/database_provider.dart)
/// constructs `SeedManager` directly (not via the removed
/// `bootstrapSeedDb()` helper). Before the fix it built the manager with
/// `SeedManager(dbDirectory: docsDir.path)` — no `logger:` argument — so
/// every one of SeedManager's `_logger?.info/warning/error(...)` diagnostic
/// calls was a silent null-safe no-op. A real extraction/upgrade/corruption
/// failure in production would leave zero trace anywhere the team could
/// retrieve (Settings → "Send Diagnostic Logs" reads AppLogger's Talker
/// history).
///
/// This test forces `SeedManager.ensureContentDb()` to throw from inside
/// `contentDbPathProvider` (no seed asset is registered for the test
/// bundle, so `rootBundle.load()` fails — the same mechanism the existing
/// `seed_manager_test.dart` first-launch-failure tests already rely on) and
/// asserts that a `seed_manager_extract_failed` entry lands in
/// `AppLogger`'s history — proving the provider wires a real logger into
/// `SeedManager`, not just constructs it silently.
///
/// NOTE on `container.listen` instead of `container.read(...future)`:
/// Riverpod 3 `FutureProvider`s auto-retry a failed build with backoff,
/// staying in `AsyncLoading(..., retrying: true)` rather than settling
/// into a terminal `AsyncError` — awaiting `.future` directly hangs for the
/// whole retry window. Listening for the first emitted state carrying an
/// error is enough to prove SeedManager threw (and logged) without waiting
/// out the retry schedule.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// ── Fake PathProviderPlatform ─────────────────────────────────────────────────
//
// Same pattern as test/features/sacred_time/sacred_location_and_data_test.dart
// — redirects getApplicationDocumentsDirectory() to an isolated temp dir so
// contentDbPathProvider's SeedManager never touches a real app-docs path.
class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('content_db_path_test_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    // Reset the AppLogger singleton so this test observes only the history
    // entries it produces itself (AppLogger.instance re-wraps the fresh
    // Talker created here).
    AppLogger.init();
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('contentDbPathProvider wires AppLogger.instance into SeedManager — a '
      'failed ensureContentDb() records seed_manager_extract_failed '
      '(AUD-app-07)', () async {
    final container = ProviderContainer();
    final firstError = Completer<Object>();

    // No seed asset is registered in the test asset bundle, so
    // SeedManager.ensureContentDb() throws inside contentDbPathProvider's
    // first-launch extraction path on its very first attempt.
    final sub = container.listen(contentDbPathProvider, (previous, next) {
      if (next.hasError && !firstError.isCompleted) {
        firstError.complete(next.error);
      }
    }, fireImmediately: true);

    await firstError.future.timeout(const Duration(seconds: 10));
    sub.close();
    container.dispose();

    final events = AppLogger.rawTalker.history
        .map((e) => e.generateTextMessage())
        .toList(growable: false);

    expect(
      events.any((m) => m.contains('seed_manager_extract_failed')),
      isTrue,
      reason:
          'contentDbPathProvider must construct SeedManager with a real '
          'logger so ensureContentDb() failures are recorded in '
          'AppLogger, not silently dropped (AUD-app-07). '
          'Talker history was: $events',
    );
  });
}
