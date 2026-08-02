/// Regression tests for [bootstrapAccount] — AUD-app-08.
///
/// `registry.close()` used to sit at the end of the try block, not in a
/// `finally`. If `sessionService.resolveActiveAccountId()` (or
/// `registry.findById()`) threw, execution jumped straight to the outer
/// `catch`, which logged and returned the fallback filename WITHOUT ever
/// closing the Drift-backed `device_registry` connection — a leaked native
/// database handle held for the app's whole lifetime.
///
/// [_SpyInterceptor] wraps an in-memory [NativeDatabase] with a
/// `QueryInterceptor` that (a) can be told to make the very first query
/// throw — simulating `resolveActiveAccountId()` failing — and (b) records
/// whether [QueryExecutor.close] was ever invoked, so the test can observe
/// the leak directly rather than inferring it from the return value alone.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/bootstrap/account_bootstrap.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

/// Wraps a real (in-memory) executor and lets the test control/observe it:
///   - [throwOnEnsureOpen]: when true, the very first attempt to open/use
///     the connection throws — this is what `resolveActiveAccountId()`'s
///     first registry query (`findById` / `getLastActiveAccountId` /
///     `getAllAccounts`) hits, so it reliably makes that call throw.
///   - [closeCalled]: set to true the moment [close] is invoked, before
///     delegating to the real executor — the direct, unambiguous signal
///     this test needs.
class _SpyInterceptor extends QueryInterceptor {
  bool throwOnEnsureOpen = false;
  bool closeCalled = false;

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) {
    if (throwOnEnsureOpen) {
      throw StateError('simulated device_registry connection failure');
    }
    return executor.ensureOpen(user);
  }

  @override
  Future<void> close(QueryExecutor inner) {
    closeCalled = true;
    return inner.close();
  }
}

AppLogger _testLogger() => AppLogger(Talker());

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late _SpyInterceptor interceptor;
  late QueryExecutor executor;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    interceptor = _SpyInterceptor();
    executor = NativeDatabase.memory().interceptWith(interceptor);
  });

  group('bootstrapAccount — registry connection lifecycle', () {
    test(
      'registry.close() is called when sessionService.resolveActiveAccountId() '
      'throws (exception path)',
      () async {
        interceptor.throwOnEnsureOpen = true;

        final result = await bootstrapAccount(
          databasesPath: '/tmp/does-not-matter',
          log: _testLogger(),
          registryExecutor: executor,
        );

        // The error is caught by the outer catch and the legacy fallback
        // filename is returned — this already worked before the fix.
        expect(result.dbFileName, 'learning_tracker');
        expect(result.accountId, null);

        // This is the actual regression guard: before the fix, close() was
        // never reached on this path because it sat at the end of the try
        // block instead of a finally.
        expect(
          interceptor.closeCalled,
          isTrue,
          reason:
              'registry.close() must run even when resolveActiveAccountId() '
              'throws, otherwise the native device_registry connection leaks '
              'for the app\'s whole lifetime',
        );
      },
    );

    test(
      'registry.close() is called on the success path (no exception)',
      () async {
        interceptor.throwOnEnsureOpen = false;

        final result = await bootstrapAccount(
          databasesPath: '/tmp/does-not-matter',
          log: _testLogger(),
          registryExecutor: executor,
        );

        // No accounts registered → fast path returns the legacy fallback.
        expect(result.dbFileName, 'learning_tracker');
        expect(result.accountId, null);
        expect(interceptor.closeCalled, isTrue);
      },
    );
  });
}
