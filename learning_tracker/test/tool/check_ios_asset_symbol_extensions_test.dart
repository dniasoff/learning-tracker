// Tests for `tool/check_ios_asset_symbol_extensions.dart` (AUD-platform-04).
//
// Fixture-based, same shape as
// test/tool/check_platform_deep_link_hosting_test.dart: each test writes a
// disposable project.pbxproj-shaped fixture under a temp dir and drives the
// checker at it via `--pbxproj`, so nothing touches this repo's real
// ios/Runner.xcodeproj/project.pbxproj and tests stay hermetic under
// `--concurrency=2`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _key = 'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS';

/// Builds a minimal pbxproj-shaped fixture with three XCBuildConfiguration
/// blocks (Profile, Debug, Release — the same order the real Runner target
/// uses) each carrying the given value for [_key].
String _fixture({
  required String profileValue,
  required String debugValue,
  required String releaseValue,
}) {
  return '''
/* Begin XCBuildConfiguration section */
		249021D3217E4FDB00AE95B9 /* Profile */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				$_key = $profileValue;
				SDKROOT = iphoneos;
			};
			name = Profile;
		};
		97C147031CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				$_key = $debugValue;
				SDKROOT = iphoneos;
			};
			name = Debug;
		};
		97C147041CF9000F007C117D /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				$_key = $releaseValue;
				SDKROOT = iphoneos;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */
''';
}

void main() {
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_ios_asset_symbol_extensions.dart';

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'asset_symbol_extensions_fixture_',
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<ProcessResult> runCheck(String contents) async {
    final pbxprojFile = File('${tempDir.path}/project.pbxproj')
      ..writeAsStringSync(contents);
    return Process.run('dart', [
      'run',
      scriptPath,
      '--pbxproj',
      pbxprojFile.path,
    ], workingDirectory: packageDir);
  }

  group('tool/check_ios_asset_symbol_extensions.dart (AUD-platform-04)', () {
    test(
      'exits 0 on the real (fixed) ios/Runner.xcodeproj/project.pbxproj',
      () async {
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
      },
    );

    test(
      'exits 0 on a well-formed fixture (Debug/Release/Profile all NO)',
      () async {
        final result = await runCheck(
          _fixture(profileValue: 'NO', debugValue: 'NO', releaseValue: 'NO'),
        );
        expect(
          result.exitCode,
          0,
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
      },
    );

    test(
      'exits 0 on a well-formed fixture (Debug/Release/Profile all YES)',
      () async {
        final result = await runCheck(
          _fixture(profileValue: 'YES', debugValue: 'YES', releaseValue: 'YES'),
        );
        expect(result.exitCode, 0);
      },
    );

    test('RED: FAILS on the exact AUD-platform-04 defect shape — Profile=YES, '
        'Debug/Release=AppIcon (invalid, copy-pasted from '
        'ASSETCATALOG_COMPILER_APPICON_NAME)', () async {
      final result = await runCheck(
        _fixture(
          profileValue: 'YES',
          debugValue: 'AppIcon',
          releaseValue: 'AppIcon',
        ),
      );
      expect(
        result.exitCode,
        isNot(0),
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(
        result.stderr.toString(),
        contains('not a valid Xcode boolean value'),
      );
      expect(result.stderr.toString(), contains('diverges across'));
    });

    test(
      'FAILS when all three values are identical but invalid (not YES/NO)',
      () async {
        final result = await runCheck(
          _fixture(
            profileValue: 'AppIcon',
            debugValue: 'AppIcon',
            releaseValue: 'AppIcon',
          ),
        );
        expect(result.exitCode, isNot(0));
        expect(
          result.stderr.toString(),
          contains('not a valid Xcode boolean value'),
        );
        // All three are equal, so no additional divergence violation.
        expect(result.stderr.toString(), isNot(contains('diverges across')));
      },
    );

    test('FAILS when values are all individually valid but diverge '
        '(Profile=YES, Debug=NO, Release=YES)', () async {
      final result = await runCheck(
        _fixture(profileValue: 'YES', debugValue: 'NO', releaseValue: 'YES'),
      );
      expect(result.exitCode, isNot(0));
      expect(result.stderr.toString(), contains('diverges across'));
      expect(
        result.stderr.toString(),
        isNot(contains('not a valid Xcode boolean value')),
      );
    });

    test('exits 2 when the pbxproj file does not exist', () async {
      final result = await Process.run('dart', [
        'run',
        scriptPath,
        '--pbxproj',
        '${tempDir.path}/does_not_exist.pbxproj',
      ], workingDirectory: packageDir);
      expect(result.exitCode, 2);
    });
  });
}
