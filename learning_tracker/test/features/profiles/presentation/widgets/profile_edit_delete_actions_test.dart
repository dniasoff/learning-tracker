/// Firestore-native profile edit/delete flow tests.
@Tags(['l1', 'profiles', 'offline_first', 'r_pr4', 'aud_profiles_02'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_edit_delete_actions.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

_MockFlutterSecureStorage _createMockStorage() {
  final mock = _MockFlutterSecureStorage();
  final store = <String, String>{};
  when(
    () => mock.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    final value = invocation.namedArguments[#value] as String?;
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  });
  when(() => mock.read(key: any(named: 'key'))).thenAnswer((invocation) async {
    return store[invocation.namedArguments[#key] as String];
  });
  when(() => mock.delete(key: any(named: 'key'))).thenAnswer((
    invocation,
  ) async {
    store.remove(invocation.namedArguments[#key] as String);
  });
  return mock;
}

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final String? _initial;

  @override
  String? build() => _initial;
}

LearnerProfileEntity _profile({
  required String id,
  required String name,
  required ProfileMode mode,
  String avatar = '',
}) => LearnerProfileEntity(
  profileId: id,
  displayName: name,
  mode: mode,
  avatar: avatar,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(ProfileMode.adult);
  });

  group('deleteProfileFlow', () {
    testWidgets('deletes a non-last profile without an online-gate snackbar', (
      tester,
    ) async {
      final repo = _MockProfileRepository();
      final profile = _profile(
        id: '01HDELETEPROFILE00000000000',
        name: 'ToDelete',
        mode: ProfileMode.child,
      );
      when(() => repo.countProfiles()).thenAnswer((_) async => 2);
      when(
        () => repo.deleteProfile(any(), allowLast: any(named: 'allowLast')),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        pumpApp(
          overrides: [
            profileRepositoryProvider.overrideWithValue(repo),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId('01HOTHERPROFILE000000000000'),
            ),
          ],
          child: _ActionButton(
            label: 'Delete',
            onPressed: (context, ref) =>
                deleteProfileFlow(context, ref, profile),
          ),
        ),
      );
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pump(const Duration(milliseconds: 100));

      verify(
        () => repo.deleteProfile(profile.profileId, allowLast: false),
      ).called(1);
      expect(find.textContaining('internet connection'), findsNothing);
    });

    testWidgets('deleting the active profile selects a remaining profile', (
      tester,
    ) async {
      const deletedId = '01HDELETEACTIVE0000000000000';
      const remainingId = '01HREMAININGPROFILE00000000';
      final profile = _profile(
        id: deletedId,
        name: 'ActiveProfile',
        mode: ProfileMode.child,
      );
      final remaining = _profile(
        id: remainingId,
        name: 'Remaining',
        mode: ProfileMode.adult,
      );
      final repo = _MockProfileRepository();
      when(() => repo.countProfiles()).thenAnswer((_) async => 2);
      when(
        () => repo.deleteProfile(any(), allowLast: any(named: 'allowLast')),
      ).thenAnswer((_) async {});
      when(() => repo.getProfiles()).thenAnswer((_) async => [remaining]);
      late ProviderContainer container;

      await tester.pumpWidget(
        pumpApp(
          overrides: [
            profileRepositoryProvider.overrideWithValue(repo),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(deletedId),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return _ActionButton(
                label: 'Delete',
                onPressed: (ctx, widgetRef) =>
                    deleteProfileFlow(ctx, widgetRef, profile),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => repo.deleteProfile(deletedId, allowLast: false)).called(1);
      expect(container.read(selectedProfileIdProvider), remainingId);
    });
  });

  group('ProfileEditFormDialog', () {
    Future<void> pumpDialog(WidgetTester tester, String? mode) async {
      await tester.pumpWidget(
        pumpApp(
          child: Scaffold(
            body: ProfileEditFormDialog(
              title: 'Edit Learner',
              initialName: 'Sample',
              initialMode: mode,
              initialAvatar: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('child, adult, and missing modes seed correctly', (
      tester,
    ) async {
      await pumpDialog(tester, 'child');
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .selected,
        {'child'},
      );
      await tester.pumpWidget(const SizedBox.shrink());

      await pumpDialog(tester, 'adult');
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .selected,
        {'adult'},
      );
      await tester.pumpWidget(const SizedBox.shrink());

      await pumpDialog(tester, null);
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .selected,
        {'child'},
      );
    });

    testWidgets('empty name shows inline validation and stays open', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpApp(
          child: const Scaffold(
            body: ProfileEditFormDialog(title: 'Edit Learner'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.widgetWithText(FilledButton, l10n.actionSave));
      await tester.pumpAndSettle();
      expect(find.text(l10n.learnerNameRequired), findsOneWidget);
      expect(find.byType(ProfileEditFormDialog), findsOneWidget);
    });
  });

  group('R-PR4 child to adult mode change', () {
    testWidgets('clears profile and tutor PINs', (tester) async {
      const profileId = '01HPR4PROFILE00000000000000';
      final storage = _createMockStorage();
      final pinService = PinService(storage);
      await pinService.setProfilePin(profileId, '1234');
      await pinService.setTutorPin(profileId, '5678');
      final child = _profile(
        id: profileId,
        name: 'Yosef',
        mode: ProfileMode.child,
      );
      final updated = child.copyWith(mode: ProfileMode.adult);
      final repo = _MockProfileRepository();
      when(
        () => repo.updateProfile(
          profileId: any(named: 'profileId'),
          displayName: any(named: 'displayName'),
          mode: any(named: 'mode'),
          avatar: any(named: 'avatar'),
        ),
      ).thenAnswer((_) async => updated);

      await tester.pumpWidget(
        pumpApp(
          overrides: [
            flutterSecureStorageProvider.overrideWithValue(storage),
            profileRepositoryProvider.overrideWithValue(repo),
          ],
          child: _ActionButton(
            label: 'Edit',
            onPressed: (context, ref) => editProfileFlow(context, ref, child),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pump(const Duration(milliseconds: 300));
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.profilesAdultLabel).first);
      await tester.tap(find.text(l10n.actionSave));
      await tester.pump(const Duration(milliseconds: 300));

      expect(await pinService.hasProfilePin(profileId), isFalse);
      expect(await pinService.hasTutorPin(profileId), isFalse);
    });
  });

  testWidgets('DuplicateProfileNameException is surfaced as profileNameTaken', (
    tester,
  ) async {
    final profile = _profile(
      id: '01HDUPLICATEPROFILE00000000',
      name: 'Original',
      mode: ProfileMode.child,
    );
    final repo = _MockProfileRepository();
    when(
      () => repo.updateProfile(
        profileId: any(named: 'profileId'),
        displayName: any(named: 'displayName'),
        mode: any(named: 'mode'),
        avatar: any(named: 'avatar'),
      ),
    ).thenThrow(const DuplicateProfileNameException('Original'));

    await tester.pumpWidget(
      pumpApp(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: _ActionButton(
          label: 'Edit',
          onPressed: (context, ref) => editProfileFlow(context, ref, profile),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pump(const Duration(milliseconds: 300));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.actionSave));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.profileNameTaken('Original')), findsOneWidget);
  });
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final Future<void> Function(BuildContext, WidgetRef) onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer(
        builder: (context, ref, _) => Center(
          child: ElevatedButton(
            onPressed: () => onPressed(context, ref),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
