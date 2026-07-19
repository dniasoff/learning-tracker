// Tests for `tool/check_platform_deep_link_hosting.dart` (AUD-platform-01).
//
// Fixture-based, same shape as test/tool/check_gitkeep_stray_test.dart: each
// test writes disposable firebase.json/AndroidManifest.xml/auth-repo
// fixtures under a temp dir and drives the checker at them via
// `--firebase-json`/`--manifest`/`--auth-repo`, so nothing touches this
// repo's real files and tests stay hermetic under `--concurrency=2`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _validManifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application>
    <activity android:name=".MainActivity">
      <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data
            android:scheme="https"
            android:host="torah-study-tracker.firebaseapp.com"
            android:pathPrefix="/sign-in"/>
      </intent-filter>
      <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data
            android:scheme="https"
            android:host="torah-study-tracker.firebaseapp.com"
            android:pathPrefix="/invite"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
''';

const _validAuthRepo = '''
class AuthRepositoryImpl {
  static const _linkDomain = 'https://torah-study-tracker.firebaseapp.com';
}
''';

Map<String, dynamic> _validFirebaseJson() => {
  'hosting': {'public': 'hosting/public'},
};

void main() {
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_platform_deep_link_hosting.dart';

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'deep_link_hosting_fixture_',
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<ProcessResult> runCheck({
    Map<String, dynamic>? firebaseJson,
    String? manifest,
    String? authRepo,
  }) async {
    final firebaseJsonFile = File('${tempDir.path}/firebase.json')
      ..writeAsStringSync(jsonEncode(firebaseJson ?? _validFirebaseJson()));
    final manifestFile = File('${tempDir.path}/AndroidManifest.xml')
      ..writeAsStringSync(manifest ?? _validManifest);
    final authRepoFile = File('${tempDir.path}/auth_repository_impl.dart')
      ..writeAsStringSync(authRepo ?? _validAuthRepo);

    return Process.run('dart', [
      'run',
      scriptPath,
      '--firebase-json',
      firebaseJsonFile.path,
      '--manifest',
      manifestFile.path,
      '--auth-repo',
      authRepoFile.path,
    ], workingDirectory: packageDir);
  }

  group('tool/check_platform_deep_link_hosting.dart (AUD-platform-01)', () {
    test('exits 0 on the real (fixed) tree', () async {
      final result = await Process.run('dart', [
        'run',
        scriptPath,
      ], workingDirectory: packageDir);
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(result.stdout.toString(), contains('passed'));
    });

    test('exits 0 on a well-formed fixture (hosting block + matching '
        'autoVerify intent-filters)', () async {
      final result = await runCheck();
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
    });

    test(
      'RED: FAILS when firebase.json has no "hosting" block at all — this '
      'is the exact AUD-platform-01 defect shape (root cause of the finding)',
      () async {
        final result = await runCheck(
          firebaseJson: {'firestore': <String, dynamic>{}},
        );
        expect(
          result.exitCode,
          isNot(0),
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(result.stderr.toString(), contains('missing a "hosting"'));
      },
    );

    test('FAILS when hosting.public is blank', () async {
      final result = await runCheck(
        firebaseJson: {
          'hosting': {'public': ''},
        },
      );
      expect(result.exitCode, isNot(0));
      expect(result.stderr.toString(), contains('missing a "hosting"'));
    });

    test('FAILS when hosting.appAssociation is "NONE" (disables the '
        'auto-served assetlinks.json this fix relies on)', () async {
      final result = await runCheck(
        firebaseJson: {
          'hosting': {'public': 'hosting/public', 'appAssociation': 'NONE'},
        },
      );
      expect(result.exitCode, isNot(0));
      expect(result.stderr.toString(), contains('appAssociation'));
    });

    test(
      'FAILS when the /invite autoVerify intent-filter is removed from the '
      'manifest (tutor-invite deep link regresses to the system browser)',
      () async {
        final manifestWithoutInvite = _validManifest.replaceAll(
          RegExp(
            r'<intent-filter android:autoVerify="true">\s*'
            r'<action android:name="android\.intent\.action\.VIEW"/>\s*'
            r'<category android:name="android\.intent\.category\.DEFAULT"/>\s*'
            r'<category android:name="android\.intent\.category\.BROWSABLE"/>\s*'
            r'<data\s*'
            r'android:scheme="https"\s*'
            r'android:host="torah-study-tracker\.firebaseapp\.com"\s*'
            r'android:pathPrefix="/invite"/>\s*'
            '</intent-filter>',
          ),
          '',
        );
        final result = await runCheck(manifest: manifestWithoutInvite);
        expect(result.exitCode, isNot(0));
        expect(result.stderr.toString(), contains('/invite'));
      },
    );

    test('FAILS when the manifest host no longer matches AuthRepositoryImpl\'s '
        '_linkDomain (configs silently drifted apart)', () async {
      final driftedManifest = _validManifest.replaceAll(
        'torah-study-tracker.firebaseapp.com',
        'stale-domain.example.com',
      );
      final result = await runCheck(manifest: driftedManifest);
      expect(result.exitCode, isNot(0));
    });
  });
}
