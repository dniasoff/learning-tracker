import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_report_sections.dart';
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
/// (AC-10). Per-source pace and *Export PDF* arrive with Story 5.3.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final access = ref.watch(parentSessionProvider);
    final allowed = access.value == true && !access.hasError;
    final Widget body;
    if (!allowed) {
      // Loading the session, or leaving: nothing of the report is built.
      body = access.isLoading && !_leaving
          ? const LoadingIndicator()
          : const SizedBox.shrink();
    } else {
      final report = ref.watch(lifetimeReportProvider(_curriculumId));
      body = report.when(
        data: (view) => _ReportBody(
          view: view,
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
    );
  }
}

/// The report content, laid out for the window size (UX-DR-162,
/// UX-DR-164): one column on a phone, a centered column at 600–839 dp and
/// a two-pane composition from 840 dp (mockup #14 tablet).
class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.view, required this.onCurriculum});

  final LifetimeReportView view;
  final ValueChanged<String> onCurriculum;

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
