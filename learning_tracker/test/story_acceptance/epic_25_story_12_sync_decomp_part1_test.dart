/// Story acceptance tests for Epic 25 — Story 25.12 (DNI-333):
/// SyncEngine decomposition Part 1 — FirestoreGateway, PushPipeline, PullPipeline.
///
/// Validates the structural and behavioural acceptance criteria called out
/// in Linear DNI-333:
///   1. Only one file in `lib/` imports `package:cloud_firestore/cloud_firestore.dart`
///      (the new `core/sync/firestore_gateway_impl.dart`) — i.e. legacy
///      Firestore importers are gone or quarantined behind the gateway.
///   2. `OutboxPushPipeline` drains the outbox via [PushPipeline] methods
///      with single-flight semantics per entityKind (no overlapping pushes
///      for the same kind).
///   3. `PullPipeline` paginates Firestore queries via the gateway and
///      dispatches batches to a [MergeDispatcher].
@Tags(['epic_25'])
library;

import 'dart:async';
import 'dart:io';

import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
import 'package:learning_tracker/core/sync/push_pipeline_impl.dart';
import 'package:test/test.dart';

void main() {
  group('Story 25.12 — SyncEngine decomp Part 1', tags: ['story_25_12'], () {
    // ── AC 1: cloud_firestore quarantine ──────────────────────────────────
    //
    // The strict target is that `core/sync/firestore_gateway_impl.dart` is
    // the *only* file importing `cloud_firestore`. DNI-333 lands the
    // canonical importer + the gateway interface; the existing 5 legacy
    // importers (`features/sync/data/*`, `features/auth/...`, the firebase
    // providers, etc.) are retired by DNI-334/335 and the auth+lifecycle
    // stories. Until those land, an explicit allowlist documents the
    // transitional state — any *new* Firestore import outside the
    // allowlist fails the test.

    group('cloud_firestore importer quarantine', () {
      test('firestore_gateway_impl.dart is the canonical importer; no new '
          'leaks outside the documented transition allowlist', () {
        final libDir = Directory('lib');
        expect(
          libDir.existsSync(),
          isTrue,
          reason: 'must run from learning_tracker/ working dir',
        );

        const canonical = 'core/sync/firestore_gateway_impl.dart';
        // Pre-DNI-333 importers slated for removal in 25.13/25.14 (and
        // adjacent auth/profile stories). DO NOT extend this list.
        const transitionalAllowlist = <String>{
          'features/sync/data/firestore_data_source.dart',
          'features/sync/data/sync_engine.dart',
          'features/auth/domain/services/account_lifecycle_service.dart',
          'features/onboarding/domain/services/user_profile_service.dart',
          'features/settings/presentation/utils/send_logs_service.dart',
          'core/providers/firebase_providers.dart',
        };

        final offenders = <String>[];
        File? canonicalFile;
        final importPattern = RegExp(
          r'''^\s*import\s+['"]package:cloud_firestore/cloud_firestore\.dart['"]''',
          multiLine: true,
        );
        for (final entity in libDir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final source = entity.readAsStringSync();
          if (!importPattern.hasMatch(source)) continue;
          final rel = entity.path
              .replaceFirst(RegExp(r'^\.[\\/]?'), '')
              .replaceAll(r'\', '/')
              .replaceFirst(RegExp('^lib/'), '');
          if (rel == canonical) {
            canonicalFile = entity;
            continue;
          }
          if (transitionalAllowlist.contains(rel)) continue;
          offenders.add(rel);
        }

        expect(
          canonicalFile,
          isNotNull,
          reason:
              'DNI-333: core/sync/firestore_gateway_impl.dart must exist '
              'and import cloud_firestore (it is the canonical importer)',
        );
        expect(
          offenders,
          isEmpty,
          reason:
              'DNI-333 AC: only firestore_gateway_impl.dart and the '
              'documented transitional allowlist may import '
              'cloud_firestore. New offenders: $offenders',
        );
      });
    });

    // ── AC 2: PushPipeline single-flight ─────────────────────────────────

    group('OutboxPushPipeline single-flight', () {
      test(
        'overlapping calls for the same entity kind are serialized',
        () async {
          final gateway = _RecordingGateway();
          final pipeline = OutboxPushPipeline(gateway: gateway);

          // Fire two concurrent completion pushes — the second must wait
          // for the first.
          final order = <String>[];
          gateway.onPushCompletion = (data) async {
            order.add('start:${data['id']}');
            await Future<void>.delayed(const Duration(milliseconds: 10));
            order.add('end:${data['id']}');
          };

          final f1 = pipeline.pushCompletion(
            profileId: 1,
            entityKey: 'a',
            payload: {'id': 'a'},
          );
          final f2 = pipeline.pushCompletion(
            profileId: 1,
            entityKey: 'b',
            payload: {'id': 'b'},
          );
          await Future.wait(<Future<void>>[f1, f2]);

          expect(
            order,
            equals(['start:a', 'end:a', 'start:b', 'end:b']),
            reason: 'same-kind pushes must not overlap',
          );
        },
      );

      test('different entity kinds may push concurrently', () async {
        final gateway = _RecordingGateway();
        final pipeline = OutboxPushPipeline(gateway: gateway);

        final order = <String>[];
        final completionStarted = Completer<void>();
        final streakAllowedToStart = Completer<void>();

        gateway.onPushCompletion = (data) async {
          order.add('completion:start');
          completionStarted.complete();
          await streakAllowedToStart.future;
          order.add('completion:end');
        };
        gateway.onPushStreak = (data) async {
          order.add('streak:start');
          order.add('streak:end');
          streakAllowedToStart.complete();
        };

        final f1 = pipeline.pushCompletion(
          profileId: 1,
          entityKey: 'a',
          payload: {'id': 'a'},
        );
        await completionStarted.future;
        final f2 = pipeline.pushStreak(
          profileId: 1,
          entityKey: 's',
          payload: {'id': 's'},
        );
        await Future.wait(<Future<void>>[f1, f2]);

        expect(
          order,
          equals([
            'completion:start',
            'streak:start',
            'streak:end',
            'completion:end',
          ]),
          reason: 'different kinds run in parallel',
        );
      });

      test(
        'failing push releases the single-flight slot for the next call',
        () async {
          final gateway = _RecordingGateway();
          final pipeline = OutboxPushPipeline(gateway: gateway);

          var calls = 0;
          gateway.onPushCompletion = (data) async {
            calls++;
            if (calls == 1) {
              throw StateError('boom');
            }
          };

          await expectLater(
            pipeline.pushCompletion(
              profileId: 1,
              entityKey: 'a',
              payload: {'id': 'a'},
            ),
            throwsA(isA<StateError>()),
          );
          await pipeline.pushCompletion(
            profileId: 1,
            entityKey: 'b',
            payload: {'id': 'b'},
          );

          expect(calls, 2);
        },
      );
    });

    // ── AC 3: PullPipeline pagination + dispatch ─────────────────────────

    group('PullPipeline pagination + dispatch', () {
      test('paginates through the gateway and dispatches each page to '
          'MergeDispatcher', () async {
        final gateway = _PagingGateway(
          pages: [
            [
              {'id': '1'},
              {'id': '2'},
            ],
            [
              {'id': '3'},
            ],
            <Map<String, dynamic>>[],
          ],
        );
        final dispatcher = _RecordingDispatcher();
        final pipeline = PullPipeline(gateway: gateway, dispatcher: dispatcher);

        await pipeline.pullCompletions(profileId: 7, pageSize: 2);

        // Three fetch calls (two with rows, one empty terminator)
        expect(gateway.fetchCalls.length, 3);
        // Cursor advances each page using the last doc seen.
        expect(gateway.fetchCalls[0].cursor, isNull);
        expect(gateway.fetchCalls[1].cursor, equals({'id': '2'}));
        expect(gateway.fetchCalls[2].cursor, equals({'id': '3'}));

        // Dispatcher receives only non-empty pages.
        expect(dispatcher.dispatched.length, 2);
        expect(dispatcher.dispatched[0].kind, 'completion');
        expect(dispatcher.dispatched[0].rows, hasLength(2));
        expect(dispatcher.dispatched[1].rows, hasLength(1));
      });

      test('pull stops cleanly when the dispatcher signals halt', () async {
        final gateway = _PagingGateway(
          pages: [
            [
              {'id': '1'},
            ],
            [
              {'id': '2'},
            ],
          ],
        );
        final dispatcher = _RecordingDispatcher()..haltAfterFirst = true;
        final pipeline = PullPipeline(gateway: gateway, dispatcher: dispatcher);

        await pipeline.pullCompletions(profileId: 7, pageSize: 1);

        expect(gateway.fetchCalls.length, 1);
        expect(dispatcher.dispatched.length, 1);
      });
    });
  });
}

// ─── Test doubles ────────────────────────────────────────────────────────────

class _RecordingGateway implements FirestoreGateway {
  Future<void> Function(Map<String, dynamic> data)? onPushCompletion;
  Future<void> Function(Map<String, dynamic> data)? onPushStreak;

  @override
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    if (onPushCompletion != null) await onPushCompletion!(data);
  }

  @override
  Future<void> pushStreak({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    if (onPushStreak != null) await onPushStreak!(data);
  }

  @override
  Future<void> pushSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushTrack({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushBookmark({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushNotificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushGamificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushLearnerProfile({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> deleteLearnerProfile(int profileId) async {}

  @override
  Future<void> pushLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushLedgerEntriesBatch({
    required int profileId,
    required List<Map<String, dynamic>> entries,
  }) async {}

  @override
  Future<void> pushProfileProgram({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> removeProfileProgramAssignment({
    required int profileId,
    required String curriculumStorageKey,
  }) async {}

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => const FirestorePage(rows: <Map<String, dynamic>>[]);

  @override
  Future<List<Map<String, dynamic>>> fetchAll({
    required int profileId,
    required String collection,
  }) async => const <Map<String, dynamic>>[];
}

class _FetchCall {
  _FetchCall({required this.collection, required this.cursor});
  final String collection;
  final Map<String, dynamic>? cursor;
}

class _PagingGateway implements FirestoreGateway {
  _PagingGateway({required this.pages});
  final List<List<Map<String, dynamic>>> pages;
  final List<_FetchCall> fetchCalls = [];
  int _index = 0;

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async {
    fetchCalls.add(_FetchCall(collection: collection, cursor: cursor));
    if (_index >= pages.length) {
      return const FirestorePage(rows: <Map<String, dynamic>>[]);
    }
    final rows = pages[_index++];
    return FirestorePage(rows: rows);
  }

  @override
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushStreak({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushTrack({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushBookmark({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushNotificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushGamificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushLearnerProfile({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> deleteLearnerProfile(int profileId) async {}

  @override
  Future<void> pushLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushLedgerEntriesBatch({
    required int profileId,
    required List<Map<String, dynamic>> entries,
  }) async {}

  @override
  Future<void> pushProfileProgram({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> removeProfileProgramAssignment({
    required int profileId,
    required String curriculumStorageKey,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchAll({
    required int profileId,
    required String collection,
  }) async => const <Map<String, dynamic>>[];
}

class _DispatchedPage {
  _DispatchedPage({required this.kind, required this.rows});
  final String kind;
  final List<Map<String, dynamic>> rows;
}

class _RecordingDispatcher implements MergeDispatcher {
  final List<_DispatchedPage> dispatched = [];
  bool haltAfterFirst = false;

  @override
  Future<MergeOutcome> dispatch({
    required int profileId,
    required String kind,
    required List<Map<String, dynamic>> rows,
  }) async {
    dispatched.add(_DispatchedPage(kind: kind, rows: rows));
    return haltAfterFirst ? MergeOutcome.halt : MergeOutcome.continueNext;
  }
}
