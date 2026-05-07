import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';

/// Pure-Dart calculator that turns a (lat, long, inIsrael) tuple into a list
/// of opaque block windows. The output is intentionally minimal — startUtc,
/// endUtc, and a kind label — because the lock screen never displays zmanim.
///
/// Algorithm:
///   For each Gregorian day in [from .. from + span], decide whether the day
///   is "blocked" (`JewishCalendar.isAssurBemelacha`: Shabbos OR Yom Tov with
///   melacha prohibition, including Yom Kippur). When the blocked flag flips
///   false→true, the window starts at candle-lighting on the *prior* day
///   (sunset − [candleOffsetMin]). When it flips true→false, the window ends
///   at tzais on the *last* blocked day (8.5° below the horizon by default).
///   Consecutive blocked days chain into one window — this naturally handles
///   Shabbos+YT, multi-day chag, YT-sheni, and Shabbos in chol hamoed.
///
/// Cushion: [cushionMin] minutes are subtracted from start and added to end
/// so the lock kicks in slightly early and releases slightly late.
///
/// Polar fallback: if sunset can't be computed (extreme latitudes during
/// solstice), the algorithm falls back to a wide local-time window (17:00 of
/// the prior day to 21:00 of the last blocked day) — over-blocking by design.
class ZmanimWindowService {
  const ZmanimWindowService();

  List<SacredWindow> computeWindows({
    required double latitude,
    required double longitude,
    required bool inIsrael,
    required DateTime from,
    required Duration span,
    double candleOffsetMin = 18,
    int cushionMin = 15,
  }) {
    final windows = <SacredWindow>[];
    final cushion = Duration(minutes: cushionMin);

    // Walk a couple of days before [from] so a window already in progress
    // when the user opens the app is still detected.
    final start = _atMidnightLocal(from).subtract(const Duration(days: 2));
    final endInclusive = start.add(span + const Duration(days: 4));

    DateTime? windowStartUtc;
    var prevBlocked = false;
    DateTime? prevDate;
    var sawYomKippur = false;
    var sawShabbos = false;
    var sawYomTov = false;

    for (
      var d = start;
      !d.isAfter(endInclusive);
      d = d.add(const Duration(days: 1))
    ) {
      final jc = JewishCalendar.fromDateTime(d)..inIsrael = inIsrael;
      final blocked = jc.isAssurBemelacha();

      if (!prevBlocked && blocked && prevDate != null) {
        // Window opens at candle-lighting on the prior day.
        windowStartUtc = _candleLighting(
          latitude: latitude,
          longitude: longitude,
          forDate: prevDate,
          candleOffsetMin: candleOffsetMin,
        );
        sawYomKippur = false;
        sawShabbos = false;
        sawYomTov = false;
      }

      if (blocked) {
        if (jc.getYomTovIndex() == JewishCalendar.YOM_KIPPUR) {
          sawYomKippur = true;
        }
        if (jc.getDayOfWeek() == 7) sawShabbos = true; // SATURDAY
        if (jc.isYomTov() && jc.getYomTovIndex() != JewishCalendar.YOM_KIPPUR) {
          sawYomTov = true;
        }
      }

      if (prevBlocked && !blocked && prevDate != null) {
        // Window closes at tzais on the previous (last blocked) day.
        final endUtc = _tzais(
          latitude: latitude,
          longitude: longitude,
          forDate: prevDate,
        );
        if (windowStartUtc != null) {
          windows.add(
            SacredWindow(
              startUtc: windowStartUtc.subtract(cushion),
              endUtc: endUtc.add(cushion),
              kind: _classify(
                yomKippur: sawYomKippur,
                shabbos: sawShabbos,
                yomTov: sawYomTov,
              ),
            ),
          );
        }
        windowStartUtc = null;
      }

      prevBlocked = blocked;
      prevDate = d;
    }

    // If iteration ends mid-window, close it at the tail's tzais so we still
    // emit a (partial) window.
    if (prevBlocked && windowStartUtc != null && prevDate != null) {
      final endUtc = _tzais(
        latitude: latitude,
        longitude: longitude,
        forDate: prevDate,
      );
      windows.add(
        SacredWindow(
          startUtc: windowStartUtc.subtract(cushion),
          endUtc: endUtc.add(cushion),
          kind: _classify(
            yomKippur: sawYomKippur,
            shabbos: sawShabbos,
            yomTov: sawYomTov,
          ),
        ),
      );
    }

    return windows;
  }

  static SacredWindowKind _classify({
    required bool yomKippur,
    required bool shabbos,
    required bool yomTov,
  }) {
    if (yomKippur) return SacredWindowKind.yomKippur;
    if (shabbos && yomTov) return SacredWindowKind.shabbosYomTov;
    if (yomTov) return SacredWindowKind.yomTov;
    return SacredWindowKind.shabbos;
  }

  /// Sunset − [candleOffsetMin] on [forDate], in UTC. Falls back to local
  /// 17:00 if sunset is uncomputable (polar latitudes).
  DateTime _candleLighting({
    required double latitude,
    required double longitude,
    required DateTime forDate,
    required double candleOffsetMin,
  }) {
    final geo = GeoLocation.setLocation(
      'sacred-time',
      latitude,
      longitude,
      forDate,
    );
    final cal = ComplexZmanimCalendar.intGeoLocation(geo)
      ..setCalendar(forDate)
      ..setCandleLightingOffset(candleOffsetMin);
    final cl = cal.getCandleLighting();
    if (cl != null) return cl.toUtc();
    return DateTime(forDate.year, forDate.month, forDate.day, 17).toUtc();
  }

  /// Tzais (8.5° below horizon, geonim) on [forDate], in UTC. Falls back to
  /// local 21:00 if uncomputable.
  DateTime _tzais({
    required double latitude,
    required double longitude,
    required DateTime forDate,
  }) {
    final geo = GeoLocation.setLocation(
      'sacred-time',
      latitude,
      longitude,
      forDate,
    );
    final cal = ComplexZmanimCalendar.intGeoLocation(geo)..setCalendar(forDate);
    final tz = cal.getTzais();
    if (tz != null) return tz.toUtc();
    return DateTime(forDate.year, forDate.month, forDate.day, 21).toUtc();
  }

  static DateTime _atMidnightLocal(DateTime d) =>
      DateTime(d.year, d.month, d.day);
}
