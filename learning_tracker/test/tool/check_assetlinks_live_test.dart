// Tests for `tool/check_assetlinks_live.sh` (AUD-platform-01, acceptance
// criterion 1).
//
// The script hits a live URL by default, so hermetic tests point it at a
// disposable local HTTP server (via `--url`) instead of the real
// production host — same isolation shape as
// test/tool/check_gitkeep_stray_test.dart's disposable temp-repo pattern,
// adapted for a network checker rather than a git-tree checker.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _expectedPackage = 'com.jcom.torah.learning_tracker';
const _validFingerprint =
    '14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5';

Future<HttpServer> _serve(String? body, {int statusCode = 200}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.statusCode = statusCode;
    if (body != null) {
      request.response.headers.contentType = ContentType.json;
      request.response.write(body);
    }
    await request.response.close();
  });
  return server;
}

String _assetlinksJson({
  String package = _expectedPackage,
  List<String> fingerprints = const [_validFingerprint],
}) => jsonEncode([
  {
    'relation': ['delegate_permission/common.handle_all_urls'],
    'target': {
      'namespace': 'android_app',
      'package_name': package,
      'sha256_cert_fingerprints': fingerprints,
    },
  },
]);

void main() {
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_assetlinks_live.sh';

  setUpAll(() {
    expect(
      File(scriptPath).existsSync(),
      isTrue,
      reason: 'tool/check_assetlinks_live.sh must exist',
    );
  });

  Future<ProcessResult> runCheck(String url, {String? expectedPackage}) =>
      Process.run('bash', [
        scriptPath,
        '--url',
        url,
        if (expectedPackage != null) ...['--expected-package', expectedPackage],
      ]);

  group('tool/check_assetlinks_live.sh (AUD-platform-01 AC1)', () {
    test('PASSES (exit 0) when the URL returns 200 with a matching '
        'package_name and a non-empty sha256_cert_fingerprints array', () async {
      final server = await _serve(_assetlinksJson());
      try {
        final url =
            'http://${server.address.address}:${server.port}/.well-known/assetlinks.json';
        final result = await runCheck(url);
        expect(
          result.exitCode,
          0,
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(result.stdout.toString(), contains('PASSED'));
      } finally {
        await server.close(force: true);
      }
    });

    test('RED: FAILS (nonzero exit) when the URL 404s — this is the exact '
        'live state of https://torah-study-tracker.firebaseapp.com/'
        '.well-known/assetlinks.json today (AUD-platform-01 evidence)', () async {
      final server = await _serve(null, statusCode: 404);
      try {
        final url =
            'http://${server.address.address}:${server.port}/.well-known/assetlinks.json';
        final result = await runCheck(url);
        expect(
          result.exitCode,
          isNot(0),
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(result.stderr.toString(), contains('FAILED'));
        expect(result.stderr.toString(), contains('404'));
      } finally {
        await server.close(force: true);
      }
    });

    test('FAILS when the response is 200 but the package_name does not match '
        '(catches a mis-registered / wrong-app fingerprint deploy)', () async {
      final server = await _serve(
        _assetlinksJson(package: 'com.example.wrong'),
      );
      try {
        final url =
            'http://${server.address.address}:${server.port}/.well-known/assetlinks.json';
        final result = await runCheck(url);
        expect(result.exitCode, isNot(0));
        expect(result.stderr.toString(), contains('FAILED'));
      } finally {
        await server.close(force: true);
      }
    });

    test('FAILS when sha256_cert_fingerprints is present but empty (Android '
        'App Links verification cannot succeed with no fingerprint)', () async {
      final server = await _serve(_assetlinksJson(fingerprints: const []));
      try {
        final url =
            'http://${server.address.address}:${server.port}/.well-known/assetlinks.json';
        final result = await runCheck(url);
        expect(result.exitCode, isNot(0));
      } finally {
        await server.close(force: true);
      }
    });

    test('FAILS when the response body is not valid JSON', () async {
      final server = await _serve('not json');
      try {
        final url =
            'http://${server.address.address}:${server.port}/.well-known/assetlinks.json';
        final result = await runCheck(url);
        expect(result.exitCode, isNot(0));
        expect(result.stderr.toString(), contains('not valid JSON'));
      } finally {
        await server.close(force: true);
      }
    });
  });
}
