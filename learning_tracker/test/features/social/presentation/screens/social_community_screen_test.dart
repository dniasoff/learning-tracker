import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/parent_session_state.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/social/domain/social_graph.dart';
import 'package:learning_tracker/features/social/presentation/providers/social_providers.dart';
import 'package:learning_tracker/features/social/presentation/screens/social_community_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  testWidgets('adult community shows follower, following, and request tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SocialCommunityScreen(),
        ),
      ),
    );

    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Requests'), findsOneWidget);
  });

  testWidgets('parent PIN session exposes child sharing controls', (
    tester,
  ) async {
    const key = (profileId: 'child-profile', parentSessionId: 'parent-session');
    final container = ProviderContainer(
      overrides: [
        socialConnectionsProvider(key).overrideWith(
          (ref) async => const SocialConnections(
            outgoingRequests: [],
            incomingRequests: [],
            following: [],
            followers: [],
          ),
        ),
        socialChildControlsProvider(key).overrideWith(
          (ref) async => const SocialChildControls(
            allowedSchoolIds: ['school-1'],
            paused: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedProfileIdProvider.notifier).select('child-profile');
    container.read(parentSessionIdProvider.notifier).set('parent-session');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SocialCommunityScreen(parentMode: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Child community controls'), findsOneWidget);
    expect(find.text('Pause sharing and social access'), findsOneWidget);
    expect(find.text('Allowed schools'), findsOneWidget);
    expect(find.text('school-1'), findsOneWidget);
  });
}
