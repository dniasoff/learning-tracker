/// The lifetime report's PDF export state (Story 5.4, DNI-519; AD-48,
/// UX-DR-145).
///
/// [lifetimeReportExportServiceProvider] wires the export service to the
/// app: the parent-session gate ([parentSessionProvider], fail closed),
/// the active learner each export is bound to ([lifetimeReportExportScope]),
/// the bundled fonts, the temporary file store and the `share_plus` share
/// sheet. Tests override it.
///
/// [lifetimeReportExportProvider] is the Export PDF pill's state: busy
/// while one export runs, which disables the pill so a second tap cannot
/// start a concurrent export (AC-7).
///
/// Plain Riverpod providers (no codegen), matching the C0 provider style.
library;

import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_document.dart';
import 'package:learning_tracker/features/progress/presentation/services/lifetime_report_export_service.dart';

/// The learner an export is bound to: the active learner scope (whose
/// state the report is projected from) and the active profile (whose name
/// the PDF and its file name carry).
typedef LifetimeReportExportScope = ({LearnerScope learner, String profileId});

/// The export identity of the active learner, from [activeLearnerScopeProvider]
/// ([learner]) and [activeProfileProvider] ([profile]); null while either is
/// loading, re-resolving after a switch, failed or absent (fail closed).
LifetimeReportExportScope? lifetimeReportExportScope(
  AsyncValue<LearnerScope?> learner,
  AsyncValue<LearnerProfileEntity?> profile,
) {
  if (learner.isLoading || learner.hasError) return null;
  if (profile.isLoading || profile.hasError) return null;
  final scope = learner.value;
  final profileId = profile.value?.profileId;
  if (scope == null || profileId == null) return null;
  return (learner: scope, profileId: profileId);
}

/// The export service of the running app.
final lifetimeReportExportServiceProvider =
    Provider.autoDispose<LifetimeReportExportService>((ref) {
      // The session is read fresh at each check; the report screen keeps
      // it alive while it is open.
      return LifetimeReportExportService(
        isParentSession: () async {
          final access = ref.read(parentSessionProvider);
          // Fail closed: a session still resolving, or re-resolving after
          // a PIN, profile or tutor change, is not a parent's (AC-12).
          return !access.isLoading && !access.hasError && access.value == true;
        },
        // Read fresh at each check, so a profile switch during an export
        // is seen before the file is shared.
        currentScope: () => lifetimeReportExportScope(
          ref.read(activeLearnerScopeProvider),
          ref.read(activeProfileProvider),
        ),
        fonts: AssetLifetimeReportPdfFontSource(rootBundle),
        files: TemporaryReportPdfFileStore(),
        sharer: const SharePlusLifetimeReportPdfSharer(),
      );
    });

/// How one export ended.
enum LifetimeReportExportResult {
  /// The share sheet opened and a target was picked (or the platform does
  /// not say).
  shared,

  /// The share sheet was dismissed: back to the report, no message.
  dismissed,

  /// Generation, the file write or the share failed: the report shows the
  /// failure snackbar with Retry (AC-9).
  failed,

  /// Outside a parent session: nothing was generated (AC-12).
  denied,

  /// The active learner changed while the export ran: nothing was shared
  /// and no file was kept; the screen has already moved to the new learner.
  superseded,

  /// Another export was already running; this one did not start.
  ignored,
}

/// The Export PDF pill's state: true while an export runs.
final lifetimeReportExportProvider =
    NotifierProvider.autoDispose<LifetimeReportExportController, bool>(
      LifetimeReportExportController.new,
    );

/// Runs exports one at a time and reports how each ended.
class LifetimeReportExportController extends Notifier<bool> {
  late LifetimeReportExportService _service;

  @override
  bool build() {
    // Watched, so the service lives as long as this state does, through
    // the whole of a running export.
    _service = ref.watch(lifetimeReportExportServiceProvider);
    return false;
  }

  /// Whether an export is running.
  bool get busy => state;

  /// Exports [document] as [fileName], with the share sheet anchored at
  /// [origin], bound to the learner [scope] (see
  /// [LifetimeReportExportService.export]). Returns
  /// [LifetimeReportExportResult.ignored] without doing anything while
  /// another export runs.
  Future<LifetimeReportExportResult> export({
    required LifetimeReportPdfDocument document,
    required String fileName,
    Rect? origin,
    Object? scope,
  }) async {
    if (state) return LifetimeReportExportResult.ignored;
    state = true;
    try {
      final outcome = await _service.export(
        document: document,
        fileName: fileName,
        origin: origin,
        scope: scope,
      );
      return outcome == LifetimeReportShareOutcome.dismissed
          ? LifetimeReportExportResult.dismissed
          : LifetimeReportExportResult.shared;
    } on LifetimeReportExportDenied {
      return LifetimeReportExportResult.denied;
    } on LifetimeReportExportSuperseded {
      return LifetimeReportExportResult.superseded;
    } on Object catch (e, st) {
      AppLogger.instance.warning(
        event: 'lifetime_report_export_failed',
        exception: e is LifetimeReportExportFailed ? e.cause : e,
        stackTrace: st,
      );
      return LifetimeReportExportResult.failed;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}
