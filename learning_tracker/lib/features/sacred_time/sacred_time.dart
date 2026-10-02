// Public surface of the sacred_time feature.
//
// Import this barrel (features/sacred_time/sacred_time.dart) from outside
// this feature. Do NOT import deep paths directly.
//
// Populated in Wave 5 (W5.x) — sacred-time domain cleanup.
//
// AUD-notifications-06: minimal exports — only the types demonstrably
// consumed by another feature live here (same discipline as
// lib/features/progress/progress.dart). DNI-481 retired the old window
// service (R9); the one lock source is `lockWindows` (lib/domain) read
// through the sacred-time providers.
library sacred_time;

export 'domain/models/sacred_location.dart'
    show SacredLocation, SacredLocationSource;
export 'domain/models/sacred_window.dart' show SacredWindow, SacredWindowKind;
