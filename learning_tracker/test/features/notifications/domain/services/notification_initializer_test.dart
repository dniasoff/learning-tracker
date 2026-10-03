// NotificationInitializer — tutor-change push taps (Story 4.7 / DNI-515,
// AC-1): a tapped parent push (or the one that launched the app) is handed
// to onParentPushTap and does not navigate on its own; reminder taps keep
// their existing behaviour.
import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/features/notifications/domain/models/parent_push_message.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_initializer.dart';
import 'package:mocktail/mocktail.dart';

class _MockGateway extends Mock implements NotificationGateway {}

class _MockRouter extends Mock implements AppRouter {}

class _FakeRoute extends Fake implements PageRouteInfo<Object?> {}

const _tap = ParentPushTap(
  ownerUid: 'owner-uid',
  profileId: '01J8XKQ2M3N4P5R6S7T8V9W0XY',
);

void main() {
  late _MockGateway gateway;
  late _MockRouter router;
  late void Function(String?) onTap;
  late List<ParentPushTap> taps;

  setUpAll(() => registerFallbackValue(_FakeRoute()));

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    gateway = _MockGateway();
    router = _MockRouter();
    taps = [];
    when(
      () => gateway.initialize(
        onNotificationTap: any(named: 'onNotificationTap'),
      ),
    ).thenAnswer((inv) async {
      onTap = inv.namedArguments[#onNotificationTap] as void Function(String?);
      return true;
    });
    when(() => router.navigate(any())).thenAnswer((_) async {});
  });

  String? launchPayload;

  NotificationInitializer build() => NotificationInitializer(
    service: gateway,
    router: router,
    onParentPushTap: taps.add,
    readLaunchPayload: () async => launchPayload,
  );

  test('a tapped parent push goes to onParentPushTap only', () async {
    launchPayload = null;
    await build().initialize();

    onTap(_tap.toPayload());

    expect(taps, [_tap]);
    verifyNever(() => router.navigate(any()));
  });

  test('the push that launched the app is handed over at start', () async {
    launchPayload = _tap.toPayload();
    await build().initialize();
    expect(taps, [_tap]);
  });

  test('a reminder launch payload is not a parent push', () async {
    launchPayload = dailyReminderPayload;
    await build().initialize();
    expect(taps, isEmpty);
  });

  test('reminder taps still open the scheduler', () async {
    launchPayload = null;
    await build().initialize();
    onTap(dailyReminderPayload);
    verify(() => router.navigate(any())).called(1);
    expect(taps, isEmpty);
  });

  test('a catch-up tap selects its profile, then opens Learn', () async {
    final selected = <String>[];
    final initializer = NotificationInitializer(
      service: gateway,
      router: router,
      onCatchUpTap: (profileId) async {
        selected.add(profileId);
        return true;
      },
    );
    const profileId = '01ARZ3NDEKTSV4RRFFQ69G5FB1';
    await initializer.handleNotificationTap(
      '$catchUpReminderPayload:$profileId',
    );
    expect(selected, [profileId]);
    final route = verify(() => router.navigate(captureAny())).captured.single;
    expect((route as PageRouteInfo).routeName, LearningRoute.name);
  });

  test('a declined or malformed catch-up tap opens nothing', () async {
    final selected = <String>[];
    final initializer = NotificationInitializer(
      service: gateway,
      router: router,
      onCatchUpTap: (profileId) async {
        selected.add(profileId);
        return false;
      },
    );
    const profileId = '01ARZ3NDEKTSV4RRFFQ69G5FB1';
    await initializer.handleNotificationTap(
      '$catchUpReminderPayload:$profileId',
    );
    await initializer.handleNotificationTap('$catchUpReminderPayload:');
    await initializer.handleNotificationTap(
      '$catchUpReminderPayload:$profileId:extra',
    );
    expect(selected, [profileId]);
    verifyNever(() => router.navigate(any()));
  });
}
