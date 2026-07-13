// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_ref_after_await_without_mounted_check.dart';

/// Writes [content] to a temporary file and returns it.
File _tmpFile(String content) {
  final file = File(
    '${Directory.systemTemp.path}/test_ref_after_await_${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

const _lintName = 'no_ref_after_await_without_mounted_check';

void main() {
  const rule = NoRefAfterAwaitWithoutMountedCheck();

  group('NoRefAfterAwaitWithoutMountedCheck', () {
    group('violations — ref/state touched after an await, no mounted guard',
        () {
      test(
        'flags the second ref.read() after a prior await with no guard '
        '(the exact AUD-sync-04 onEnqueueDrain shape)',
        () async {
          final file = _tmpFile('''
class Ref {
  bool get mounted => true;
  T? read<T>(Object provider) => null;
}

class Foo {
  void build(Ref ref, int profileId) {
    Function() onEnqueueDrain = () async {
      await (ref.read(Object())?.toString() ?? Future<int>.value(0));
      await ref.read(Object())?.toString();
    };
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'A ref.read() that runs after an earlier await with no '
                'ref.mounted guard in between must be flagged',
          );
        },
      );

      test('flags a state = ... assignment after an await with no guard',
          () async {
        final file = _tmpFile('''
class Ref {
  bool get mounted => true;
}

class FooNotifier {
  int state = 0;
  Ref ref = Ref();

  Future<void> increment() async {
    await Future<void>.value();
    state = 1;
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isNotEmpty,
          reason: 'state = ... after an await with no mounted guard must be '
              'flagged',
        );
      });

      test('flags ref.watch() (not just ref.read()) after an await', () async {
        final file = _tmpFile('''
class Ref {
  bool get mounted => true;
  T? watch<T>(Object provider) => null;
}

class Foo {
  Future<void> run(Ref ref) async {
    await Future<void>.value();
    ref.watch(Object());
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isNotEmpty,
        );
      });
    });

    group('allowed — guarded, or no risk of a stale ref', () {
      test(
          'does not flag ref.read() guarded by `if (!ref.mounted) return;` '
          'right after the await (the correct SM-4 fix)', () async {
        final file = _tmpFile('''
class Ref {
  bool get mounted => true;
  T? read<T>(Object provider) => null;
}

class Foo {
  void build(Ref ref, int profileId) {
    Function() onEnqueueDrain = () async {
      await (ref.read(Object())?.toString() ?? Future<int>.value(0));
      if (!ref.mounted) return;
      await ref.read(Object())?.toString();
    };
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'A ref.mounted guard immediately after the await must '
              'silence the rule for every ref use that follows it',
        );
      });

      test('does not flag ref.read() that runs before the first await',
          () async {
        final file = _tmpFile('''
class Ref {
  bool get mounted => true;
  T? read<T>(Object provider) => null;
}

class Foo {
  Future<void> run(Ref ref) async {
    ref.read(Object());
    await Future<void>.value();
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'ref use before any await in the body carries no '
              'staleness risk and must not be flagged',
        );
      });

      test('does not flag a synchronous method (no await at all)', () async {
        final file = _tmpFile('''
class Ref {
  bool get mounted => true;
  T? read<T>(Object provider) => null;
}

class Foo {
  void run(Ref ref) {
    ref.read(Object());
    ref.read(Object());
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'A non-async method has no await, hence no staleness risk',
        );
      });

      test(
          'does not flag a nested closure\'s own ref use (different async '
          'scope)', () async {
        final file = _tmpFile('''
class Ref {
  bool get mounted => true;
  T? read<T>(Object provider) => null;
}

class Foo {
  Future<void> run(Ref ref) async {
    await Future<void>.value();
    Future<void>.value().then((_) {
      ref.read(Object());
    });
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'A nested closure has its own async scope; this rule '
              'analyzes each function body independently rather than '
              'attributing an inner closure\'s ref use to the outer '
              'sequence',
        );
      });

      test(
          'does not flag an unrelated variable that happens to be named '
          '"ref" but is not a Riverpod Ref (no matching method name)',
          () async {
        final file = _tmpFile('''
class Reference {
  Future<String> getDownloadURL() async => '';
}

class Foo {
  Future<void> run(Reference ref) async {
    await Future<void>.value();
    ref.getDownloadURL();
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'Only read/watch/invalidate/refresh/listen method names '
              'on an identifier literally named `ref` are in scope, so an '
              'unrelated Reference.getDownloadURL() must not be flagged',
        );
      });
    });

    // AC2 (AUD-dashboard-06): confirms this checker covers the exact hazard
    // shapes dashboardTrackCompletionPercentage, dashboardCompletionPercentage,
    // stripStockMilestonesEffect, and dashboardPaceStatus had in
    // dashboard_providers.dart before their SM-4 fix — a `ref.watch`/
    // `ref.read` after a Drift DB-read `await` with no intervening
    // `ref.mounted` guard. Fires on the deliberately-broken (guard-removed)
    // shape and passes clean on the actual production fix shape.
    group('AUD-dashboard-06 — dashboard_providers.dart SM-4 hazard shapes', () {
      test(
        'flags a ref.watch(...) that follows a `final x = await '
        'db.call();` DB-read await with no guard (the '
        'dashboardTrackCompletionPercentage / dashboardCompletionPercentage '
        '/ dashboardPaceStatus shape before their fix)',
        () async {
          final file = _tmpFile('''
class Ref {
  bool get mounted => true;
  T? watch<T>(Object provider) => null;
}

class Db {
  Future<Object?> getTrackById(int id) async => null;
}

class Foo {
  Future<double> run(Ref ref, Db db, int trackId) async {
    final track = await db.getTrackById(trackId);
    if (track == null) return 0.0;
    ref.watch(Object());
    return 0.0;
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'ref.watch after the DB-read await with no mounted '
                'guard in between must be flagged — the exact hazard shape '
                'these dashboard providers had before their AUD-dashboard-06 '
                'fix',
          );
        },
      );

      test(
        'does not flag once the mounted guard sits between the DB-read '
        'await and the later ref.watch (the actual '
        'dashboardTrackCompletionPercentage / dashboardCompletionPercentage '
        '/ dashboardPaceStatus fix shape)',
        () async {
          final file = _tmpFile('''
class Ref {
  bool get mounted => true;
  T? watch<T>(Object provider) => null;
}

class Db {
  Future<Object?> getTrackById(int id) async => null;
}

class Foo {
  Future<double> run(Ref ref, Db db, int trackId) async {
    final track = await db.getTrackById(trackId);
    if (!ref.mounted) return 0.0;
    if (track == null) return 0.0;
    ref.watch(Object());
    return 0.0;
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'the ref.mounted guard immediately after the DB-read '
                'await must silence the rule for the ref.watch that '
                'follows it',
          );
        },
      );

      test(
        'flags a ref.read(...) inside a later if-body that follows an '
        'earlier `final stripped = await ...;` await with no guard (the '
        'stripStockMilestonesEffect shape once its await is extracted out '
        'of the if-condition)',
        () async {
          final file = _tmpFile('''
class Ref {
  bool get mounted => true;
  T? watch<T>(Object provider) => null;
  T? read<T>(Object provider) => null;
}

class Foo {
  Future<void> stripStockMilestonesEffect(Ref ref) async {
    final milestoneService = ref.watch(Object());
    final stripped = await Future<bool>.value(true);
    if (stripped) {
      await ref.read(Object())?.toString();
    }
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'ref.read inside the if-body runs after an earlier '
                'await with no ref.mounted guard in between — must be '
                'flagged',
          );
        },
      );

      test(
        'does not flag the actual stripStockMilestonesEffect fix shape: '
        'mounted guard between the extracted await and the later if-body '
        'ref.read',
        () async {
          final file = _tmpFile('''
class Ref {
  bool get mounted => true;
  T? watch<T>(Object provider) => null;
  T? read<T>(Object provider) => null;
}

class Foo {
  Future<void> stripStockMilestonesEffect(Ref ref) async {
    final milestoneService = ref.watch(Object());
    final stripped = await Future<bool>.value(true);
    if (!ref.mounted) return;
    if (stripped) {
      await ref.read(Object())?.toString();
    }
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'the ref.mounted guard immediately after the extracted '
                'await must silence the rule for the ref.read that follows '
                'it — this is the actual production fix in '
                'dashboard_providers.dart',
          );
        },
      );
    });
  });
}
