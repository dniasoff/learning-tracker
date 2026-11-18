import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/social/presentation/widgets/groups_entry_tile.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

const _adultProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXY1';
const _childProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXY2';

LearnerProfileEntity _profile(String id, ProfileMode mode) =>
    LearnerProfileEntity(
      profileId: id,
      displayName: 'Learner',
      mode: mode,
      avatar: '',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

Widget _buildEntry({
  required Locale locale,
  required String? profileId,
  required LearnerProfileEntity? profile,
  StackRouter? router,
}) => pumpApp(
  locale: locale,
  overrides: [
    activeProfileIdProvider.overrideWithValue(profileId),
    activeProfileProvider.overrideWith((ref) async => profile),
  ],
  child: router == null
      ? const Scaffold(body: GroupsEntryTile())
      : StackRouterScope(
          controller: router,
          stateHash: 0,
          child: const Scaffold(body: GroupsEntryTile()),
        ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  testWidgets('English entry opens groups for the adult active profile', (
    tester,
  ) async {
    final router = _MockStackRouter();
    when(
      () => router.push<Object?>(
        any<PageRouteInfo>(),
        onFailure: any(named: 'onFailure'),
      ),
    ).thenAnswer((_) async => null);

    await tester.pumpWidget(
      _buildEntry(
        locale: const Locale('en'),
        profileId: _adultProfileId,
        profile: _profile(_adultProfileId, ProfileMode.adult),
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learning groups'), findsOneWidget);
    expect(
      find.text('Find your group learning and tasks here.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Learning groups'));
    await tester.pump();

    final route =
        verify(
              () => router.push<Object?>(
                captureAny<PageRouteInfo>(),
                onFailure: any(named: 'onFailure'),
              ),
            ).captured.single
            as LearningGroupsRoute;
    final args = route.args!;
    expect(args.profileId, _adultProfileId);
    expect(args.isAdult, isTrue);
  });

  testWidgets('Hebrew entry opens child groups in the child context', (
    tester,
  ) async {
    final router = _MockStackRouter();
    when(
      () => router.push<Object?>(
        any<PageRouteInfo>(),
        onFailure: any(named: 'onFailure'),
      ),
    ).thenAnswer((_) async => null);

    await tester.pumpWidget(
      _buildEntry(
        locale: const Locale('he'),
        profileId: _childProfileId,
        profile: _profile(_childProfileId, ProfileMode.child),
        router: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('קבוצות לימוד'), findsOneWidget);
    expect(find.text('מצאו כאן את הלמידה והמשימות של הקבוצה.'), findsOneWidget);
    await tester.tap(find.text('קבוצות לימוד'));
    await tester.pump();

    final route =
        verify(
              () => router.push<Object?>(
                captureAny<PageRouteInfo>(),
                onFailure: any(named: 'onFailure'),
              ),
            ).captured.single
            as LearningGroupsRoute;
    final args = route.args!;
    expect(args.profileId, _childProfileId);
    expect(args.isAdult, isFalse);
  });

  testWidgets('entry is hidden until a profile is selected', (tester) async {
    await tester.pumpWidget(
      _buildEntry(locale: const Locale('en'), profileId: null, profile: null),
    );

    expect(find.byType(GroupsEntryTile), findsOneWidget);
    expect(find.text('Learning groups'), findsNothing);
  });
}
