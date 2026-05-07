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
  }) = _SacredWindow;
}
