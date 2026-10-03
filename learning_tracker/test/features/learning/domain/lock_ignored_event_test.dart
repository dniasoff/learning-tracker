// DNI-504 (Story 3.1) AC-9 integration: an owner device's offline queue
// (or wrong clock) lands a learning event whose effective instant is
// inside the lock. It is stored, not rejected (prd-deviations #2); the
// engine ignores it in every derived number; history labels it "kept, not
// counted"; no undo is offered or accepted; and the Learn tab says once
// "Some learning was kept, not counted — it was recorded during Shabbos."
//
// Rules: firestore.rules has no lock clause on learning_events (only the
// AD-54 client-time skew bound), so the store-not-reject half is the
// existing DNI-471 learning_events rules coverage; nothing here changes
// rules or functions.
@Tags(['learning'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/data/repositories/lock_ignored_notice_store.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/models/mishna_history_item.dart';
import 'package:learning_tracker/features/learning/domain/models/profile_history_log.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/lock_ignored_notice.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../sub_tracks/helpers/capture_harness.dart';
import '../../sub_tracks/helpers/up_to_fixtures.dart';

/// Friday 2026-09-04 09:00Z: erev of the fixture lock (12:00Z Friday to
/// 01:00Z Sunday, fail-closed fallback for the UTC learner).
final _erev = DateTime.utc(2026, 9, 4, 9);

/// Sunday 2026-09-06 08:00Z: after the lock.
final _after = DateTime.utc(2026, 9, 6, 8);

/// Minutes from 2026-09-01T00:00Z to Saturday 2026-09-05 10:00Z.
const _shabbosMinutes = 4 * 24 * 60 + 10 * 60;

const _leaf = 'Mishnah Berakhot 1:1';

/// A dated main learn queued offline on Shabbos morning.
final _lockStamped = engineLearn(
  90,
  _leaf,
  minutes: _shabbosMinutes,
  learnedOn: '2026-09-05',
);

/// A dated main learn recorded on erev, before the lock.
final _beforeLock = engineLearn(
  91,
  'Mishnah Berakhot 1:2',
  minutes: 3 * 24 * 60 + 9 * 60,
  learnedOn: '2026-09-04',
);

final class _MemoryStore implements LockIgnoredNoticeStore {
  final Map<LearnerScope, Set<String>> byScope = {};

  @override
  Future<Set<String>> announced(LearnerScope scope) async => {
    ...?byScope[scope],
  };

  @override
  Future<void> setAnnounced(LearnerScope scope, Set<String> ids) async =>
      byScope[scope] = {...ids};
}

const _snackbar =
    'Some learning was kept, not counted — it was recorded during Shabbos.';

void main() {
  group('the synced lock-stamped event', () {
    test('is stored and ignored in every derived number', () {
      final rig = CaptureRig(now: _after, seed: [_beforeLock])
        ..recordElsewhere(_lockStamped);
      addTearDown(rig.dispose);

      // Stored: the log holds it.
      expect(rig.events.map((e) => e.id), contains(_lockStamped.id));
      final state = rig.state;
      expect(state.lockIgnoredEventIds, {_lockStamped.id});
      expect(state.countedEventIds, isNot(contains(_lockStamped.id)));
      expect(state.earningEventIds, isNot(contains(_lockStamped.id)));
      final curriculum = state.curricula[engineCurriculum]!;
      expect(curriculum.learntLeaves, isNot(contains(_leaf)));
      // The event recorded before the lock still counts.
      expect(curriculum.learntLeaves, contains('Mishnah Berakhot 1:2'));
      expect(state.countedEventIds, contains(_beforeLock.id));
    });

    test('offers no undo, and the command refuses one', () async {
      final rig = CaptureRig(now: _after)..recordElsewhere(_lockStamped);
      addTearDown(rig.dispose);
      // Undo is refused, and so is removing it from history.
      expect(
        await rig.commands.undoEvents([_lockStamped.id]),
        isA<CaptureRejected>(),
      );
      expect(
        await rig.commands.voidEvent(_lockStamped.id),
        const CaptureResult.rejected(CaptureRejection.lockIgnoredTarget),
      );
      expect(rig.port.attempts, isEmpty);

      final history = MishnaHistory.project(
        curriculumId: engineCurriculum,
        leafRef: _leaf,
        log: ProfileHistoryLog(events: rig.events, subTracks: const []),
        state: rig.state,
      );
      final item = history.items.single;
      expect(item.status, MishnaHistoryStatus.lockIgnored);
      for (final viewer in MishnaHistoryViewer.values) {
        expect(allowedCorrections(item, viewer), isEmpty, reason: '$viewer');
      }
    });

    test('history labels it kept, not counted', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(
        en.mishnaHistoryLockIgnored,
        'kept, not counted — recorded during Shabbos/Yom Tov',
      );
      expect(en.erevLockIgnoredSnackbar, _snackbar);
    });
  });

  group('the Learn tab notice', () {
    Future<(CaptureRig, _MemoryStore)> pump(
      WidgetTester tester, {
      DateTime? now,
      _MemoryStore? store,
      List<String> seedIds = const [],
    }) async {
      final rig = CaptureRig(now: now ?? _erev);
      addTearDown(rig.dispose);
      final memory = store ?? _MemoryStore();
      useSurface(tester, phoneSize);
      await tester.pumpWidget(
        pumpApp(
          overrides: [
            ...rig.overrides(),
            lockIgnoredNoticeStoreProvider.overrideWithValue(memory),
          ],
          child: const Scaffold(body: LockIgnoredNotice()),
        ),
      );
      await tester.pumpAndSettle();
      return (rig, memory);
    }

    testWidgets('says so once when a lock-stamped event syncs', (tester) async {
      final (rig, _) = await pump(tester);
      expect(find.text(_snackbar), findsNothing);

      rig
        ..now = _after
        ..recordElsewhere(_lockStamped);
      await tester.pumpAndSettle();
      expect(find.text(_snackbar), findsOneWidget);

      // The same event again (another state update): no repeat.
      ScaffoldMessenger.of(
        tester.element(find.byType(LockIgnoredNotice)),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      rig.now = _after.add(const Duration(minutes: 5));
      await tester.pumpAndSettle();
      expect(find.text(_snackbar), findsNothing);
    });

    testWidgets('an event already announced on this device is not '
        'announced again on a later visit', (tester) async {
      final store = _MemoryStore();
      final (first, _) = await pump(tester, now: _after, store: store);
      first.recordElsewhere(_lockStamped);
      await tester.pumpAndSettle();
      expect(find.text(_snackbar), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final rig = CaptureRig(now: _after, seed: [_lockStamped]);
      addTearDown(rig.dispose);
      await tester.pumpWidget(
        pumpApp(
          overrides: [
            ...rig.overrides(),
            lockIgnoredNoticeStoreProvider.overrideWithValue(store),
          ],
          child: const Scaffold(body: LockIgnoredNotice()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_snackbar), findsNothing);
    });

    testWidgets('nothing is said when nothing is lock-ignored', (tester) async {
      final (rig, store) = await pump(tester);
      rig.recordElsewhere(_beforeLock);
      await tester.pumpAndSettle();
      expect(find.text(_snackbar), findsNothing);
      expect(store.byScope, isEmpty);
    });
  });
}
