// Sub-tracks story 1.1 (DNI-463) AC-1 — the target stack and platform
// floors are declared, resolved and locked.
//
// Reads the project manifests (pubspec.yaml, pubspec.lock,
// .flutter-version, the iOS/macOS Xcode projects) — never a lib/ file — and
// asks pub itself, via a lockfile-enforced dry-run resolve, whether the
// committed lockfile satisfies the declared constraints. Nothing on disk is
// modified, so it is safe in the parallel test lane.
@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AC-1's exact dependency constraints.
const _expectedConstraints = <String, String>{
  'firebase_core': '^4.15.0',
  'cloud_firestore': '^6.10.0',
  'firebase_auth': '^6.7.0',
  'cloud_functions': '^6.5.0',
  'firebase_analytics': '^12.6.0',
  'firebase_messaging': '^16.7.0',
  'pdf': '^3.13.1',
  'kosher_dart': '^2.0.20',
  'flutter_local_notifications': '^22.3.1',
  'share_plus': '^13.3.0',
};

List<int> _parseVersion(String v) => v
    .split(RegExp('[+-]'))
    .first
    .split('.')
    .map(int.parse)
    .toList(growable: false);

int _compare(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    final c = a[i].compareTo(b[i]);
    if (c != 0) return c;
  }
  return 0;
}

/// `^x.y.z` semantics: at least the base, below the next breaking version.
bool _satisfiesCaret(String version, String caret) {
  final base = _parseVersion(caret.substring(1));
  final v = _parseVersion(version);
  if (_compare(v, base) < 0) return false;
  return base[0] > 0 ? v[0] == base[0] : v[1] == base[1];
}

/// Top-level `dependencies:` entries of pubspec.yaml with a scalar
/// constraint (`name: ^1.2.3`).
Map<String, String> _directDependencies(String pubspec) {
  final start = pubspec.indexOf('\ndependencies:');
  final end = pubspec.indexOf('\ndev_dependencies:');
  final section = pubspec.substring(start, end);
  return {
    for (final m in RegExp(
      r'''^  ([a-z0-9_]+): ['"]?([^'"\s#]+)['"]?\s*$''',
      multiLine: true,
    ).allMatches(section))
      m.group(1)!: m.group(2)!,
  };
}

/// `package -> locked version` from pubspec.lock.
Map<String, String> _lockedVersions(String lock) {
  final versions = <String, String>{};
  String? current;
  for (final line in lock.split('\n')) {
    final pkg = RegExp(r'^  ([a-z0-9_]+):$').firstMatch(line);
    if (pkg != null) {
      current = pkg.group(1);
      continue;
    }
    final ver = RegExp(r'^    version: "([^"]+)"$').firstMatch(line);
    if (ver != null && current != null) versions[current] = ver.group(1)!;
  }
  return versions;
}

void main() {
  final packageDir = Directory.current.path;
  String read(String rel) => File('$packageDir/$rel').readAsStringSync();

  group('DNI-463 AC-1: target stack and platform floors', () {
    test('environment pins Dart ^3.12.0 and a Flutter floor of 3.41.6', () {
      final pubspec = read('pubspec.yaml');
      expect(
        pubspec,
        contains(RegExp(r'^  sdk: \^3\.12\.0$', multiLine: true)),
      );
      expect(
        pubspec,
        contains(
          RegExp(r'''^  flutter: ["']>=3\.41\.6["']$''', multiLine: true),
        ),
      );
    });

    test('pubspec.yaml declares exactly the AC-1 dependency constraints', () {
      final deps = _directDependencies(read('pubspec.yaml'));
      _expectedConstraints.forEach((name, constraint) {
        expect(deps[name], constraint, reason: '$name constraint');
      });
    });

    test('pubspec.lock locks every AC-1 package at a version satisfying its '
        'constraint (nothing pinned back below the floor)', () {
      final locked = _lockedVersions(read('pubspec.lock'));
      _expectedConstraints.forEach((name, constraint) {
        final version = locked[name];
        expect(version, isNotNull, reason: '$name missing from pubspec.lock');
        expect(
          _satisfiesCaret(version!, constraint),
          isTrue,
          reason: '$name locked at $version does not satisfy $constraint',
        );
      });
    });

    test('pub resolves the declared constraints against the committed '
        'lockfile without changing it', () async {
      final result = await Process.run('dart', [
        'pub',
        'get',
        '--dry-run',
        '--enforce-lockfile',
        '--offline',
      ], workingDirectory: packageDir);
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(
        result.stdout.toString(),
        contains('No dependencies would change'),
      );
    });

    test('the pinned CI Flutter version is at least 3.41.6', () {
      final pinned = read('../.flutter-version').trim();
      expect(
        _compare(_parseVersion(pinned), [3, 41, 6]) >= 0,
        isTrue,
        reason: '.flutter-version is $pinned',
      );
    });

    test('every iOS build configuration targets iOS 13.0', () {
      final targets = RegExp(
        'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);',
      ).allMatches(read('ios/Runner.xcodeproj/project.pbxproj'));
      expect(targets, isNotEmpty);
      expect(targets.map((m) => m.group(1)).toSet(), {'13.0'});
    });

    test('a macOS host exists and every build configuration meets the '
        'macOS 10.15 floor share_plus 13 requires', () {
      final targets = RegExp(
        'MACOSX_DEPLOYMENT_TARGET = ([0-9.]+);',
      ).allMatches(read('macos/Runner.xcodeproj/project.pbxproj')).toList();
      expect(targets, isNotEmpty);
      for (final m in targets) {
        final parts = m.group(1)!.split('.').map(int.parse).toList();
        while (parts.length < 3) {
          parts.add(0);
        }
        expect(
          _compare(parts, [10, 15, 0]) >= 0,
          isTrue,
          reason: 'MACOSX_DEPLOYMENT_TARGET ${m.group(1)} is below 10.15',
        );
      }
    });
  });
}
