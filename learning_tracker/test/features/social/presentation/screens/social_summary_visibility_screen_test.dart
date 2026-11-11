import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/parent_session_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/social/data/social_graph_repository.dart';
import 'package:learning_tracker/features/social/domain/social_summary_visibility.dart';
import 'package:learning_tracker/features/social/presentation/providers/social_providers.dart';
import 'package:learning_tracker/features/social/presentation/screens/social_summary_visibility_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  testWidgets('owner can toggle sharing and preview the published sections', (
    tester,
  ) async {
    const profileId = 'adult-profile';
    const query = (profileId: profileId, parentSessionId: null);
    final calls = <(String, Map<String, Object?>)>[];
    final repository = SocialGraphRepository((name, data) async {
      calls.add((name, data));
      if (name == 'getSocialSummaryVisibility') {
        return {'visibility': const SocialSummaryVisibility.allOn().toWire()};
      }
      return {'success': true};
    });
    final container = ProviderContainer(
      overrides: [
        activeProfileIdProvider.overrideWithValue(profileId),
        activeLearnerStateProvider.overrideWith(
          (ref) => AsyncData<LearnerState?>(
            LearnerState.empty(DateTime.utc(2026, 11, 10)),
          ),
        ),
        socialSummaryVisibilityProvider(
          query,
        ).overrideWith((ref) async => const SocialSummaryVisibility.allOn()),
        socialGraphRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SocialSummaryVisibilityScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What followers can see'), findsOneWidget);
    expect(find.text('Preview shared progress'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(6));
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    final update = calls.singleWhere(
      (call) => call.$1 == 'setSocialSummaryVisibility',
    );
    expect(update.$2['parentSessionId'], isNull);
    expect(
      (update.$2['visibility'] as Map<String, Object?>)['overallStreak'],
      isFalse,
    );
    expect(update.$2['summary'], isA<Map<String, Object?>>());
  });

  testWidgets('parent PIN session is sent for child visibility changes', (
    tester,
  ) async {
    const profileId = 'child-profile';
    const sessionId = 'parent-session';
    const query = (profileId: profileId, parentSessionId: sessionId);
    final calls = <(String, Map<String, Object?>)>[];
    final repository = SocialGraphRepository((name, data) async {
      calls.add((name, data));
      if (name == 'getSocialSummaryVisibility') {
        return {'visibility': const SocialSummaryVisibility.allOn().toWire()};
      }
      return {'success': true};
    });
    final container = ProviderContainer(
      overrides: [
        activeProfileIdProvider.overrideWithValue(profileId),
        activeLearnerStateProvider.overrideWith(
          (ref) => AsyncData<LearnerState?>(
            LearnerState.empty(DateTime.utc(2026, 11, 10)),
          ),
        ),
        socialSummaryVisibilityProvider(
          query,
        ).overrideWith((ref) async => const SocialSummaryVisibility.allOn()),
        socialGraphRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.read(parentSessionIdProvider.notifier).set(sessionId);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SocialSummaryVisibilityScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile).last);
    await tester.pumpAndSettle();

    final update = calls.singleWhere(
      (call) => call.$1 == 'setSocialSummaryVisibility',
    );
    expect(update.$2['parentSessionId'], sessionId);
  });
}
