/// Regression test for AUD-notifications-09.
///
/// SacredWindowRepository.invalidate() and _persistToDb() (invoked via
/// getWindows()/isWindowActive() on a cache miss) each write to
/// SacredWindowDao without any ordering guarantee between them. If
/// invalidate() is called just before a fresh _persistToDb() cycle, the
/// OLDER invalidate()-triggered DB write could physically land AFTER the
/// NEWER _persistToDb() write has already committed, wiping the table back
/// to empty even though a valid, newer cache generation was just persisted.
///
/// This test forces exactly that interleaving via a DAO test double that
/// can hold one physical write mid-flight, and asserts the table never ends
/// up empty (or stomped by stale data) once the newer write has committed.
///
/// RED (before the fix): the invalidate()-triggered clear runs as a bare,
/// un-queued `dao.clearAll()`/`dao.replaceAll()` call with no relationship
/// to the newer _persistToDb() write, so releasing the held clear after the
/// newer write has committed wipes the table -- final state is empty.
///
/// GREEN (after the fix): every DB write triggered by invalidate() and
/// _persistToDb() is funneled through one serialized, generation-guarded
/// queue, so a write that has been superseded before its turn comes up is
/// skipped rather than allowed to stomp a newer commit.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/sacred_window_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/notifications/data/services/sacred_window_repository.dart';
import 'package:learning_tracker/features/sacred_time/sacred_time.dart';

import '../../../../helpers/drift_memory.dart';

/// Test double that lets a test force a specific PHYSICAL execution order
/// for [clearAll], independent of the LOGICAL order the repository invoked
/// it in -- reproducing the interleaving the old fire-and-forget code
/// allowed (an older invalidate() call whose underlying I/O happens to
/// resolve after a newer _persistToDb() write has already committed).
class _OrderControlledSacredWindowDao extends SacredWindowDao {
  _OrderControlledSacredWindowDao(super.db);

  /// When set, the NEXT call to [clearAll] awaits this completer before
  /// running the real delete, then clears itself (one-shot).
  Completer<void>? holdNextClear;

  @override
  Future<void> clearAll() async {
    final hold = holdNextClear;
    holdNextClear = null;
    if (hold != null) {
      await hold.future;
    }
    return super.clearAll();
  }
}

void main() {
  late UserDatabase db;
  late _OrderControlledSacredWindowDao dao;

  final locationA = SacredLocation(
    latitude: 40.0959,
    longitude: -74.2222,
    source: SacredLocationSource.manualCoords,
    fixedAt: DateTime.utc(2026, 1, 1),
  );
  final locationB = SacredLocation(
    latitude: 31.7683,
    longitude: 35.2137,
    source: SacredLocationSource.manualCoords,
    fixedAt: DateTime.utc(2026, 1, 1),
  );
  final from = DateTime.utc(2026, 5, 1);

  setUp(() {
    db = inMemoryDb();
    dao = _OrderControlledSacredWindowDao(db);
  });

  tearDown(() async => db.close());

  test('a stale invalidate() clear cannot stomp a newer, already-committed '
      '_persistToDb() write (AUD-notifications-09)', () async {
    final repo = SacredWindowRepository(dao: dao);

    // 1. Establish a committed, non-empty baseline for location A.
    repo.getWindows(location: locationA, inIsrael: false, from: from);
    await repo.debugPendingDbWrites;

    final baseline = await dao.getAll();
    expect(baseline, isNotEmpty, reason: 'sanity: baseline cycle wrote rows');
    expect(
      baseline.every((r) => (r.lat! - locationA.latitude).abs() < 0.001),
      isTrue,
      reason: 'sanity: baseline rows belong to location A',
    );

    // 2. Race: invalidate() (the OLDER call) is invoked first, but its
    //    underlying clear is held mid-flight so it does not physically
    //    run yet.
    final release = Completer<void>();
    dao.holdNextClear = release;
    repo.invalidate();

    // 3. A NEWER _persistToDb() cycle for a different location is queued
    //    right behind it -- e.g. TimezoneLifecycleObserver invalidating on
    //    resume immediately followed by the next scheduling pass
    //    recomputing windows.
    repo.getWindows(location: locationB, inIsrael: true, from: from);

    // Let the microtask queue advance as far as it can without the held
    // clear -- if the newer write is unheld, it fully commits here.
    await Future<void>.delayed(Duration.zero);

    // 4. NOW let the stale, older clear physically run -- after the newer
    //    write may already have committed.
    release.complete();
    await repo.debugPendingDbWrites;

    final rows = await dao.getAll();
    expect(
      rows,
      isNotEmpty,
      reason:
          'a stale invalidate() clear must never leave '
          'sacred_window_entries empty once a newer _persistToDb() write '
          'has committed -- Sacred Time notification suppression must '
          'never silently fail open because of write interleaving.',
    );
    expect(
      rows.every((r) => (r.lat! - locationB.latitude).abs() < 0.001),
      isTrue,
      reason:
          'the final state must reflect the NEWER _persistToDb() cycle '
          '(location B), not be stomped by the stale, older invalidate() '
          'clear (which targeted location A\'s now-superseded cache '
          'generation).',
    );
  });
}
