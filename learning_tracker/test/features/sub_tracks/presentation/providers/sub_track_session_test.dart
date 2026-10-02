// Story 2.9 (DNI-500) — viewer role and the navigation seam.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_session.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

LearnerProfileEntity _profile(ProfileMode mode) => LearnerProfileEntity(
  profileId: 'p1',
  displayName: 'Moshe',
  mode: mode,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _NoTutor extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

class _Tutor extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => const TutoredProfileSelection(
    profileId: 'p1',
    ownerUid: 'o',
    grantId: 'g',
    permissions: TutorPermissions(),
  );
}

class _PinFor extends ParentPinAuthenticatedProfileId {
  _PinFor(this.id);
  final String? id;
  @override
  String? build() => id;
}

Future<SubTrackViewerRole> _role({
  LearnerProfileEntity? profile,
  bool tutor = false,
  String? pinFor,
}) async {
  final container = ProviderContainer(
    overrides: [
      activeTutoredProfileSelectionProvider.overrideWith(
        tutor ? _Tutor.new : _NoTutor.new,
      ),
      selectedProfileProvider.overrideWith((ref) async => profile),
      parentPinAuthenticatedProfileIdProvider.overrideWith(
        () => _PinFor(pinFor),
      ),
    ],
  );
  addTearDown(container.dispose);
  final sub = container.listen(subTrackViewerRoleProvider, (_, _) {});
  await container.read(selectedProfileProvider.future);
  final role = container.read(subTrackViewerRoleProvider);
  sub.close();
  return role;
}

void main() {
  test('a tutored session is the tutor', () async {
    expect(
      await _role(profile: _profile(ProfileMode.adult), tutor: true),
      SubTrackViewerRole.tutor,
    );
  });

  test('an adult profile is the parent', () async {
    expect(
      await _role(profile: _profile(ProfileMode.adult)),
      SubTrackViewerRole.parent,
    );
  });

  test('a child-mode profile is the child unless the parent PIN is '
      'verified for it', () async {
    expect(
      await _role(profile: _profile(ProfileMode.child)),
      SubTrackViewerRole.child,
    );
    expect(
      await _role(profile: _profile(ProfileMode.child), pinFor: 'other'),
      SubTrackViewerRole.child,
    );
    expect(
      await _role(profile: _profile(ProfileMode.child), pinFor: 'p1'),
      SubTrackViewerRole.parent,
    );
  });

  test('no profile is the least-privileged role', () async {
    expect(await _role(), SubTrackViewerRole.child);
  });

  test('the default navigator opens only the hub: no unbuilt destination '
      'is reported, so its entry point stays disabled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final navigator = container.read(subTrackNavigatorProvider);
    expect(navigator, isA<HubOnlySubTrackNavigator>());
    for (final destination in SubTrackDestination.values) {
      expect(navigator.canOpen(destination), isFalse, reason: '$destination');
    }
  });
}
