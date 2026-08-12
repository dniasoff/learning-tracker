@Tags(['needs_flutter', 'gamification', 'achievement_unlock_celebration'])
library;

import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/achievement_unlock_celebration.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/pump_app.dart';

const _profileId = '01J00000000000000000000011';

RewardUnlockRecord _unlock({String title = 'Gold Star'}) => RewardUnlockRecord(
  milestoneId: 'milestone-1',
  profileId: _profileId,
  title: title,
  thresholdPoints: 100,
  pointsAtUnlock: 100,
  unlockedAt: DateTime.utc(2026),
);

final _profile = LearnerProfileEntity(
  profileId: _profileId,
  displayName: 'Chaya',
  mode: ProfileMode.child,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

BuildContext? _lastTriggerContext;
WidgetRef? _lastTriggerRef;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('empty unlock list does not open a dialog', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeProfileIdProvider.overrideWithValue(_profileId),
          selectedProfileProvider.overrideWith((ref) async => _profile),
        ],
        child: const _Trigger(unlocks: []),
      ),
    );
    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pump();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('an unlock opens the celebration dialog with its title', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeProfileIdProvider.overrideWithValue(_profileId),
          selectedProfileProvider.overrideWith((ref) async => _profile),
        ],
        child: _Trigger(unlocks: [_unlock()]),
      ),
    );
    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Gold Star'), findsOneWidget);
  });

  testWidgets('continue dismisses the celebration dialog', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeProfileIdProvider.overrideWithValue(_profileId),
          selectedProfileProvider.overrideWith((ref) async => _profile),
        ],
        child: _Trigger(unlocks: [_unlock()]),
      ),
    );
    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text("Yay! Let's go!"), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, "Yay! Let's go!"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('auto-closes the celebration after five seconds', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeProfileIdProvider.overrideWithValue(_profileId),
          selectedProfileProvider.overrideWith((ref) async => _profile),
        ],
        child: _Trigger(unlocks: [_unlock()]),
      ),
    );
    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Dialog), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('only the first unlock title is shown', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeProfileIdProvider.overrideWithValue(_profileId),
          selectedProfileProvider.overrideWith((ref) async => _profile),
        ],
        child: _Trigger(
          unlocks: [
            _unlock(title: 'Bronze Star'),
            _unlock(title: 'Silver Star'),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Bronze Star'), findsOneWidget);
    expect(find.textContaining('Silver Star'), findsNothing);
    await tester.tap(find.text("Yay! Let's go!"));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('renders both confetti animations', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeProfileIdProvider.overrideWithValue(_profileId),
          selectedProfileProvider.overrideWith((ref) async => _profile),
        ],
        child: _Trigger(unlocks: [_unlock()]),
      ),
    );
    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ConfettiWidget), findsNWidgets(2));
    await tester.tap(find.text("Yay! Let's go!"));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('uses the profile-name fallback when no profile is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeProfileIdProvider.overrideWithValue(_profileId),
          selectedProfileProvider.overrideWith((ref) async => null),
        ],
        child: _Trigger(unlocks: [_unlock()]),
      ),
    );
    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('friend'), findsOneWidget);
    await tester.tap(find.text("Yay! Let's go!"));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('second call while open does not stack another dialog', (
    tester,
  ) async {
    final unlocks = [_unlock()];
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeProfileIdProvider.overrideWithValue(_profileId),
          selectedProfileProvider.overrideWith((ref) async => _profile),
        ],
        child: _Trigger(unlocks: unlocks),
      ),
    );
    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Dialog), findsOneWidget);

    unawaited(
      AchievementUnlockCelebration.showForUnlockedMilestones(
        context: _lastTriggerContext!,
        ref: _lastTriggerRef!,
        newUnlocks: unlocks,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text("Yay! Let's go!"));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('Hebrew locale renders the dialog and its button', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpApp(
        locale: const Locale('he'),
        overrides: [
          activeProfileIdProvider.overrideWithValue(_profileId),
          selectedProfileProvider.overrideWith((ref) async => _profile),
        ],
        child: _Trigger(unlocks: [_unlock()]),
      ),
    );
    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 300));
  });
}

class _Trigger extends StatelessWidget {
  const _Trigger({required this.unlocks});
  final List<RewardUnlockRecord> unlocks;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, child) {
      _lastTriggerContext = context;
      _lastTriggerRef = ref;
      return ElevatedButton(
        key: const Key('trigger'),
        onPressed: () => AchievementUnlockCelebration.showForUnlockedMilestones(
          context: context,
          ref: ref,
          newUnlocks: unlocks,
        ),
        child: const Text('SHOW'),
      );
    },
  );
}
