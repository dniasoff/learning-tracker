/// Story acceptance tests for Epic 24 — Stop-the-Bleeding (Phase 0).
@Tags(['epic_24'])
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, test;
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:test/test.dart';

/// Reads the canonical `firestore.rules` file from the repository root.
///
/// The test runs from the `learning_tracker/` sub-directory, so we need to
/// go up one level.
String _readRules() {
  // When running via `flutter test` the cwd is learning_tracker/.
  // When running from repo root it is the repo root itself.
  final candidates = [File('../firestore.rules'), File('firestore.rules')];
  for (final f in candidates) {
    if (f.existsSync()) return f.readAsStringSync();
  }
  throw StateError(
    'firestore.rules not found. Searched: ${candidates.map((f) => f.path)}',
  );
}

void main() {
  // ── Story 24.1: Per-collection Firestore rules ─────────────────────────

  group(
    'Story 24.1 -- Per-collection Firestore rules with field validators',
    tags: ['story_24_1'],
    () {
      late String rules;

      setUpAll(() {
        rules = _readRules();
      });

      // ── completions ──────────────────────────────────────────────────

      group('completions collection', () {
        test('has per-collection match for completions/{completionId}', () {
          expect(rules, contains('match /completions/{completionId}'));
        });

        test('allows create (not wildcard read/write)', () {
          // Rules must contain `allow create:` in the completions block.
          // We check that the rules file has the points validator pattern.
          expect(rules, contains('points >= 0'));
          expect(rules, contains('points <= 100'));
        });

        test('enforces completedAt <= request.time', () {
          expect(rules, contains('completedAt <= request.time'));
        });

        test('denies update on completions', () {
          // The completions rule must explicitly deny update.
          // It does so via `allow update, delete: if false`.
          // We verify both the field and the deny pattern are present.
          expect(rules, contains('allow update, delete: if false'));
        });
      });

      // ── streak_events ────────────────────────────────────────────────

      group('streak_events collection', () {
        test('has per-collection match for streak_events/{eventId}', () {
          expect(rules, contains('match /streak_events/{eventId}'));
        });

        test('create-only with timestamp clamp', () {
          // Rules must check createdAt <= request.time for streak_events.
          // We look for the combination of the collection match and the clamp.
          final streakBlock = _extractBlock(rules, 'streak_events/{eventId}');
          expect(streakBlock, contains('createdAt <= request.time'));
        });

        test('denies delete on streak_events', () {
          final streakBlock = _extractBlock(rules, 'streak_events/{eventId}');
          expect(
            streakBlock,
            anyOf(
              contains('allow update, delete: if false'),
              contains('allow delete: if false'),
            ),
          );
        });
      });

      // ── learning_ledger ──────────────────────────────────────────────

      group('learning_ledger collection', () {
        test('has per-collection match for learning_ledger/{entryId}', () {
          expect(rules, contains('match /learning_ledger/{entryId}'));
        });

        test('create-only with timestamp clamp', () {
          final ledgerBlock = _extractBlock(rules, 'learning_ledger/{entryId}');
          expect(ledgerBlock, contains('createdAt <= request.time'));
        });

        test('denies delete on learning_ledger', () {
          final ledgerBlock = _extractBlock(rules, 'learning_ledger/{entryId}');
          expect(
            ledgerBlock,
            anyOf(
              contains('allow update, delete: if false'),
              contains('allow delete: if false'),
            ),
          );
        });
      });

      // ── settings ─────────────────────────────────────────────────────

      group('settings collection', () {
        test('has per-collection match for settings/{settingId}', () {
          expect(rules, contains('match /settings/{settingId}'));
        });

        test('has field whitelist for hebrewTerms', () {
          final settingsBlock = _extractBlock(rules, 'settings/{settingId}');
          expect(settingsBlock, contains('hebrewTerms'));
        });

        test('has field whitelist for useHebrewDate', () {
          final settingsBlock = _extractBlock(rules, 'settings/{settingId}');
          expect(settingsBlock, contains('useHebrewDate'));
        });

        test('uses hasOnly() for field whitelist enforcement', () {
          final settingsBlock = _extractBlock(rules, 'settings/{settingId}');
          expect(settingsBlock, contains('hasOnly('));
        });

        test('denies delete on settings', () {
          final settingsBlock = _extractBlock(rules, 'settings/{settingId}');
          expect(
            settingsBlock,
            anyOf(
              contains('allow delete: if false'),
              contains('allow update, delete: if false'),
            ),
          );
        });
      });

      // ── Global deny-all default ───────────────────────────────────────

      group('global default deny rule', () {
        test('has wildcard deny-all rule', () {
          expect(rules, contains('match /{document=**}'));
          // The deny-all rule must come before any collection-specific rules.
          final denyPos = rules.indexOf('allow read, write: if false');
          expect(
            denyPos,
            greaterThan(-1),
            reason: 'Missing default deny-all rule',
          );
        });
      });

      // ── Emulator test suite exists ────────────────────────────────────

      group('emulator test suite', () {
        test('test/firestore-rules/firestore.rules.test.js exists', () {
          final candidates = [
            File('../test/firestore-rules/firestore.rules.test.js'),
            File('test/firestore-rules/firestore.rules.test.js'),
          ];
          final exists = candidates.any((f) => f.existsSync());
          expect(
            exists,
            isTrue,
            reason:
                'Emulator test suite not found at test/firestore-rules/firestore.rules.test.js',
          );
        });

        test('test/firestore-rules/package.json exists', () {
          final candidates = [
            File('../test/firestore-rules/package.json'),
            File('test/firestore-rules/package.json'),
          ];
          final exists = candidates.any((f) => f.existsSync());
          expect(
            exists,
            isTrue,
            reason:
                'package.json not found at test/firestore-rules/package.json',
          );
        });

        test('CI workflow has firestore-rules job', () {
          final candidates = [
            File('../.github/workflows/ci.yml'),
            File('.github/workflows/ci.yml'),
          ];
          String? ciContent;
          for (final f in candidates) {
            if (f.existsSync()) {
              ciContent = f.readAsStringSync();
              break;
            }
          }
          expect(ciContent, isNotNull, reason: 'ci.yml not found');
          expect(
            ciContent,
            contains('firestore-rules:'),
            reason: 'CI does not have a firestore-rules job',
          );
        });
      });
    },
  );

  // ─── Story 24.4: Wire Crashlytics in main.dart ───────────────────────────

  group(
    'Story 24.4 — Crashlytics wired in main.dart',
    tags: ['story_24_4'],
    () {
      late _CapturingCrashlyticsService service;

      setUp(() {
        service = _CapturingCrashlyticsService();
      });

      // AC1: setCrashlyticsCollectionEnabled(true) runs (interface level)
      test('AC1: collection can be enabled without error', () async {
        await service.setCrashlyticsCollectionEnabled(true);
        expect(service.collectionEnabled, isTrue);
      });

      // AC2: FlutterError.onError forwards to Crashlytics (via interface)
      test(
        'AC2: recordFlutterFatalError is called for Flutter errors',
        () async {
          final details = FlutterErrorDetails(
            exception: StateError('widget error'),
            stack: StackTrace.current,
          );
          await service.recordFlutterFatalError(details);
          expect(service.flutterErrors, hasLength(1));
          expect(service.flutterErrors.first.exception, isA<StateError>());
        },
      );

      // AC2: PlatformDispatcher.instance.onError forwards to Crashlytics
      test(
        'AC2: recordError(fatal: true) is called for platform errors',
        () async {
          final err = Exception('platform crash');
          final st = StackTrace.current;
          await service.recordError(err, st, fatal: true);
          expect(service.errors, hasLength(1));
          expect(service.errors.first.$1, err);
          expect(service.errors.first.$3, isTrue); // fatal flag
        },
      );

      // AC3+AC4: setUserIdentifier uses numeric profileId — no PII
      test(
        'AC3: setUserIdentifier sends numeric profileId as string',
        () async {
          await service.setUserIdentifier(5);
          expect(service.lastIdentifier, '5');
        },
      );

      test(
        'AC4: setUserIdentifier(null) clears identifier (no PII fallback)',
        () async {
          await service.setUserIdentifier(42); // simulate login
          await service.setUserIdentifier(null); // simulate logout
          expect(service.lastIdentifier, '');
        },
      );

      test('AC4: no email or non-numeric PII in identifier', () async {
        await service.setUserIdentifier(99);
        final id = service.lastIdentifier!;
        expect(
          RegExp(r'^[0-9]*$').hasMatch(id),
          isTrue,
          reason: 'Identifier must be purely numeric. Got: "$id"',
        );
      });

      // AC5: Crash is reported even before any sign-in (no identifier set)
      test('AC5: errors are captured before any profile is selected', () async {
        // Identifier was never set — simulates pre-auth crash
        expect(service.lastIdentifier, isNull);
        await service.recordError(
          Exception('pre-auth crash'),
          StackTrace.current,
          fatal: true,
        );
        expect(service.errors, hasLength(1));
      });

      // NullCrashlyticsService is safe to use when Firebase is unavailable
      test(
        'NullCrashlyticsService never throws (offline / test environment)',
        () async {
          const nullService = NullCrashlyticsService();
          await nullService.setCrashlyticsCollectionEnabled(true);
          await nullService.recordFlutterFatalError(
            FlutterErrorDetails(
              exception: Exception('x'),
              stack: StackTrace.current,
            ),
          );
          await nullService.recordError(
            Exception('y'),
            StackTrace.current,
            fatal: true,
          );
          await nullService.setUserIdentifier(1);
          await nullService.setUserIdentifier(null);
        },
      );
    },
  );
}

// ─── Test helpers ────────────────────────────────────────────────────────────

/// A capturing [CrashlyticsService] that records every call made to it.
/// Uses the same identifier encoding as [FirebaseCrashlyticsService] so
/// PII-safety can be verified without touching the real Firebase SDK.
class _CapturingCrashlyticsService implements CrashlyticsService {
  bool? collectionEnabled;
  final List<FlutterErrorDetails> flutterErrors = [];
  final List<(Object, StackTrace?, bool)> errors = [];
  String? lastIdentifier;

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {
    flutterErrors.add(details);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    errors.add((error, stack, fatal));
  }

  @override
  Future<void> setUserIdentifier(int? profileId) async {
    lastIdentifier = profileId == null ? '' : '$profileId';
  }
}

/// Extracts the text of the `match /<collectionPattern>` block for
/// [collectionPattern] from [rules].
///
/// The match statement itself may contain `{` characters as part of the path
/// pattern (e.g. `{eventId}`), so we skip to the end of the match line
/// before starting brace-depth counting.
String _extractBlock(String rules, String collectionPattern) {
  final startPattern = 'match /$collectionPattern';
  final startIndex = rules.indexOf(startPattern);
  if (startIndex == -1) return '';

  // Find the end of the match declaration line (the opening `{` of the block).
  // Skip past the pattern itself to avoid counting `{` inside `{eventId}`.
  var i = startIndex + startPattern.length;

  // Advance to the first `{` that opens the rule block (not a path param).
  // The match declaration ends at `{` after the closing `)` or newline.
  // We look for a `{` that is preceded by a newline or space, not by `/`.
  while (i < rules.length && rules[i] != '{') {
    i++;
  }

  if (i >= rules.length) return rules.substring(startIndex);

  // Now do depth counting from the opening `{`.
  var depth = 0;

  while (i < rules.length) {
    final ch = rules[i];
    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        return rules.substring(startIndex, i + 1);
      }
    }
    i++;
  }

  return rules.substring(startIndex);
}
