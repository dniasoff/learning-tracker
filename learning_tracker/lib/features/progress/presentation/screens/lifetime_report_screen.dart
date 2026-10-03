import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_export_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/providers/pace_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/providers/per_source_pace_report_provider.dart';
import 'package:learning_tracker/features/progress/presentation/services/lifetime_report_export_service.dart';
import 'package:learning_tracker/features/progress/presentation/services/lifetime_report_pdf_composer.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_report_sections.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/on_track_report_block.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/per_source_pace_section.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The lifetime report (Story 5.2, DNI-517; screen #14, FR-31).
///
/// A parent surface (UX-DR-153) under Progress → Lifetime → Report: the
/// route guard refuses child and tutor sessions, and this screen also
/// leaves for Lifetime the moment the session stops being a parent's (a
/// PIN lock, a profile switch), never showing report data outside one
/// (AC-2).
///
/// It renders one curriculum's [LifetimeReportView]: the Distinct and
/// Learning events totals, By source and School years (AC-1). Every value
/// is the engine projection's (AD-48). While the learner state is still
/// paging it shows [LoadingIndicator], never partial totals; a failed
/// read shows [AppErrorView] with a retry of the whole input chain
/// (AC-10).
///
/// Story 5.3 (DNI-518) adds, after the totals, the On-track block and the
/// Per-source pace section of an evaluated curriculum
/// ([perSourcePaceReportProvider]); a retired or archived curriculum keeps
/// only its lifetime totals (AC-9). Both are built only inside the parent
/// session this screen already requires (AC-10).
///
/// Story 5.4 (DNI-519) adds the primary *Export PDF* pill (UX-DR-43) at
/// the foot of the screen, for a parent session only (AC-12). It is
/// disabled until the report's inputs are complete (AC-10) and while an
/// export runs (AC-7), and stays enabled for a report with no counted
/// events (AC-1). It exports exactly the views on screen
/// ([composeLifetimeReportPdf]) and anchors the share sheet to itself
/// (AC-8); a failed export keeps the report open with a Retry snackbar
/// (AC-9, UX-DR-145).
@RoutePage()
class LifetimeReportScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [curriculumId] (a storage key); null picks
  /// the first curriculum with learning.
  const LifetimeReportScreen({
    super.key,
    @QueryParam('curriculum') this.curriculumId,
  });

  /// The curriculum in view when the report was opened.
  final String? curriculumId;

  @override
  ConsumerState<LifetimeReportScreen> createState() =>
      _LifetimeReportScreenState();
}

class _LifetimeReportScreenState extends ConsumerState<LifetimeReportScreen> {
  late String? _curriculumId = widget.curriculumId;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(parentSessionProvider, (_, next) {
      final denied = next.hasError || (next.hasValue && next.value != true);
      if (denied) _leave();
    }, fireImmediately: true);
    // Another learner (a profile switch that keeps a parent session): the
    // curriculum picked for the previous learner is not carried over.
    ref.listenManual(activeLearnerScopeProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if (before != null && after != null && before != after) {
        setState(() => _curriculumId = widget.curriculumId);
      }
    });
  }

  /// Back to Lifetime: pop to it when it is below, else replace this
  /// screen with it (a deep link).
  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = context.router;
      if (router.stack.any((r) => r.name == LifetimeKnowledgeRoute.name)) {
        router.popUntilRouteWithName(LifetimeKnowledgeRoute.name);
      } else {
        router.replace(const LifetimeKnowledgeRoute());
      }
    });
  }

  /// The Export PDF pill: its bounds anchor the iPad share sheet.
  final _exportKey = GlobalKey();

  /// Exports the report on screen (AC-2) and opens the share sheet.
  ///
  /// The export is bound to the learner on screen, taken together with the
  /// report: a profile switch while it runs abandons it before the share
  /// sheet opens, never sharing one learner's report from another's screen.
  Future<void> _export() async {
    final report = ref.read(lifetimeReportProvider(_curriculumId));
    final pace = ref.read(perSourcePaceReportProvider(_curriculumId));
    final scope = lifetimeReportExportScope(
      ref.read(activeLearnerScopeProvider),
      ref.read(activeProfileProvider),
    );
    if (report case AsyncData(
      :final value,
    ) when !pace.isLoading && scope != null) {
      final l10n = AppLocalizations.of(context)!;
      final messenger = ScaffoldMessenger.of(context);
      final learner = ref.read(activeProfileProvider).value?.displayName ?? '';
      final today =
          ref.read(activeLearnerStateProvider).value?.today ??
          formatCivilDay(ref.read(localDayClockProvider).nowUtc());
      final document = composeLifetimeReportPdf(
        view: value,
        pace: pace.value,
        l10n: l10n,
        localeTag: Localizations.localeOf(context).toLanguageTag(),
        rtl: Directionality.of(context) == TextDirection.rtl,
        useHebrewTerms: ref.read(effectiveUseHebrewTermsProvider),
        variant: ref.read(currentTransliterationVariantProvider),
        learnerName: learner,
        today: today,
      );
      final fileName = lifetimeReportFileName(
        learner: learner,
        curriculum: value.curriculumId,
        date: today,
      );
      final box = _exportKey.currentContext?.findRenderObject();
      final origin = box is RenderBox && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      final result = await ref
          .read(lifetimeReportExportProvider.notifier)
          .export(
            document: document,
            fileName: fileName,
            origin: origin,
            scope: scope,
          );
      if (!mounted || result != LifetimeReportExportResult.failed) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            key: const ValueKey('lifetimeReportExportError'),
            behavior: SnackBarBehavior.floating,
            content: Text(l10n.reportExportError),
            action: SnackBarAction(label: l10n.retry, onPressed: _export),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final access = ref.watch(parentSessionProvider);
    // Fail closed: a session re-resolving after a PIN, profile or tutor
    // change is not a parent's yet, even with an earlier `true` retained.
    final allowed =
        !access.isLoading && !access.hasError && access.value == true;
    final Widget body;
    Widget? export;
    if (!allowed) {
      // Loading the session, or leaving: nothing of the report is built,
      // and the report provider (auto-dispose) is dropped.
      body = access.isLoading && !_leaving
          ? const LoadingIndicator()
          : const SizedBox.shrink();
    } else {
      final report = ref.watch(lifetimeReportProvider(_curriculumId));
      // The same state as the report: data together with it.
      final pace = ref.watch(perSourcePaceReportProvider(_curriculumId));
      final busy = ref.watch(lifetimeReportExportProvider);
      // The learner's name for the PDF and its file name.
      final profile = ref.watch(activeProfileProvider);
      // AC-10: only a complete report (never a loading or paging one) is
      // exported; AC-1: an empty report is complete too.
      final ready =
          report is AsyncData<LifetimeReportView> &&
          pace is AsyncData &&
          profile.hasValue;
      export = _ExportPill(
        anchorKey: _exportKey,
        enabled: ready && !busy,
        busy: busy,
        onPressed: _export,
      );
      body = report.when(
        data: (view) => _ReportBody(
          view: view,
          pace: pace.value,
          onCurriculum: (id) => setState(() => _curriculumId = id),
        ),
        loading: () => const LoadingIndicator(),
        error: (error, stackTrace) => error is LifetimeReportAccessDenied
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: AppErrorView(
                  error: error,
                  stackTrace: stackTrace,
                  onRetry: () => retryLifetimeReport(ref),
                ),
              ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.brandInk,
        title: Text(l10n.reportTitle),
      ),
      body: body,
      bottomNavigationBar: export,
    );
  }
}

/// The primary *Export PDF* pill (UX-DR-43): full width at the foot of
/// the report, centred and capped on wider windows (UX-DR-162).
class _ExportPill extends StatelessWidget {
  const _ExportPill({
    required this.anchorKey,
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  /// On the button itself: its bounds anchor the iPad share sheet.
  final Key anchorKey;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final label = busy ? l10n.reportExportBusy : l10n.reportExportAction;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SizedBox(
              key: anchorKey,
              width: double.infinity,
              child: Semantics(
                hint: l10n.reportExportSemantics,
                child: FilledButton.icon(
                  key: const ValueKey('lifetimeReportExportPdf'),
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(52),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: enabled ? onPressed : null,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The report content, laid out for the window size (UX-DR-162,
/// UX-DR-164): one column on a phone, a centered column at 600–839 dp and
/// a two-pane composition from 840 dp (mockup #14 tablet).
class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.view,
    required this.onCurriculum,
    this.pace,
  });

  final LifetimeReportView view;
  final ValueChanged<String> onCurriculum;

  /// The Per-source pace and On-track view; null for a curriculum that is
  /// not evaluated (AC-9).
  final PaceReportView? pace;

  @override
  Widget build(BuildContext context) {
    final switcher = _CurriculumSwitcher(view: view, onSelected: onCurriculum);
    final totals = LifetimeReportTotals(view: view);
    // AC-8: with no counted event only the zero totals render.
    final bySource = view.isEmpty ? null : LifetimeReportBySource(view: view);
    // AC-7: no School years section (and no prompt) without sub-tracks.
    final years = view.isEmpty || view.groups.isEmpty
        ? null
        : LifetimeReportSchoolYears(view: view);
    // Story 5.3: evaluated curricula only (AC-9), after the totals; the
    // On-track block above the per-source rows (AC-6).
    final paceView = view.isEmpty ? null : pace;
    final onTrack = switch (paceView?.onTrack) {
      final OnTrackView v => OnTrackReportBlock(
        view: v,
        curriculum: paceView!.curriculum,
      ),
      null => null,
    };
    final paceSection = paceView == null || paceView.rows.isEmpty
        ? null
        : PerSourcePaceSection(view: paceView);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const gap = SizedBox(height: 16);
        final List<Widget> children;
        if (width >= 840) {
          children = [
            switcher,
            gap,
            totals,
            if (onTrack != null || paceSection != null) ...[
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: onTrack ?? const SizedBox.shrink()),
                  const SizedBox(width: 16),
                  Expanded(child: paceSection ?? const SizedBox.shrink()),
                ],
              ),
            ],
            if (bySource != null || years != null) ...[
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: bySource ?? const SizedBox.shrink()),
                  const SizedBox(width: 16),
                  Expanded(child: years ?? const SizedBox.shrink()),
                ],
              ),
            ],
          ];
        } else {
          children = [
            switcher,
            gap,
            totals,
            if (onTrack != null) ...[gap, onTrack],
            if (paceSection != null) ...[gap, paceSection],
            if (bySource != null) ...[gap, bySource],
            if (years != null) ...[gap, years],
          ];
        }
        final maxWidth = width >= 840
            ? 1200.0
            : width >= 600
            ? 720.0
            : double.infinity;
        return SingleChildScrollView(
          key: const ValueKey('lifetimeReportScroll'),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The curriculum picker: one choice chip per curriculum the learner has
/// a report for, retired ones included (AC-9); just the name when there
/// is only one.
class _CurriculumSwitcher extends ConsumerWidget {
  const _CurriculumSwitcher({required this.view, required this.onSelected});

  final LifetimeReportView view;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    String name(String key) {
      final id = CurriculumId.fromStorageKey(key);
      return id == null ? key : curriculumLabelText(ref, curriculum: id);
    }

    if (view.curricula.length <= 1) {
      return Semantics(
        header: true,
        child: Text(
          name(view.curriculumId),
          key: const ValueKey('lifetimeReportCurriculum'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Semantics(
      label: l10n.reportCurriculumLabel,
      container: true,
      child: Wrap(
        key: const ValueKey('lifetimeReportCurriculumPicker'),
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final key in view.curricula)
            ChoiceChip(
              key: ValueKey('lifetimeReportCurriculum-$key'),
              label: Text(name(key)),
              selected: key == view.curriculumId,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) => onSelected(key),
            ),
        ],
      ),
    );
  }
}
