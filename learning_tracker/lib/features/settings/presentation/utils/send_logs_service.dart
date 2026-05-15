import 'package:flutter/material.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _logWindowMinutes = 10;

/// Uploads the last [_logWindowMinutes] minutes of log history to
/// `users/{uid}/diagnostic_logs/{auto-id}` in Firestore via [FirestoreGateway].
///
/// The developer can view and query logs directly in the Firebase console.
/// Each document expires after 7 days (set `expires_at` as Firestore TTL
/// field to enable automatic cleanup).
Future<void> sendLogsToFirebase({
  required BuildContext context,
  required AppLogger logger,
  required FirestoreGateway? gateway,
  required AuthRepository auth,
}) async {
  final uid = auth.currentUser?.uid;
  if (uid == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.errorSendLogsMustBeSignedIn,
          ),
        ),
      );
    }
    return;
  }

  if (gateway == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync not available — not signed in.')),
      );
    }
    return;
  }

  final now = DateTimeFactory.nowUtc();
  final cutoff = now.subtract(const Duration(minutes: _logWindowMinutes));
  final recent = logger.talker.history
      .where((e) => e.time.isAfter(cutoff))
      .toList();

  PackageInfo? pkgInfo;
  try {
    pkgInfo = await PackageInfo.fromPlatform();
  } catch (_) {
    // no-op: PackageInfo failure is non-fatal; log upload proceeds without version metadata
  }

  final entries = recent
      .map(
        (e) => <String, dynamic>{
          'ts': e.time.toIso8601String(),
          'lvl': (e.logLevel?.name ?? e.title ?? 'log').toUpperCase(),
          'msg': e.message ?? '',
          if (e.exception != null) 'exc': e.exception.toString(),
          if (e.error != null) 'err': e.error.toString(),
        },
      )
      .toList();

  try {
    await gateway.pushDiagnosticLog(
      uid: uid,
      data: {
        'version': pkgInfo != null
            ? '${pkgInfo.version}+${pkgInfo.buildNumber}'
            : 'unknown',
        'window_minutes': _logWindowMinutes,
        'entry_count': entries.length,
        'entries': entries,
        // TTL field — enable automatic deletion in Firebase console:
        // Firestore → Data → TTL policies → collection: diagnostic_logs, field: expires_at
        'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
      },
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logs sent (${entries.length} entries). '
            'View in Firebase console → diagnostic_logs.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.errorSendLogsFailed(e.toString()),
          ),
        ),
      );
    }
  }
}
