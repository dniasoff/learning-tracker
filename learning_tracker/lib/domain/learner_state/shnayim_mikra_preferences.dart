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

/// Converts the explicit Yom Tov minhag to the Shnayim Mikra parsha schedule.
/// The persisted `yom_tov_days` choice is authoritative. `legacyInIsrael` is
/// only a compatibility fallback for profiles that have not received that
/// setting yet. Call during track creation and persist the result; schedule
/// reads must not call this again after the learner changes location.
ShnayimMikraParshaSchedule shnayimMikraScheduleFromLegacyYomTovFlag({
  required int? yomTovDays,
  required bool? legacyInIsrael,
}) => switch (yomTovDays) {
  1 => ShnayimMikraParshaSchedule.eretzYisrael,
  2 => ShnayimMikraParshaSchedule.chutzLaaretz,
  _ =>
    legacyInIsrael == true
        ? ShnayimMikraParshaSchedule.eretzYisrael
        : ShnayimMikraParshaSchedule.chutzLaaretz,
};
