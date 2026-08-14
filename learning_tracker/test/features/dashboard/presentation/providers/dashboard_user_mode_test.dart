import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const _uid = 'dashboard-user-mode-test';
const _adultProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXYA';
const _childProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXYB';

AccountFirebaseHandles _handles(FakeFirebaseFirestore firestore) {
  return AccountFirebaseHandles(
    app: _MockFirebaseApp(),
    firestore: firestore,
    auth: _MockFirebaseAuth(),
    uid: _uid,
  );
}

ProviderContainer _makeContainer(
  FakeFirebaseFirestore firestore, {
  String? activeProfileId,
}) {
  return ProviderContainer(
    overrides: [
      activeAccountFirebaseProvider.overrideWith(
        (ref) async => _handles(firestore),
      ),
      if (activeProfileId != null)
        activeProfileIdProvider.overrideWith(
          () => _FixedActiveProfileId(activeProfileId),
        ),
    ],
  );
}

/// Pins the active profile to a Firestore document id, used to simulate a
/// tutor viewing the child's profile while the selected own profile is adult.
class _FixedActiveProfileId extends ActiveProfileId {
  _FixedActiveProfileId(this._id);
  final String _id;

  @override
  String build() => _id;
}

void main() {
  group('dashboardUserModeProvider', () {
    late FakeFirebaseFirestore firestore;

    setUp(() async {
      firestore = createFakeFirestore(authenticatedUid: _uid);
      await seedAccount(firestore, uid: _uid);
    });

    test('returns child when active profile mode is child', () async {
      await seedProfile(
        firestore,
        uid: _uid,
        profileId: _childProfileId,
        mode: ProfileMode.child,
      );
      final container = _makeContainer(firestore);
      addTearDown(container.dispose);
      container
          .read(selectedProfileIdProvider.notifier)
          .select(_childProfileId);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.child);
    });

    test('returns adult when active profile mode is adult', () async {
      await seedProfile(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        mode: ProfileMode.adult,
      );
      final container = _makeContainer(firestore);
      addTearDown(container.dispose);
      container
          .read(selectedProfileIdProvider.notifier)
          .select(_adultProfileId);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.adult);
    });

    test(
      'returns child for a tutored CHILD mirror even though the tutor is an '
      'adult (Bug 1 regression: tutor must see the talmid points/rewards)',
      () async {
        await seedProfile(
          firestore,
          uid: _uid,
          profileId: _adultProfileId,
          mode: ProfileMode.adult,
        );
        await seedProfile(
          firestore,
          uid: _uid,
          profileId: _childProfileId,
          displayName: 'Child',
          mode: ProfileMode.child,
        );

        final container = _makeContainer(
          firestore,
          activeProfileId: _childProfileId,
        );
        addTearDown(container.dispose);
        container
            .read(selectedProfileIdProvider.notifier)
            .select(_adultProfileId);
        container
            .read(activeProfileDocIdProvider.notifier)
            .set(_childProfileId);

        final mode = await container.read(dashboardUserModeProvider.future);
        expect(mode, ProfileMode.child);
      },
    );

    test('defaults to adult when no profile row exists', () async {
      final container = _makeContainer(firestore);
      addTearDown(container.dispose);
      container
          .read(selectedProfileIdProvider.notifier)
          .select('01J6Q2H4A8M7K3P9R5T6V8WXYC');

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.adult);
    });
  });
}
