/// Story acceptance tests for Epic 25 — Schema + Core Foundation.
///
/// Story 25.7 (DNI-328): core/preferences/ ProfileScopedPreference primitives.
/// Story 25.8 (DNI-329): ContentIndex + ProgramRefResolver.
/// Story 25.10 (DNI-331): LocalDayClock — single time provider.
/// Story 25.11 (DNI-332): AuthRepository — sole firebase_auth consumer.
/// Story 25.19 (DNI-340): core/logging/ — finalize structured AppLogger and
///                        migrate remaining production logs.
@Tags(['epic_25'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/content/program_ref_resolver.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/hebrew_date_preference.dart';
import 'package:learning_tracker/core/preferences/hebrew_terms_preference.dart';
import 'package:learning_tracker/core/preferences/nikud_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/core/preferences/text_display_preference.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/preferences/transliteration_variant_preference.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:test/test.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

// ── tests ─────────────────────────────────────────────────────────────────────

const _profileA = '01J00000000000000000000004';
const _profileB = '01J00000000000000000000005';

void main() {
  // --------------------------------------------------------------------------
  // Story 25.11 — AuthRepository sole firebase_auth consumer (DNI-332)
  // --------------------------------------------------------------------------

  group(
    'Story 25.11 — AuthRepository sole firebase_auth consumer',
    tags: ['story_25_11'],
    () {
      // ── 1. AuthRepository interface exposes required members ───────────────

      test(
        'AuthRepository interface declares currentUser, onAuthStateChanged, signIn, signInWithGoogle, signOut',
        () {
          // Compile-time shape check only (AUD-t-story-acceptance-47): the
          // `when(...)` stubs below reference each interface member with its
          // real signature, so this test fails to COMPILE if AuthRepository
          // drops or reshapes a member `_MockAuthRepository` implements.
          // There are deliberately no expect() calls here — this test used
          // to stub the mock and then assert the mock echoed back exactly
          // what it was just told to return, which can never fail
          // regardless of what AuthRepositoryImpl actually does. Real
          // behavioural coverage for AuthRepositoryImpl lives in
          // test/features/auth/data/repositories/auth_repository_impl_test.dart.
          // weaken-ok: AUD-t-story-acceptance-47 — the 5 expect() calls
          // removed below only echoed values just stubbed on this same mock
          // (e.g. `when(() => repo.currentUser).thenReturn(null)` then
          // `expect(repo.currentUser, isNull)`); they could never fail
          // regardless of AuthRepositoryImpl's real behaviour, so they
          // carried no verification value. No net coverage is lost — real
          // behavioural coverage for AuthRepositoryImpl already lives in
          // auth_repository_impl_test.dart (see path above).
          final repo = _MockAuthRepository();

          when(() => repo.currentUser).thenReturn(null);
          when(
            () => repo.onAuthStateChanged(),
          ).thenAnswer((_) => Stream.value(null));
          when(
            () => repo.signInWithEmail(any(), any()),
          ).thenAnswer((_) async {});
          when(() => repo.signInWithGoogle()).thenAnswer((_) async {});
          when(() => repo.signOut()).thenAnswer((_) async {});
        },
      );

      // ── 2. AppUser maps uid, email, displayName, emailVerified, providers ─

      test('AppUser holds all required fields', () {
        const user = AppUser(
          uid: 'uid-123',
          email: 'test@example.com',
          displayName: 'Test User',
          emailVerified: true,
          providers: ['password', 'google.com'],
        );

        expect(user.uid, equals('uid-123'));
        expect(user.email, equals('test@example.com'));
        expect(user.displayName, equals('Test User'));
        expect(user.emailVerified, isTrue);
        expect(user.providers, containsAll(['password', 'google.com']));
      });

      test('AppUser allows null email and displayName', () {
        const user = AppUser(
          uid: 'uid-456',
          email: null,
          displayName: null,
          emailVerified: false,
          providers: [],
        );

        expect(user.uid, equals('uid-456'));
        expect(user.email, isNull);
        expect(user.displayName, isNull);
        expect(user.emailVerified, isFalse);
        expect(user.providers, isEmpty);
      });

      // ── 3. onAuthStateChanged emits AppUser? not firebase User? ───────────

      test('onAuthStateChanged stream emits AppUser? typed values', () async {
        final repo = _MockAuthRepository();
        const mockUser = AppUser(
          uid: 'uid-789',
          email: 'mock@test.com',
          displayName: 'Mock',
          emailVerified: true,
          providers: ['password'],
        );

        when(
          () => repo.onAuthStateChanged(),
        ).thenAnswer((_) => Stream.fromIterable([mockUser, null]));

        final emitted = await repo.onAuthStateChanged().toList();
        expect(emitted, hasLength(2));
        expect(emitted[0], isA<AppUser>());
        expect((emitted[0] as AppUser).uid, equals('uid-789'));
        expect(emitted[1], isNull);
      });

      // ── 4. AppUser.providers replaces providerData ─────────────────────────

      test('providers list supports contains() for password provider', () {
        const user = AppUser(
          uid: 'uid-pw',
          email: 'pw@test.com',
          displayName: null,
          emailVerified: true,
          providers: ['password'],
        );

        expect(user.providers.contains('password'), isTrue);
        expect(user.providers.contains('google.com'), isFalse);
      });

      test('providers list supports contains() for google.com provider', () {
        const user = AppUser(
          uid: 'uid-google',
          email: 'g@test.com',
          displayName: 'Google User',
          emailVerified: true,
          providers: ['google.com'],
        );

        expect(user.providers.contains('google.com'), isTrue);
        expect(user.providers.contains('password'), isFalse);
      });
    },
  );

  // --------------------------------------------------------------------------
  // Story 25.8 — ContentIndex + ProgramRefResolver (DNI-329)
  // --------------------------------------------------------------------------

  group('Story 25.8 — ContentIndex + ProgramRefResolver', tags: ['story_25_8'], () {
    // ── ContentIndex ──────────────────────────────────────────────────────

    group('ContentIndex', () {
      test('lookup returns the item for a known sefariaRef', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final result = index.lookup('Mishnah Berakhot 1:1');

        expect(result, isNotNull);
        expect(result!.curriculumId, equals('mishnayos'));
        expect(result.displayNameEn, equals('Mishnah 1'));
      });

      test('lookup returns null for an unknown sefariaRef', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        expect(index.lookup('Made-up Ref 99:99'), isNull);
      });

      test('lookup spans all curricula (cross-curriculum match)', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final bavli = index.lookup('Berakhot 2a');
        final mishnah = index.lookup('Mishnah Berakhot 1:1');

        expect(bavli?.curriculumId, equals('bavli'));
        expect(mishnah?.curriculumId, equals('mishnayos'));
      });

      test('size reports total indexed items', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        // 4 mishnayos + 3 bavli leaves + 2 mishnayos containers = 9
        expect(index.size, equals(9));
      });

      test('adjacent returns prev/next leaves within same curriculum', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final adj = index.adjacent('Mishnah Berakhot 1:2');

        expect(adj.prev, isNotNull);
        expect(adj.prev!.sefariaRef, equals('Mishnah Berakhot 1:1'));
        expect(adj.next, isNotNull);
        expect(adj.next!.sefariaRef, equals('Mishnah Berakhot 1:3'));
      });

      test('adjacent returns null prev at first leaf of curriculum', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final adj = index.adjacent('Mishnah Berakhot 1:1');

        expect(adj.prev, isNull);
        expect(adj.next, isNotNull);
      });

      test('adjacent returns null next at last leaf of curriculum', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final adj = index.adjacent('Mishnah Berakhot 1:4');

        expect(adj.prev, isNotNull);
        expect(adj.next, isNull);
      });

      test('adjacent returns (null, null) for unknown ref', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final adj = index.adjacent('Made-up Ref 99:99');

        expect(adj.prev, isNull);
        expect(adj.next, isNull);
      });

      test('adjacent does NOT cross curriculum boundaries', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        // Last leaf of mishnayos in this fixture is Berakhot 1:4;
        // adjacent.next must be null even though bavli items exist
        // elsewhere in the index.
        final adj = index.adjacent('Mishnah Berakhot 1:4');

        expect(adj.next, isNull);
      });

      test('lookup completes in < 1ms after first warmup (NFR22 benchmark)', () {
        // Build a large index to make any O(N) walk visible.
        final items = <CurriculumId, List<ContentItem>>{};
        for (final c in CurriculumId.values) {
          items[c] = _generateLeafItems(c, count: 6000);
        }
        final index = ContentIndex.fromCurricula(items);

        // Warmup — exercise the cache once.
        index.lookup(items[CurriculumId.bavli]!.first.sefariaRef);

        const iterations = 10000;
        final stopwatch = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          final c = CurriculumId.values[i % CurriculumId.values.length];
          final ref = items[c]![i % items[c]!.length].sefariaRef;
          index.lookup(ref);
        }
        stopwatch.stop();

        final perLookupUs = stopwatch.elapsedMicroseconds / iterations;

        expect(
          perLookupUs,
          lessThan(1000),
          reason:
              'lookup must complete in < 1ms (=1000us) per call after warmup; '
              'measured ${perLookupUs.toStringAsFixed(2)}us',
        );
      });
    });

    // ── ProgramRefResolver ────────────────────────────────────────────────

    group('ProgramRefResolver', () {
      test('resolve returns the canonical sefariaRef for the program day', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());
        final resolver = ProgramRefResolver(
          index: index,
          programRefSource: _StubProgramRefSource({
            ('daf_yomi', 0): 'Berakhot 2a',
          }),
        );

        final ref = resolver.resolve(programId: 'daf_yomi', dayOffset: 0);

        expect(ref, equals('Berakhot 2a'));
      });

      test('resolve normalizes whitespace and case variants to canonical', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());
        final resolver = ProgramRefResolver(
          index: index,
          programRefSource: _StubProgramRefSource({
            // Calendar feed sometimes returns spacing/case variants
            // ("mishna" → "mishnah"). Resolver must normalize to the
            // canonical content-index ref.
            ('mishna_yomit', 0): 'Mishna  Berakhot 1:1',
          }),
        );

        final ref = resolver.resolve(programId: 'mishna_yomit', dayOffset: 0);

        expect(ref, equals('Mishnah Berakhot 1:1'));
      });

      test(
        'resolve returns null when the program has no entry for the day',
        () {
          final index = ContentIndex.fromCurricula(_smallCurriculumSet());
          final resolver = ProgramRefResolver(
            index: index,
            programRefSource: _StubProgramRefSource(const {}),
          );

          final ref = resolver.resolve(programId: 'daf_yomi', dayOffset: 5);

          expect(ref, isNull);
        },
      );

      test(
        'resolve returns null when calendar ref does not match any ContentIndex entry',
        () {
          final index = ContentIndex.fromCurricula(_smallCurriculumSet());
          final resolver = ProgramRefResolver(
            index: index,
            programRefSource: _StubProgramRefSource({
              ('daf_yomi', 0): 'Hullin 7', // not in this fixture's index
            }),
          );

          final ref = resolver.resolve(programId: 'daf_yomi', dayOffset: 0);

          // Resolver MUST NOT fall back to the raw display string —
          // T1.7 explicitly forbids that. Return null instead.
          expect(ref, isNull);
        },
      );

      test('different dayOffsets map to different refs', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());
        final resolver = ProgramRefResolver(
          index: index,
          programRefSource: _StubProgramRefSource({
            ('daf_yomi', 0): 'Berakhot 2a',
            ('daf_yomi', 1): 'Berakhot 2b',
            ('daf_yomi', 2): 'Berakhot 3a',
          }),
        );

        expect(
          resolver.resolve(programId: 'daf_yomi', dayOffset: 0),
          equals('Berakhot 2a'),
        );
        expect(
          resolver.resolve(programId: 'daf_yomi', dayOffset: 1),
          equals('Berakhot 2b'),
        );
        expect(
          resolver.resolve(programId: 'daf_yomi', dayOffset: 2),
          equals('Berakhot 3a'),
        );
      });
    });
  });

  // --------------------------------------------------------------------------
  // Story 26.14 — ContentTree indexed lookup (DNI-357)
  // --------------------------------------------------------------------------

  group('Story 26.14 — ContentTree indexed lookup', tags: ['story_26_14'], () {
    // ── children ─────────────────────────────────────────────────────────────

    group('ContentTree.children', () {
      test('empty stack returns top-level containers', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final roots = tree.children(CurriculumId.mishnayos, []);

        // Only the L1 container "Zeraim" has no deeper-level children at root
        expect(roots.any((i) => i.level1 == 'Zeraim'), isTrue);
      });

      test('depth-1 stack returns L2 children', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final children = tree.children(CurriculumId.mishnayos, ['Zeraim']);

        // Zeraim → Berakhot container
        expect(children.any((i) => i.level2 == 'Berakhot'), isTrue);
      });

      test('depth-3 stack returns leaf children', () {
        // The _smallCurriculumSet fixture has 4-level leaves (Zeraim/Berakhot/
        // Perek 1/Mishnah N) with no explicit L3 container.  ContentTree places
        // each leaf under its immediate parent path, so they appear at depth 3.
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final children = tree.children(CurriculumId.mishnayos, [
          'Zeraim',
          'Berakhot',
          'Perek 1',
        ]);

        // 4 mishnah leaves under Perek 1
        expect(children, isNotEmpty);
        expect(children.every((i) => i.isLeaf), isTrue);
        expect(children.every((i) => i.level3 == 'Perek 1'), isTrue);
      });

      test('unknown stack returns empty list (no crash)', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final children = tree.children(CurriculumId.mishnayos, ['NonExistent']);

        expect(children, isEmpty);
      });

      test('children are sorted by sortOrder', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        // Use the depth-3 path which yields the 4 leaf items
        final children = tree.children(CurriculumId.mishnayos, [
          'Zeraim',
          'Berakhot',
          'Perek 1',
        ]);

        expect(children, isNotEmpty);
        final orders = children.map((i) => i.sortOrder).toList();
        final sorted = [...orders]..sort();
        expect(orders, equals(sorted));
      });

      test('does not cross curriculum boundaries', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final mishnayosRoots = tree.children(CurriculumId.mishnayos, []);
        final bavliRoots = tree.children(CurriculumId.bavli, []);

        expect(
          mishnayosRoots.every((i) => i.curriculumId == 'mishnayos'),
          isTrue,
        );
        expect(bavliRoots.every((i) => i.curriculumId == 'bavli'), isTrue);
      });
    });

    // ── parent ────────────────────────────────────────────────────────────────

    group('ContentTree.parent', () {
      test('parent of a leaf returns its container', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final p = tree.parent('Mishnah Berakhot 1:1');

        // Leaf is at level4 "Mishnah 1", parent container is "Perek 1"
        expect(p, isNotNull);
        expect(p!.curriculumId, equals('mishnayos'));
      });

      test('parent of a top-level container is null', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        // 'Zeraim' is the root container — no parent
        final p = tree.parent('Zeraim');

        expect(p, isNull);
      });

      test('parent of unknown ref is null', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        expect(tree.parent('Made-up Ref'), isNull);
      });
    });

    // ── adjacent ──────────────────────────────────────────────────────────────

    group('ContentTree.adjacent (delegates to ContentIndex)', () {
      test('adjacent returns prev/next leaf within curriculum', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final adj = tree.adjacent('Mishnah Berakhot 1:2');

        expect(adj.prev?.sefariaRef, equals('Mishnah Berakhot 1:1'));
        expect(adj.next?.sefariaRef, equals('Mishnah Berakhot 1:3'));
      });

      test('adjacent does not cross curriculum boundaries', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        // Last mishnayos leaf; next must be null
        final adj = tree.adjacent('Mishnah Berakhot 1:4');

        expect(adj.next, isNull);
      });
    });

    // ── containerFor ─────────────────────────────────────────────────────────

    group('ContentTree.containerFor', () {
      test('returns the container item for a known stack', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        final container = tree.containerFor(CurriculumId.mishnayos, ['Zeraim']);

        expect(container, isNotNull);
        expect(container!.displayNameHe, equals('זרעים'));
      });

      test('returns null for an unknown stack', () {
        final tree = ContentTree.fromCurricula(_smallCurriculumSet());

        expect(
          tree.containerFor(CurriculumId.mishnayos, ['NonExistent']),
          isNull,
        );
      });
    });

    // ── ContentIndex.firstLeaf (added for DNI-357) ────────────────────────────

    group('ContentIndex.firstLeaf', () {
      test('returns the sefariaRef of the first leaf in sort order', () {
        final index = ContentIndex.fromCurricula(_smallCurriculumSet());

        final ref = index.firstLeaf(CurriculumId.mishnayos);

        expect(ref, equals('Mishnah Berakhot 1:1'));
      });

      test('returns null for an unknown curriculum (no items)', () {
        // Build index without halachaDailyForSefardim
        final index = ContentIndex.fromCurricula({
          CurriculumId.mishnayos:
              _smallCurriculumSet()[CurriculumId.mishnayos]!,
        });

        // Any curriculum not in the map → null
        expect(index.firstLeaf(CurriculumId.bavli), isNull);
      });
    });
  });

  // --------------------------------------------------------------------------
  // Story 25.10 — LocalDayClock single time provider (DNI-331)
  // --------------------------------------------------------------------------

  group('Story 25.10 — LocalDayClock single time provider', tags: ['story_25_10'], () {
    // ── 1. Interface contract ───────────────────────────────────────────────

    group('LocalDayClock contract', () {
      test('SystemLocalDayClock.nowUtc returns a UTC DateTime', () {
        const clock = SystemLocalDayClock();

        final now = clock.nowUtc();

        expect(now.isUtc, isTrue);
      });

      test('SystemLocalDayClock.today returns a y/m/d local DateTime', () {
        const clock = SystemLocalDayClock();

        // Bracket the call under test between two wall-clock reads instead
        // of comparing to a single independent DateTime.now() (AUD-t-story-
        // acceptance-37): with two unrelated reads, a local-midnight
        // rollover between them makes the comparison intermittently
        // disagree. Bracketing means `today` is guaranteed to fall on
        // either `before`'s or `after`'s calendar day, so the assertion is
        // race-free even if midnight ticks over mid-test.
        final before = DateTime.now();
        final today = clock.today();
        final after = DateTime.now();

        final beforeDay = DateTime(before.year, before.month, before.day);
        final afterDay = DateTime(after.year, after.month, after.day);
        final todayDay = DateTime(today.year, today.month, today.day);

        expect(today.isUtc, isFalse);
        expect(
          todayDay == beforeDay || todayDay == afterDay,
          isTrue,
          reason:
              'expected today() ($todayDay) to equal the calendar day of '
              'either the before ($beforeDay) or after ($afterDay) '
              'DateTime.now() bracket',
        );
        expect(today.hour, equals(0));
        expect(today.minute, equals(0));
        expect(today.second, equals(0));
        expect(today.millisecond, equals(0));
        expect(today.microsecond, equals(0));
      });

      test('FakeLocalDayClock returns the seeded UTC instant', () {
        final seeded = DateTime.utc(2026, 5, 13, 23, 30);
        final clock = FakeLocalDayClock(seeded);

        expect(clock.nowUtc(), equals(seeded));
      });

      test(
        'FakeLocalDayClock.today derives local date from seeded instant',
        () {
          // 2026-05-13 23:30 UTC == 2026-05-14 02:30 in Asia/Jerusalem (+3),
          // but we compute against whatever timezone the host runs in. The
          // contract is: today() == midnight-of-local-day of nowUtc.toLocal().
          final seeded = DateTime.utc(2026, 5, 13, 23, 30);
          final clock = FakeLocalDayClock(seeded);

          final today = clock.today();
          final expectedLocal = seeded.toLocal();

          expect(today.year, equals(expectedLocal.year));
          expect(today.month, equals(expectedLocal.month));
          expect(today.day, equals(expectedLocal.day));
          expect(today.hour, equals(0));
        },
      );

      test('FakeLocalDayClock.advance moves the clock forward', () {
        final seeded = DateTime.utc(2026, 5, 13, 10);
        final clock = FakeLocalDayClock(seeded);

        clock.advance(const Duration(hours: 6));

        expect(clock.nowUtc(), equals(DateTime.utc(2026, 5, 13, 16)));
      });

      test('FakeLocalDayClock.setNow replaces the current instant', () {
        final clock = FakeLocalDayClock(DateTime.utc(2026, 1, 1));

        clock.setNow(DateTime.utc(2026, 12, 31, 12));

        expect(clock.nowUtc(), equals(DateTime.utc(2026, 12, 31, 12)));
      });
    });

    // ── 2. Riverpod provider integration ────────────────────────────────────

    group('localDayClockProvider', () {
      test('default provider yields a SystemLocalDayClock', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final clock = container.read(localDayClockProvider);

        expect(clock, isA<SystemLocalDayClock>());
      });

      test('container override replaces the system clock with a fake', () {
        final fake = FakeLocalDayClock(DateTime.utc(2026, 5, 13, 23, 30));
        final container = ProviderContainer(
          overrides: [localDayClockProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        final clock = container.read(localDayClockProvider);

        expect(identical(clock, fake), isTrue);
        expect(clock.nowUtc(), equals(DateTime.utc(2026, 5, 13, 23, 30)));
      });
    });

    // ── 3. Day-boundary determinism (NFR21 / T1.2 root cause) ───────────────

    group('day-boundary determinism', () {
      test(
        'today is read consistently when the clock is fixed, regardless of host TZ',
        () {
          // The contract: any code reading today() through the provider must
          // see the SAME (y, m, d) for a given fake instant, no matter where
          // the host runs. We pin the seed and assert the y/m/d derived from
          // it locally — this proves the clock-override IS the single source.
          final seeded = DateTime.utc(2026, 5, 13, 20, 30);
          final fake = FakeLocalDayClock(seeded);
          final container = ProviderContainer(
            overrides: [localDayClockProvider.overrideWithValue(fake)],
          );
          addTearDown(container.dispose);

          final today = container.read(localDayClockProvider).today();
          final expectedLocal = seeded.toLocal();

          expect(today.year, equals(expectedLocal.year));
          expect(today.month, equals(expectedLocal.month));
          expect(today.day, equals(expectedLocal.day));
        },
      );
    });

    // ── 4. No-rogue-DateTime-now invariant (AC: grep zero results) ──────────

    group('no-rogue-DateTime.now invariant', () {
      test(
        'grep "DateTime.now()" in lib/ outside core/time/ returns zero results',
        () {
          // AC: "grep -rn 'DateTime\\.now\\(\\)' lib/ --exclude-dir=core/time"
          // must return zero results. We run grep directly so the test fails
          // loudly the moment a new rogue DateTime.now() lands.
          final libDir = Directory('lib');
          expect(
            libDir.existsSync(),
            isTrue,
            reason:
                'test must run from learning_tracker/ (Flutter project root)',
          );

          final result = Process.runSync('grep', const [
            '-rn',
            'DateTime.now()',
            'lib/',
            '--exclude-dir=time',
          ]);

          // grep returns 1 when no matches found — that's the success case.
          expect(
            result.exitCode,
            equals(1),
            reason:
                'DateTime.now() is forbidden outside lib/core/time/. '
                'Use LocalDayClock via localDayClockProvider instead.\n'
                'Found:\n${result.stdout}',
          );
        },
      );
    });
  });

  // --------------------------------------------------------------------------
  // Story 25.7 — core/preferences/ ProfileScopedPreference primitives (DNI-328)
  // --------------------------------------------------------------------------

  group('Story 25.7 — ProfileScopedPreference primitives', tags: ['story_25_7'], () {
    setUp(() {
      // `SharedPreferences.getInstance` reads the platform channel; the in-memory
      // mock binding is required for tests that exercise the file boundary.
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('defaults — new profiles start with the AC-mandated values', () {
      test(
        // Updated by fix(issue-7a): new profiles default to Hebrew script/calendar
        'HebrewTermsPreference defaults to true (Hebrew script on first launch)',
        () async {
          final pref = HebrewTermsPreference();
          expect(pref.defaultValue, isTrue);
          expect(await pref.read(_profileA), isTrue);
          expect(await pref.read(_profileB), isTrue);
          await pref.dispose();
        },
      );

      test(
        // Updated by fix(issue-7a): new profiles default to Hebrew calendar
        'HebrewDatePreference defaults to true (Hebrew calendar on first launch)',
        () async {
          final pref = HebrewDatePreference();
          expect(pref.defaultValue, isTrue);
          expect(await pref.read(_profileA), isTrue);
          expect(await pref.read(_profileB), isTrue);
          await pref.dispose();
        },
      );

      test('NikudPreference defaults to true (pointed text on)', () async {
        final pref = NikudPreference();
        expect(pref.defaultValue, isTrue);
        expect(await pref.read(_profileA), isTrue);
        await pref.dispose();
      });

      test('TransliterationVariantPreference defaults to ashkenazi', () async {
        final pref = TransliterationVariantPreference();
        expect(pref.defaultValue, TransliterationVariant.ashkenazi);
        expect(await pref.read(_profileA), TransliterationVariant.ashkenazi);
        await pref.dispose();
      });

      test('TextDisplayPreference defaults to FontSize.medium', () async {
        final pref = TextDisplayPreference();
        expect(pref.defaultValue, FontSize.medium);
        expect(await pref.read(_profileA), FontSize.medium);
        await pref.dispose();
      });
    });

    group('per-profile isolation — writes do not leak across profiles', () {
      test('writing for profile A does not affect profile B (bool)', () async {
        final pref = HebrewTermsPreference();
        await pref.write(
          _profileA,
          false,
        ); // explicitly write false so profile 2's true default is distinct
        expect(await pref.read(_profileA), isFalse);
        expect(
          await pref.read(_profileB),
          isTrue,
          reason: 'profile 2 must keep its default (true since fix(issue-7a))',
        );
        await pref.dispose();
      });

      test(
        'writing for profile A does not affect profile B (string-coded enum)',
        () async {
          final pref = TransliterationVariantPreference();
          await pref.write(_profileA, TransliterationVariant.sephardi);
          expect(await pref.read(_profileA), TransliterationVariant.sephardi);
          expect(await pref.read(_profileB), TransliterationVariant.ashkenazi);
          await pref.dispose();
        },
      );

      test(
        'writing for profile A does not affect profile B (int-coded enum)',
        () async {
          final pref = TextDisplayPreference();
          await pref.write(_profileA, FontSize.large);
          expect(await pref.read(_profileA), FontSize.large);
          expect(await pref.read(_profileB), FontSize.medium);
          await pref.dispose();
        },
      );
    });

    group('round-trip — read after write returns the written value', () {
      test('HebrewTermsPreference', () async {
        final pref = HebrewTermsPreference();
        await pref.write(_profileA, true);
        expect(await pref.read(_profileA), isTrue);
        await pref.write(_profileA, false);
        expect(await pref.read(_profileA), isFalse);
        await pref.dispose();
      });

      test('HebrewDatePreference', () async {
        final pref = HebrewDatePreference();
        await pref.write(_profileA, true);
        expect(await pref.read(_profileA), isTrue);
        await pref.dispose();
      });

      test('NikudPreference', () async {
        final pref = NikudPreference();
        await pref.write(_profileA, false);
        expect(await pref.read(_profileA), isFalse);
        await pref.dispose();
      });

      test('TransliterationVariantPreference', () async {
        final pref = TransliterationVariantPreference();
        await pref.write(_profileA, TransliterationVariant.sephardi);
        expect(await pref.read(_profileA), TransliterationVariant.sephardi);
        await pref.dispose();
      });

      test('TextDisplayPreference', () async {
        final pref = TextDisplayPreference();
        await pref.write(_profileA, FontSize.small);
        expect(await pref.read(_profileA), FontSize.small);
        await pref.dispose();
      });
    });

    group('observe — every write reaches the matching profile stream', () {
      test(
        'observers see writes for the requested profile and ignore others',
        () async {
          final pref = HebrewTermsPreference();
          final fromProfile1 = <bool>[];
          final fromProfile2 = <bool>[];
          final sub1 = pref.observe(_profileA).listen(fromProfile1.add);
          final sub2 = pref.observe(_profileB).listen(fromProfile2.add);
          await pref.write(_profileA, true);
          await pref.write(_profileB, true);
          await pref.write(_profileA, false);
          // Allow microtasks to drain.
          await Future<void>.delayed(Duration.zero);
          expect(fromProfile1, equals([true, false]));
          expect(fromProfile2, equals([true]));
          await sub1.cancel();
          await sub2.cancel();
          await pref.dispose();
        },
      );

      test('every primitive exposes a working observe stream', () async {
        // Smoke test all five primitives share the same `(read, write, observe)`
        // contract.
        final cases = <ProfileScopedPreference<Object>>[
          HebrewTermsPreference(),
          HebrewDatePreference(),
          NikudPreference(),
          TransliterationVariantPreference(),
          TextDisplayPreference(),
        ];
        try {
          for (final pref in cases) {
            final seen = <Object>[];
            final sub = pref.observe(_profileA).listen(seen.add);
            await pref.write(_profileA, _flippedValue(pref));
            await Future<void>.delayed(Duration.zero);
            expect(
              seen,
              hasLength(1),
              reason: '${pref.runtimeType} did not notify observers',
            );
            await sub.cancel();
          }
        } finally {
          for (final p in cases) {
            await p.dispose();
          }
        }
      });
    });

    test(
      'profile-switch scenario — preference resolves to the new profile value',
      () async {
        // AC: "When the user switches profiles, the new profile loads its own
        // preference values (no global leakage)."
        final pref = HebrewTermsPreference();
        await pref.write(_profileA, true);
        await pref.write(_profileB, false);
        // Active profile starts at 1.
        expect(await pref.read(_profileA), isTrue);
        // Switching to profile 2 must see its own stored value, not profile 1's.
        expect(await pref.read(_profileB), isFalse);
        // Switching back to profile 1 still sees true.
        expect(await pref.read(_profileA), isTrue);
        await pref.dispose();
      },
    );

    test(
      'storage key contract — writes land at `<key>_p<profileId>` so they survive a fresh read',
      () async {
        final pref = HebrewTermsPreference();
        await pref.write(_profileA, true);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(
            ProfileScopedPreferenceKeys.hebrewTermsScript(_profileA),
          ),
          isTrue,
          reason: 'Writes must use the profile-scoped key namespace',
        );
        expect(
          prefs.getBool(
            ProfileScopedPreferenceKeys.hebrewTermsScript(_profileB),
          ),
          isNull,
          reason: 'the other valid profile row must remain absent',
        );
        await pref.dispose();
      },
    );
  });

  // --------------------------------------------------------------------------
  // Story 25.19 — Finalize AppLogger; migrate remaining production logs (DNI-340)
  // --------------------------------------------------------------------------

  group(
    'Story 25.19 — Finalize AppLogger and migrate remaining production logs',
    tags: ['story_25_19'],
    () {
      // ── AC: no debugPrint / bare print() outside generated files ────────────

      test(
        'grep debugPrint|print() in lib/ returns zero non-generated results',
        () {
          final libDir = Directory('lib');
          expect(
            libDir.existsSync(),
            isTrue,
            reason:
                'test must run from learning_tracker/ (Flutter project root)',
          );

          // One single piped pipeline: grep for debugPrint/bare-print, strip
          // generated files and core/logging/ (where AppLogger lives).
          // Raw string keeps backslashes (\|, \., \s) destined for the shell.
          const cmd =
              r"""grep -rn 'debugPrint\|^\s*print(' lib/ --include='*.dart' | grep -v '\.g\.dart' | grep -v '\.freezed\.dart' | grep -v 'core/logging/' || true""";
          final result = Process.runSync('bash', const ['-c', cmd]);

          final stdout = (result.stdout as String).trim();
          expect(
            stdout,
            isEmpty,
            reason:
                'debugPrint() and bare print() are forbidden outside '
                'core/logging/. Use AppLogger.info/.debug/.warning/.error '
                'with the named-param API instead.\nFound:\n$stdout',
          );
        },
      );

      // ── AC: no raw `package:talker/talker.dart` import outside core/logging/

      test('grep raw package:talker/talker.dart import outside core/logging/ '
          'returns zero results', () {
        final libDir = Directory('lib');
        expect(libDir.existsSync(), isTrue);

        final result = Process.runSync('grep', const [
          '-rn',
          "import 'package:talker/talker.dart'",
          'lib/',
          '--exclude-dir=logging',
        ]);

        // grep exits 1 when no matches — that is the green case.
        expect(
          result.exitCode,
          equals(1),
          reason:
              "Raw `import 'package:talker/talker.dart'` is forbidden "
              'outside lib/core/logging/. Inject an `AppLogger` instead '
              '(or use `talker_flutter` when a raw Talker is genuinely '
              'required by a third-party widget).\nFound:\n${result.stdout}',
        );
      });

      // ── AC: structured-event shape — the field-based redactor is applied ────

      test('AppLogger.info(event:, fields:) builds {event field=value} message '
          'and redacts sensitive keys', () {
        final talker = Talker(
          settings: TalkerSettings(
            enabled: true,
            useConsoleLogs: false,
            maxHistoryItems: 16,
          ),
        );
        final log = AppLogger(talker);

        log.info(
          event: 'sync_pull_completed',
          fields: const {
            'profileId': 7,
            'durationMs': 142,
            'status': 'ok',
            'email': 'leak@example.com',
          },
        );

        // Wait until Talker drains its internal queue.
        final entry = talker.history.firstWhere(
          (e) => (e.message ?? '').startsWith('sync_pull_completed'),
        );
        final msg = entry.message ?? '';

        // event prefix preserved verbatim
        expect(msg, startsWith('sync_pull_completed '));
        // non-sensitive fields preserved
        expect(msg, contains('profileId: 7'));
        expect(msg, contains('durationMs: 142'));
        expect(msg, contains('status: ok'));
        // sensitive value redacted by key
        expect(msg, contains('email: [REDACTED]'));
        expect(msg, isNot(contains('leak@example.com')));
      });

      test(
        'SeedManager and ContentDbHealthChecker constructors take AppLogger',
        () {
          final seed = File(
            'lib/core/database/seed_manager.dart',
          ).readAsStringSync();
          expect(
            seed,
            contains('AppLogger? logger'),
            reason: 'SeedManager must accept an optional AppLogger.',
          );
          expect(seed, isNot(contains("import 'package:talker/talker.dart'")));

          final hc = File(
            'lib/core/database/content_db_health_checker.dart',
          ).readAsStringSync();
          expect(
            hc,
            contains('AppLogger? logger'),
            reason: 'ContentDbHealthChecker must accept an optional AppLogger.',
          );
          expect(hc, isNot(contains("import 'package:talker/talker.dart'")));
        },
      );
    },
  );

  // --------------------------------------------------------------------------
  // Story 25.17 — the old user Drift database layer is retired.
  group(
    'Story 25.17 — legacy user-DB artefacts are absent',
    tags: ['story_25_17'],
    () {
      test('only the current content tables remain in the database layer', () {
        final tableNames = Directory('lib/core/database/tables')
            .listSync()
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .toSet();

        expect(
          tableNames,
          equals({
            'calendar_cycles.dart',
            'daily_content.dart',
            'seed_metadata.dart',
            'text_cache.dart',
          }),
        );
        expect(File('lib/core/database/base_dao.dart').existsSync(), isFalse);
        expect(
          File('lib/core/database/track_scope.dart').existsSync(),
          isFalse,
        );
        expect(
          File('lib/core/database/track_scope.freezed.dart').existsSync(),
          isFalse,
        );

        // Deliberately retained architecture: content DB, registry DB,
        // content seeding/health support, and the shared Drift file resolver.
        expect(
          File('lib/core/database/content/content_database.dart').existsSync(),
          isTrue,
        );
        expect(
          File(
            'lib/core/database/registry/device_registry_database.dart',
          ).existsSync(),
          isTrue,
        );
        expect(
          File('lib/core/database/seed_manager.dart').existsSync(),
          isTrue,
        );
        expect(
          File('lib/core/database/content_db_health_checker.dart').existsSync(),
          isTrue,
        );
        expect(
          File('lib/core/database/drift_db_file.dart').existsSync(),
          isTrue,
        );
      });
    },
  );
}

Object _flippedValue(ProfileScopedPreference<Object> pref) {
  if (pref is HebrewTermsPreference ||
      pref is HebrewDatePreference ||
      pref is NikudPreference) {
    return !(pref.defaultValue as bool);
  }
  if (pref is TransliterationVariantPreference) {
    return TransliterationVariant.sephardi;
  }
  if (pref is TextDisplayPreference) {
    return FontSize.large;
  }
  throw StateError('Unhandled preference type: ${pref.runtimeType}');
}

// ── Story 25.8 helpers ───────────────────────────────────────────────────────

/// Builds a small but realistic content fixture spanning two curricula:
/// 1 masechta of Mishnah Berakhot with 4 mishnayos (plus 2 containers),
/// and 3 leaf amudim of Bavli Berakhot.
Map<CurriculumId, List<ContentItem>> _smallCurriculumSet() {
  final mishnayos = <ContentItem>[
    const ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      displayNameHe: 'זרעים',
      displayNameEn: 'Zeraim',
      sefariaRef: 'Zeraim',
      sortOrder: 0,
      isLeaf: false,
    ),
    const ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      level2: 'Berakhot',
      displayNameHe: 'ברכות',
      displayNameEn: 'Berakhot',
      sefariaRef: 'Mishnah Berakhot',
      sortOrder: 1,
      isLeaf: false,
    ),
    for (var i = 1; i <= 4; i++)
      ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Zeraim',
        level2: 'Berakhot',
        level3: 'Perek 1',
        level4: 'Mishnah $i',
        displayNameHe: 'משנה $i',
        displayNameEn: 'Mishnah $i',
        sefariaRef: 'Mishnah Berakhot 1:$i',
        sortOrder: 1 + i,
        isLeaf: true,
      ),
  ];

  final bavli = <ContentItem>[
    const ContentItem(
      curriculumId: 'bavli',
      level1: 'Berakhot',
      level2: 'Daf 2',
      level3: 'Amud a',
      displayNameHe: 'ברכות ב.',
      displayNameEn: 'Berakhot 2a',
      sefariaRef: 'Berakhot 2a',
      sortOrder: 0,
      isLeaf: true,
    ),
    const ContentItem(
      curriculumId: 'bavli',
      level1: 'Berakhot',
      level2: 'Daf 2',
      level3: 'Amud b',
      displayNameHe: 'ברכות ב:',
      displayNameEn: 'Berakhot 2b',
      sefariaRef: 'Berakhot 2b',
      sortOrder: 1,
      isLeaf: true,
    ),
    const ContentItem(
      curriculumId: 'bavli',
      level1: 'Berakhot',
      level2: 'Daf 3',
      level3: 'Amud a',
      displayNameHe: 'ברכות ג.',
      displayNameEn: 'Berakhot 3a',
      sefariaRef: 'Berakhot 3a',
      sortOrder: 2,
      isLeaf: true,
    ),
  ];

  return {CurriculumId.mishnayos: mishnayos, CurriculumId.bavli: bavli};
}

/// Synthesises [count] unique leaf items for [curriculum]. Used by the
/// benchmark test to size the index up to realistic content scale
/// (~52K rows across 9 curricula).
List<ContentItem> _generateLeafItems(
  CurriculumId curriculum, {
  required int count,
}) {
  final prefix = curriculum.storageKey;
  return [
    for (var i = 0; i < count; i++)
      ContentItem(
        curriculumId: curriculum.storageKey,
        level1: 'Section',
        level2: 'Unit $i',
        displayNameHe: '$prefix-$i',
        displayNameEn: '$prefix-$i',
        sefariaRef: '$prefix-bench:$i',
        sortOrder: i,
        isLeaf: true,
      ),
  ];
}

/// Stub implementation of [ProgramRefSource] for tests. Backs a fixed
/// `(programId, dayOffset) → rawRef` map; returns null otherwise.
class _StubProgramRefSource implements ProgramRefSource {
  _StubProgramRefSource(this._map);

  final Map<(String, int), String> _map;

  @override
  String? rawRefFor({required String programId, required int dayOffset}) =>
      _map[(programId, dayOffset)];
}

// ── mock for story 25.11 ──────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}
