// Story 5.2 (DNI-517) AC-2: the parent-session rule behind the lifetime
// report entry, route guard and provider.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

const _profileId = 'profile-1';

LearnerProfileEntity _profile(ProfileMode mode) => LearnerProfileEntity(
  profileId: _profileId,
  displayName: 'Yehuda',
  mode: mode,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<bool> _session({
  LearnerProfileEntity? profile,
  String? pinProfileId,
  bool tutored = false,
  bool throws = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      activeProfileProvider.overrideWith((ref) async {
        if (throws) throw StateError('profile read failed');
        return profile;
      }),
    ],
  );
  addTearDown(container.dispose);
  if (pinProfileId != null) {
    container
        .read(parentPinAuthenticatedProfileIdProvider.notifier)
        .setAuthenticated(pinProfileId);
  }
  if (tutored) {
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
  final sub = container.listen(parentSessionProvider.future, (_, _) {});
  addTearDown(sub.close);
  return sub.read();
}

void main() {
  test(
    'a child profile with its parent PIN unlocked is a parent session',
    () async {
      expect(
        await _session(
          profile: _profile(ProfileMode.child),
          pinProfileId: _profileId,
        ),
        isTrue,
      );
    },
  );

  test('a child profile with the PIN locked is not', () async {
    expect(await _session(profile: _profile(ProfileMode.child)), isFalse);
  });

  test('a PIN unlocked for another profile does not count', () async {
    expect(
      await _session(
        profile: _profile(ProfileMode.child),
        pinProfileId: 'someone-else',
      ),
      isFalse,
    );
  });

  test('an adult profile is its own parent', () async {
    expect(await _session(profile: _profile(ProfileMode.adult)), isTrue);
  });

  test('a tutored session never is, even with a parent PIN', () async {
    expect(
      await _session(
        profile: _profile(ProfileMode.adult),
        pinProfileId: _profileId,
        tutored: true,
      ),
      isFalse,
    );
  });

  test('no profile, or a failed profile read, fails closed', () async {
    expect(await _session(), isFalse);
    expect(await _session(throws: true), isFalse);
  });
}
