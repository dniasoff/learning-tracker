import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/widgets/app_dialog.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';
import 'package:learning_tracker/features/settings/presentation/providers/data_export_import_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Cloud backup controls for the Settings screen and Parent Settings hero.
///
/// Local-born accounts keep the existing local-only message. Cloud-born
/// accounts receive explicit export/import controls backed by the versioned
/// Firestore backup service.
class BackupSyncSection extends ConsumerStatefulWidget {
  const BackupSyncSection({super.key, this.parentSettingsHeroLayout = false});

  final bool parentSettingsHeroLayout;

  @override
  ConsumerState<BackupSyncSection> createState() => _BackupSyncSectionState();
}

class _BackupSyncSectionState extends ConsumerState<BackupSyncSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    if (!authState.isCloudBorn) {
      return _buildLocalOnlyCard(context);
    }

    final serviceAsync = ref.watch(dataExportImportServiceProvider);
    return _buildCloudCard(context, serviceAsync);
  }

  Widget _buildCloudCard(
    BuildContext context,
    AsyncValue<DataExportImportService?> serviceAsync,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(
      widget.parentSettingsHeroLayout ? 24 : 16,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B3FB4),
        borderRadius: radius,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.parentSettingsHeroLayout ? 20 : 16,
          widget.parentSettingsHeroLayout ? 22 : 18,
          widget.parentSettingsHeroLayout ? 20 : 16,
          18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.backupSyncCardTitle,
              textAlign: widget.parentSettingsHeroLayout
                  ? TextAlign.center
                  : TextAlign.start,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.backupSyncStatusUnavailable,
              textAlign: widget.parentSettingsHeroLayout
                  ? TextAlign.center
                  : TextAlign.start,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            serviceAsync.when(
              loading: () => _buildLoadingState(context),
              error: (error, stackTrace) =>
                  _buildErrorState(context, error, stackTrace),
              data: (service) => service == null
                  ? Text(
                      l10n.backupDataUnavailable,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    )
                  : _buildActions(context, service),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.backupDataLoading,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 320,
            child: AppErrorView(error: error, stackTrace: stackTrace),
          ),
          TextButton.icon(
            onPressed: () => ref.invalidate(dataExportImportServiceProvider),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.actionRetry),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, DataExportImportService service) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _export(service),
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.ios_share_outlined),
          label: Text(l10n.backupExportAction),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70),
          ),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : () => _startImport(service),
          icon: const Icon(Icons.restore_outlined),
          label: Text(l10n.backupImportAction),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0B3FB4),
          ),
        ),
      ],
    );
  }

  Future<void> _export(DataExportImportService service) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final json = await service.exportData();
      await ref.read(backupFileDeliveryProvider).share(json);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.backupExportSuccess)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.backupExportError)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startImport(DataExportImportService service) async {
    final json = await _showPasteDialog();
    if (!mounted || json == null || json.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    late final ImportPreview preview;
    try {
      preview = service.validateAndPreview(json);
    } catch (_) {
      _showMessage(l10n.backupImportInvalid);
      return;
    }

    if (!mounted) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.backupImportPreviewTitle,
      message: l10n.backupImportPreviewBody(
        preview.totalDocumentCount,
        preview.userProfileCount,
        preview.exportedAt,
      ),
      confirmLabel: l10n.backupImportConfirm,
      icon: Icons.warning_amber_rounded,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await service.importData(json);
      if (mounted) _showMessage(l10n.backupImportSuccess);
    } catch (_) {
      if (mounted) _showMessage(l10n.backupImportError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _showPasteDialog() {
    return showAppDialog<String>(
      context: context,
      // The dialog body owns its controller so it remains alive until the
      // route has removed the field from the tree.
      builder: (context) => const _BackupPasteDialogBody(),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildLocalOnlyCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = Text(
      l10n.backupSyncCardTitle,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 22,
      ),
    );
    final body = Text(
      l10n.backupSyncCardBody,
      textAlign: widget.parentSettingsHeroLayout
          ? TextAlign.center
          : TextAlign.start,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.88),
        height: 1.35,
        fontWeight: FontWeight.w600,
        fontSize: 17,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B3FB4),
        borderRadius: BorderRadius.circular(
          widget.parentSettingsHeroLayout ? 24 : 16,
        ),
        boxShadow: widget.parentSettingsHeroLayout
            ? const [
                BoxShadow(
                  color: Color(0x30053698),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: widget.parentSettingsHeroLayout
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.cloud_upload_outlined,
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  Center(child: title),
                  const SizedBox(height: 10),
                  body,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Flexible(child: title),
                    ],
                  ),
                  const SizedBox(height: 10),
                  body,
                ],
              ),
      ),
    );
  }
}

class _BackupPasteDialogBody extends StatefulWidget {
  const _BackupPasteDialogBody();

  @override
  State<_BackupPasteDialogBody> createState() => _BackupPasteDialogBodyState();
}

class _BackupPasteDialogBodyState extends State<_BackupPasteDialogBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.backupImportPasteTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(l10n.backupImportPasteBody, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 8,
          maxLines: 14,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: l10n.backupImportPasteLabel,
            hintText: l10n.backupImportPasteHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.backupImportPreviewAction),
        ),
      ],
    );
  }
}
