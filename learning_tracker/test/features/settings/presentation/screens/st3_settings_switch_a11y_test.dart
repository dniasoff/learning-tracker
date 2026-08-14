/// ST-3 regression test — Hebrew-Terms Switch in SettingsScreen exposes no
/// accessibility label.
///
/// SYMPTOM: The Hebrew Terms toggle in Settings renders a bare Switch() with
/// the label text in a sibling node.  Screen readers announce the control as
/// an unlabeled switch ("Switch, on/off") rather than "Hebrew Terms, Switch".
///
/// ROOT CAUSE: _HebrewTermsTile in settings_screen.dart used a plain Switch()
/// with no wrapping Semantics node.  The label lives in PreferenceListTile's
/// leading Text, which is a separate leaf in the semantic tree.
///
/// FIX UNDER TEST (ST-3 wave-B): _HebrewTermsTile now wraps the Switch in
/// a Semantics(label: l10n.hebrewTermsPreference) node so assistive tech can
/// announce "Hebrew Terms, Switch, on/off".
///
/// TEST:
///   S1.  The Switch that is a descendant of the PreferenceListTile carrying
///        l10n.hebrewTermsPreference (i.e. _HebrewTermsTile's own Switch,
///        located specifically — not "any labelled Switch on the screen")
///        has a semantics label equal to l10n.hebrewTermsPreference.
@Tags(['settings', 'st3', 'a11y'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/preference_list_tile.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/pump_app.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _StubAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.signedOut();
}

class _FakeActiveProfileId extends ActiveProfileId {
  @override
  String? build() => null; // signed-out test has no active profile
}

Widget _buildSettings({
  required _MockAuthRepository authRepo,
}) {
  return pumpApp(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      authStateProvider.overrideWith(() => _StubAuthStateNotifier()),
      activeProfileIdProvider.overrideWith(() => _FakeActiveProfileId()),
      profileListStreamProvider.overrideWith((ref) => Stream.value(const [])),
    ],
    // Wrap in a Scaffold so the screen has a proper scaffold ancestor.
    child: const SettingsScreen(),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'Test',
      packageName: 'test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  late _MockAuthRepository authRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authRepo = _MockAuthRepository();
    when(() => authRepo.currentUser).thenReturn(null);
    when(
      () => authRepo.onAuthStateChanged(),
    ).thenAnswer((_) => const Stream.empty());
  });

  // ── S1: Hebrew Terms Switch has a semantics label ───────────────────────────

  testWidgets(
    'S1. Hebrew Terms switch exposes a non-empty accessibility label',
    (tester) async {
      await tester.pumpWidget(_buildSettings(authRepo: authRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final l10n = AppLocalizations.of(
        tester.element(find.byType(SettingsScreen)),
      )!;

      // SettingsScreen's outer ListView only builds/mounts elements near the
      // viewport (Sliver lazy-build). _HebrewTermsTile sits below several
      // earlier cards — including SacredTimeSettingsCard, which renders its
      // OWN unrelated Switch higher up the list. Scroll it into view rather
      // than assuming it (or its Switch) is already mounted: without this,
      // `find.byType(Switch)` would find the Sacred-Time card's Switch
      // instead (it merges its Row's text into a non-empty semantics label),
      // which is precisely the "any labelled Switch" trap ST-3 must not
      // fall into.
      await tester.scrollUntilVisible(
        find.text(l10n.hebrewTermsPreference),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Locate the *specific* PreferenceListTile that carries the
      // Hebrew-Terms preference title — not any tile, not any switch.
      final hebrewTermsTile = find.byWidgetPredicate(
        (widget) =>
            widget is PreferenceListTile &&
            widget.title == l10n.hebrewTermsPreference,
      );
      expect(
        hebrewTermsTile,
        findsOneWidget,
        reason:
            'ST-3: SettingsScreen must render exactly one PreferenceListTile '
            'titled l10n.hebrewTermsPreference (_HebrewTermsTile) in the en '
            'locale — cannot isolate the Hebrew-Terms Switch without it.',
      );

      // Locate the Switch that is a descendant of THAT tile specifically —
      // not "any Switch in the screen that happens to have a label".
      final hebrewTermsSwitch = find.descendant(
        of: hebrewTermsTile,
        matching: find.byType(Switch),
      );
      expect(
        hebrewTermsSwitch,
        findsOneWidget,
        reason:
            'ST-3: The Hebrew-Terms PreferenceListTile must render exactly '
            'one Switch as its trailing control.',
      );

      final semanticsNode = tester.getSemantics(hebrewTermsSwitch);
      expect(
        semanticsNode.label,
        equals(l10n.hebrewTermsPreference),
        reason:
            'ST-3: _HebrewTermsTile\'s own Switch must carry a Semantics '
            'label equal to l10n.hebrewTermsPreference so screen readers '
            'announce it by name (e.g. "Hebrew Terms, Switch, on/off"). '
            'This asserts the label on the Hebrew-Terms Switch specifically '
            '— a labelled Switch elsewhere on SettingsScreen must NOT be '
            'able to satisfy this check.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
