import 'package:freezed_annotation/freezed_annotation.dart';

part 'sacred_window.freezed.dart';

/// Categorisation of a [SacredWindow]. Used for the lock-screen label only —
/// no zmanim are exposed to the UI.
enum SacredWindowKind { shabbos, yomTov, shabbosYomTov, yomKippur }

/// A continuous block window during which the app is silenced and locked.
/// Bounds are stored in UTC.
@freezed
abstract class SacredWindow with _$SacredWindow {
  const factory SacredWindow({
    required DateTime startUtc,
    required DateTime endUtc,
    required SacredWindowKind kind,

    /// The learner whose lock this is (the one the overlay's "change
    /// location" action edits); null when unknown.
    String? profileId,

    /// IANA time zone for rendering the window's UTC bounds as local times.
    @Default('UTC') String timeZone,
  }) = _SacredWindow;
}
