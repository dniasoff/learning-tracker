/// DNI-513 Change history providers: the screen's own access check (AC-1:
/// only an own session whose parent PIN is unlocked for the active
/// learner), the AD-36 / E-4 lock judgement that keeps the history
/// unreadable during a lock, and the Story 4.6 Undo seam that stays empty
/// in this story.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/change_history/data/repositories/change_history_sources.dart';
import 'package:learning_tracker/features/change_history/presentation/providers/change_history_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _childId = '01J6Q2H4A8M7K3P9R5T6V8WXY8';
const _otherId = '01J6Q2H4A8M7K3P9R5T6V8WXY9';

const _tutored = TutoredProfileSelection(
  profileId: _childId,
  ownerUid: 'parent-uid',
  grantId: 'grant-1',
  permissions: TutorPermissions(),
);

class _Tutored extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => _tutored;
}

class _Own extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

class _PinFor extends ParentPinAuthenticatedProfileId {
  _PinFor(this._id);
  final String? _id;

  @override
  String? build() => _id;
}

final _scope = LearnerScope(ownerUid: 'owner-uid', profileId: profileUlid);

/// A sub-track read whose `watchAll` emits what the test adds.
class _LiveSubTracks implements SubTrackRepository {
  _LiveSubTracks(this.reads);

  final StreamController<CompleteRead<SubTrack>> reads;

  @override
  Stream<CompleteRead<SubTrack>> watchAll(LearnerScope scope) => reads.stream;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('changeHistoryAccessProvider (AC-1)', () {
    bool access({
      required bool tutored,
      required String? pinFor,
      String? active = _childId,
    }) {
      final container = ProviderContainer(
        overrides: [
          activeTutoredProfileSelectionProvider.overrideWith(
            tutored ? _Tutored.new : _Own.new,
          ),
          activeProfileIdProvider.overrideWithValue(active),
          parentPinAuthenticatedProfileIdProvider.overrideWith(
            () => _PinFor(pinFor),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(changeHistoryAccessProvider);
    }

    test('parent PIN unlocked for the active learner: open', () {
      expect(access(tutored: false, pinFor: _childId), isTrue);
    });

    test('child role (no parent PIN session): closed', () {
      expect(access(tutored: false, pinFor: null), isFalse);
    });

    test('parent PIN unlocked for another learner: closed', () {
      expect(access(tutored: false, pinFor: _otherId), isFalse);
    });

    test('no active learner: closed', () {
      expect(access(tutored: false, pinFor: null, active: null), isFalse);
    });

    test('tutor device (tutored session): closed', () {
      expect(access(tutored: true, pinFor: _childId), isFalse);
    });
  });

  group('changeHistoryLockedProvider (AD-36, E-4)', () {
    final settings = constantHistory(newYorkNoLocation);
    // The Shabbos lock of 2026-09-05 in New York.
    final lock = lockWindows(
      settings,
      DateTime.utc(2026, 9, 4),
      DateTime.utc(2026, 9, 6),
    ).single;

    Future<AsyncValue<bool>> locked({
      required DateTime now,
      SacredWindow? device,
      Stream<LearnerSettingsHistory>? learner,
    }) async {
      final container = ProviderContainer(
        overrides: [
          currentSacredWindowProvider.overrideWithValue(device),
          changeHistoryClockProvider.overrideWithValue(() => now),
          learnerLockSettingsProvider.overrideWith(
            (ref, scope) => learner ?? Stream.value(settings),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        changeHistoryLockedProvider(_scope),
        (_, _) {},
      );
      addTearDown(sub.close);
      // Let the learner's settings stream emit.
      await Future<void>.delayed(Duration.zero);
      return container.read(changeHistoryLockedProvider(_scope));
    }

    test("readable outside the learner's lock", () async {
      final value = await locked(
        now: lock.startUtc.subtract(const Duration(hours: 1)),
      );
      expect(value, const AsyncData(false));
    });

    test("unreadable inside the learner's lock", () async {
      final value = await locked(
        now: lock.startUtc.add(const Duration(hours: 1)),
      );
      expect(value, const AsyncData(true));
    });

    test("unreadable during the device's sacred-time window, whatever the "
        "learner's settings", () async {
      final value = await locked(
        now: DateTime.utc(2026, 9, 2, 12),
        device: SacredWindow(
          startUtc: DateTime.utc(2026, 9, 1),
          endUtc: DateTime.utc(2026, 9, 3),
          kind: SacredWindowKind.shabbos,
        ),
        learner: Completer<LearnerSettingsHistory>().future.asStream(),
      );
      expect(value, const AsyncData(true));
    });

    test("not judged readable while the learner's settings are unknown "
        '(fail closed)', () async {
      final value = await locked(
        now: DateTime.utc(2026, 9, 2, 12),
        learner: Completer<LearnerSettingsHistory>().future.asStream(),
      );
      expect(value.isLoading, isTrue);
      expect(value.hasValue, isFalse);
    });
  });

  test('sub-track names are the snapshot the history opened with: a '
      'rename while it is open does not relabel older rows', () async {
    final reads = StreamController<CompleteRead<SubTrack>>();
    addTearDown(() => reads.close());
    final repo = _LiveSubTracks(reads);
    final container = ProviderContainer(
      overrides: [subTrackRepositoryProvider.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);
    final values = <Map<String, String>>[];
    container.listen(
      changeHistorySubTrackNamesProvider(_scope),
      (_, next) => next.whenData(values.add),
      fireImmediately: true,
    );
    final opened = c0SubTrack();
    repo.reads.add(CompleteReadReady([opened]));
    await pumpEventQueue();
    repo.reads.add(
      CompleteReadReady([
        SubTrack.fromStorage(opened.id, {
          ...opened.toStorage(),
          SubTrack.kName: 'Renamed while open',
        }),
      ]),
    );
    await pumpEventQueue();
    expect(values, [
      {opened.id: opened.name},
    ]);
  });

  test('the Story 4.6 Undo seam is empty: no Undo is offered', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(changeHistoryUndoHandlerProvider), isNull);
  });
}
