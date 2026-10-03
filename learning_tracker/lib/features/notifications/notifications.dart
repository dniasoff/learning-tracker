// Public surface of the notifications feature.
//
// Import this barrel (features/notifications/notifications.dart) from outside
// this feature. Do NOT import deep paths directly.
//
// Populated in Wave 5 (W5.x) — notifications domain and scheduling cleanup.
library notifications;

// Story 3.5 (DNI-508): the catch-up reminder API the sacred-time scheduler
// drives through the shared gateway (no second plugin owner).
export 'domain/services/notification_gateway.dart'
    show
        NotificationGateway,
        catchUpReminderIdForProfile,
        catchUpReminderIdSlots,
        catchUpReminderPayload;
export 'presentation/providers/notification_providers.dart'
    show notificationServiceProvider;
