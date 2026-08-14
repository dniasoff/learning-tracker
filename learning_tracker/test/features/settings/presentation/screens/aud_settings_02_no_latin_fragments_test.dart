// AUD-settings-02 — no hardcoded Latin (English) sentence fragments in
// ScopeSelectionScreen / CurriculumSettingsScreen under the Hebrew locale.
//
// Regression for the P1 finding: ScopeSelectionScreen had roughly half its
// visible copy hardcoded in English (app-bar title, "All content is
// included" / "Only selected sections are tracked" subtitle, "Select Scope
// Level" / "Summary" headers, the un-pluralized "N items will be tracked"
// line, both save-confirmation SnackBar messages, and the level-tile
// "N options" subtitle), and CurriculumSettingsScreen hardcoded its app-bar
// title prefix and the "Copy" SnackBarAction label. A Hebrew-locale parent
// configuring curriculum scope — a core settings flow — saw a screen that
// switched between Hebrew and untranslated English mid-sentence.
//
// This file is the AC-2 checker named by the finding's acceptance criteria:
// "Widget test with Locale('he') renders both screens and asserts no
// Latin-script sentence fragments remain in the visible text tree." It walks
// every `Text` widget in the rendered tree and fails if any contains a run of
// 2+ consecutive Latin letters, across every reachable screen state
// (select-all default, level list, value checkboxes, summary, and both
// save-confirmation SnackBar variants for ScopeSelectionScreen; default
// "Custom schedule" render and the "no email app" SnackBar with its Copy
// action for CurriculumSettingsScreen).
//
// PROTOCOL: no pumpAndSettle — only pump() / pump(Duration) calls.
// Teardown: pumpWidget(SizedBox.shrink()) + pump(Duration.zero).

@Tags(['settings', 'scope_selection', 'curriculum_settings', 'aud_settings_02'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_scope_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_profile_program_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/curriculum_settings_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/scope_selection_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockContentRepository extends Mock implements ContentRepository {}

// ── Provider stubs ─────────────────────────────────────────────────────────────

class _HebrewTermsOn extends UseHebrewTerms {
  @override
  bool build() => true;
}

// ── Minimal synthetic content (mishnayos, 2 Sedarim / 2 Masechtos / 2 leaves) ──
//
// Every item carries a Hebrew display name so that, with useHebrewTerms=true,
// every value/level word on screen has a genuine Hebrew rendering available —
// isolating the assertion to genuinely-hardcoded English UI copy rather than
// content that merely lacks a Hebrew name in this fixture.

const _kSeder1 = 'Seder Zeraim';
const _kSeder2 = 'Seder Moed';
const _kMasechta1 = 'Berakhot';
const _kMasechta2 = 'Shabbat';

final _kFakeItems = [
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder1,
    displayNameHe: 'סדר זרעים',
    displayNameEn: _kSeder1,
    sefariaRef: 'Mishnah_Zeraim',
    sortOrder: 0,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder2,
    displayNameHe: 'סדר מועד',
    displayNameEn: _kSeder2,
    sefariaRef: 'Mishnah_Moed',
    sortOrder: 10,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder1,
    level2: _kMasechta1,
    displayNameHe: 'ברכות',
    displayNameEn: _kMasechta1,
    sefariaRef: 'Mishnah_Berakhot',
    sortOrder: 1,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder2,
    level2: _kMasechta2,
    displayNameHe: 'שבת',
    displayNameEn: _kMasechta2,
    sefariaRef: 'Mishnah_Shabbat',
    sortOrder: 11,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder1,
    level2: _kMasechta1,
    level3: '1',
    displayNameHe: 'א',
    displayNameEn: '1',
    sefariaRef: 'Mishnah_Berakhot.1',
    sortOrder: 2,
    isLeaf: true,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder2,
    level2: _kMasechta2,
    level3: '1',
    displayNameHe: 'א',
    displayNameEn: '1',
    sefariaRef: 'Mishnah_Shabbat.1',
    sortOrder: 12,
    isLeaf: true,
  ),
];

_MockContentRepository _makeContentRepo() {
  final repo = _MockContentRepository();
  when(
    () => repo.getContentForCurriculum(any<CurriculumId>()),
  ).thenAnswer((_) async => _kFakeItems);
  return repo;
}

// ── url_launcher platform-channel mock (forces the "no email app" branch) ────
//
// CurriculumSettingsScreen._onRequestProgram calls canLaunchUrl(mailto:...);
// returning false drives the SnackBar-with-Copy-action branch that carries
// the finding's "Copy" hardcoded string (line 204). The desktop-test host
// resolves url_launcher's platform interface to the classic MethodChannel
// implementation on `plugins.flutter.io/url_launcher` with method `canLaunch`
// (verified empirically against this checkout's pinned url_launcher_linux —
// NOT the `_linux`-suffixed channel / `canLaunchUrl` method name used by some
// other plugin versions).

const _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

void _setUpUrlLauncherMock({required bool canLaunch}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_urlLauncherChannel, (MethodCall call) async {
        if (call.method == 'canLaunch') return canLaunch;
        if (call.method == 'launch') return canLaunch;
        return null;
      });
}

void _clearUrlLauncherMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_urlLauncherChannel, null);
}

// ── Latin-fragment checker ────────────────────────────────────────────────────
//
// A "Latin-script sentence fragment" is approximated as 2+ consecutive ASCII
// Latin letters in the `.data` of any rendered Text widget — long enough to
// catch words/sentences while not tripping on single-letter tokens.

final _latinRun = RegExp('[A-Za-z]{2,}');

List<String> _findLatinFragments(WidgetTester tester) {
  final offenders = <String>[];
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final data = widget.data;
    if (data == null) continue;
    if (_latinRun.hasMatch(data)) offenders.add(data);
  }
  return offenders;
}

void _expectNoLatinFragments(WidgetTester tester, {required String where}) {
  final offenders = _findLatinFragments(tester);
  expect(
    offenders,
    isEmpty,
    reason:
        'Found Latin-script sentence fragment(s) under Hebrew locale at '
        '$where: $offenders',
  );
}

// ── Pump / teardown helpers ───────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Widget factories ──────────────────────────────────────────────────────────

Widget _buildScopeApp({
  required FirestoreCurriculumScopeRepository scopeRepository,
  ContentRepository? contentRepo,
}) {
  return ProviderScope(
    overrides: [
      firestoreCurriculumScopeRepositoryProvider.overrideWith(
        (ref) async => scopeRepository,
      ),
      contentRepositoryProvider.overrideWithValue(
        contentRepo ?? _makeContentRepo(),
      ),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOn()),
    ],
    child: const MaterialApp(
      locale: Locale('he'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ScopeSelectionScreen(curriculumId: CurriculumId.mishnayos),
    ),
  );
}

/// Variant of [_buildScopeApp] that PUSHES [ScopeSelectionScreen] onto a
/// placeholder home route (matching real usage — "Push this screen from
/// Settings or Onboarding") instead of making it the app's sole `home:`
/// route. `_save()` calls `Navigator.of(context).pop()` before showing its
/// confirmation SnackBar; with no underlying route to pop back to, popping
/// the app's only route empties the Navigator and tears down the whole
/// widget tree (including the ScaffoldMessenger's SnackBar), so the
/// SnackBar-content assertions need a real "screen underneath" to pop to.
Widget _buildScopeAppPushed({
  required FirestoreCurriculumScopeRepository scopeRepository,
  ContentRepository? contentRepo,
}) {
  return ProviderScope(
    overrides: [
      firestoreCurriculumScopeRepositoryProvider.overrideWith(
        (ref) async => scopeRepository,
      ),
      contentRepositoryProvider.overrideWithValue(
        contentRepo ?? _makeContentRepo(),
      ),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOn()),
    ],
    child: MaterialApp(
      locale: const Locale('he'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScopeSelectionScreen(
                    curriculumId: CurriculumId.mishnayos,
                  ),
                ),
              ),
              // Hebrew label — the previous route stays mounted (not
              // disposed) underneath the pushed ScopeSelectionScreen, so an
              // English placeholder label here would itself trip the
              // no-Latin-fragments assertion on the pushed screen's state.
              child: const Text('פתח'),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildCurriculumSettingsApp({
  required FirestoreProfileProgramRepository profileProgramRepository,
}) {
  return ProviderScope(
    overrides: [
      firestoreProfileProgramRepositoryProvider.overrideWith(
        (ref) async => profileProgramRepository,
      ),
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOn()),
    ],
    child: const MaterialApp(
      locale: Locale('he'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: CurriculumSettingsScreen(curriculumId: 'mishnayos'),
    ),
  );
}

// ── Shared state ───────────────────────────────────────────────────────────────

const _uid = 'aud-settings-02-test-uid';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY7';
late FakeFirebaseFirestore _firestore;
late FirestoreCurriculumScopeRepository _scopeRepository;
late FirestoreProfileProgramRepository _profileProgramRepository;

// ── Main ───────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  setUp(() async {
    _firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedAccount(_firestore, uid: _uid);
    await seedProfile(_firestore, uid: _uid, profileId: _profileId);
    _scopeRepository = FirestoreCurriculumScopeRepository(
      firestore: _firestore,
      uid: _uid,
      profileId: _profileId,
    );
    _profileProgramRepository = FirestoreProfileProgramRepository(
      firestore: _firestore,
      uid: _uid,
      profileId: _profileId,
    );
  });

  group('ScopeSelectionScreen — he locale: no Latin fragments', () {
    testWidgets(
      'select-all default state (app-bar title + "All content is included" '
      'subtitle) is fully Hebrew',
      (tester) async {
        await _pump(tester, _buildScopeApp(scopeRepository: _scopeRepository));

        // Sanity: the screen actually rendered (would be trivially "empty" if
        // the localized subtitle silently vanished instead of translating).
        expect(find.byType(SwitchListTile), findsOneWidget);

        _expectNoLatinFragments(tester, where: 'select-all default state');

        await _tearDown(tester);
      },
    );

    testWidgets(
      'level-list state ("Select Scope Level" header + "N options" subtitle) '
      'is fully Hebrew',
      (tester) async {
        await _pump(tester, _buildScopeApp(scopeRepository: _scopeRepository));

        await tester.tap(find.byType(SwitchListTile));
        await tester.pump();

        // Sanity: level tiles actually rendered.
        expect(find.byIcon(Icons.chevron_right), findsWidgets);

        _expectNoLatinFragments(tester, where: 'level-list state');

        await _tearDown(tester);
      },
    );

    testWidgets(
      'value-checkbox + summary state (item-count line, "Summary" header) '
      'is fully Hebrew',
      (tester) async {
        await _pump(tester, _buildScopeApp(scopeRepository: _scopeRepository));

        await tester.tap(find.byType(SwitchListTile));
        await tester.pump();
        final levelTile = find.descendant(
          of: find.byType(ListTile),
          matching: find.byIcon(Icons.chevron_right),
        );
        await tester.tap(levelTile.first);
        await tester.pump();
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();

        // Sanity: the Summary section actually appeared.
        expect(find.byType(CheckboxListTile), findsWidgets);

        _expectNoLatinFragments(
          tester,
          where: 'value-checkbox + summary state',
        );

        await _tearDown(tester);
      },
    );

    testWidgets(
      'save-confirmation SnackBar for selectAll=true ("Scope set to entire '
      'curriculum") is fully Hebrew',
      (tester) async {
        await _pump(
          tester,
          _buildScopeAppPushed(scopeRepository: _scopeRepository),
        );
        await tester.tap(find.text('פתח'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final saveLabel = AppLocalizations.of(
          tester.element(find.byType(ScopeSelectionScreen)),
        )!.scopeSelectionSave;
        await tester.tap(find.text(saveLabel));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Sanity: the SnackBar actually appeared.
        expect(find.byType(SnackBar), findsOneWidget);

        _expectNoLatinFragments(
          tester,
          where: 'save-confirmation SnackBar (selectAll=true)',
        );

        await _tearDown(tester);
      },
    );

    testWidgets(
      'save-confirmation SnackBar for a saved subset ("Scope updated: …") '
      'is fully Hebrew',
      (tester) async {
        await _pump(
          tester,
          _buildScopeAppPushed(scopeRepository: _scopeRepository),
        );
        await tester.tap(find.text('פתח'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(find.byType(SwitchListTile));
        await tester.pump();
        final levelTile = find.descendant(
          of: find.byType(ListTile),
          matching: find.byIcon(Icons.chevron_right),
        );
        await tester.tap(levelTile.first);
        await tester.pump();
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();

        final saveLabel = AppLocalizations.of(
          tester.element(find.byType(ScopeSelectionScreen)),
        )!.scopeSelectionSave;
        await tester.tap(find.text(saveLabel));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Sanity: the SnackBar actually appeared.
        expect(find.byType(SnackBar), findsOneWidget);

        _expectNoLatinFragments(
          tester,
          where: 'save-confirmation SnackBar (subset)',
        );

        await _tearDown(tester);
      },
    );
  });

  group('CurriculumSettingsScreen — he locale: no Latin fragments', () {
    testWidgets(
      'default render ("Custom schedule" state, all tiles) is fully Hebrew',
      (tester) async {
        await _pump(
          tester,
          _buildCurriculumSettingsApp(
            profileProgramRepository: _profileProgramRepository,
          ),
        );

        // Sanity: the screen actually rendered its tiles.
        expect(find.byType(ListTile), findsWidgets);

        _expectNoLatinFragments(tester, where: 'default render');

        await _tearDown(tester);
      },
    );

    testWidgets('"no email app" SnackBar with Copy action is fully Hebrew', (
      tester,
    ) async {
      _setUpUrlLauncherMock(canLaunch: false);
      addTearDown(_clearUrlLauncherMock);

      await _pump(
        tester,
        _buildCurriculumSettingsApp(
          profileProgramRepository: _profileProgramRepository,
        ),
      );

      await tester.tap(find.byIcon(Icons.mail_outline));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Sanity: the SnackBar (with its Copy action) actually appeared.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(SnackBarAction), findsOneWidget);

      _expectNoLatinFragments(
        tester,
        where: '"no email app" SnackBar with Copy action',
      );

      await _tearDown(tester);
    });
  });
}
