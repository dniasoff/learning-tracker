// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_side_effect_in_provider_build.dart';

/// Writes [content] to a temporary file and returns it.
File _tmpFile(String content) {
  final file = File(
    '${Directory.systemTemp.path}/test_side_effect_build_${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

const _lintName = 'no_side_effect_in_provider_build';

void main() {
  const rule = NoSideEffectInProviderBuild();

  group('NoSideEffectInProviderBuild', () {
    group('violations', () {
      test(
        'flags a chained-property (DAO field) assignment directly inside '
        "a Provider's create callback (the pre-fix AUD-sync-08 "
        'outboxSyncWriteFacadeProvider shape)',
        () async {
          final file = _tmpFile('''
class Dao {
  Object? syncSink;
}

class Database {
  final Dao pointsBalanceDao = Dao();
}

class Facade {}

class Ref {
  Database watch(Object provider) => Database();
}

final databaseProvider = 'database';

final facadeProvider = Provider<Facade?>((ref) {
  final database = ref.watch(databaseProvider);
  database.pointsBalanceDao.syncSink = Facade();
  return Facade();
});

class Provider<T> {
  Provider(T Function(Ref ref) create);
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'A chained-property assignment (database.pointsBalanceDao.'
                'syncSink = ...) made directly inside a Provider create '
                'callback must be flagged as a DAO field mutation',
          );
        },
      );

      test(
        'flags an unawaited(...) fire-and-forget call directly inside a '
        "Provider's create callback",
        () async {
          final file = _tmpFile('''
import 'dart:async';

class Dao {
  Future<void> reEnqueueUnsyncedLedgerRows(String profileId) async {}
}

class Database {
  final Dao pointsBalanceDao = Dao();
}

class Ref {
  Database watch(Object provider) => Database();
}

final databaseProvider = 'database';

final facadeProvider = Provider<Object?>((ref) {
  final database = ref.watch(databaseProvider);
  unawaited(database.pointsBalanceDao.reEnqueueUnsyncedLedgerRows('p1'));
  return null;
});

class Provider<T> {
  Provider(T Function(Ref ref) create);
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'A bare unawaited(...) call directly inside a Provider '
                'create callback must be flagged as a fire-and-forget side '
                'effect',
          );
        },
      );

      test(
        'flags both violation shapes inside StreamProvider.autoDispose too',
        () async {
          final file = _tmpFile('''
class Dao {
  Object? syncSink;
}

class Database {
  final Dao pointsBalanceDao = Dao();
}

class Ref {
  Database watch(Object provider) => Database();
}

final databaseProvider = 'database';

final streamProvider = StreamProvider.autoDispose<int>((ref) {
  final database = ref.watch(databaseProvider);
  database.pointsBalanceDao.syncSink = 1;
  return const Stream.empty();
});

class StreamProvider<T> {
  StreamProvider(Stream<T> Function(Ref ref) create);
  StreamProvider.autoDispose(Stream<T> Function(Ref ref) create);
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'The .autoDispose named constructor of the provider family '
                'must be scanned too, not only the plain constructor',
          );
        },
      );
    });

    group('allowed', () {
      test(
        'does not flag a plain ref.state assignment (single-hop, not a '
        'chained DAO reach)',
        () async {
          final file = _tmpFile('''
class Ref {
  int state = 0;
}

final counterProvider = Provider<int>((ref) {
  ref.state = 1;
  return ref.state;
});

class Provider<T> {
  Provider(T Function(Ref ref) create);
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: "A single-hop assignment to a bare identifier's property "
                '(ref.state = ...) is an ordinary state write, not a '
                'chained DAO field mutation, and must not be flagged',
          );
        },
      );

      test(
        'does not flag a local variable assignment',
        () async {
          final file = _tmpFile('''
class Ref {}

final valueProvider = Provider<int>((ref) {
  var count = 0;
  count = 1;
  return count;
});

class Provider<T> {
  Provider(T Function(Ref ref) create);
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'Assigning a bare local variable must not be flagged',
          );
        },
      );

      test(
        'does not flag a chained assignment or unawaited(...) call inside '
        'a nested closure argument (deferred callback, not synchronous '
        'build-time)',
        () async {
          final file = _tmpFile('''
import 'dart:async';

class Dao {
  Object? syncSink;
  Future<void> drain() async {}
}

class Database {
  final Dao pointsBalanceDao = Dao();
}

class Ref {
  Database watch(Object provider) => Database();
}

final databaseProvider = 'database';

final facadeProvider = Provider<Object?>((ref) {
  final database = ref.watch(databaseProvider);
  void onEnqueueDrain() {
    database.pointsBalanceDao.syncSink = null;
    unawaited(database.pointsBalanceDao.drain());
  }
  return onEnqueueDrain;
});

class Provider<T> {
  Provider(T Function(Ref ref) create);
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'A side effect nested inside a closure runs later (on '
                'whatever triggers that closure), not synchronously during '
                'build/create, and must not be flagged',
          );
        },
      );

      test(
        'does not flag a chained property read (no assignment)',
        () async {
          final file = _tmpFile('''
class Dao {
  Object? syncSink;
}

class Database {
  final Dao pointsBalanceDao = Dao();
}

class Ref {
  Database watch(Object provider) => Database();
}

final databaseProvider = 'database';

final facadeProvider = Provider<Object?>((ref) {
  final database = ref.watch(databaseProvider);
  return database.pointsBalanceDao.syncSink;
});

class Provider<T> {
  Provider(T Function(Ref ref) create);
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'A read (no assignment) must not be flagged',
          );
        },
      );

      test(
        'does not flag an unrelated constructor call named Provider-like '
        'but outside the provider family',
        () async {
          final file = _tmpFile('''
class Dao {
  Object? syncSink;
}

class Database {
  final Dao pointsBalanceDao = Dao();
}

final facadeProvider = NotAProvider((db) {
  db.pointsBalanceDao.syncSink = null;
});

class NotAProvider {
  NotAProvider(void Function(Database db) create);
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'Only the Provider/StreamProvider/FutureProvider '
                'constructor family is in scope for this rule',
          );
        },
      );
    });
  });
}
