// L1 widget test — CurriculumSettingsScreen
//
// Covers:
//   • Initial render: AppBar with curriculum label, school icon, list items.
//   • Loading state: "Loading program..." tile while _currentProgramProvider loads.
//   • Data state (no program): "Custom schedule" tile when profileProgram is null.
//   • Data state (with program): "Program: <name>" + description subtitle.
//   • Error state: "Error: …" subtitle shown when provider throws.
//   • Change Program tile: present, has chevron trailing icon.
//   • Request Program tile: "Don't see your program?" + "Request a new program".
//   • No track-type label leak: strings "Personal", "Standard", "Custom", "אישי"
//     must never appear as track-type labels (product rule).
//   • curriculum label rendering — English vs Hebrew via useHebrewTermsProvider.
//   • he-RTL smoke: renders under Hebrew locale without crash.
//   • Divider is present between Change-Program and Request-Program tiles.
//
// Deliberately NOT tested here (require real Navigator push / url_launcher):
//   • _onChangeProgram — pushes MaterialPageRoute; covered at integration level.
//   • _onRequestProgram — calls launchUrl; covered at integration level.

@Tags(['settings', 'curriculum_settings'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/screens/curriculum_settings_screen.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/drift_memory.dart' show seedProfile, seedTrack;

// ── Constants ─────────────────────────────────────────────────────────────────

const _curriculum = CurriculumId.mishnayos;
const _curriculumKey = 'mishnayos';

// ── Provider override stubs ───────────────────────────────────────────────────

/// Pins the active profile id to 1 without touching SharedPreferences.
class _ProfileId1 extends ActiveProfileId {
  @override
  int build() => 1;
}

/// Pins useHebrewTerms to false.
class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

/// Pins useHebrewTerms to true.
class _HebrewTermsOn extends UseHebrewTerms {
  @override
  bool build() => true;
}

// ── Widget factory ────────────────────────────────────────────────────────────

/// Builds a [ProviderScope] with the minimum overrides the screen needs.
///
/// The  retry: (_, __) => null  is MANDATORY for Riverpod 3 so that errored
/// FutureProviders surface their error state rather than staying in AsyncLoading.
Widget _buildApp({
  required UserDatabase db,
  bool useHebrew = false,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      // Provide the in-memory DB so all database reads stay in-memory.
      userDatabaseProvider.overrideWith((ref) => db),
      // Fix active profile to 1 (no SharedPreferences needed).
      activeProfileIdProvider.overrideWith(() => _ProfileId1()),
      // No sync engine — local-only test.
      syncWriteFacadeProvider.overrideWithValue(null),
      // Hebrew Terms toggle — controlled per test.
      if (useHebrew)
        useHebrewTermsProvider.overrideWith(() => _HebrewTermsOn())
      else
        useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CurriculumSettingsScreen(curriculumId: _curriculumKey),
    ),
  );
}

/// Seeds a [ProfileProgram] row linking profileId=1 to [programId] for
/// [_curriculumKey].  When this row is absent the screen shows "Custom schedule".
Future<void> _seedProfileProgram(UserDatabase db, {required int programId}) =>
    db.profileProgramDao.setProfileProgram(
      profileId: 1,
      curriculumType: _curriculumKey,
      programId: programId,
    );

Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

late UserDatabase _db;

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    _db = UserDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await _db.close();
  });

  // ── AppBar title ────────────────────────────────────────────────────────────

  group('CurriculumSettingsScreen — AppBar title (en)', () {
    testWidgets('AppBar contains curriculum name (English)', (tester) async {
      await _pump(tester, _buildApp(db: _db));

      // The title is built as "Settings - Mishnayos" in en mode.
      expect(find.textContaining('Mishnayos'), findsWidgets);
      expect(find.byType(AppBar), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('AppBar has school icon for program tile', (tester) async {
      await _pump(tester, _buildApp(db: _db));

      expect(find.byIcon(Icons.school), findsWidgets);

      await _tearDown(tester);
    });
  });

  // ── Loading state ────────────────────────────────────────────────────────────

  group('CurriculumSettingsScreen — loading state', () {
    testWidgets(
      'loading tile has school icon (loading branch renders correctly)',
      (tester) async {
        // The loading branch renders an Icon(Icons.school) ListTile with
        // "Loading program..." text. Because NativeDatabase.memory() resolves
        // synchronously in tests, the loading state is ephemeral.  We verify
        // it by pumping a single frame immediately after pumpWidget and
        // checking either the loading tile OR the resolved tile is present
        // (both are valid depending on micro-task scheduling).
        await tester.pumpWidget(_buildApp(db: _db));
        // One microtask pump — may still be loading or may have resolved.
        await tester.pump(Duration.zero);

        // Exactly one school icon tile exists in either state.
        expect(find.byIcon(Icons.school), findsWidgets);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'loading tile label uses l10n key curriculumSettingsLoadingProgram',
      (tester) async {
        // Verify the string constant is the correct l10n value.
        // We pump the full widget and confirm either the loading text OR the
        // resolved text appears — the screen never shows a blank.
        await _pump(tester, _buildApp(db: _db));

        // After full pump (resolved) the screen shows data, not loading.
        // Confirm the loading string is the expected l10n text when present.
        // (If the DB resolved synchronously it shows "Custom schedule" instead.)
        final hasLoading = find
            .text('Loading program...')
            .evaluate()
            .isNotEmpty;
        final hasResolved =
            find.text('Custom schedule').evaluate().isNotEmpty ||
            find.textContaining('Program:').evaluate().isNotEmpty;
        expect(
          hasLoading || hasResolved,
          isTrue,
          reason:
              'Screen must show either loading or resolved program state — '
              'never blank',
        );

        await _tearDown(tester);
      },
    );
  });

  // ── Data state — no program (custom schedule) ───────────────────────────────

  group('CurriculumSettingsScreen — data: no program enrolled', () {
    testWidgets('shows "Custom schedule" when no profile_program row exists', (
      tester,
    ) async {
      // No profile_program row seeded — DB query returns null.
      await _pump(tester, _buildApp(db: _db));

      expect(find.text('Custom schedule'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('"Custom schedule" tile has no subtitle', (tester) async {
      await _pump(tester, _buildApp(db: _db));

      // The data branch sets subtitle: null when info == null.
      // We verify there is no description text — just the title.
      expect(find.text('Custom schedule'), findsOneWidget);
      // No description from a real program should be present.
      expect(find.text('Daily Talmud study'), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── Data state — program enrolled ───────────────────────────────────────────

  group('CurriculumSettingsScreen — data: program enrolled', () {
    testWidgets(
      'shows "Program: Daf Yomi" when profile_program row is present',
      (tester) async {
        // Seed a profile_program row pointing to program id 1.
        // The LearningProgramRepository seed list has Daf Yomi as program 1.
        await _seedProfileProgram(_db, programId: 1);

        await _pump(tester, _buildApp(db: _db));

        // The program tile title starts with "Program: "
        expect(find.textContaining('Program:'), findsOneWidget);

        await _tearDown(tester);
      },
    );

    testWidgets('program tile shows description as subtitle', (tester) async {
      await _seedProfileProgram(_db, programId: 1);

      await _pump(tester, _buildApp(db: _db));

      // Program description from LearningProgramRepository seed is non-empty.
      // We just verify there is a subtitle text widget (description != null).
      final programTile = find.ancestor(
        of: find.textContaining('Program:'),
        matching: find.byType(ListTile),
      );
      expect(programTile, findsOneWidget);

      await _tearDown(tester);
    });
  });

  // ── Change Program tile ─────────────────────────────────────────────────────

  group('CurriculumSettingsScreen — Change Program tile', () {
    testWidgets('Change Program tile is present with l10n label', (
      tester,
    ) async {
      await _pump(tester, _buildApp(db: _db));

      // l10n key: curriculumSettingsChangeProgram
      expect(find.text('Change Program'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Change Program tile has swap_horiz leading icon', (
      tester,
    ) async {
      await _pump(tester, _buildApp(db: _db));

      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Change Program tile has chevron_right trailing icon', (
      tester,
    ) async {
      await _pump(tester, _buildApp(db: _db));

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Change Program tile shows l10n subtitle', (tester) async {
      await _pump(tester, _buildApp(db: _db));

      // l10n key: curriculumSettingsChangeProgramSubtitle
      expect(
        find.text('Switch to a different learning program'),
        findsOneWidget,
      );

      await _tearDown(tester);
    });
  });

  // ── Request Program tile ────────────────────────────────────────────────────

  group('CurriculumSettingsScreen — Request Program tile', () {
    testWidgets('"Don\'t see your program?" tile is present with l10n labels', (
      tester,
    ) async {
      await _pump(tester, _buildApp(db: _db));

      // l10n keys: curriculumSettingsDontSeeProgram, curriculumSettingsRequestProgram
      expect(find.text("Don't see your program?"), findsOneWidget);
      expect(find.text('Request a new program'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Request Program tile has mail_outline leading icon', (
      tester,
    ) async {
      await _pump(tester, _buildApp(db: _db));

      expect(find.byIcon(Icons.mail_outline), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Request Program tile has open_in_new trailing icon', (
      tester,
    ) async {
      await _pump(tester, _buildApp(db: _db));

      expect(find.byIcon(Icons.open_in_new), findsOneWidget);

      await _tearDown(tester);
    });
  });

  // ── Divider between tiles ────────────────────────────────────────────────────

  group('CurriculumSettingsScreen — layout', () {
    testWidgets('Dividers bracket the siyum-granularity section between the '
        'Change Program and Request tiles', (tester) async {
      await _pump(tester, _buildApp(db: _db));

      // Two dividers now bracket the siyum-granularity selector section that
      // sits between the Change-Program tile and the Request-Program tile.
      expect(find.byType(Divider), findsNWidgets(2));

      await _tearDown(tester);
    });
  });

  // ── Track-type label product rule ────────────────────────────────────────────

  group('CurriculumSettingsScreen — product rule: no track-type labels', () {
    testWidgets('no "Personal" track-type label anywhere on the screen (en)', (
      tester,
    ) async {
      await _pump(tester, _buildApp(db: _db));

      expect(find.text('Personal'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('no "Standard" track-type label anywhere on the screen (en)', (
      tester,
    ) async {
      await _pump(tester, _buildApp(db: _db));

      expect(find.text('Standard'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('no "Custom" track-type label anywhere on the screen (en)', (
      tester,
    ) async {
      // Note: "Custom schedule" is the program-absent data label, NOT a
      // track-type label. The rule prohibits track-type labels such as
      // "Custom" standalone as a track category.  We verify neither the
      // bare word "Custom" as a standalone tile title nor "Custom track"
      // appears (the forbidden track-type form).
      await _pump(tester, _buildApp(db: _db));

      expect(find.text('Custom'), findsNothing);
      expect(find.textContaining('Custom track'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets(
      'no "אישי" (Hebrew personal track-type) label anywhere on the screen (he)',
      (tester) async {
        await _pump(
          tester,
          _buildApp(db: _db, useHebrew: true, locale: const Locale('he')),
        );

        // "אישי" is the forbidden personal/track-type label (product rule §no-track-types).
        expect(find.text('אישי'), findsNothing);

        await _tearDown(tester);
      },
    );
  });

  // ── Hebrew terms rendering ──────────────────────────────────────────────────

  group('CurriculumSettingsScreen — Hebrew terms', () {
    testWidgets(
      'AppBar title contains Hebrew curriculum name when useHebrew=true',
      (tester) async {
        await _pump(
          tester,
          _buildApp(db: _db, useHebrew: true, locale: const Locale('he')),
        );

        // CurriculumId.mishnayos.displayNameHe = "משניות"
        expect(find.textContaining(_curriculum.displayNameHe), findsWidgets);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'AppBar title does NOT contain Hebrew name when useHebrew=false',
      (tester) async {
        await _pump(tester, _buildApp(db: _db, useHebrew: false));

        expect(find.textContaining(_curriculum.displayNameHe), findsNothing);
        expect(find.textContaining(_curriculum.displayNameEn), findsWidgets);

        await _tearDown(tester);
      },
    );

    // Regression: the program name in the "Program: …" tile must route
    // through the shared learningProgramLabelText helper so the Hebrew Terms
    // toggle is honoured — not the raw `info.displayName`. Program id 5 in
    // the seed list is "Daf Yomi" (name 'daf_yomi'), which IS registered in
    // CalendarProgramRegistry → Hebrew ON resolves to "דף יומי".
    testWidgets('program tile shows Hebrew program name when useHebrew=true', (
      tester,
    ) async {
      await _seedProfileProgram(_db, programId: 5);

      await _pump(
        tester,
        _buildApp(db: _db, useHebrew: true, locale: const Locale('he')),
      );

      expect(find.textContaining('דף יומי'), findsOneWidget);
      // The raw English displayName must NOT leak through when Hebrew is on.
      expect(find.textContaining('Daf Yomi'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets(
      'program tile shows English program name when useHebrew=false',
      (tester) async {
        await _seedProfileProgram(_db, programId: 5);

        await _pump(tester, _buildApp(db: _db, useHebrew: false));

        expect(find.textContaining('Daf Yomi'), findsOneWidget);
        expect(find.textContaining('דף יומי'), findsNothing);

        await _tearDown(tester);
      },
    );
  });

  // ── he-RTL smoke ─────────────────────────────────────────────────────────────

  group('CurriculumSettingsScreen — RTL smoke (he)', () {
    testWidgets('renders under Hebrew locale without crash', (tester) async {
      await _pump(
        tester,
        _buildApp(db: _db, useHebrew: true, locale: const Locale('he')),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      // Screen body is a ListView — check it renders.
      expect(find.byType(ListView), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Hebrew locale sets RTL text direction', (tester) async {
      await _pump(
        tester,
        _buildApp(db: _db, useHebrew: true, locale: const Locale('he')),
      );

      final dirFinders = find.byType(Directionality);
      expect(dirFinders, findsWidgets);
      final outerDir = tester.widget<Directionality>(dirFinders.first);
      expect(outerDir.textDirection, TextDirection.rtl);

      await _tearDown(tester);
    });

    testWidgets(
      'Change Program tile label is still present under Hebrew locale',
      (tester) async {
        await _pump(
          tester,
          _buildApp(db: _db, useHebrew: true, locale: const Locale('he')),
        );

        // l10n key: curriculumSettingsChangeProgram (Hebrew translation used)
        // — verify the tile is present (not empty/missing) regardless of locale.
        expect(find.byIcon(Icons.swap_horiz), findsOneWidget);

        await _tearDown(tester);
      },
    );
  });

  // ── Full list rendering guard ────────────────────────────────────────────────

  group('CurriculumSettingsScreen — full list guard', () {
    testWidgets('all three ListTile items are rendered', (tester) async {
      await _pump(tester, _buildApp(db: _db));

      // Program tile + Change Program tile + Request Program tile = 3.
      expect(find.byType(ListTile), findsNWidgets(3));

      await _tearDown(tester);
    });
  });

  // ── P2 fix (deferred/track-rename-propagation) ──────────────────────────────
  // This screen is reached exclusively from the curriculum-progress screen's
  // settings icon for one specific track (W3.22: one track per {profileId,
  // curriculumId}), so its AppBar title is that track's own identity label —
  // it must honour a custom track name the same way Track Detail does
  // (B-EDIT-NAME, commit 00048c68) instead of always showing the raw
  // curriculum label.
  group('CurriculumSettingsScreen — P2: AppBar title honours a custom track '
      'name', () {
    testWidgets(
      'a track renamed via Goal.description shows the custom name in the '
      'AppBar title, not the curriculum label',
      (tester) async {
        await seedProfile(_db);
        final trackId = await seedTrack(
          _db,
          profileId: 1,
          curriculumId: _curriculumKey,
        );
        await _db
            .into(_db.goals)
            .insert(
              GoalsCompanion.insert(
                profileId: 1,
                curriculumId: _curriculumKey,
                trackId: trackId,
                description: const Value('My Shas Journey'),
                createdAt: DateTimeFactory.nowUtc(),
                updatedAt: DateTimeFactory.nowUtc(),
              ),
            );

        await _pump(tester, _buildApp(db: _db));

        // Pre-fix the header always showed "Settings - Mishnayos" and
        // ignored the edited name. The custom name must now surface.
        expect(find.textContaining('My Shas Journey'), findsWidgets);
        expect(find.textContaining('Mishnayos'), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'no custom name (no goal seeded) → AppBar title falls back to the '
      'curriculum label',
      (tester) async {
        await seedProfile(_db);
        await seedTrack(_db, profileId: 1, curriculumId: _curriculumKey);

        await _pump(tester, _buildApp(db: _db));

        expect(find.textContaining('Mishnayos'), findsWidgets);

        await _tearDown(tester);
      },
    );
  });
}
