// Mirror test for
// `lib/features/sacred_time/presentation/providers/account_lock_provider.dart`
// (DNI-481 AC-1, AC-2 and the multi-learner / tutor edge rows).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/sacred_lock.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _owner = 'owner-uid';
const _sibling = '01ARZ3NDEKTSV4RRFFQ69G5FB2';
const _talmid = '01ARZ3NDEKTSV4RRFFQ69G5FB3';

LearnerProfileEntity _profile(String id) => LearnerProfileEntity(
  profileId: id,
  displayName: id,
  mode: ProfileMode.child,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final _a = LearnerScope(ownerUid: _owner, profileId: profileUlid);
final _b = LearnerScope(ownerUid: _owner, profileId: _sibling);
final _t = LearnerScope(ownerUid: 'parent-uid', profileId: _talmid);

/// A tutored-session selection of [_t].
class _Tutored extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => const TutoredProfileSelection(
    profileId: _talmid,
    ownerUid: 'parent-uid',
    grantId: 'grant-1',
    permissions: TutorPermissions(),
  );
}

ProviderContainer _container({
  String? uid = _owner,
  List<String> profiles = const [profileUlid, _sibling],
  bool tutored = false,
  List<Override> extra = const [],
}) {
  final container = ProviderContainer.test(
    overrides: [
      ownAccountPathUidProvider.overrideWith((ref) async => uid),
      profileListStreamProvider.overrideWith(
        (ref) => Stream.value([for (final id in profiles) _profile(id)]),
      ),
      if (tutored)
        activeTutoredProfileSelectionProvider.overrideWith(_Tutored.new),
      ...extra,
    ],
  );
  return container;
}

Future<AsyncValue<List<LearnerScope>>> _scopes(ProviderContainer c) async {
  final sub = c.listen(lockDrivingScopesProvider, (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < 10 && sub.read().isLoading; i++) {
    await pumpEventQueue();
  }
  return sub.read();
}

void main() {
  group('lockDrivingScopesProvider', () {
    test('every learner profile of the signed-in account, owned by the '
        'account path uid', () async {
      final scopes = await _scopes(_container());
      expect(scopes.requireValue, [_a, _b]);
    });

    test('signed out (no path uid): no learner drives the lock', () async {
      final scopes = await _scopes(_container(uid: null));
      expect(scopes.requireValue, isEmpty);
    });

    test('a tutored talmid never drives the account lock, in or out of a '
        'tutored session (AD-36)', () async {
      expect((await _scopes(_container(tutored: true))).requireValue, [_a, _b]);
      expect((await _scopes(_container())).requireValue, [_a, _b]);
    });

    test('signed out in a tutored session: still no learner', () async {
      final scopes = await _scopes(_container(uid: null, tutored: true));
      expect(scopes.requireValue, isEmpty);
    });

    test('loading while the path uid loads; an error when it fails', () async {
      final never = Completer<String?>();
      final loading = ProviderContainer.test(
        overrides: [
          ownAccountPathUidProvider.overrideWith((ref) => never.future),
        ],
      );
      expect(loading.read(lockDrivingScopesProvider).isLoading, isTrue);

      final failing = ProviderContainer.test(
        overrides: [
          ownAccountPathUidProvider.overrideWith(
            (ref) async => throw StateError('re-home pending'),
          ),
        ],
      );
      expect((await _scopes(failing)).hasError, isTrue);
    });
  });

  group('accountLockHistoriesProvider', () {
    final lakewoodH = constantHistory(lakewood);

    test('each learner judged by its own learnerLockSettingsProvider '
        'history', () async {
      final jerusalemH = constantHistory(jerusalem);
      final c = _container(
        extra: [
          learnerLockSettingsProvider(
            _a,
          ).overrideWithValue(AsyncData(lakewoodH)),
          learnerLockSettingsProvider(
            _b,
          ).overrideWithValue(AsyncData(jerusalemH)),
        ],
      );
      await _scopes(c);
      expect(c.read(accountLockHistoriesProvider), [lakewoodH, jerusalemH]);
    });

    test(
      'a learner whose settings load or fail is judged fail-closed',
      () async {
        final c = _container(
          extra: [
            learnerLockSettingsProvider(
              _a,
            ).overrideWithValue(const AsyncLoading()),
            learnerLockSettingsProvider(_b).overrideWithValue(
              AsyncError(StateError('unreadable'), StackTrace.empty),
            ),
          ],
        );
        await _scopes(c);
        expect(c.read(accountLockHistoriesProvider), [
          failClosedSettingsHistory(profileUlid),
          failClosedSettingsHistory(_sibling),
        ]);
      },
    );

    test('the whole account is fail-closed while its learners load', () {
      final never = Completer<String?>();
      final c = ProviderContainer.test(
        overrides: [
          ownAccountPathUidProvider.overrideWith((ref) => never.future),
        ],
      );
      expect(c.read(accountLockHistoriesProvider), [
        failClosedSettingsHistory(unknownAccountLearner),
      ]);
    });

    test('signed out: no history, so no lock', () async {
      final c = _container(uid: null);
      await _scopes(c);
      expect(c.read(accountLockHistoriesProvider), isEmpty);
      expect(
        sacredWindowAt(
          c.read(accountLockHistoriesProvider),
          DateTime.utc(2026, 9, 5, 12),
        ),
        isNull,
      );
    });

    test('LearnerSettingsHistory equality keeps the list stable', () {
      expect(
        failClosedSettingsHistory('x'),
        LearnerSettingsHistory.constant(
          failClosedSettingsHistory('x').spans.single.settings,
        ),
      );
    });
  });

  group('tutoredLearnerLockHistoryProvider (AD-36 tutor rule)', () {
    test('null outside a tutored session', () {
      expect(_container().read(tutoredLearnerLockHistoryProvider), isNull);
    });

    test("the talmid's own history in a tutored session, and it stays out "
        'of the account histories', () async {
      final lakewoodH = constantHistory(lakewood);
      final jerusalemH = constantHistory(jerusalem);
      final c = _container(
        tutored: true,
        extra: [
          learnerLockSettingsProvider(
            _a,
          ).overrideWithValue(AsyncData(jerusalemH)),
          learnerLockSettingsProvider(
            _b,
          ).overrideWithValue(AsyncData(jerusalemH)),
          learnerLockSettingsProvider(
            _t,
          ).overrideWithValue(AsyncData(lakewoodH)),
        ],
      );
      await _scopes(c);
      expect(c.read(tutoredLearnerLockHistoryProvider), lakewoodH);
      expect(c.read(accountLockHistoriesProvider), [jerusalemH, jerusalemH]);
      // Saturday 20:00Z: Lakewood (the talmid) is locked, Jerusalem (the
      // tutor's own learners) is not — the device predicate stays open.
      expect(
        c.read(deviceLockPredicateProvider)(DateTime.utc(2026, 9, 5, 20)),
        isFalse,
      );
    });

    test("fail closed while the talmid's settings load or fail", () {
      for (final value in <AsyncValue<LearnerSettingsHistory>>[
        const AsyncLoading(),
        AsyncError(StateError('unreadable'), StackTrace.empty),
      ]) {
        final c = _container(
          tutored: true,
          extra: [learnerLockSettingsProvider(_t).overrideWithValue(value)],
        );
        expect(
          c.read(tutoredLearnerLockHistoryProvider),
          failClosedSettingsHistory(_talmid),
        );
      }
    });
  });

  group('deviceLockPredicateProvider (DNI-481 AC-5)', () {
    test('judges an instant with the same union the overlay shows', () {
      final lakewoodH = constantHistory(lakewood);
      final jerusalemH = constantHistory(jerusalem);
      final c = ProviderContainer.test(
        overrides: [
          accountLockHistoriesProvider.overrideWithValue([
            jerusalemH,
            lakewoodH,
          ]),
        ],
      );
      final isLocked = c.read(deviceLockPredicateProvider);
      for (final t in [
        DateTime.utc(2026, 9, 5, 12),
        DateTime.utc(2026, 9, 5, 20),
        DateTime.utc(2026, 9, 8, 12),
      ]) {
        expect(
          isLocked(t),
          sacredWindowAt([jerusalemH, lakewoodH], t) != null,
          reason: '$t',
        );
      }
      expect(isLocked(DateTime.utc(2026, 9, 5, 20)), isTrue);
      expect(isLocked(DateTime.utc(2026, 9, 8, 12)), isFalse);
    });
  });
}
