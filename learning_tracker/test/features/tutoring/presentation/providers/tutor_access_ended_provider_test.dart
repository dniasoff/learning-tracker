// Story 4.4 (DNI-512): the access-ended notice and its notifier — the
// session is ended only for the grant that is open, the learner's name is
// resolved before anything clears, and only a real revocation (not a
// signed-out verdict) counts as access lost.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_access_ended_provider.dart';

const _owner = 'parent-uid';
const _profile = '01J8XKQ2M3N4P5R6S7T8V9W0XY';
const _grant = 'grant-yossi';

const _selection = TutoredProfileSelection(
  profileId: _profile,
  ownerUid: _owner,
  grantId: _grant,
  permissions: TutorPermissions(canEditLearning: true),
);

LearnerProfileEntity _mirror(String name, {String id = _profile}) =>
    LearnerProfileEntity(
      profileId: id,
      displayName: name,
      mode: ProfileMode.child,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

ProviderContainer _container({LearnerProfileEntity? mirror}) {
  final c = ProviderContainer(
    overrides: <Override>[
      activeProfileProvider.overrideWith((ref) async => mirror),
      connectivityStreamProvider.overrideWith((ref) => const Stream.empty()),
    ],
  );
  addTearDown(c.dispose);
  c.listen(tutorAccessEndedProvider, (_, _) {});
  c.listen(activeProfileProvider, (_, _) {});
  return c;
}

void main() {
  group('TutorAccessEnded', () {
    test('has value equality over grant id and name', () {
      const a = TutorAccessEnded(grantId: 'g', learnerName: 'Yossi');

      expect(a, const TutorAccessEnded(grantId: 'g', learnerName: 'Yossi'));
      expect(
        a.hashCode,
        const TutorAccessEnded(grantId: 'g', learnerName: 'Yossi').hashCode,
      );
      expect(a, isNot(const TutorAccessEnded(grantId: 'g')));
      expect(
        a,
        isNot(const TutorAccessEnded(grantId: 'h', learnerName: 'Yossi')),
      );
    });

    test('toString names the grant but not the learner', () {
      expect(
        const TutorAccessEnded(grantId: 'g', learnerName: 'Yossi').toString(),
        'TutorAccessEnded(g)',
      );
    });
  });

  group('tutorScopeAccessLost', () {
    final scope = LearnerScope(ownerUid: _owner, profileId: _profile);
    AsyncValue<Object?> denied(TutorScopeDenialReason r) =>
        AsyncError(TutorScopeAccessDeniedException(scope, r), StackTrace.empty);

    test('is true for every refusal except signed-out', () {
      for (final r in TutorScopeDenialReason.values) {
        expect(
          tutorScopeAccessLost(denied(r)),
          r != TutorScopeDenialReason.notSignedIn,
          reason: r.name,
        );
      }
    });

    test('is false for data, loading and unrelated errors', () {
      expect(tutorScopeAccessLost(const AsyncData<Object?>(1)), isFalse);
      expect(tutorScopeAccessLost(const AsyncLoading<Object?>()), isFalse);
      expect(
        tutorScopeAccessLost(
          const AsyncError<Object?>('boom', StackTrace.empty),
        ),
        isFalse,
      );
    });
  });

  group('TutorAccessEndedNotifier', () {
    test('starts with no notice', () {
      expect(_container().read(tutorAccessEndedProvider), isNull);
    });

    test('end with no open session is a no-op', () {
      final c = _container();

      c.read(tutorAccessEndedProvider.notifier).end(_grant);

      expect(c.read(tutorAccessEndedProvider), isNull);
    });

    test('end for another grant leaves the session open', () async {
      final c = _container(mirror: _mirror('Yossi'));
      c.read(activeTutoredProfileSelectionProvider.notifier).enter(_selection);
      await c.read(activeProfileProvider.future);

      c.read(tutorAccessEndedProvider.notifier).end('someone-else');

      expect(c.read(activeTutoredProfileSelectionProvider), _selection);
      expect(c.read(tutorAccessEndedProvider), isNull);
    });

    test(
      'end exits the session and names the learner from the mirror',
      () async {
        final c = _container(mirror: _mirror('  Yossi '));
        c
            .read(activeTutoredProfileSelectionProvider.notifier)
            .enter(_selection);
        await c.read(activeProfileProvider.future);

        c.read(tutorAccessEndedProvider.notifier).end(_grant);

        expect(c.read(activeTutoredProfileSelectionProvider), isNull);
        expect(
          c.read(tutorAccessEndedProvider),
          const TutorAccessEnded(grantId: _grant, learnerName: 'Yossi'),
        );
      },
    );

    test('a mirror of a different profile gives no name', () async {
      final c = _container(mirror: _mirror('Dovi', id: 'OTHER'));
      c.read(activeTutoredProfileSelectionProvider.notifier).enter(_selection);
      await c.read(activeProfileProvider.future);

      c.read(tutorAccessEndedProvider.notifier).end(_grant);

      expect(c.read(tutorAccessEndedProvider)?.learnerName, isNull);
    });

    test('acknowledge clears only the notice it was given', () async {
      final c = _container(mirror: _mirror('Yossi'));
      c.read(activeTutoredProfileSelectionProvider.notifier).enter(_selection);
      await c.read(activeProfileProvider.future);
      final notifier = c.read(tutorAccessEndedProvider.notifier)..end(_grant);
      final notice = c.read(tutorAccessEndedProvider)!;

      notifier.acknowledge(const TutorAccessEnded(grantId: 'stale'));
      expect(c.read(tutorAccessEndedProvider), notice);

      notifier.acknowledge(notice);
      expect(c.read(tutorAccessEndedProvider), isNull);
    });
  });
}
