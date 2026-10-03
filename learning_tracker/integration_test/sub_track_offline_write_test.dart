// DNI-492 (story 2.1) AC-6 — a sub-track create or edit made OFFLINE through
// the real `SubTrackCommands` + `FirestoreSubTrackRepository` is queued as
// one doc + one change_log entry (2 writes, 2 Rules access calls), visible at
// once from the local cache, lands on reconnect without loss, and a queued
// batch the rules refuse for good surfaces as the AD-54 per-item
// "not saved — retry" entry.
//
// Fakes cannot prove this: fake_cloud_firestore has no network, no pending
// writes and no rules (AD-29). The unit-level shape is covered by
// test/features/learning/domain/commands/learning_commands_sub_track_test.dart
// and test/data/repositories/firestore_sub_track_repository_test.dart.
//
// Run (from learning_tracker/, Android emulator booted):
//   firebase emulators:exec --only firestore,auth --project demo-offline-batch \
//     "flutter test integration_test/sub_track_offline_write_test.dart -d emulator-5554"
//
// Same harness as learning_event_offline_batch_test.dart: NAMED apps,
// placeholder options, the repo's real firestore.rules on the emulator.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';

/// Android emulator alias for the host loopback (firebase.json ports).
const _emulatorHost = '10.0.2.2';
const _firestorePort = 8080;
const _authPort = 9099;
const _projectId = 'demo-offline-batch';
const _profileId = '01JSB0TRACK0FF11NE00000001';

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

/// A self-paced `shas` main track with no calendar program (the
/// governed-intent repository is DNI-470's; this test needs only "a main
/// track, no program" — a create for a curriculum with no main track is
/// refused).
final class _NoProgramIntent implements GovernedIntentRepository {
  @override
  Stream<LearnerIntent> watch(LearnerScope scope) => Stream.value(
    LearnerIntent(
      settings: const LearnerSettings(profileId: _profileId, timeZone: 'UTC'),
      mainTracks: {
        'shas': MainTrackIntent(
          curriculumId: 'shas',
          track: MainTrack(curriculumId: 'shas', state: MainTrackState.active),
        ),
      },
      goals: const {},
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore deviceA; // goes offline
  late FirebaseFirestore deviceB; // watches the server
  late LearnerScope scope;
  late SubTrackCommands commands;
  late FirestoreSubTrackRepository repoA;

  setUpAll(() async {
    final (dbA, authA) = await _device('sub-track-offline-a');
    final (dbB, authB) = await _device('sub-track-offline-b');
    deviceA = dbA;
    deviceB = dbB;
    final email = 'sub-track-offline-${newUlid().toLowerCase()}@example.com';
    const password = 'sub-track-offline-pw';
    final cred = await authA.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await authB.signInWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    scope = LearnerScope(ownerUid: uid, profileId: _profileId);
    repoA = FirestoreSubTrackRepository(firestore: deviceA);
    commands = SubTrackCommands(
      scope: scope,
      actor: Actor(uid: uid, role: ActorRole.parent, displayName: 'Abba'),
      subTracks: repoA,
      intent: _NoProgramIntent(),
      today: () => '2026-10-01',
      // A fixed past instant: AD-54's skew rule bounds only the future.
      nowUtc: () => DateTime.utc(2026, 10, 1, 8),
      newId: newUlid,
      ackTimeout: const Duration(seconds: 1),
    );
  });

  tearDown(() => deviceA.enableNetwork());

  DocumentReference<Map<String, dynamic>> serverDoc(String path) =>
      deviceB.doc(path);

  String profilePath() =>
      'users/${scope.ownerUid}/learner_profiles/${scope.profileId}';

  testWidgets('an offline create is queued, cache-visible and syncs', (
    tester,
  ) async {
    final id = newUlid();
    await deviceA.disableNetwork();
    final result = await commands.createSubTrack(
      const SubTrackDraft(
        curriculumId: 'shas',
        name: 'Night seder',
        type: SubTrackType.ongoing,
        windowStart: '2026-09-01',
        ratePerWeek: 5,
        weeksPerYear: 40,
        learnsOnShabbos: false,
        ground: [NodeEntry(level: 'masechta', ref: 'Berakhot')],
      ),
      subTrackId: id,
    );
    expect(result, isA<CaptureSuccess>());
    final success = result as CaptureSuccess;
    expect(success.queued, isTrue);
    final entryId = success.changeIds.single;

    // Visible at once from the local cache through the curriculum view.
    final local = await repoA
        .watchActiveByCurriculum(scope, 'shas')
        .firstWhere(
          (r) =>
              r is CompleteReadReady<SubTrack> &&
              r.items.any((t) => t.id == id),
        )
        .timeout(const Duration(seconds: 10));
    expect(local, isA<CompleteReadReady<SubTrack>>());

    // Exactly the doc and its entry are pending; nothing is on the server.
    final docPath = '${profilePath()}/sub_tracks/$id';
    final entryPath = '${profilePath()}/change_log/$entryId';
    for (final path in [docPath, entryPath]) {
      final snap = await deviceA
          .doc(path)
          .snapshots(includeMetadataChanges: true)
          .firstWhere((s) => s.exists)
          .timeout(const Duration(seconds: 10));
      expect(snap.metadata.hasPendingWrites, isTrue, reason: path);
      final server = await serverDoc(
        path,
      ).get(const GetOptions(source: Source.server));
      expect(server.exists, isFalse, reason: '$path must not be on server');
    }

    await deviceA.enableNetwork();
    await deviceA.waitForPendingWrites().timeout(const Duration(seconds: 30));

    final doc = await serverDoc(
      docPath,
    ).get(const GetOptions(source: Source.server));
    final entry = await serverDoc(
      entryPath,
    ).get(const GetOptions(source: Source.server));
    expect(doc.data()!['last_change_id'], entryId);
    expect(entry.data()!['entity'], 'subTrack');
    expect(entry.data()!['entity_id'], id);
    expect(
      (entry.data()!['before'] as Map).values,
      everyElement(isNull),
      reason: 'a create logs null before per field',
    );
  });

  testWidgets(
    'a queued edit the rules refuse becomes a "not saved — retry" entry',
    (tester) async {
      final id = newUlid();
      // Land a sub-track online first.
      final created = await commands.createSubTrack(
        const SubTrackDraft(
          curriculumId: 'shas',
          name: 'Gemara',
          type: SubTrackType.ongoing,
          windowStart: '2026-09-01',
          ratePerWeek: 3,
          weeksPerYear: 40,
          learnsOnShabbos: false,
          ground: [NodeEntry(level: 'masechta', ref: 'Shabbat')],
        ),
        subTrackId: id,
      );
      expect(created, isA<CaptureSuccess>());
      await deviceA.waitForPendingWrites();

      await deviceA.disableNetwork();
      // A 201-character name passes the client codec but not the AD-46
      // rules (`isBoundedString(name, 200)`): rejected for good on sync.
      final edited = await commands.editSubTrack(
        id,
        SubTrackEdit(name: 'x' * 201),
      );
      expect((edited as CaptureSuccess).queued, isTrue);
      await deviceA.enableNetwork();

      final pending = await commands
          .watchPendingFailures()
          .firstWhere((l) => l.isNotEmpty)
          .timeout(const Duration(seconds: 30));
      expect(pending.single.changeIds, edited.changeIds);
      expect(pending.single.reason, PendingFailureReason.permissionDenied);

      final server = await serverDoc(
        '${profilePath()}/sub_tracks/$id',
      ).get(const GetOptions(source: Source.server));
      expect(server.data()!['name'], 'Gemara', reason: 'nothing landed');
    },
  );
}
