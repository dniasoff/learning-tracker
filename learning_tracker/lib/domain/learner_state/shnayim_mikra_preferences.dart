/// Reading workflow stored in the governed learner settings.
enum ShnayimMikraMode {
  /// Complete each pasuk's three readings before moving on.
  pasuk('pasuk'),

  /// Complete all pesukim in one aliyah for each reading.
  aliyah('aliyah'),

  /// Complete the full parsha for each reading.
  parsha('parsha');

  const ShnayimMikraMode(this.storageKey);

  final String storageKey;
}

/// Whether aliyah-sized work is paced by the learner or by weekdays.
enum ShnayimMikraPace {
  self('self'),
  dailyAliyah('daily_aliyah');

  const ShnayimMikraPace(this.storageKey);

  final String storageKey;
}

/// Third reading selected for the learner's Shnayim Mikra assignment.
enum ShnayimMikraSource {
  onkelos('onkelos'),
  rashi('rashi');

  const ShnayimMikraSource(this.storageKey);

  final String storageKey;
}

/// Weekly Torah-reading minhag used only for Shnayim Mikra scheduling.
enum ShnayimMikraParshaSchedule {
  eretzYisrael('eretz_yisrael'),
  chutzLaaretz('chutz_laaretz');

  const ShnayimMikraParshaSchedule(this.storageKey);

  final String storageKey;

  bool get usesEretzYisraelCalendar =>
      this == ShnayimMikraParshaSchedule.eretzYisrael;
}

/// Temporary bridge from the existing one-day/two-day Yom Tov location flag.
/// Call when creating the Shnayim Mikra track and persist the returned value;
/// schedule reads must not call this again after the learner changes location.
ShnayimMikraParshaSchedule shnayimMikraScheduleFromLegacyYomTovFlag(
  bool? inIsrael,
) => inIsrael == true
    ? ShnayimMikraParshaSchedule.eretzYisrael
    : ShnayimMikraParshaSchedule.chutzLaaretz;
