// Public surface of the sacred_time feature.
//
// Import this barrel (features/sacred_time/sacred_time.dart) from outside
// this feature. Do NOT import deep paths directly.
//
// Populated in Wave 5 (W5.x) — sacred-time domain cleanup.
//
// AUD-notifications-06: minimal exports — only the types demonstrably
// consumed by another feature live here (same discipline as
// lib/features/progress/progress.dart). Consumed by:
//   - lib/features/notifications/data/services/sacred_window_repository.dart
library sacred_time;

export 'domain/models/sacred_location.dart' show SacredLocation;
export 'domain/models/sacred_window.dart' show SacredWindow;
export 'domain/services/zmanim_window_service.dart' show ZmanimWindowService;
