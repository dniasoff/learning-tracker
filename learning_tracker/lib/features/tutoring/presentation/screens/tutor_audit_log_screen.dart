// TutorAuditLogScreen — W6.13
//
// Parent-side audit log viewer for a specific tutor grant.
// Shows a scrollable list of audit entries, filterable by:
//   - Tutor (shows name snapshot)
//   - Action type (chips for each TutorAuditAction)
//   - Date range (start/end date picker)
//
// Read-only — parents cannot modify entries.
// Wired to TutorAuditLogRepository (read path only).

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_audit_log_entry.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/audit_log_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class TutorAuditLogScreen extends ConsumerStatefulWidget {
  const TutorAuditLogScreen({
    super.key,
    required this.grantId,
    required this.tutorEmail,
  });

  /// The grant whose audit log to display.
  final String grantId;

  /// Tutor email shown in the app bar.
  final String tutorEmail;

  @override
  ConsumerState<TutorAuditLogScreen> createState() =>
      _TutorAuditLogScreenState();
}

class _TutorAuditLogScreenState extends ConsumerState<TutorAuditLogScreen> {
  // ── Filter state ──────────────────────────────────────────────────────────

  /// When non-null, show only entries with this action type.
  TutorAuditAction? _filterAction;

  /// When non-null, show only entries on or after this date.
  DateTime? _filterFrom;

  /// When non-null, show only entries on or before this date.
  DateTime? _filterTo;

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<TutorAuditLogEntry> _applyFilters(List<TutorAuditLogEntry> entries) {
    return entries.where((entry) {
      if (_filterAction != null && entry.action != _filterAction) return false;
      if (_filterFrom != null && entry.timestamp.isBefore(_filterFrom!)) {
        return false;
      }
      if (_filterTo != null) {
        final endOfDay = DateTime(
          _filterTo!.year,
          _filterTo!.month,
          _filterTo!.day,
          23,
          59,
          59,
        );
        if (entry.timestamp.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();
  }

  // ── Date picker helpers ───────────────────────────────────────────────────

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterFrom ?? DateTimeFactory.nowLocal(),
      firstDate: DateTime(2020),
      lastDate: _filterTo ?? DateTimeFactory.nowLocal(),
      helpText: AppLocalizations.of(context)!.auditLogFilterFromDate,
    );
    if (picked != null) setState(() => _filterFrom = picked);
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterTo ?? DateTimeFactory.nowLocal(),
      firstDate: _filterFrom ?? DateTime(2020),
      lastDate: DateTimeFactory.nowLocal(),
      helpText: AppLocalizations.of(context)!.auditLogFilterToDate,
    );
    if (picked != null) setState(() => _filterTo = picked);
  }

  void _clearFilters() {
    setState(() {
      _filterAction = null;
      _filterFrom = null;
      _filterTo = null;
    });
  }

  bool get _hasActiveFilters =>
      _filterAction != null || _filterFrom != null || _filterTo != null;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(tutorAuditLogProvider(widget.grantId));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.auditLogTitle, style: const TextStyle(fontSize: 16)),
            Text(
              widget.tutorEmail,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded),
              tooltip: l10n.auditLogClearFilters,
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            selectedAction: _filterAction,
            filterFrom: _filterFrom,
            filterTo: _filterTo,
            onActionChanged: (action) => setState(() => _filterAction = action),
            onPickFrom: _pickFromDate,
            onPickTo: _pickToDate,
          ),
          const Divider(height: 1),
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => AppErrorView(
                error: e,
                stackTrace: st,
                onRetry: () =>
                    ref.refresh(tutorAuditLogProvider(widget.grantId)),
              ),
              data: (entries) {
                final filtered = _applyFilters(entries);
                if (filtered.isEmpty) {
                  return _EmptyLogView(
                    hasFilters: _hasActiveFilters,
                    theme: theme,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) =>
                      _AuditEntryTile(entry: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedAction,
    required this.filterFrom,
    required this.filterTo,
    required this.onActionChanged,
    required this.onPickFrom,
    required this.onPickTo,
  });

  final TutorAuditAction? selectedAction;
  final DateTime? filterFrom;
  final DateTime? filterTo;
  final ValueChanged<TutorAuditAction?> onActionChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Action filter chips
          for (final action in TutorAuditAction.values) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: FilterChip(
                label: Text(
                  _actionLabel(l10n, action),
                  style: const TextStyle(fontSize: 12),
                ),
                selected: selectedAction == action,
                onSelected: (selected) =>
                    onActionChanged(selected ? action : null),
                selectedColor: AppTheme.brandBlue.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.brandBlue,
                labelStyle: TextStyle(
                  color: selectedAction == action
                      ? AppTheme.brandBlue
                      : theme.colorScheme.onSurface,
                ),
                side: BorderSide(
                  color: selectedAction == action
                      ? AppTheme.brandBlue
                      : theme.colorScheme.outline.withValues(alpha: 0.4),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ],
          // Date range chips
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.calendar_today_rounded, size: 14),
            label: Text(
              filterFrom != null
                  ? '${filterFrom!.day}/${filterFrom!.month}/${filterFrom!.year}'
                  : l10n.auditLogFilterFrom,
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: onPickFrom,
            backgroundColor: filterFrom != null
                ? AppTheme.brandBlue.withValues(alpha: 0.1)
                : null,
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.calendar_today_rounded, size: 14),
            label: Text(
              filterTo != null
                  ? '${filterTo!.day}/${filterTo!.month}/${filterTo!.year}'
                  : l10n.auditLogFilterTo,
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: onPickTo,
            backgroundColor: filterTo != null
                ? AppTheme.brandBlue.withValues(alpha: 0.1)
                : null,
          ),
        ],
      ),
    );
  }

  String _actionLabel(AppLocalizations l10n, TutorAuditAction action) =>
      switch (action) {
        TutorAuditAction.configChanged => l10n.auditLogChipConfig,
        TutorAuditAction.completionBulkPrior => l10n.auditLogChipBulkPrior,
        TutorAuditAction.completionReset => l10n.auditLogChipReset,
        TutorAuditAction.bookmarkAdvanced => l10n.auditLogChipBookmark,
        TutorAuditAction.profileEdited => l10n.auditLogChipProfile,
        TutorAuditAction.goalChanged => l10n.auditLogChipGoal,
        TutorAuditAction.stageChanged => l10n.auditLogChipStage,
        TutorAuditAction.rewardChanged => l10n.auditLogChipReward,
        TutorAuditAction.studyDayChanged => l10n.auditLogChipStudyDay,
      };
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyLogView extends StatelessWidget {
  const _EmptyLogView({required this.hasFilters, required this.theme});

  final bool hasFilters;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilters ? Icons.filter_alt_off_rounded : Icons.history_rounded,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? l10n.auditLogEmptyFiltered : l10n.auditLogEmpty,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? l10n.auditLogEmptyFilteredBody
                  : l10n.auditLogEmptyBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Audit entry tile ──────────────────────────────────────────────────────────

class _AuditEntryTile extends StatelessWidget {
  const _AuditEntryTile({required this.entry});

  final TutorAuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final actionColor = _actionColor(entry.action);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action indicator circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _actionIcon(entry.action),
              color: actionColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action + tutor name
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: actionColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _actionLabel(l10n, entry.action),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: actionColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.tutorNameSnapshot,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Target
                Text(
                  entry.target,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Before/after values if present
                if (entry.beforeValue != null || entry.afterValue != null) ...[
                  const SizedBox(height: 4),
                  _BeforeAfterRow(
                    before: entry.beforeValue,
                    after: entry.afterValue,
                    theme: theme,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Timestamp
          Text(
            _formatTimestamp(entry.timestamp),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Color _actionColor(TutorAuditAction action) => switch (action) {
    TutorAuditAction.configChanged => Colors.blue.shade600,
    TutorAuditAction.completionBulkPrior => Colors.green.shade600,
    TutorAuditAction.completionReset => Colors.orange.shade700,
    TutorAuditAction.bookmarkAdvanced => Colors.purple.shade600,
    TutorAuditAction.profileEdited => Colors.teal.shade600,
    TutorAuditAction.goalChanged => Colors.indigo.shade600,
    TutorAuditAction.stageChanged => Colors.cyan.shade700,
    TutorAuditAction.rewardChanged => Colors.amber.shade700,
    TutorAuditAction.studyDayChanged => Colors.deepOrange.shade600,
  };

  IconData _actionIcon(TutorAuditAction action) => switch (action) {
    TutorAuditAction.configChanged => Icons.settings_rounded,
    TutorAuditAction.completionBulkPrior => Icons.playlist_add_check_rounded,
    TutorAuditAction.completionReset => Icons.restart_alt_rounded,
    TutorAuditAction.bookmarkAdvanced => Icons.bookmark_added_rounded,
    TutorAuditAction.profileEdited => Icons.person_outline_rounded,
    TutorAuditAction.goalChanged => Icons.flag_rounded,
    TutorAuditAction.stageChanged => Icons.layers_rounded,
    TutorAuditAction.rewardChanged => Icons.card_giftcard_rounded,
    TutorAuditAction.studyDayChanged => Icons.calendar_month_rounded,
  };

  String _actionLabel(AppLocalizations l10n, TutorAuditAction action) =>
      switch (action) {
        TutorAuditAction.configChanged => l10n.auditLogActionConfigChanged,
        TutorAuditAction.completionBulkPrior => l10n.auditLogActionBulkPrior,
        TutorAuditAction.completionReset => l10n.auditLogActionReset,
        TutorAuditAction.bookmarkAdvanced => l10n.auditLogActionBookmark,
        TutorAuditAction.profileEdited => l10n.auditLogActionProfileEdited,
        TutorAuditAction.goalChanged => l10n.auditLogActionGoalChanged,
        TutorAuditAction.stageChanged => l10n.auditLogActionStageChanged,
        TutorAuditAction.rewardChanged => l10n.auditLogActionRewardChanged,
        TutorAuditAction.studyDayChanged => l10n.auditLogActionStudyDay,
      };

  String _formatTimestamp(DateTime dt) {
    final now = DateTimeFactory.nowLocal();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(dt.year, dt.month, dt.day);
    final pad2 = (int v) => v.toString().padLeft(2, '0');

    if (entryDate == today) {
      return '${pad2(dt.hour)}:${pad2(dt.minute)}';
    }
    return '${dt.day}/${dt.month}\n${pad2(dt.hour)}:${pad2(dt.minute)}';
  }
}

class _BeforeAfterRow extends StatelessWidget {
  const _BeforeAfterRow({
    required this.before,
    required this.after,
    required this.theme,
  });

  final String? before;
  final String? after;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 11,
    );
    return Wrap(
      spacing: 8,
      children: [
        if (before != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: l10n.auditLogBefore,
                  style: style?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: before,
                  style: style?.copyWith(color: theme.colorScheme.error),
                ),
              ],
            ),
          ),
        if (after != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: l10n.auditLogAfter,
                  style: style?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: after,
                  style: style?.copyWith(color: Colors.green.shade700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
