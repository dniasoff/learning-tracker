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
