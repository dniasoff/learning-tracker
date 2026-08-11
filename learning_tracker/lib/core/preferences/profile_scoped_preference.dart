import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Fixed storage bucket used for every profile-scoped preference before any
/// real profile has ever been selected (AD-24 replacement for the old `0`
/// int sentinel — [ProfileScopedPreference]'s key space is non-nullable, so
/// "no profile yet" still needs SOME concrete bucket to read/write). Shared
/// between `preference_providers.dart` (which substitutes this in whenever
/// `activeProfileIdProvider` is null) and `ProfileScopedPreferenceKeys`
/// (whose legacy-key fallback branches key off it).
const kNoProfilePreferenceSentinel = '_no_profile_';

/// Base contract for a per-profile user preference stored in
/// [SharedPreferences] under a `key_p<profileId>` namespace.
///
/// AD-24: [profileId] is the Firestore ULID string, not a Drift-local int.
///
/// Concrete subclasses implement [readFromPrefs], [writeToPrefs], and
/// [defaultValue]; this class provides the common `(read, write, observe)`
/// triplet that callers — and `core/labels/` — depend on.
///
/// Observers are notified after every successful [write]. The first observer
/// added does not receive a synthetic "current value" event; callers that
/// need an initial snapshot should call [read] first.
abstract class ProfileScopedPreference<T> {
  ProfileScopedPreference();

  final _controller = StreamController<_Update<T>>.broadcast();

  /// Default value applied when no per-profile setting exists in
  /// [SharedPreferences] yet. New profiles start here.
  T get defaultValue;

  /// Pure read from [prefs] for [profileId]. Must not write.
  T readFromPrefs(SharedPreferences prefs, String profileId);

  /// Pure write to [prefs] for [profileId]. Must not notify observers — that
  /// is done by the framework method [write].
  Future<void> writeToPrefs(SharedPreferences prefs, String profileId, T value);

  /// Loads the current value for [profileId]. When no row exists yet, returns
  /// [defaultValue].
  Future<T> read(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    return readFromPrefs(prefs, profileId);
  }

  /// Persists [value] for [profileId] and broadcasts the change to observers.
  Future<void> write(String profileId, T value) async {
    final prefs = await SharedPreferences.getInstance();
    await writeToPrefs(prefs, profileId, value);
    _controller.add(_Update<T>(profileId: profileId, value: value));
  }

  /// Stream of `(profileId, value)` updates produced by [write]. Use to drive
  /// reactive consumers in non-Riverpod contexts; Riverpod-based consumers
  /// typically watch the matching provider in `core/preferences/providers.dart`
  /// instead.
  Stream<T> observe(String profileId) => _controller.stream
      .where((u) => u.profileId == profileId)
      .map((u) => u.value);

  /// Drops the broadcast stream. Tests call this between cases; production
  /// code keeps the singleton alive for the whole app lifetime.
  Future<void> dispose() => _controller.close();
}

class _Update<T> {
  _Update({required this.profileId, required this.value});
  final String profileId;
  final T value;
}
