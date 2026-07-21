/// Rule-0 checker — Android App Link deep-link hosting stays wired up
/// (AUD-platform-01).
///
/// AUD-platform-01 found that `AndroidManifest.xml` declares two
/// `android:autoVerify="true"` intent-filters (the Firebase email
/// sign-in-continuation and tutor-invite-accept deep links) against
/// `torah-study-tracker.firebaseapp.com`, but `firebase.json` had no
/// `hosting` block at all — so nothing could ever serve
/// `/.well-known/assetlinks.json`, and Android would never verify the app
/// as the handler for those links. This checker is the static,
/// offline half of that finding's remediation (the live half —
/// "curl -f .../.well-known/assetlinks.json returns 200" — is
/// `tool/check_assetlinks_live.sh`, run post-deploy in CI/CD since it
/// needs network access and cannot be a `make audit` grep).
///
/// It fails if any of the following regress:
///   1. `firebase.json` is missing a `hosting` block, or `hosting.public`
///      is blank.
///   2. `hosting.appAssociation` is explicitly set to `"NONE"` — that
///      disables Firebase Hosting's built-in auto-served
///      `.well-known/assetlinks.json` (derived from the SHA-256
///      fingerprints registered against the Firebase Android app), which
///      is the mechanism this fix relies on (see `hosting/README.md`;
///      a static hosting/public/.well-known/assetlinks.json IS committed because AUTO was verified to serve [] for this project — 2026-07-21).
///   3. `AndroidManifest.xml` no longer declares
///      `android:autoVerify="true"` intent-filters for `/sign-in` and
///      `/invite` against the same host `AuthRepositoryImpl._linkDomain`
///      points at — catches the two configs drifting apart again.
///
/// Usage:
///   dart run tool/check_platform_deep_link_hosting.dart
///   dart run tool/check_platform_deep_link_hosting.dart \
///     --firebase-json <path> --manifest <path> --auth-repo <path>
///     # test-only overrides so the regression test
///     # (test/tool/check_platform_deep_link_hosting_test.dart) can exercise
///     # deliberately-broken fixtures without touching this repo's real
///     # firebase.json / AndroidManifest.xml.
///
/// Exit codes:
///   0 — hosting config, appAssociation, and manifest/authrepo host
///       agreement all hold
///   1 — one or more of the above regressed (prints what and why)
///   2 — a required input file is missing/unreadable
library;

import 'dart:convert';
import 'dart:io';

String? _argValue(List<String> args, String flag) {
  final i = args.indexOf(flag);
  if (i == -1 || i + 1 >= args.length) return null;
  return args[i + 1];
}

/// Extracts the host from a `https://host[/...]` string, e.g.
/// `'https://torah-study-tracker.firebaseapp.com/sign-in'` -> the domain.
String? _hostFromUrlLike(String value) {
  final match = RegExp(r'^https?://([^/\s]+)').firstMatch(value);
  return match?.group(1);
}

void main(List<String> args) {
  final firebaseJsonPath =
      _argValue(args, '--firebase-json') ?? 'firebase.json';
  final manifestPath =
      _argValue(args, '--manifest') ??
      'android/app/src/main/AndroidManifest.xml';
  final authRepoPath =
      _argValue(args, '--auth-repo') ??
      'lib/features/account/data/repositories/auth_repository_impl.dart';

  final violations = <String>[];

  // ── 1 & 2: firebase.json hosting block ──────────────────────────────────
  final firebaseJsonFile = File(firebaseJsonPath);
  if (!firebaseJsonFile.existsSync()) {
    stderr.writeln('ERROR: $firebaseJsonPath not found.');
    exit(2);
  }
  Map<String, dynamic> firebaseJson;
  try {
    firebaseJson =
        jsonDecode(firebaseJsonFile.readAsStringSync()) as Map<String, dynamic>;
  } on FormatException catch (e) {
    stderr.writeln('ERROR: $firebaseJsonPath is not valid JSON: $e');
    exit(2);
  }

  final hosting = firebaseJson['hosting'];
  if (hosting is! Map<String, dynamic> ||
      ((hosting['public'] as String?)?.trim().isEmpty ?? true)) {
    violations.add(
      '$firebaseJsonPath: missing a "hosting" block with a non-empty '
      '"public" directory (AUD-platform-01) — nothing will serve '
      '/.well-known/assetlinks.json, so Android will never verify this app '
      'for the autoVerify sign-in/invite deep links.',
    );
  } else {
    final appAssociation = hosting['appAssociation'];
    if (appAssociation == 'NONE') {
      violations.add(
        '$firebaseJsonPath: hosting.appAssociation is "NONE", which '
        'disables Firebase Hosting\'s built-in auto-served '
        '.well-known/assetlinks.json (AUD-platform-01; see '
        'hosting/README.md). Remove this key (default is auto-serve) '
        'unless a static assetlinks.json is committed instead.',
      );
    }
  }

  // ── 3: manifest autoVerify hosts match AuthRepositoryImpl's domain ─────
  final manifestFile = File(manifestPath);
  final authRepoFile = File(authRepoPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln('ERROR: $manifestPath not found.');
    exit(2);
  }
  if (!authRepoFile.existsSync()) {
    stderr.writeln('ERROR: $authRepoPath not found.');
    exit(2);
  }

  final authRepoSource = authRepoFile.readAsStringSync();
  final linkDomainMatch = RegExp(
    r'''_linkDomain\s*=\s*['"]([^'"]+)['"]''',
  ).firstMatch(authRepoSource);
  if (linkDomainMatch == null) {
    violations.add(
      '$authRepoPath: could not find a `_linkDomain = \'...\'` constant to '
      'cross-check against the manifest (AUD-platform-01) — has the auth '
      'continuation-link domain been renamed/restructured?',
    );
  }
  final expectedHost = linkDomainMatch == null
      ? null
      : _hostFromUrlLike(linkDomainMatch.group(1)!);

  final manifestSource = manifestFile.readAsStringSync();
  // One intent-filter block per <intent-filter ...> ... </intent-filter>.
  final intentFilterBlocks = RegExp(
    r'<intent-filter\b[^>]*>.*?</intent-filter>',
    dotAll: true,
  ).allMatches(manifestSource).map((m) => m.group(0)!).toList();

  bool hasAutoVerifyHostFor(String pathPrefix) {
    return intentFilterBlocks.any((block) {
      if (!block.contains('android:autoVerify="true"')) return false;
      if (expectedHost != null &&
          !block.contains('android:host="$expectedHost"')) {
        return false;
      }
      return block.contains('android:pathPrefix="$pathPrefix"');
    });
  }

  if (expectedHost != null) {
    for (final pathPrefix in ['/sign-in', '/invite']) {
      if (!hasAutoVerifyHostFor(pathPrefix)) {
        violations.add(
          '$manifestPath: no `android:autoVerify="true"` intent-filter '
          'found for host "$expectedHost" and pathPrefix "$pathPrefix" '
          '(AUD-platform-01) — the sign-in/invite deep link would fall '
          'back to the system browser.',
        );
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln(
      'Deep-link hosting check FAILED (AUD-platform-01) — '
      '${violations.length} violation(s):',
    );
    for (final v in violations) {
      stderr.writeln('  - $v');
    }
    exit(1);
  }

  stdout.writeln(
    'Deep-link hosting check passed — firebase.json declares a hosting '
    'block with auto-served assetlinks.json, and AndroidManifest.xml\'s '
    'autoVerify intent-filters still match AuthRepositoryImpl\'s link '
    'domain (AUD-platform-01).',
  );
}
