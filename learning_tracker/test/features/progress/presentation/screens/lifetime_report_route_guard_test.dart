// Story 5.2 (DNI-517) AC-1, AC-2: the lifetime report is a parent surface.
//
// A real AppRouter whose other guards let everything through, so these
// tests exercise exactly the report's parent-session guard, the Lifetime
// entry and the screen's own session check. The session is the real
// parentSessionProvider over a chosen profile, parent PIN state and tutor
// selection.
@Tags(['progress', 'lifetime', 'route_guards', 'story_5_2'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/parent_session_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_knowledge_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_report_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_report_sections.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/progress/lifetime_report_fixtures.dart';
import '../../../../helpers/pump_app.dart';

class _AllowAll extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) =>
      resolver.next(true);
}

class _PinService extends Mock implements PinService {}

final class _AllowProfile extends ProfileGuard {
  _AllowProfile()
    : super(
        getProfiles: () async => const [],
        getSelectedProfileId: () => null,
        setSelectedProfileId: (_) {},
        isTutoredSession: () => false,
        profilePickerRoute: () => const SettingsRoute(),
      );

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async => resolver.next(true);
}

final class _AllowChildMode extends ChildModeGuard {
  _AllowChildMode()
    : super(
        getProfileById: (_) async => null,
        getSelectedProfileId: () => null,
      );

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async => resolver.next(true);
}

final class _AllowPin extends PinGuard {
  _AllowPin()
    : super(
        pinService: _PinService(),
        promptForPin: () async => true,
        getScope: () => null,
        pinSetupRoute: () => const SettingsRoute(),
      );

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async => resolver.next(true);
}

const _profileId = 'profile-1';

/// The session under test.
enum _Session { child, childPinUnlocked, adult, tutor }

class _Harness {
  _Harness(
    this.session, {
    List<CurriculumCompletionSummary> lifetime = const [],
    List<ReportProjection>? reports,
  }) {
    container = ProviderContainer(
      overrides: [
        activeProfileProvider.overrideWith(
          (ref) async => LearnerProfileEntity(
            profileId: _profileId,
            displayName: 'Yehuda',
            mode: session == _Session.adult || session == _Session.tutor
                ? ProfileMode.adult
                : ProfileMode.child,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ),
        effectiveUseHebrewTermsProvider.overrideWithValue(false),
        currentSacredWindowProvider.overrideWithValue(null),
        activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
        learnerStateProvider.overrideWith((ref, _) {
          return Stream.value(reportState(reports ?? [fullReport()]));
        }),
        lifetimeReportProvider.overrideWith((ref, _) {
          reportReads++;
          return const AsyncLoading<LifetimeReportView>();
        }),
        // The Lifetime screen's own (legacy) reads: the tree it lists.
        lifetimeViewSummariesProvider.overrideWith((ref) async => lifetime),
        itemsLearnedSummariesProvider.overrideWith((ref) async => lifetime),
        lifetimeHeaderCountersProvider.overrideWith(
          (ref) async =>
              const LifetimeHeaderCounters(itemsLearned: 0, totalChazaros: 0),
        ),
        trackOnlyHeaderCountersProvider.overrideWith(
          (ref) async =>
              const LifetimeHeaderCounters(itemsLearned: 0, totalChazaros: 0),
        ),
      ],
    );
    if (session == _Session.childPinUnlocked) unlockPin();
    if (session == _Session.tutor) {
      container
          .read(activeTutoredProfileSelectionProvider.notifier)
          .enter(
            const TutoredProfileSelection(
              profileId: _profileId,
              ownerUid: 'owner',
              grantId: 'grant',
              permissions: TutorPermissions(canViewProgress: true),
              tutorOwnProfileId: 'tutor-own',
            ),
          );
    }
    router = AppRouter(
      sacredTimeLocationGuard: _AllowAll(),
      authGuard: _AllowAll(),
      profileGuard: _AllowProfile(),
      childModeGuard: _AllowChildMode(),
      pinGuard: _AllowPin(),
      parentSessionGuard: ParentSessionGuard(
        isParentSession: () async {
          final sub = container.listen(parentSessionProvider.future, (_, _) {});
          try {
            return await sub.read();
          } finally {
            sub.close();
          }
        },
      ),
    );
  }

  final _Session session;
  late final ProviderContainer container;
  late final AppRouter router;
  var reportReads = 0;

  void unlockPin() => container
      .read(parentPinAuthenticatedProfileIdProvider.notifier)
      .setAuthenticated(_profileId);

  void lockPin() =>
      container.read(parentPinAuthenticatedProfileIdProvider.notifier).clear();

  Future<void> pump(WidgetTester tester, String path) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      pumpApp(
        routerConfig: router.config(
          deepLinkBuilder: (_) => DeepLink.path(path),
        ),
        container: container,
      ),
    );
    await tester.pumpAndSettle();
  }
}

final _entry = find.byKey(const ValueKey('lifetimeReportEntry'));

void main() {
  group('no Report entry and no report for a non-parent session (AC-2)', () {
    for (final session in [_Session.child, _Session.tutor]) {
      testWidgets('${session.name}: Lifetime has no Report entry', (
        tester,
      ) async {
        final h = _Harness(session);
        await h.pump(tester, '/progress/lifetime');
        expect(find.byType(LifetimeKnowledgeScreen), findsOneWidget);
        expect(_entry, findsNothing);
      });

      testWidgets('${session.name}: a deep link to the report lands on '
          'Lifetime without reading report data', (tester) async {
        final h = _Harness(session);
        await h.pump(tester, '/progress/lifetime/report');
        expect(find.byType(LifetimeKnowledgeScreen), findsOneWidget);
        expect(find.byType(LifetimeReportScreen), findsNothing);
        expect(find.byType(LifetimeReportTotals), findsNothing);
        expect(h.reportReads, 0);
      });
    }
  });

  group('a parent session reaches the report (AC-1)', () {
    for (final session in [_Session.childPinUnlocked, _Session.adult]) {
      testWidgets('${session.name}: Lifetime → Report opens the report', (
        tester,
      ) async {
        final h = _Harness(session);
        await h.pump(tester, '/progress/lifetime');
        expect(_entry, findsOneWidget);
        expect(find.text('Report'), findsOneWidget);

        await tester.tap(_entry);
        await tester.pumpAndSettle();
        expect(find.byType(LifetimeReportScreen), findsOneWidget);
        expect(
          find.bySemanticsLabel('Learning events · 2,040'),
          findsOneWidget,
        );
      });

      testWidgets('${session.name}: the deep link opens the report', (
        tester,
      ) async {
        final h = _Harness(session);
        await h.pump(tester, '/progress/lifetime/report?curriculum=mishnayos');
        expect(find.byType(LifetimeReportScreen), findsOneWidget);
        expect(
          find.bySemanticsLabel('Distinct · 1,204 Mishnayos'),
          findsOneWidget,
        );
      });
    }
  });

  group('the report opens for the curriculum in view on Lifetime (AC-1)', () {
    CurriculumCompletionSummary listed(CurriculumId curriculum) =>
        CurriculumCompletionSummary(
          curriculumId: curriculum,
          learnedLeafCount: 3,
          totalLeafCount: 10,
          tree: const [],
        );

    // Chumash is first in app order, so it is what the report would pick
    // on its own.
    final both = [
      fullReport(),
      homeOnlyReport(
        curriculumId: reportRetiredCurriculum,
        events: 30,
        distinct: 25,
        withBeforeTracking: false,
      ),
    ];

    testWidgets('the expanded curriculum card, not the first one', (
      tester,
    ) async {
      final h = _Harness(
        _Session.adult,
        lifetime: [
          listed(CurriculumId.chumash),
          listed(CurriculumId.mishnayos),
        ],
        reports: both,
      );
      await h.pump(tester, '/progress/lifetime');
      await tester.tap(find.text('Mishnayos'));
      await tester.pumpAndSettle();

      await tester.tap(_entry);
      await tester.pumpAndSettle();
      expect(find.byType(LifetimeReportScreen), findsOneWidget);
      expect(
        find.bySemanticsLabel('Distinct · 1,204 Mishnayos'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Distinct · 25 Pesukim'), findsNothing);
    });

    testWidgets('the curriculum the tree lists when it is not the first with '
        'report data', (tester) async {
      final h = _Harness(
        _Session.childPinUnlocked,
        lifetime: [listed(CurriculumId.mishnayos)],
        reports: both,
      );
      await h.pump(tester, '/progress/lifetime');
      await tester.tap(_entry);
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Distinct · 1,204 Mishnayos'),
        findsOneWidget,
      );
    });

    testWidgets('collapsing the card falls back to the first one listed', (
      tester,
    ) async {
      final h = _Harness(
        _Session.adult,
        lifetime: [
          listed(CurriculumId.chumash),
          listed(CurriculumId.mishnayos),
        ],
        reports: both,
      );
      await h.pump(tester, '/progress/lifetime');
      await tester.tap(find.text('Mishnayos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mishnayos'));
      await tester.pumpAndSettle();

      await tester.tap(_entry);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Distinct · 25 Pesukim'), findsOneWidget);
    });
  });

  testWidgets('locking the parent PIN on the report leaves for Lifetime and '
      'drops the report (AC-2)', (tester) async {
    final h = _Harness(_Session.childPinUnlocked);
    await h.pump(tester, '/progress/lifetime');
    await tester.tap(_entry);
    await tester.pumpAndSettle();
    expect(find.byType(LifetimeReportTotals), findsOneWidget);

    h.lockPin();
    await tester.pumpAndSettle();
    expect(find.byType(LifetimeReportScreen), findsNothing);
    expect(find.byType(LifetimeKnowledgeScreen), findsOneWidget);
    expect(_entry, findsNothing);
  });

  testWidgets('a parent PIN unlocked later shows the entry', (tester) async {
    final h = _Harness(_Session.child);
    await h.pump(tester, '/progress/lifetime');
    expect(_entry, findsNothing);
    h.unlockPin();
    await tester.pumpAndSettle();
    expect(_entry, findsOneWidget);
  });
}
