// Decompresses assets/db/content.db.xz (source-of-truth in the repo,
// committed at ~62 MB) and re-compresses it as assets/db/content.db.gz
// (gitignored, bundled into the APK). Runtime [SeedManager] decodes
// gzip via dart:io's native zlib — fast and isolate-free.
//
// Run before `flutter build`:
//   dart run tool/prepare_asset.dart
//
// CI runs this in the deploy workflow before the APK build.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _xzPath = 'assets/db/content.db.xz';
const _gzPath = 'assets/db/content.db.gz';

Future<void> main() async {
  final src = File(_xzPath);
  if (!src.existsSync()) {
    stderr.writeln(
      '$_xzPath not found. The committed seed asset is missing — '
      'run tool/seed_content_db.dart to regenerate (needs Mongo + '
      'Sefaria-Project venv).',
    );
    exit(1);
  }

  final sw = Stopwatch()..start();
  stdout.writeln('Decompressing $_xzPath…');

  // Use the system xz binary — every Linux/macOS CI runner has it,
  // and it's an order of magnitude faster than the pure-Dart decoder.
  final decoded = Process.runSync(
    'xz',
    ['-dc', src.path],
    stdoutEncoding: null,
    stderrEncoding: utf8,
  );
  if (decoded.exitCode != 0) {
    stderr.writeln('xz failed: ${decoded.stderr}');
    exit(2);
  }
  final raw = decoded.stdout as List<int>;
  stdout.writeln(
    '  decoded: ${(raw.length / 1024 / 1024).toStringAsFixed(1)} MB '
    'in ${sw.elapsed.inSeconds}s',
  );

  stdout.writeln('Re-compressing as gzip (-9)…');
  final compressed = GZipCodec(level: 9).encode(raw);
  if (File(_gzPath).existsSync()) File(_gzPath).deleteSync();
  File(_gzPath).writeAsBytesSync(compressed, flush: true);

  final mb = compressed.length / 1024 / 1024;
  stdout.writeln(
    '✓ wrote $_gzPath  ${mb.toStringAsFixed(1)} MB '
    'in ${sw.elapsed.inSeconds}s',
  );
}
