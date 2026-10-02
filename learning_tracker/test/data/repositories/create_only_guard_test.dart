/// DNI-464 review R2: `readExistingForCreate` — the create-only pre-read
/// for `learning_events` and `change_log`. A cache miss falls through to
/// the server; an offline server read means "queue"; every OTHER read
/// failure is rethrown and never collapsed into "absent" (which would turn
/// a read error into an upsert over an existing document).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/create_only_guard.dart';

/// A scripted outcome for one `get(source)`: data, absent, or an error.
sealed class _Outcome {
  const _Outcome();
}

final class _Exists extends _Outcome {
  const _Exists(this.data);
  final Map<String, dynamic> data;
}

final class _Absent extends _Outcome {
  const _Absent();
}

final class _Fails extends _Outcome {
  const _Fails(this.code);
  final String code;
}

// ignore: subtype_of_sealed_class
final class _Snapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this._data);
  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}

// ignore: subtype_of_sealed_class
final class _Doc extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Doc({required this.cache, this.server});

  final _Outcome cache;
  final _Outcome? server;
  final List<Source> reads = [];

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    final source = options?.source ?? Source.serverAndCache;
    reads.add(source);
    final outcome = switch (source) {
      Source.cache => cache,
      Source.server => server ?? (throw StateError('unexpected server read')),
      Source.serverAndCache => throw StateError('unexpected default read'),
    };
    return switch (outcome) {
      _Exists(:final data) => _Snapshot(data),
      _Absent() => _Snapshot(null),
      _Fails(:final code) => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: code,
      ),
    };
  }
}

void main() {
  const stored = {'kind': 'learn'};

  test('a cache hit is returned without a server read', () async {
    final doc = _Doc(cache: const _Exists(stored));
    expect(await readExistingForCreate(doc), stored);
    expect(doc.reads, [Source.cache]);
  });

  test('a cache miss falls through to the server: a REMOTE-ONLY existing '
      'document is found', () async {
    final doc = _Doc(
      cache: const _Fails('unavailable'),
      server: const _Exists(stored),
    );
    expect(await readExistingForCreate(doc), stored);
    expect(doc.reads, [Source.cache, Source.server]);
  });

  test('a cached absence is confirmed against the server', () async {
    final doc = _Doc(cache: const _Absent(), server: const _Exists(stored));
    expect(await readExistingForCreate(doc), stored);
  });

  test(
    'absent in cache and on the server → null (create may proceed)',
    () async {
      final doc = _Doc(
        cache: const _Fails('unavailable'),
        server: const _Absent(),
      );
      expect(await readExistingForCreate(doc), isNull);
    },
  );

  test('offline (server unavailable) → null: the create stays queueable and '
      'the AD-46 rules guard at sync time', () async {
    final doc = _Doc(
      cache: const _Fails('unavailable'),
      server: const _Fails('unavailable'),
    );
    expect(await readExistingForCreate(doc), isNull);
  });

  for (final code in ['internal', 'permission-denied', 'data-loss']) {
    test(
      'a cache failure ($code) is rethrown, never treated as a miss',
      () async {
        final doc = _Doc(cache: _Fails(code), server: const _Absent());
        await expectLater(
          readExistingForCreate(doc),
          throwsA(isA<FirebaseException>().having((e) => e.code, 'code', code)),
        );
        expect(doc.reads, [Source.cache]);
      },
    );

    test(
      'a server failure ($code) is rethrown, never treated as absent',
      () async {
        final doc = _Doc(
          cache: const _Fails('unavailable'),
          server: _Fails(code),
        );
        await expectLater(
          readExistingForCreate(doc),
          throwsA(isA<FirebaseException>().having((e) => e.code, 'code', code)),
        );
      },
    );
  }
}
