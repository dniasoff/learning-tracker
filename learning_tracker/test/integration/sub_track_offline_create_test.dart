// DNI-496 (Story 2.5) AC-5 / AC-7: ongoing creates made offline, run on
// the host through the real `SubTrackCommands` (Story 2.1) over the
// in-memory ports, whose offline mode applies a write to the local cache
// at once and settles it, or reverts it, only on "reconnect" — the same
// latency-compensation contract as Firestore.
//
// - Two offline devices each add a fifth ongoing sub-track: both pass
//   local AD-45 validation and are queued; a sixth on one device is
//   rejected before any write; once both sync the six are tolerated by the
//   engine (AD-45) and the cap still governs later creates.
// - A queued create the server refuses for good is rolled back alone:
//   unrelated queued edits queued before and after it survive, it becomes
//   a "not saved — retry" pending failure, and retry re-sends it.
// - The same, end to end through the hub and the ongoing form: the queued
//   row shows, rolls back with "Your change couldn't be saved." and Retry
//   brings it back (UX-DR-121).
//
// The Firestore-emulator run of the same flow (real rules, real offline
// cache) is integration_test/sub_track_offline_create_test.dart; device
// runs are deferred to release verification (ruling B12).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/ongoing_sub_track_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ongoing_sub_track_form_validation.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ongoing_sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ongoing_sub_track_hub_seam.dart';

import '../helpers/learner_state/c0_fixtures.dart';
import '../helpers/learner_state/engine_fixtures.dart';
import '../helpers/learner_state/in_memory_ports.dart';
import '../helpers/learner_state_fixtures.dart';
import '../helpers/pump_app.dart';

/// `engineAt(10000)` is 2026-09-07 (UTC learner).
const _today = '2026-09-07';

int _seq = 0;

/// Fresh ULIDs that never collide with the seeded ones.
String _newId() => engineUlid(5000 + ++_seq);

LearnerIntent _intent() => LearnerIntent(
  settings: c0Settings,
  mainTracks: {engineCurriculum: engineIntent()},
  goals: const {},
);

/// The draft the ongoing form writes for [name] (no dates: starts today).
SubTrackDraft _formDraft(String name) => validateOngoingSubTrackForm(
  OngoingSubTrackFormInput(
    name: name,
    rateText: '5',
    weeksText: '52',
    start: null,
    end: null,
    learnsOnShabbos: false,
  ),
  today: _today,
).values!.toDraft(engineCurriculum);

SubTrack _ongoing(int id, String name) => SubTrack(
  id: engineUlid(id),
  curriculumId: engineCurriculum,
  name: name,
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 5,
  weeksPerYear: 52,
  learnsOnShabbos: false,
  ground: const [],
  lastChangeId: engineUlid(id + 1000),
);

/// One device: its own local cache and its own commands.
final class _Device {
  _Device(
    LearnerScope scope,
    InMemoryGovernedIntentRepository intent, {
    bool fakeAsync = false,
  }) : repo = InMemorySubTrackRepository() {
    reads = fakeAsync ? _FakeAsyncSafeSubTracks(repo) : repo;
    commands = SubTrackCommands(
      scope: scope,
      actor: parentActor,
      subTracks: reads,
      intent: fakeAsync ? _FakeAsyncSafeIntent(intent) : intent,
      today: () => _today,
      nowUtc: () => engineAt(10000),
      newId: _newId,
      ackTimeout: const Duration(milliseconds: 20),
      readTimeout: const Duration(seconds: 2),
    );
  }

  final InMemorySubTrackRepository repo;

  /// What the app reads and writes through.
  late final SubTrackRepository reads;
  late final SubTrackCommands commands;

  Future<void> dispose() async {
    await commands.dispose();
    await repo.dispose();
  }
}

/// [source] re-emitted without handing back its cancel future. The
/// in-memory fakes' single-read streams return a cancel future that
/// FakeAsync never completes, which would stall `first` / `firstWhere` in
/// the commands under `testWidgets`; production streams are unaffected.
Stream<T> _fakeAsyncSafe<T>(Stream<T> Function() source) {
  StreamSubscription<T>? sub;
  late final StreamController<T> out;
  out = StreamController<T>(
    onListen: () => sub = source().listen(
      out.add,
      onError: out.addError,
      onDone: out.close,
    ),
    onCancel: () => unawaited(sub?.cancel()),
  );
  return out.stream;
}

/// The sub-track fake as a widget test reads it (see [_fakeAsyncSafe]).
final class _FakeAsyncSafeSubTracks implements SubTrackRepository {
  _FakeAsyncSafeSubTracks(this.inner);

  final InMemorySubTrackRepository inner;

  @override
  Stream<CompleteRead<SubTrack>> watchAll(LearnerScope scope) =>
      _fakeAsyncSafe(() => inner.watchAll(scope));

  @override
  Future<void> applyGovernedChange(LearnerScope scope, SubTrackChange change) =>
      inner.applyGovernedChange(scope, change);
}

/// The intent fake as a widget test reads it (see [_fakeAsyncSafe]).
final class _FakeAsyncSafeIntent implements GovernedIntentRepository {
  _FakeAsyncSafeIntent(this.inner);

  final GovernedIntentRepository inner;

  @override
  Stream<LearnerIntent> watch(LearnerScope scope) =>
      _fakeAsyncSafe(() => inner.watch(scope));
}

/// [LearningCommands] whose sub-track commands are the real
/// [SubTrackCommands] (the facade delegates one line per command); the
/// event commands are not used by these screens.
final class _SubTrackFacade implements LearningCommands {
  _SubTrackFacade(this.inner);

  final SubTrackCommands inner;

  @override
  Future<CaptureResult> createSubTrack(
    SubTrackDraft draft, {
    String? subTrackId,
  }) => inner.createSubTrack(draft, subTrackId: subTrackId);

  @override
  Future<CaptureResult> editSubTrack(String subTrackId, SubTrackEdit edit) =>
      inner.editSubTrack(subTrackId, edit);

  @override
  Future<CaptureResult> endSubTrack(String subTrackId) =>
      inner.endSubTrack(subTrackId);

  @override
  Future<CaptureResult> deleteSubTrack(String subTrackId) =>
      inner.deleteSubTrack(subTrackId);

  @override
  Stream<List<PendingFailure>> watchPendingFailures() =>
      inner.watchPendingFailures();

  @override
  Future<CaptureResult> retry(String pendingFailureId) =>
      inner.retry(pendingFailureId);

  @override
  Future<CaptureResult> capture({
    required String curriculumId,
    List<LeafRef> refs = const [],
    List<NodeEntry> nodes = const [],
    required String source,
    required DateState dateState,
    CivilDate? learnedOn,
    int? stage,
  }) => throw UnsupportedError('capture');

  @override
  Future<CaptureResult> voidEvent(String targetId) =>
      throw UnsupportedError('voidEvent');

  @override
  Future<CaptureResult> replace(
    String targetId,
    EventReplacement replacement,
  ) => throw UnsupportedError('replace');

  @override
  Future<CaptureResult> unlearn(String curriculumId, Set<LeafRef> leafSet) =>
      throw UnsupportedError('unlearn');

  @override
  Future<CaptureResult> undoEvents(List<String> eventIds) =>
      throw UnsupportedError('undoEvents');

  @override
  Future<CaptureResult> applyGovernedChange(GovernedAction action) =>
      throw UnsupportedError('applyGovernedChange');

  @override
  Future<CaptureResult> undoAction(String actionId) =>
      throw UnsupportedError('undoAction');
}

/// Lets queued futures and stream events run.
Future<void> _drain() => Future<void>.delayed(Duration.zero);

void main() {
  final scope = c0Scope();
  late InMemoryGovernedIntentRepository intent;

  setUp(() {
    intent = InMemoryGovernedIntentRepository()..emit(scope, _intent());
  });

  tearDown(() => intent.dispose());

  test('two offline fifth creates both sync; the engine tolerates six; '
      'a sixth on one device is rejected with no write', () async {
    final a = _Device(scope, intent);
    final b = _Device(scope, intent);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final four = [for (var i = 1; i <= 4; i++) _ongoing(i * 2, 'Rebbe $i')];
    a.repo.seed(scope, four);
    b.repo.seed(scope, four);
    a.repo.offline = true;
    b.repo.offline = true;

    final fromA = await a.commands.createSubTrack(_formDraft('Chavrusa A'));
    final fromB = await b.commands.createSubTrack(_formDraft('Chavrusa B'));
    expect((fromA as CaptureSuccess).queued, isTrue);
    expect((fromB as CaptureSuccess).queued, isTrue);

    // Device A now holds five locally: a sixth is refused before any write.
    final sixth = await a.commands.createSubTrack(_formDraft('Sixth'));
    expect(sixth, isA<CaptureRejected>());
    expect(
      (sixth as CaptureRejected).violations.map((v) => v.limit),
      contains(SubTrackLimit.ongoingLimit),
    );
    expect(a.repo.calls, hasLength(1), reason: 'no batch for the sixth');
    expect(a.repo.heldCount, 1);
    expect(a.repo.tracksOf(scope), hasLength(5));

    // Reconnect: both queued creates land; each device then reads both.
    a.repo.settleHeld();
    b.repo.settleHeld();
    await _drain();
    final server = {
      for (final t in [...a.repo.tracksOf(scope), ...b.repo.tracksOf(scope)])
        t.id: t,
    }.values.toList();
    a.repo.seed(scope, server);
    expect(server, hasLength(6));
    expect(
      ongoingSubTracksInUse(
        server,
        curriculumId: engineCurriculum,
        today: _today,
      ),
      6,
    );

    // The engine accepts the excess without error (AD-45).
    final state = const LearnerStateEngine().run(
      engineInputs(
        subTracks: server,
        goals: {
          engineCurriculum: const CurriculumGoals(
            deadline: DeadlineGoal(
              curriculumId: engineCurriculum,
              targetDate: '2026-12-31',
            ),
          ),
        },
      ),
    )[engineCurriculum]!;
    expect(state.subTracks.keys, containsAll([for (final t in server) t.id]));
    expect(state.validationErrors, isEmpty);

    // The cap still governs new creates; editing one of the six is not a
    // create and is accepted.
    a.repo.offline = false;
    final seventh = await a.commands.createSubTrack(_formDraft('Seventh'));
    expect(seventh, isA<CaptureRejected>());
    final edit = await a.commands.editSubTrack(
      four.first.id,
      const SubTrackEdit(name: 'Rebbe 1 (renamed)'),
    );
    expect(edit, isA<CaptureSuccess>());
  });

  test('a queued create refused for good rolls back alone; unrelated '
      'queued edits survive; retry re-sends it', () async {
    final a = _Device(scope, intent);
    addTearDown(a.dispose);
    final gemara = _ongoing(2, 'Gemara');
    a.repo
      ..seed(scope, [gemara])
      ..offline = true;
    final failures = <List<PendingFailure>>[];
    final sub = a.commands.watchPendingFailures().listen(failures.add);
    addTearDown(sub.cancel);

    final rename = await a.commands.editSubTrack(
      gemara.id,
      const SubTrackEdit(name: "Gemara b'iyun"),
    );
    a.repo.failNextWith(const PermanentWriteRejection('failed-precondition'));
    final create = await a.commands.createSubTrack(_formDraft('Night seder'));
    final rate = await a.commands.editSubTrack(
      gemara.id,
      const SubTrackEdit(ratePerWeek: 7),
    );
    for (final r in [rename, create, rate]) {
      expect((r as CaptureSuccess).queued, isTrue);
    }
    final createId = (create as CaptureSuccess).changeIds.single;
    expect(a.repo.tracksOf(scope), hasLength(2), reason: 'cache shows it');

    a.repo.settleHeld();
    await _drain();

    // Only the refused create is rolled back.
    final local = a.repo.tracksOf(scope);
    expect(local.map((t) => t.id), [gemara.id]);
    expect(local.single.name, "Gemara b'iyun");
    expect(local.single.ratePerWeek, 7);
    expect(failures.last, [
      PendingFailure(
        id: createId,
        eventIds: const [],
        changeIds: [createId],
        reason: PendingFailureReason.failedPrecondition,
      ),
    ]);

    // Retry re-sends the identical batch.
    a.repo.offline = false;
    final retried = await a.commands.retry(createId);
    expect(retried, isA<CaptureSuccess>());
    await _drain();
    expect(failures.last, isEmpty);
    expect(
      a.repo.tracksOf(scope).map((t) => t.name),
      containsAll(["Gemara b'iyun", 'Night seder']),
    );
  });

  testWidgets('hub and form: a rejected queued create rolls back with the '
      'shared failure notice, an earlier queued edit survives, and Retry '
      'restores it', (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final device = _Device(scope, intent, fakeAsync: true);
    final gemara = _ongoing(2, 'Gemara');
    device.repo
      ..seed(scope, [gemara])
      ..offline = true;
    final facade = _SubTrackFacade(device.commands);

    await tester.pumpWidget(
      pumpApp(
        overrides: [
          useHebrewTermsProvider.overrideWith(_EnglishTerms.new),
          activeLearnerScopeProvider.overrideWith((ref) async => scope),
          subTrackRepositoryProvider.overrideWith((ref) async => device.reads),
          governedIntentRepositoryProvider.overrideWith((ref) async => intent),
          localDayClockProvider.overrideWithValue(
            FakeLocalDayClock(DateTime.utc(2026, 9, 7, 12)),
          ),
          ongoingSubTrackParentSessionProvider.overrideWith(
            (ref) async => true,
          ),
          ongoingSubTrackWriteScopeProvider.overrideWith((ref) async => scope),
          learningCommandsProvider.overrideWith((ref) async => facade),
        ],
        child: Scaffold(
          body: ListView(
            children: const [
              OngoingSubTrackHubSeam(curriculumId: engineCurriculum),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final messenger = ScaffoldMessenger.of(
      tester.element(find.byType(OngoingSubTrackHubSeam)),
    );
    Finder key(String k) => find.byKey(ValueKey(k));
    Future<void> save() async {
      await tester.dragUntilVisible(
        key('ongoingSubTrackSave'),
        find.byType(ListView).last,
        const Offset(0, -150),
      );
      await tester.tap(key('ongoingSubTrackSave'));
      await tester.pumpAndSettle();
      expect(
        find.text("Saved. It will sync when you're back online."),
        findsOneWidget,
      );
      messenger.hideCurrentSnackBar();
      await tester.pumpAndSettle();
    }

    // An unrelated edit, queued offline.
    await tester.tap(find.text('Gemara'));
    await tester.pumpAndSettle();
    await tester.enterText(key('ongoingSubTrackName'), "Gemara b'iyun");
    await save();

    // A create the server will refuse for good, queued offline.
    device.repo.failNextWith(
      const PermanentWriteRejection('failed-precondition'),
    );
    await tester.tap(key('ongoingSubTrackHubAdd'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();
    await tester.enterText(key('ongoingSubTrackName'), 'Night seder');
    await save();
    expect(find.text('Night seder'), findsOneWidget, reason: 'cache shows it');

    // Reconnect: the create is refused and rolled back; the edit lands.
    await tester.runAsync(() async {
      device.repo.settleHeld();
      await _drain();
    });
    await tester.pumpAndSettle();
    expect(find.text('Night seder'), findsNothing);
    expect(find.text("Gemara b'iyun"), findsOneWidget);
    expect(find.text("Your change couldn't be saved."), findsOneWidget);

    // Retry re-sends the same create, now online.
    device.repo.offline = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Night seder'), findsOneWidget);
    expect(
      device.repo.tracksOf(scope).map((t) => t.name),
      containsAll(["Gemara b'iyun", 'Night seder']),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(device.dispose);
  });
}

/// English unit words, so labels are deterministic.
class _EnglishTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}
