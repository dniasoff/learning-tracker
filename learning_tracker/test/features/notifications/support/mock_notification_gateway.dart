/// Shared mock NotificationGateway for notifications feature tests.
///
/// AUD-t-notifications-03: notifications_screen_test.dart and
/// ws5_two_layers_test.dart each declared an identical top-level
/// `MockNotificationGateway` class. Both now import this single definition
/// so the two copies cannot silently drift apart.
library;

import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationGateway extends Mock implements NotificationGateway {}
