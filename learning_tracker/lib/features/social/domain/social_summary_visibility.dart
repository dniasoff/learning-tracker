/// Owner-selected summary sections. The server stores these choices and
/// removes disabled sections from the published projection.
final class SocialSummaryVisibility {
  const SocialSummaryVisibility({
    required this.overallStreak,
    required this.overallWeekly,
    required this.perTrackStreaks,
    required this.perTrackWeekly,
    required this.currentTracks,
    required this.siyumim,
  });

  const SocialSummaryVisibility.allOn()
    : overallStreak = true,
      overallWeekly = true,
      perTrackStreaks = true,
      perTrackWeekly = true,
      currentTracks = true,
      siyumim = true;

  final bool overallStreak;
  final bool overallWeekly;
  final bool perTrackStreaks;
  final bool perTrackWeekly;
  final bool currentTracks;
  final bool siyumim;

  factory SocialSummaryVisibility.fromWire(Object? value) {
    if (value is! Map ||
        value.keys.toSet().difference(const {
          'overallStreak',
          'overallWeekly',
          'perTrackStreaks',
          'perTrackWeekly',
          'currentTracks',
          'siyumim',
        }).isNotEmpty) {
      throw const FormatException('Invalid social visibility choices');
    }
    bool read(String key) {
      final choice = value[key];
      if (choice is! bool) {
        throw FormatException('Invalid social visibility choice: $key');
      }
      return choice;
    }

    return SocialSummaryVisibility(
      overallStreak: read('overallStreak'),
      overallWeekly: read('overallWeekly'),
      perTrackStreaks: read('perTrackStreaks'),
      perTrackWeekly: read('perTrackWeekly'),
      currentTracks: read('currentTracks'),
      siyumim: read('siyumim'),
    );
  }

  Map<String, Object?> toWire() => {
    'overallStreak': overallStreak,
    'overallWeekly': overallWeekly,
    'perTrackStreaks': perTrackStreaks,
    'perTrackWeekly': perTrackWeekly,
    'currentTracks': currentTracks,
    'siyumim': siyumim,
  };

  SocialSummaryVisibility copyWith({
    bool? overallStreak,
    bool? overallWeekly,
    bool? perTrackStreaks,
    bool? perTrackWeekly,
    bool? currentTracks,
    bool? siyumim,
  }) => SocialSummaryVisibility(
    overallStreak: overallStreak ?? this.overallStreak,
    overallWeekly: overallWeekly ?? this.overallWeekly,
    perTrackStreaks: perTrackStreaks ?? this.perTrackStreaks,
    perTrackWeekly: perTrackWeekly ?? this.perTrackWeekly,
    currentTracks: currentTracks ?? this.currentTracks,
    siyumim: siyumim ?? this.siyumim,
  );
}
