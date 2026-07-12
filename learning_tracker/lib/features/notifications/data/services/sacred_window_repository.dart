import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:learning_tracker/core/database/daos/sacred_window_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/sacred_time/sacred_time.dart';

/// Repository that provides Sacred Time block windows for notification
/// scheduling (DNI-367, Story 26.24).
///
/// Wraps [ZmanimWindowService] with a two-level cache:
///
/// 1. **In-memory** — a `List<SacredWindow>?` keyed on (lat, lng, inIsrael),
///    identical to the original implementation, so synchronous callers
///    ([NotificationScheduler]) are unaffected.
///
/// 2. **DB** (optional) — if a [SacredWindowDao] is supplied, computed
///    windows are written to the database asynchronously (fire-and-forget)
///    so that background notification-fire-time checks can read them on
///    cold-start without the Flutter engine (AC 26.24 requirement 4).
///
/// Call [invalidate] whenever the user's location or timezone changes — the
/// next query recomputes and re-persists.
class SacredWindowRepository {
  SacredWindowRepository({ZmanimWindowService? service, SacredWindowDao? dao})
    : _service = service ?? const ZmanimWindowService(),
      _dao = dao;

  final ZmanimWindowService _service;
  final SacredWindowDao? _dao;

  /// Span used for window computation: 14 days forward + 2 days look-back
  /// inside the service itself (service always looks back 2 days from `from`).
  static const Duration _span = Duration(days: 18);

  List<SacredWindow>? _cachedWindows;
  double? _cachedLat;
  double? _cachedLong;
  bool? _cachedInIsrael;

  // AUD-notifications-09: [invalidate] and [_persistToDb] each write to
  // [SacredWindowDao] fire-and-forget, with no ordering relationship to
  // each other. Funneling every write through this single chain guarantees
  // they commit strictly in invocation order — an older (now-superseded)
  // write can never physically land after a newer one and stomp its data.
  // [_writeGeneration] additionally lets an already-superseded write skip
  // the DB entirely once its turn comes up.
  Future<void> _dbWriteChain = Future<void>.value();
  int _writeGeneration = 0;

  /// Exposes the tail of the serialized DB-write chain so tests can await
  /// every write triggered by [invalidate]/[_persistToDb] so far.
  @visibleForTesting
  Future<void> get debugPendingDbWrites => _dbWriteChain;

  /// Invalidates the in-memory cache and asynchronously clears the DB cache.
  ///
  /// Called by [TimezoneLifecycleObserver] on resume, and whenever the user's
  /// location changes.
  void invalidate() {
    _cachedWindows = null;
    _cachedLat = null;
    _cachedLong = null;
    _cachedInIsrael = null;
    _enqueueDbWrite((dao) => dao.replaceAll(const []));
  }

  /// Returns true if [fireTimeUtc] (UTC) falls inside any Sacred Time block
  /// window.
  ///
  /// Pass [fireTimeUtc] in UTC. Use `tz_datetime.toUtc()` from a tz-aware
  /// [tz.TZDateTime] for correct local-to-UTC conversion.
  ///
  /// If [location] is null (user never set a location), returns false — no
  /// suppression without a location.
  bool isWindowActive(
    DateTime fireTimeUtc, {
    required SacredLocation? location,
    required bool inIsrael,
  }) {
    if (location == null) return false;

    final windows = _getOrComputeWindows(
      location: location,
      inIsrael: inIsrael,
      // Start 2 days before the fire time so in-progress windows are caught.
      from: fireTimeUtc.subtract(const Duration(days: 2)),
    );

    for (final w in windows) {
      if (!fireTimeUtc.isBefore(w.startUtc) && !fireTimeUtc.isAfter(w.endUtc)) {
        return true;
      }
    }
    return false;
  }

  /// Returns all Sacred Time windows for the 14-day scheduling window.
  ///
  /// Results are cached until [invalidate] is called (or location/inIsrael
  /// changes).
  List<SacredWindow> getWindows({
    required SacredLocation? location,
    required bool inIsrael,
    required DateTime from,
    Duration span = const Duration(days: 14),
  }) {
    if (location == null) return const [];
    return _getOrComputeWindows(
      location: location,
      inIsrael: inIsrael,
      from: from,
    );
  }

  List<SacredWindow> _getOrComputeWindows({
    required SacredLocation location,
    required bool inIsrael,
    required DateTime from,
  }) {
    // Cache hit: same location + inIsrael.
    if (_cachedWindows != null &&
        _cachedLat == location.latitude &&
        _cachedLong == location.longitude &&
        _cachedInIsrael == inIsrael) {
      return _cachedWindows!;
    }

    // Cache miss: recompute over a wide span (18 days) so all possible
    // fire-times in the batch are covered regardless of [from].
    _cachedWindows = _service.computeWindows(
      latitude: location.latitude,
      longitude: location.longitude,
      inIsrael: inIsrael,
      from: from,
      span: _span,
    );
    _cachedLat = location.latitude;
    _cachedLong = location.longitude;
    _cachedInIsrael = inIsrael;

    // Persist to DB asynchronously so background cold-start checks can read
    // the windows without the Flutter engine (DNI-367 AC 26.24 requirement 4).
    _persistToDb(
      windows: _cachedWindows!,
      lat: location.latitude,
      lng: location.longitude,
      inIsrael: inIsrael,
    );

    return _cachedWindows!;
  }

  /// Writes the computed windows to the DB (fire-and-forget).
  ///
  /// Silently no-ops when [_dao] is null (e.g. in unit tests that construct
  /// [SacredWindowRepository] without a DAO).
  void _persistToDb({
    required List<SacredWindow> windows,
    required double lat,
    required double lng,
    required bool inIsrael,
  }) {
    final dao = _dao;
    if (dao == null) return;

    // Build companions outside the async closure so we don't capture mutable
    // state that could change before the future resolves.
    final companions = windows
        .map(
          (w) => SacredWindowEntriesCompanion.insert(
            startUtc: w.startUtc,
            endUtc: w.endUtc,
            kind: w.kind.name,
            lat: Value(lat),
            lng: Value(lng),
            inIsrael: inIsrael,
          ),
        )
        .toList();

    // AUD-core-database-04: clear+insert is atomic (one transaction inside
    // [SacredWindowDao.replaceAll]). AUD-notifications-09: routed through
    // [_enqueueDbWrite] so this write can never be stomped by (or stomp) a
    // racing [invalidate] call.
    _enqueueDbWrite((dao) => dao.replaceAll(companions));
  }

  /// Queues [write] onto the serialized, generation-guarded DB-write chain.
  ///
  /// Still fire-and-forget from the caller's perspective ([invalidate] and
  /// [_persistToDb] both stay synchronous so [getWindows]/[isWindowActive]
  /// are unaffected), but every write now:
  ///   - commits strictly in invocation order (no interleaving with any
  ///     other write queued through this method), and
  ///   - is skipped if a newer write was already queued by the time its
  ///     turn comes up, so a stale write can never stomp a newer commit
  ///     (AUD-notifications-09), and
  ///   - logs failures via [AppLogger] instead of silently discarding them
  ///     (AUD-core-database-04).
  void _enqueueDbWrite(Future<void> Function(SacredWindowDao dao) write) {
    final dao = _dao;
    if (dao == null) return;

    final generation = ++_writeGeneration;
    _dbWriteChain = _dbWriteChain.then((_) async {
      if (generation != _writeGeneration) {
        return; // Superseded by a newer write before this one's turn.
      }
      try {
        await write(dao);
      } catch (e, st) {
        AppLogger.instance.error(
          event: 'sacred_window_db_write_failed',
          exception: e,
          stackTrace: st,
        );
      }
    });
  }
}
