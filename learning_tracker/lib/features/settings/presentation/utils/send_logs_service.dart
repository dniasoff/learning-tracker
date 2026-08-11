import 'package:flutter/material.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/settings/data/repositories/firestore_diagnostic_log_repository_impl.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _logWindowMinutes = 10;

/// Uploads the last [_logWindowMinutes] minutes of log history to
/// `users/{uid}/diagnostic_logs/{autoId}` in Firestore via
/// [FirestoreDiagnosticLogRepositoryAdapter]. Replaces
/// `FirestoreGatewayImpl.pushDiagnosticLog` (archived with the rest of the
/// Drift sync engine).
///
/// The developer can view and query logs directly in the Firebase console.
/// Each document expires after 7 days (set `expires_at` as Firestore TTL
/// field to enable automatic cleanup).
Future<void> sendLogsToFirebase({
  required BuildContext context,
  required AppLogger logger,
  required FirestoreDiagnosticLogRepositoryAdapter repository,
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
    await repository.pushLog({
      'version': pkgInfo != null
          ? '${pkgInfo.version}+${pkgInfo.buildNumber}'
          : 'unknown',
      'window_minutes': _logWindowMinutes,
      'entry_count': entries.length,
      'entries': entries,
      // TTL field — enable automatic deletion in Firebase console:
      // Firestore → Data → TTL policies → collection: diagnostic_logs, field: expires_at
      'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.sendLogsSuccess(entries.length),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } on DiagnosticLogRepositoryNotReadyException catch (e, stackTrace) {
    logger.error(
      event: 'send_logs_failed_not_ready',
      exception: e,
      stackTrace: stackTrace,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSendLogsNoGateway),
        ),
      );
    }
  } catch (e, stackTrace) {
    // EH-5/ST-4: never surface the raw exception's toString() in the UI —
    // log it for diagnostics and show only the fixed, localized fallback
    // copy instead.
    logger.error(
      event: 'send_logs_failed',
      exception: e,
      stackTrace: stackTrace,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSendLogsFailed),
        ),
      );
    }
  }
}
