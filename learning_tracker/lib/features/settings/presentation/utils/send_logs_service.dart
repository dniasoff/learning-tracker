import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:talker/talker.dart';
import 'package:url_launcher/url_launcher.dart';

const _devEmail = 'dniasoff@jcom.dev';
const _logWindowMinutes = 10;

/// Collects the last [_logWindowMinutes] minutes of Talker history, formats
/// them as plain text, and opens the system email client addressed to the
/// developer inbox.
///
/// Falls back to a clipboard-copy dialog if the mailto URI cannot be launched
/// (some devices lack an email app).
Future<void> sendLogsToDevEmail(BuildContext context, Talker talker) async {
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(minutes: _logWindowMinutes));

  final recent = talker.history.where((e) => e.time.isAfter(cutoff)).toList();

  PackageInfo? pkgInfo;
  try {
    pkgInfo = await PackageInfo.fromPlatform();
  } catch (_) {}

  final header = [
    '=== Learning Tracker Diagnostic Logs ===',
    'App    : ${pkgInfo != null ? "v${pkgInfo.version}+${pkgInfo.buildNumber}" : "unknown"}',
    'Window : last $_logWindowMinutes minutes (${recent.length} entries)',
    'Captured: ${now.toUtc().toIso8601String()}',
    '',
  ].join('\n');

  final body = StringBuffer(header);
  for (final entry in recent) {
    final t = entry.time;
    final ts =
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
    final level = (entry.logLevel?.name ?? entry.title ?? 'log').toUpperCase();
    body.writeln('[$ts][$level] ${entry.message ?? ""}');
    if (entry.exception != null) body.writeln('  EXC: ${entry.exception}');
    if (entry.error != null) body.writeln('  ERR: ${entry.error}');
  }

  final subject =
      '[Learning Tracker] Diagnostic Logs ${now.toIso8601String().substring(0, 10)}';

  // mailto: bodies are limited on some devices; cap at ~6 KB to be safe.
  var bodyStr = body.toString();
  if (bodyStr.length > 6000) {
    bodyStr =
        '...(truncated, showing most recent)\n\n'
        '${bodyStr.substring(bodyStr.length - 6000)}';
  }

  final uri = Uri(
    scheme: 'mailto',
    path: _devEmail,
    queryParameters: {'subject': subject, 'body': bodyStr},
  );

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else if (context.mounted) {
    // No email app — show a snackbar with instructions
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No email app found. Install an email app and try again.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }
}
