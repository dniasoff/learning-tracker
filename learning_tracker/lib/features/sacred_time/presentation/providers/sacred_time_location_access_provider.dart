/// The one-shot pass that lets an in-app flow which has ALREADY verified the
/// Parent PIN open the city picker without being asked a second time
/// (DNI-481 AC-3, AUD-sacred_time-08).
///
/// The city picker route (`/sacred-time/city`) writes the active learner's
/// lock settings, so the router guards it with a Parent PIN challenge
/// whenever the device holder is a child with a PIN — including a direct
/// deep link. The Sacred Time settings card and the after-lock location
/// prompt verify the PIN themselves, before they push the route; each then
/// [SacredTimeLocationAccess.grant]s the learner it verified, and the
/// route guard [SacredTimeLocationAccess.consume]s that pass instead of
/// prompting again. A pass is bound to one profile, used at most once, and
/// lapses after [SacredTimeLocationAccess.ttl], so a pass that was never
/// used (a navigation that did not happen) cannot open the picker later.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds at most one pending city-picker pass.
final class SacredTimeLocationAccess {
  /// Creates the holder; [now] is the clock the pass's lifetime is read on.
  SacredTimeLocationAccess({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// How long a granted pass stays usable.
  static const Duration ttl = Duration(minutes: 1);

  final DateTime Function() _now;
  String? _profileId;
  DateTime? _grantedAt;

  /// Records that [profileId]'s Parent PIN (or every PIN guarding the
  /// action) was just verified for opening the city picker. Replaces any
  /// earlier pass.
  void grant(String profileId) {
    _profileId = profileId;
    _grantedAt = _now();
  }

  /// Whether a live pass for [profileId] is pending. Always clears the
  /// pending pass, whoever it was for: a pass is used at most once.
  bool consume(String? profileId) {
    final grantedFor = _profileId;
    final grantedAt = _grantedAt;
    _profileId = null;
    _grantedAt = null;
    if (profileId == null || grantedFor != profileId || grantedAt == null) {
      return false;
    }
    final age = _now().difference(grantedAt);
    return !age.isNegative && age <= ttl;
  }
}

/// The app's single [SacredTimeLocationAccess].
final sacredTimeLocationAccessProvider = Provider<SacredTimeLocationAccess>(
  (ref) => SacredTimeLocationAccess(),
);
