/// Domain value type for a streak event.
///
/// Distinct from Drift's row class (also called `StreakEvent` and
/// generated from `tables/streak_events.dart`): this one is what the
/// reducer/log/merger work with, with no autogen-id and no DB
/// dependency. The DAO converts to/from the Drift companion at the
/// storage boundary.
library;

class StreakEvent {
  const StreakEvent({
    required this.profileId,
    required this.eventType,
    required this.eventTimestamp,
    this.clientDeviceId,
  });

  final int profileId;

  /// `completion` | `day_boundary` | `manual_adjust`.
  final String eventType;

  /// UTC timestamp — the natural-key component used for dedup.
  final DateTime eventTimestamp;

  final String? clientDeviceId;

  StreakEvent copyWith({
    int? profileId,
    String? eventType,
    DateTime? eventTimestamp,
    String? clientDeviceId,
  }) => StreakEvent(
    profileId: profileId ?? this.profileId,
    eventType: eventType ?? this.eventType,
    eventTimestamp: eventTimestamp ?? this.eventTimestamp,
    clientDeviceId: clientDeviceId ?? this.clientDeviceId,
  );
}
