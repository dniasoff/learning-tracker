// DNI-471 (story 1.9) AC-5 — an owner learning batch queued OFFLINE lands
// atomically on reconnect (AD-29 instrumented evidence, AD-54 "an
// instrumented test that an offline batch lands atomically").
//
// What it proves, against the REAL cloud_firestore SDK and the Firestore +
// Auth emulators running the repo's real `firestore.rules`:
//   1. A batch carrying learning events, their `pts_{eventId}` points
//      entries, one AD-38 governed doc (a sub-track) and its `change_log`
//      entry is accepted locally while the network is disabled, every member
//      is served from cache with `hasPendingWrites == true`, and NOTHING of
//      it is on the server.
//   2. After `enableNetwork()` the batch commits, and every server read a
//      second device performs (each read is a transaction-consistent
//      snapshot of all members) sees either none or all of the members —
//      never a partial commit. The final server state is complete and
//      internally consistent (pts_ ids bind to their events, the sub-track's
//      `last_change_id` names the entry, actor is the caller).
//   3. All-or-nothing in the failure direction: a queued batch with one
//      member the rules reject (a governed doc whose change_log entry is
//      missing) lands NOTHING, including its otherwise-valid event and pts_.
//
// Fakes cannot prove this: fake_cloud_firestore has no network, no pending
// writes and no rules (AD-29).
//
// Run (from learning_tracker/, Android emulator booted):
//   firebase emulators:exec --only firestore,auth --project demo-offline-batch \
//     "flutter test integration_test/learning_event_offline_batch_test.dart -d emulator-5554"
//
// Uses NAMED apps (the default app is auto-registered from
// google-services.json on Android — see firestore_offline_probe_test.dart)
// and placeholder options; the emulator only checks `projectId`, which must
// match `--project` because firebase.json sets singleProjectMode.
//
// Writes go straight through the SDK on purpose: this is SDK/rules evidence
// for the batch SHAPE that LearningCommands (DNI-469/DNI-470) emits, not a
// test of the command layer, which is not on dev yet.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/core/time/ulid.dart';

/// Android emulator alias for the host loopback (firebase.json ports).
const _emulatorHost = '10.0.2.2';
const _firestorePort = 8080;
const _authPort = 9099;
const _projectId = 'demo-offline-batch';
const _profileId = 'p1';

FirebaseOptions _options() => const FirebaseOptions(
  apiKey: 'placeholder-api-key',
  appId: '1:000000000000:android:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: _projectId,
);

Future<(FirebaseFirestore, FirebaseAuth)> _device(String name) async {
  final app = await Firebase.initializeApp(name: name, options: _options());
  final db = FirebaseFirestore.instanceFor(app: app);
  db.useFirestoreEmulator(_emulatorHost, _firestorePort);
  db.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 20 * 1024 * 1024,
  );
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator(_emulatorHost, _authPort);
  return (db, auth);
}

/// One owner learning batch: [eventCount] learn events + their pts_ entries,
/// one sub-track (governed, AD-38) + its change_log entry. When
/// [withChangeLog] is false the governed doc's entry is omitted, which the
/// rules must reject — taking the whole batch down with it.
class _OwnerBatch {
  _OwnerBatch(this.profile, this.actor, {int eventCount = 2})
    : eventIds = List.generate(eventCount, (_) => newUlid()),
      subTrackId = newUlid(),
      changeId = newUlid();

  final DocumentReference<Map<String, dynamic>> profile;
  final Map<String, dynamic> actor;
  final List<String> eventIds;
  final String subTrackId;
  final String changeId;

  // A fixed past instant: retry payloads never carry a freshly stamped time
  // (AD-46) and AD-54's skew rule only bounds the future.
  final Timestamp recordedAt = Timestamp.fromDate(DateTime.utc(2026, 9, 1, 8));

  DocumentReference<Map<String, dynamic>> event(String id) =>
      profile.collection('learning_events').doc(id);
  DocumentReference<Map<String, dynamic>> points(String id) =>
      profile.collection('points_ledger').doc('pts_$id');
  DocumentReference<Map<String, dynamic>> get subTrack =>
      profile.collection('sub_tracks').doc(subTrackId);
  DocumentReference<Map<String, dynamic>> get changeLog =>
      profile.collection('change_log').doc(changeId);

  List<DocumentReference<Map<String, dynamic>>> refs({
    bool withChangeLog = true,
  }) => [
    for (final id in eventIds) ...[event(id), points(id)],
    subTrack,
    if (withChangeLog) changeLog,
  ];

  WriteBatch build(FirebaseFirestore db, {bool withChangeLog = true}) {
    final batch = db.batch();
    for (var i = 0; i < eventIds.length; i++) {
      final id = eventIds[i];
      batch.set(event(id), {
        'kind': 'learn',
        'curriculum_id': 'shas',
        'ref': 'Berakhot.${i + 2}a',
        'source': 'main',
        'date_state': 'dated',
        'learned_on': '2026-09-01',
        'stage': 1,
        'recorded_at': recordedAt,
        'actor': actor,
      });
      batch.set(points(id), {
        'event_id': id,
        'points': 10,
        'created_at': recordedAt,
      });
    }
    batch.set(subTrack, {
      'curriculum_id': 'shas',
      'name': 'Morning seder',
      'type': 'ongoing',
      'window_start': '2026-09-01',
      'window_end': null,
      'rate_per_week': 5,
      'weeks_per_year': 48,
      'learns_on_shabbos': false,
      'ground': [
        {'level': 'masechta', 'ref': 'Berakhot'},
      ],
      'last_change_id': changeId,
    }, SetOptions(merge: true));
    if (withChangeLog) {
      batch.set(changeLog, {
        'entity': 'subTrack',
        'entity_id': subTrackId,
        'action_id': changeId,
        'before': <String, dynamic>{},
        'after': {'sub_tracks/$subTrackId.name': 'Morning seder'},
        'at': recordedAt,
        'actor': actor,
      });
    }
    return batch;
  }
}

/// How many of [refs] exist on the SERVER, read inside one transaction so
/// the count comes from a single consistent snapshot.
Future<int> _serverCount(
  FirebaseFirestore db,
  List<DocumentReference<Map<String, dynamic>>> refs,
) => db.runTransaction<int>((tx) async {
  var n = 0;
  for (final ref in refs) {
    if ((await tx.get(ref)).exists) n++;
  }
  return n;
});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore deviceA; // goes offline and queues the batch
  late FirebaseFirestore deviceB; // stays online and watches the server
  late DocumentReference<Map<String, dynamic>> profileA;
  late DocumentReference<Map<String, dynamic>> profileB;
  late Map<String, dynamic> actor;

  setUpAll(() async {
    final (dbA, authA) = await _device('offline-batch-a');
    final (dbB, authB) = await _device('offline-batch-b');
    deviceA = dbA;
    deviceB = dbB;
    // Same account on both devices (email/password, so device B can sign
    // in as the same uid; anonymous sign-in would mint a second uid).
    final email = 'offline-batch-${newUlid().toLowerCase()}@example.com';
    const password = 'offline-batch-pw';
    final cred = await authA.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await authB.signInWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    actor = {'uid': uid, 'role': 'parent', 'display_name': 'Abba'};
    profileA = deviceA
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(_profileId);
    profileB = deviceB
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(_profileId);
  });

  tearDown(() async {
    await deviceA.enableNetwork();
  });

  testWidgets('owner batch queued offline commits atomically after reconnect', (
    tester,
  ) async {
    final batch = _OwnerBatch(profileA, actor);
    final refsA = batch.refs();
    final refsB = [for (final r in refsA) deviceB.doc(r.path)];
    expect(refsA, hasLength(6)); // 2 events + 2 pts_ + sub-track + entry

    await deviceA.disableNetwork();
    // The commit future only completes on server ack, so it is held, not
    // awaited, while offline.
    final commit = batch.build(deviceA).commit();

    // Pending locally: every member is in the local view with pending
    // writes. The batch is applied to the local view asynchronously over the
    // platform channel, so wait for each member's first local snapshot
    // rather than racing a cache-only get against it.
    for (final ref in refsA) {
      final snap = await ref
          .snapshots(includeMetadataChanges: true)
          .firstWhere((s) => s.exists)
          .timeout(const Duration(seconds: 10));
      expect(snap.exists, isTrue, reason: '${ref.path} queued locally');
      expect(
        snap.metadata.hasPendingWrites,
        isTrue,
        reason: '${ref.path} pending',
      );
    }
    // ...and nothing has reached the server.
    expect(await _serverCount(deviceB, refsB), 0);

    // Watch the server from device B across the reconnect: every
    // consistent snapshot must hold none or all of the batch.
    final observed = <int>[];
    var watching = true;
    final watcher = () async {
      while (watching) {
        observed.add(await _serverCount(deviceB, refsB));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }();

    // Let the watcher record at least two pre-reconnect snapshots so the
    // trace spans the transition, then reconnect device A.
    while (observed.length < 2) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await deviceA.enableNetwork();
    await commit.timeout(const Duration(seconds: 30));
    final settled = observed.length;
    while (observed.length < settled + 2) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    watching = false;
    await watcher;

    // Evidence line for the AD-29 record (counts per consistent snapshot).
    // ignore: avoid_print
    print('OFFLINE_BATCH_SERVER_COUNTS :: $observed');
    expect(observed, isNotEmpty);
    expect(
      observed.every((n) => n == 0 || n == refsB.length),
      isTrue,
      reason: 'partial commit observed: $observed',
    );
    expect(observed.first, 0);
    expect(observed.last, refsB.length);

    // Final server state is complete and internally consistent.
    for (final id in batch.eventIds) {
      final event = await profileB
          .collection('learning_events')
          .doc(id)
          .get(const GetOptions(source: Source.server));
      final points = await profileB
          .collection('points_ledger')
          .doc('pts_$id')
          .get(const GetOptions(source: Source.server));
      expect(event.data()!['actor'], actor);
      expect(points.data()!['event_id'], id);
    }
    final subTrack = await profileB
        .collection('sub_tracks')
        .doc(batch.subTrackId)
        .get(const GetOptions(source: Source.server));
    final entry = await profileB
        .collection('change_log')
        .doc(batch.changeId)
        .get(const GetOptions(source: Source.server));
    expect(subTrack.data()!['last_change_id'], batch.changeId);
    expect(entry.data()!['entity'], 'subTrack');
    expect(entry.data()!['entity_id'], batch.subTrackId);

    // Device A's cache has caught up: nothing is pending any more.
    for (final ref in refsA) {
      final snap = await ref.get(const GetOptions(source: Source.cache));
      expect(snap.metadata.hasPendingWrites, isFalse);
    }
  });

  testWidgets(
    'a queued batch with one rejected member lands nothing on reconnect',
    (tester) async {
      final batch = _OwnerBatch(profileA, actor, eventCount: 1);
      final refsB = [
        for (final r in batch.refs(withChangeLog: false)) deviceB.doc(r.path),
      ];

      await deviceA.disableNetwork();
      // The governed sub-track has no change_log entry → the AD-38 owner
      // rule rejects it, and with it the whole batch.
      final commit = batch.build(deviceA, withChangeLog: false).commit();
      await deviceA.enableNetwork();

      await expectLater(
        commit.timeout(const Duration(seconds: 30)),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      expect(
        await _serverCount(deviceB, refsB),
        0,
        reason: 'the valid event and pts_ must not land without the batch',
      );
    },
  );
}
