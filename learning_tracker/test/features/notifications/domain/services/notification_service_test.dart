import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late NotificationService service;

  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const NotificationDetails());
  });

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    service = NotificationService(plugin: mockPlugin);
  });

  group('NotificationService', () {
    group('initialize', () {
      test('returns true when plugin initializes successfully', () async {
        when(
          () => mockPlugin.initialize(
            settings: any<InitializationSettings>(named: 'settings'),
            onDidReceiveNotificationResponse: any(
              named: 'onDidReceiveNotificationResponse',
            ),
          ),
        ).thenAnswer((_) async => true);

        final result = await service.initialize();

        expect(result, isTrue);
      });

      test('returns false when plugin returns null', () async {
        when(
          () => mockPlugin.initialize(
            settings: any<InitializationSettings>(named: 'settings'),
            onDidReceiveNotificationResponse: any(
              named: 'onDidReceiveNotificationResponse',
            ),
          ),
        ).thenAnswer((_) async => null);

        final result = await service.initialize();

        expect(result, isFalse);
      });
    });

    group('cancelDailyReminder', () {
      test('cancels notification with dailyReminderId', () async {
        when(
          () => mockPlugin.cancel(id: any<int>(named: 'id')),
        ).thenAnswer((_) async {});

        await service.cancelDailyReminder();

        verify(() => mockPlugin.cancel(id: dailyReminderId)).called(1);
      });
    });

    group('cancelStreakAlert', () {
      test('cancels notification with streakAlertId', () async {
        when(
          () => mockPlugin.cancel(id: any<int>(named: 'id')),
        ).thenAnswer((_) async {});

        await service.cancelStreakAlert();

        verify(() => mockPlugin.cancel(id: streakAlertId)).called(1);
      });
    });

    group('showRewardMilestone', () {
      test('shows notification with incrementing IDs', () async {
        when(
          () => mockPlugin.show(
            id: any<int>(named: 'id'),
            title: any<String>(named: 'title'),
            body: any<String>(named: 'body'),
            notificationDetails: any<NotificationDetails>(
              named: 'notificationDetails',
            ),
            payload: any<String>(named: 'payload'),
          ),
        ).thenAnswer((_) async {});

        await service.showRewardMilestone(body: 'First milestone');
        await service.showRewardMilestone(body: 'Second milestone');

        verify(
          () => mockPlugin.show(
            id: 100,
            title: 'Reward Milestone',
            body: 'First milestone',
            notificationDetails: any<NotificationDetails>(
              named: 'notificationDetails',
            ),
            payload: rewardMilestonePayload,
          ),
        ).called(1);
        verify(
          () => mockPlugin.show(
            id: 101,
            title: 'Reward Milestone',
            body: 'Second milestone',
            notificationDetails: any<NotificationDetails>(
              named: 'notificationDetails',
            ),
            payload: rewardMilestonePayload,
          ),
        ).called(1);
      });
    });
  });
}
