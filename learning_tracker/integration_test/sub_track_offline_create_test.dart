// DNI-496 (story 2.5) AC-5 / AC-7 — ongoing sub-track creates made OFFLINE
// through the real `SubTrackCommands` + `FirestoreSubTrackRepository`, on
// the Firestore emulator with the repo's real firestore.rules:
//
// 1. Two offline devices each add a fifth ongoing sub-track. Both pass the
//    local AD-45 check and are queued; a sixth on one device is refused
//    before any write (nothing cached, nothing pending). Both creates sync,
//    so the server holds six; the cap still refuses a later create, while an
//    edit of one of the six is accepted (AD-45: excess is tolerated).
// 2. A queued create the rules refuse for good is rolled back alone: the
//    local cache drops it, unrelated edits queued before and after it land,
//    it surfaces as a "not saved — retry" pending failure, and a retry of
//    a still-invalid batch is refused at once without landing anything.
//
// The host-run twin (real commands over in-memory ports, plus the hub and
// form flow with a successful retry) is
// test/integration/sub_track_offline_create_test.dart. This file needs a
// device or emulator; per ruling B12 it runs at release verification and in
// the continue-on-error emulator CI job, not in `flutter test`.
//
// Run (from learning_tracker/, Android emulator booted):
//   firebase emulators:exec --only firestore,auth --project demo-offline-batch \
//     "flutter test integration_test/sub_track_offline_create_test.dart -d emulator-5554"

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ongoing_sub_track_form_validation.dart';

/// Android emulator alias for the host loopback (firebase.json ports).
const _emulatorHost = '10.0.2.2';
const _firestorePort = 8080;
const _authPort = 9099;
const _projectId = 'demo-offline-batch';
const _profileId = '01JSB0TRACK0FF11NE00000002';
const _today = '2026-10-01';

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

/// No calendar program on any curriculum (AD-45 needs only "no program").
final class _NoProgramIntent implements GovernedIntentRepository {
  @override
  Stream<LearnerIntent> watch(LearnerScope scope) => Stream.value(
    LearnerIntent(
      settings: const LearnerSettings(profileId: _profileId, timeZone: 'UTC'),
      mainTracks: const {},
      goals: const {},
    ),
  );
}

/// The draft the ongoing form writes for [name] on [curriculumId]: no
/// dates (starts today, open end), 5 leaf units a week, 52 weeks.
SubTrackDraft _formDraft(String curriculumId, String name) =>
    validateOngoingSubTrackForm(
      OngoingSubTrackFormInput(
        name: name,
        rateText: '5',
        weeksText: '52',
        start: null,
        end: null,
        learnsOnShabbos: false,
      ),
      today: _today,
    ).values!.toDraft(curriculumId);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore deviceA;
  late FirebaseFirestore deviceB;
  late LearnerScope scope;
  late FirestoreSubTrackRepository repoA;
  late FirestoreSubTrackRepository repoB;
  late SubTrackCommands commandsA;
  late SubTrackCommands commandsB;

  SubTrackCommands commandsFor(String uid, SubTrackRepository repo) =>
      SubTrackCommands(
        scope: scope,
        actor: Actor(uid: uid, role: ActorRole.parent, displayName: 'Abba'),
        subTracks: repo,
        intent: _NoProgramIntent(),
        today: () => _today,
        // A fixed past instant: AD-54's skew rule bounds only the future.
        nowUtc: () => DateTime.utc(2026, 10, 1, 8),
        newId: newUlid,
        ackTimeout: const Duration(seconds: 1),
      );

  setUpAll(() async {
    final (dbA, authA) = await _device('sub-track-create-a');
    final (dbB, authB) = await _device('sub-track-create-b');
    deviceA = dbA;
    deviceB = dbB;
    final email = 'sub-track-create-${newUlid().toLowerCase()}@example.com';
    const password = 'sub-track-create-pw';
    final cred = await authA.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await authB.signInWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;
    scope = LearnerScope(ownerUid: uid, profileId: _profileId);
    repoA = FirestoreSubTrackRepository(firestore: deviceA);
    repoB = FirestoreSubTrackRepository(firestore: deviceB);
    commandsA = commandsFor(uid, repoA);
    commandsB = commandsFor(uid, repoB);
  });

  tearDown(() async {
    await deviceA.enableNetwork();
    await deviceB.enableNetwork();
  });

  String docPath(String collection, String id) =>
      'users/${scope.ownerUid}/learner_profiles/${scope.profileId}/'
      '$collection/$id';

  Future<List<SubTrack>> liveOn(
    FirestoreSubTrackRepository repo,
    String curriculumId, {
    required int count,
  }) async {
    final ready = await repo
        .watchActiveByCurriculum(scope, curriculumId)
        .firstWhere(
          (r) => r is CompleteReadReady<SubTrack> && r.items.length == count,
        )
        .timeout(const Duration(seconds: 30));
    return (ready as CompleteReadReady<SubTrack>).items;
  }

  testWidgets('two offline fifth creates both sync; a sixth is refused '
      'locally; the excess is tolerated', (tester) async {
    const curriculum = 'mishnayos';
    // Four ongoing sub-tracks land online; both devices cache them.
    for (var i = 1; i <= 4; i++) {
      final r = await commandsA.createSubTrack(
        _formDraft(curriculum, 'Rebbe $i'),
      );
      expect(r, isA<CaptureSuccess>());
    }
    await deviceA.waitForPendingWrites();
    await liveOn(repoA, curriculum, count: 4);
    await liveOn(repoB, curriculum, count: 4);

    await deviceA.disableNetwork();
    await deviceB.disableNetwork();
    final fromA = await commandsA.createSubTrack(
      _formDraft(curriculum, 'Chavrusa A'),
    );
    final fromB = await commandsB.createSubTrack(
      _formDraft(curriculum, 'Chavrusa B'),
    );
    expect((fromA as CaptureSuccess).queued, isTrue);
    expect((fromB as CaptureSuccess).queued, isTrue);

    // Device A holds five locally: the sixth is refused with no write.
    final sixthId = newUlid();
    final sixth = await commandsA.createSubTrack(
      _formDraft(curriculum, 'Sixth'),
      subTrackId: sixthId,
    );
    expect(sixth, isA<CaptureRejected>());
    expect(
      (sixth as CaptureRejected).violations.map((v) => v.limit),
      contains(SubTrackLimit.ongoingLimit),
    );
    final cached = await deviceA
        .doc(docPath('sub_tracks', sixthId))
        .get(const GetOptions(source: Source.cache))
        .then<bool>((s) => s.exists, onError: (_) => false);
    expect(cached, isFalse, reason: 'nothing written for the sixth');

    await deviceA.enableNetwork();
    await deviceB.enableNetwork();
    await deviceA.waitForPendingWrites().timeout(const Duration(seconds: 30));
    await deviceB.waitForPendingWrites().timeout(const Duration(seconds: 30));

    // Both creates landed: six on the server, read back on each device.
    final six = await liveOn(repoA, curriculum, count: 6);
    await liveOn(repoB, curriculum, count: 6);
    expect(
      ongoingSubTracksInUse(six, curriculumId: curriculum, today: _today),
      6,
    );

    // The cap still governs creates; an edit of one of six is accepted.
    final seventh = await commandsA.createSubTrack(
      _formDraft(curriculum, 'Seventh'),
    );
    expect(seventh, isA<CaptureRejected>());
    final edit = await commandsA.editSubTrack(
      six.first.id,
      const SubTrackEdit(name: 'Renamed at the cap'),
    );
    expect(edit, isA<CaptureSuccess>());
  });

  testWidgets('a queued create the rules refuse rolls back alone; edits '
      'queued around it land; a retry of it is refused', (tester) async {
    const curriculum = 'shas';
    final gemaraId = newUlid();
    final created = await commandsA.createSubTrack(
      _formDraft(curriculum, 'Gemara'),
      subTrackId: gemaraId,
    );
    expect(created, isA<CaptureSuccess>());
    await deviceA.waitForPendingWrites();

    await deviceA.disableNetwork();
    final rename = await commandsA.editSubTrack(
      gemaraId,
      const SubTrackEdit(name: "Gemara b'iyun"),
    );
    // A 201-character name passes the client codec but not the AD-46
    // rules (`isBoundedString(name, 200)`): refused for good on sync.
    final badId = newUlid();
    final bad = await commandsA.createSubTrack(
      _formDraft(curriculum, 'x' * 201),
      subTrackId: badId,
    );
    final rate = await commandsA.editSubTrack(
      gemaraId,
      const SubTrackEdit(ratePerWeek: 7),
    );
    for (final r in [rename, bad, rate]) {
      expect((r as CaptureSuccess).queued, isTrue);
    }
    final badChangeId = (bad as CaptureSuccess).changeIds.single;
    final local = await deviceA
        .doc(docPath('sub_tracks', badId))
        .get(const GetOptions(source: Source.cache));
    expect(local.exists, isTrue, reason: 'cache shows the queued create');

    await deviceA.enableNetwork();
    final pending = await commandsA
        .watchPendingFailures()
        .firstWhere((l) => l.any((f) => f.changeIds.contains(badChangeId)))
        .timeout(const Duration(seconds: 30));
    expect(
      pending.singleWhere((f) => f.changeIds.contains(badChangeId)).id,
      badChangeId,
    );
    await deviceA.waitForPendingWrites().timeout(const Duration(seconds: 30));

    // Rolled back locally and absent on the server.
    final afterLocal = await deviceA
        .doc(docPath('sub_tracks', badId))
        .get(const GetOptions(source: Source.cache))
        .then<bool>((s) => s.exists, onError: (_) => false);
    expect(afterLocal, isFalse, reason: 'the refused create is rolled back');
    final onServer = await deviceB
        .doc(docPath('sub_tracks', badId))
        .get(const GetOptions(source: Source.server));
    expect(onServer.exists, isFalse);

    // The unrelated edits queued before and after it landed.
    final gemara = await deviceB
        .doc(docPath('sub_tracks', gemaraId))
        .get(const GetOptions(source: Source.server));
    expect(gemara.data()!['name'], "Gemara b'iyun");
    expect(gemara.data()!['rate_per_week'], 7);

    // Retrying the identical, still-invalid batch online is refused at
    // once and lands nothing.
    final retried = await commandsA.retry(badChangeId);
    expect(retried, isA<CaptureRejected>());
    final stillAbsent = await deviceB
        .doc(docPath('sub_tracks', badId))
        .get(const GetOptions(source: Source.server));
    expect(stillAbsent.exists, isFalse);
  });
}
