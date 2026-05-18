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
    group('cloud_firestore importer quarantine', () {
      test('firestore_gateway_impl.dart is the canonical importer; no new '
          'leaks outside the documented transition allowlist', () {
        final libDir = Directory('lib');
        expect(
          libDir.existsSync(),
          isTrue,
          reason: 'must run from learning_tracker/ working dir',
        );

        // The canonical importer — all other files must be in canonicalZone
        // or be an offender. `firestore_instance_provider.dart` lives in
        // `core/sync/` (the allowed zone) and provides the Riverpod-level
        // FirebaseFirestore instance; it is a sanctioned second importer.
        const canonical = 'core/sync/firestore_gateway_impl.dart';
        const canonicalZone = <String>{
          canonical,
          'core/sync/providers/firestore_instance_provider.dart',
        };

        final offenders = <String>[];
        File? canonicalFile;
        final importPattern = RegExp(
          r"""^\s*import\s+['"](package:cloud_firestore/cloud_firestore\.dart)['"]""",
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
          if (canonicalZone.contains(rel)) continue;
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
              'DNI-333 AC: only files in core/sync/ may import '
              'cloud_firestore. New offenders: $offenders',
        );
      });
    });

    group('OutboxPushPipeline single-flight', () {
      test(
        'overlapping calls for the same entity kind are serialized',
        () async {
          final gateway = _RecordingGateway();
          final pipeline = OutboxPushPipeline(gateway: gateway);
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
            if (calls == 1) throw StateError('boom');
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

    group('PullPipeline pagination + dispatch', () {
      test(
        'paginates through the gateway and dispatches each page to MergeDispatcher',
        () async {
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
          final pipeline = PullPipeline(
            gateway: gateway,
            dispatcher: dispatcher,
          );
          await pipeline.pullCompletions(profileId: 7, pageSize: 2);
          expect(gateway.fetchCalls.length, 3);
          expect(gateway.fetchCalls[0].cursor, isNull);
          expect(gateway.fetchCalls[1].cursor, equals({'id': '2'}));
          expect(gateway.fetchCalls[2].cursor, equals({'id': '3'}));
          expect(dispatcher.dispatched.length, 2);
          expect(dispatcher.dispatched[0].kind, 'completion');
          expect(dispatcher.dispatched[0].rows, hasLength(2));
          expect(dispatcher.dispatched[1].rows, hasLength(1));
        },
      );

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
    String? docId,
  }) async {
    if (onPushCompletion != null) await onPushCompletion!(data);
  }

  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> items,
  }) async {
    for (final item in items) {
      if (onPushCompletion != null) await onPushCompletion!(item.payload);
    }
    return items.map((e) => e.entityKey).toList();
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
  @override
  Future<void> pushGoal({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushUiPreferences({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushAccountProfile({required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushCurriculumImportMetadata({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> deleteUserData(String uid) async {}
  @override
  Future<void> pushDiagnosticLog({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushAccountUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Stream<List<Map<String, dynamic>>> listenToCollection({
    required int profileId,
    required String collection,
  }) => const Stream.empty();
  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();
  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async =>
      const <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => null;
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
    if (_index >= pages.length)
      return const FirestorePage(rows: <Map<String, dynamic>>[]);
    final rows = pages[_index++];
    return FirestorePage(rows: rows);
  }

  @override
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
    String? docId,
  }) async {}
  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> items,
  }) async => items.map((e) => e.entityKey).toList();
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
  @override
  Future<void> pushGoal({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushUiPreferences({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushAccountProfile({required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushCurriculumImportMetadata({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> deleteUserData(String uid) async {}
  @override
  Future<void> pushDiagnosticLog({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Future<void> pushAccountUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}
  @override
  Stream<List<Map<String, dynamic>>> listenToCollection({
    required int profileId,
    required String collection,
  }) => const Stream.empty();
  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();
  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async =>
      const <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => null;
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
