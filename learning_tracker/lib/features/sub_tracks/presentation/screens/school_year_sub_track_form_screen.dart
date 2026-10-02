import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/core/widgets/info_note.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/school_year_sub_track_form_validation.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_goal_setup_flow.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/academic_year_picker.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/no_deadline_note.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_parent_session_hold.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

final _log = AppLogger.instance;

/// The width at and above which the form sits next to a summary panel
/// (UX-DR-162, tablet ≥ 600dp).
const kSubTrackFormTabletBreakpoint = 600.0;

/// The form's maximum width on tablets (UX-DR-162).
const kSubTrackFormMaxWidth = 600.0;

/// The school-year sub-track create / edit form (Story 2.4 / DNI-495,
/// screens.md #05): name, academic year, start and end month, rate in the
/// curriculum's leaf unit, weeks per year, the shabbos switch, the ground
/// note and *Save sub-track*. There is no exclusion checkbox and no
/// bein-hazmanim switch (AC-4).
///
/// Saving calls Story 2.1 `createSubTrack` / `editSubTrack` (only changed
/// fields); the form never writes Firestore itself. The route is behind the
/// parent-session guard, and the form renders nothing for a non-parent
/// session as well (AC-3, defence in depth). A session that ends while the
/// form is open hides it with its values kept ([SubTrackParentSessionHold]),
/// and a save re-checks the session first. It also renders nothing until
/// the Story 2.1 commands are live, and no form until the sub-track and
/// governed-intent reads have loaded (fail closed).
@RoutePage()
class SchoolYearSubTrackFormScreen extends ConsumerWidget {
  const SchoolYearSubTrackFormScreen({
    @PathParam('curriculumId') required this.curriculumId,
    @QueryParam('subTrackId') this.subTrackId,
    super.key,
  });

  /// The curriculum (storage key) the sub-track belongs to.
  final String curriculumId;

  /// The edited sub-track, or null to create one.
  final String? subTrackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final editing = subTrackId != null;
    return Scaffold(
      backgroundColor: context.colors.surfaceF5,
      appBar: AppBar(
        backgroundColor: context.colors.surfaceF5,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          editing
              ? l10n.subTrackFormEditSchoolYearTitle
              : l10n.subTrackTypeSchoolYear,
        ),
      ),
      body: SubTrackParentSessionHold(
        child: _CommandsGate(
          child: _ReadsGate(
            curriculumId: curriculumId,
            builder: (tracks) => _formFor(ref, tracks),
          ),
        ),
      ),
    );
  }

  Widget _formFor(WidgetRef ref, List<SubTrack> tracks) {
    SubTrack? existing;
    if (subTrackId case final id?) {
      // The id must name a school-year row of this route's curriculum: a
      // stale or crafted URL must not edit another curriculum's row (or an
      // ongoing one) against the wrong sibling set.
      existing = tracks
          .where(
            (t) =>
                t.id == id &&
                t.curriculumId == curriculumId &&
                t.type == SubTrackType.schoolYear,
          )
          .firstOrNull;
      if (existing == null) {
        return AppErrorView(
          error: SubTrackNotFoundForFormException(id),
          onRetry: () => ref.invalidate(learnerSubTracksProvider),
        );
      }
    }
    return SchoolYearSubTrackForm(
      key: ValueKey(subTrackId ?? 'new'),
      curriculumId: curriculumId,
      existing: existing,
      subTracks: tracks,
    );
  }
}

/// Renders [child] only while the Story 2.1 commands are live for the
/// learner. The entry point stays inert until they are (ruling: "the
/// sub-track entry point stays inert until 2.1 commands are live"), so a
/// direct route or deep link never opens a form whose save cannot work:
/// unavailable or failed commands render nothing, loading a spinner.
class _CommandsGate extends ConsumerWidget {
  const _CommandsGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = ref.watch(learningCommandsProvider);
    if (commands.value != null) return child;
    if (commands.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return const SizedBox.shrink(key: ValueKey('subTrackFormInert'));
  }
}

/// Builds the form only once both the complete sub-track read and the
/// curriculum's governed intent have loaded: a loading read shows a
/// spinner and an unavailable or failed one the shared [AppErrorView]
/// with retry (fail closed: never a form over unknown siblings or intent).
class _ReadsGate extends ConsumerWidget {
  const _ReadsGate({required this.curriculumId, required this.builder});

  final String curriculumId;
  final Widget Function(List<SubTrack> tracks) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intent = ref.watch(subTrackCurriculumIntentProvider(curriculumId));
    final tracks = ref.watch(learnerSubTracksProvider);
    final failed = intent.hasError ? intent : (tracks.hasError ? tracks : null);
    if (failed != null) {
      return AppErrorView(
        error: failed.error!,
        stackTrace: failed.stackTrace,
        onRetry: () {
          ref
            ..invalidate(subTrackCurriculumIntentProvider(curriculumId))
            ..invalidate(learnerSubTracksProvider);
        },
      );
    }
    final all = tracks.value;
    if (intent.value == null || all == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return builder(all);
  }
}

/// The edited sub-track is not a school-year row of the route's curriculum
/// in the learner's complete sub-track read.
final class SubTrackNotFoundForFormException implements Exception {
  /// Creates the exception.
  const SubTrackNotFoundForFormException(this.subTrackId);

  /// The missing sub-track id.
  final String subTrackId;

  @override
  String toString() => 'SubTrackNotFoundForFormException: $subTrackId';
}

/// The form body: fields, validation and save. [subTracks] is the learner's
/// complete sub-track read (validation, *Used* years, summary panel).
class SchoolYearSubTrackForm extends ConsumerStatefulWidget {
  const SchoolYearSubTrackForm({
    required this.curriculumId,
    required this.existing,
    required this.subTracks,
    super.key,
  });

  /// The curriculum storage key.
  final String curriculumId;

  /// The edited sub-track, or null to create one.
  final SubTrack? existing;

  /// Every sub-track of the learner.
  final List<SubTrack> subTracks;

  @override
  ConsumerState<SchoolYearSubTrackForm> createState() =>
      _SchoolYearSubTrackFormState();
}

class _SchoolYearSubTrackFormState
    extends ConsumerState<SchoolYearSubTrackForm> {
  late final TextEditingController _name;
  late final TextEditingController _rate;
  late final TextEditingController _weeks;
  final _nameFocus = FocusNode();
  final _rateFocus = FocusNode();
  final _weeksFocus = FocusNode();

  int? _academicYear;
  late int _startMonth;
  int? _endMonth;

  /// The edited row is open-ended: the end-month field offers "No end
  /// month" so an untouched open end stays open (AC-8).
  late final bool _openEndAllowed;
  late bool _learnsOnShabbos;

  /// Fields validated so far (blurred or changed); all are after a save.
  final _touched = <SchoolYearFormField>{};
  bool _submitted = false;
  bool _saving = false;

  /// Errors the save command returned (shared AD-45 validation), cleared on
  /// the next change.
  Map<SchoolYearFormField, SchoolYearFormError> _commandErrors = const {};

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final initial = existing == null
        ? const SchoolYearFormValues(
            name: '',
            academicYear: null,
            startMonth: kDefaultSchoolYearStartMonth,
            endMonth: kDefaultSchoolYearEndMonth,
            rateText: '$kDefaultSchoolYearRatePerWeek',
            weeksText: '$kDefaultSchoolYearWeeksPerYear',
            learnsOnShabbos: false,
          )
        : SchoolYearFormValues.of(existing);
    _name = TextEditingController(text: initial.name);
    _rate = TextEditingController(text: initial.rateText);
    _weeks = TextEditingController(text: initial.weeksText);
    _academicYear = initial.academicYear;
    _startMonth = initial.startMonth;
    _endMonth = initial.endMonth;
    _openEndAllowed = existing != null && existing.windowEnd == null;
    _learnsOnShabbos = initial.learnsOnShabbos;
    _blurValidates(_nameFocus, SchoolYearFormField.name);
    _blurValidates(_rateFocus, SchoolYearFormField.rate);
    _blurValidates(_weeksFocus, SchoolYearFormField.weeks);
  }

  void _blurValidates(FocusNode node, SchoolYearFormField field) {
    node.addListener(() {
      if (!node.hasFocus && mounted) setState(() => _touched.add(field));
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _weeks.dispose();
    _nameFocus.dispose();
    _rateFocus.dispose();
    _weeksFocus.dispose();
    super.dispose();
  }

  SchoolYearFormValues get _values => SchoolYearFormValues(
    name: _name.text,
    academicYear: _academicYear,
    startMonth: _startMonth,
    endMonth: _endMonth,
    rateText: _rate.text,
    weeksText: _weeks.text,
    learnsOnShabbos: _learnsOnShabbos,
  );

  Map<SchoolYearFormField, SchoolYearFormError> get _errors =>
      validateSchoolYearForm(
        _values,
        curriculumId: widget.curriculumId,
        subTracks: widget.subTracks,
        editingId: widget.existing?.id,
      );

  /// A change: the field counts as validated and the command's errors are
  /// stale.
  void _changed(SchoolYearFormField field, [VoidCallback? apply]) {
    setState(() {
      apply?.call();
      _touched.add(field);
      _commandErrors = const {};
    });
  }

  String? _errorText(
    AppLocalizations l10n,
    Map<SchoolYearFormField, SchoolYearFormError> errors,
    SchoolYearFormField field,
  ) {
    final error =
        _commandErrors[field] ??
        ((_submitted || _touched.contains(field)) ? errors[field] : null);
    return switch (error) {
      null => null,
      SchoolYearFormError.nameRequired => l10n.subTrackErrorNameRequired,
      SchoolYearFormError.yearRequired => l10n.subTrackErrorYearRequired,
      SchoolYearFormError.yearUsed => l10n.subTrackErrorYearUsed,
      SchoolYearFormError.windowOverlap => l10n.subTrackErrorWindowOverlap,
      SchoolYearFormError.windowReversed => l10n.subTrackErrorWindowReversed,
      SchoolYearFormError.notPositive => l10n.subTrackErrorPositiveNumber,
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _commandErrors = const {};
    });
    final values = _values;
    if (_errors.isNotEmpty) return;
    setState(() => _saving = true);
    CaptureResult? result;
    try {
      final commands = await ref.read(learningCommandsProvider.future);
      if (commands == null) {
        throw StateError('No active learner for the sub-track commands');
      }
      // The command boundary (AC-3): the parent session may have ended
      // since the form opened. Nothing is written; the values stay.
      if (!await readSubTrackParentSession(ref)) {
        throw StateError('No parent session for the sub-track save');
      }
      final existing = widget.existing;
      if (existing == null) {
        result = await commands.createSubTrack(
          schoolYearDraft(values, curriculumId: widget.curriculumId),
        );
      } else {
        final edit = schoolYearEdit(existing, values);
        result = edit == null
            ? const CaptureResult.success()
            : await commands.editSubTrack(existing.id, edit);
      }
    } on Object catch (error, stack) {
      _log.error(
        event: 'sub_track_form_save_failed',
        fields: {'curriculum_id': widget.curriculumId},
        exception: error,
        stackTrace: stack,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _handle(result);
  }

  void _handle(CaptureResult? result) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case CaptureSuccess():
        unawaited(Navigator.of(context).maybePop(true));
        return;
      case CaptureRejected(:final violations)
          when violations.any(
            (v) => v.limit == SubTrackLimit.calendarProgramCurriculum,
          ):
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.subTrackCalendarProgramRejected)),
        );
        return;
      case CaptureRejected(:final violations)
          when schoolYearErrorsFromViolations(violations).isNotEmpty:
        setState(
          () => _commandErrors = schoolYearErrorsFromViolations(violations),
        );
        return;
      case _:
        // Offline with no cache, a lost parent session, an unavailable
        // command or a thrown error: keep every value and offer a retry
        // (UX-DR-120). Nothing was written.
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.subTrackSaveFailed),
            action: SnackBarAction(label: l10n.actionRetry, onPressed: _save),
          ),
        );
    }
  }

  void _stepRate(int delta) {
    final current = parsePositiveNumber(_rate.text) ?? 0;
    final next = (current + delta).clamp(1, 9999).toDouble();
    _changed(SchoolYearFormField.rate, () {
      _rate.text = formatFormNumber(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final today = ref.watch(subTrackTodayProvider);
    final intent = ref
        .watch(subTrackCurriculumIntentProvider(widget.curriculumId))
        .value;
    final unit = subTrackLeafUnitLabel(ref, widget.curriculumId);
    final errors = _errors;
    final currentYear = academicYearOf(today);
    final years = academicYearOptions(
      today: today,
      deadline: intent?.deadline,
      include: widget.existing?.academicYear,
    );
    final used = usedAcademicYears(
      widget.subTracks,
      curriculumId: widget.curriculumId,
      exceptId: widget.existing?.id,
    );

    final form = _buildForm(
      context,
      l10n: l10n,
      unit: unit,
      errors: errors,
      years: years,
      states: {
        for (final y in years)
          y: academicYearState(y, used: used, currentYear: currentYear),
      },
      showNoDeadlineNote: intent != null && intent.deadline == null,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kSubTrackFormTabletBreakpoint) return form;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: kSubTrackFormMaxWidth,
              ),
              child: form,
            ),
            Expanded(
              child: SubTrackSummaryPanel(
                curriculumId: widget.curriculumId,
                subTracks: widget.subTracks,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildForm(
    BuildContext context, {
    required AppLocalizations l10n,
    required String unit,
    required Map<SchoolYearFormField, SchoolYearFormError> errors,
    required List<int> years,
    required Map<int, AcademicYearState> states,
    required bool showNoDeadlineNote,
  }) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final monthNames = DateFormat.MMMM(
      Localizations.localeOf(context).toLanguageTag(),
    );
    String monthName(int m) => monthNames.format(DateTime(2000, m));

    InputDecoration filled(String label, {String? error, String? helper}) =>
        InputDecoration(
          labelText: label,
          errorText: error,
          helperText: helper,
          helperMaxLines: 3,
          errorMaxLines: 3,
          filled: true,
          fillColor: colors.brandCreamCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.brandOutline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.brandOutline),
          ),
        );

    Widget monthField(
      String label,
      int? value,
      ValueChanged<int?> onChanged, {
      bool allowOpen = false,
    }) => DropdownButtonFormField<int?>(
      initialValue: value,
      isExpanded: true,
      decoration: filled(label),
      items: [
        if (allowOpen)
          DropdownMenuItem<int?>(child: Text(l10n.subTrackFormEndMonthOpen)),
        for (var m = 1; m <= 12; m++)
          DropdownMenuItem<int?>(value: m, child: Text(monthName(m))),
      ],
      onChanged: (m) {
        if (m != null || allowOpen) onChanged(m);
      },
    );

    final startField = monthField(
      l10n.subTrackFormStartMonthLabel,
      _startMonth,
      (m) => _changed(SchoolYearFormField.window, () => _startMonth = m!),
    );
    final endField = monthField(
      l10n.subTrackFormEndMonthLabel,
      _endMonth,
      (m) => _changed(SchoolYearFormField.window, () => _endMonth = m),
      allowOpen: _openEndAllowed,
    );
    final windowError = _errorText(l10n, errors, SchoolYearFormField.window);

    final rate = parsePositiveNumber(_rate.text);
    final curriculum = CurriculumId.fromStorageKey(widget.curriculumId);
    final schoolDays = curriculum == null
        ? null
        : ref.watch(studyDaysPerWeekProvider(curriculum)).value;
    final perDay = rate != null && schoolDays != null && schoolDays > 0
        ? rate / schoolDays
        : null;

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
      children: [
        TextField(
          key: const ValueKey('subTrackFormName'),
          controller: _name,
          focusNode: _nameFocus,
          textInputAction: TextInputAction.next,
          decoration: filled(
            l10n.subTrackFormNameLabel,
            error: _errorText(l10n, errors, SchoolYearFormField.name),
          ),
          onChanged: (_) => setState(() => _commandErrors = const {}),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.subTrackFormAcademicYearLabel,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        AcademicYearPicker(
          years: years,
          states: states,
          selected: _academicYear,
          onSelected: (y) => _changed(
            SchoolYearFormField.academicYear,
            () => _academicYear = y,
          ),
          errorText: _errorText(l10n, errors, SchoolYearFormField.academicYear),
        ),
        const SizedBox(height: 20),
        if (largeText) ...[
          startField,
          const SizedBox(height: 12),
          endField,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: startField),
              const SizedBox(width: 12),
              Expanded(child: endField),
            ],
          ),
        if (windowError != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
            child: Text(
              windowError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () => _stepRate(-1),
              icon: Icon(
                Icons.remove,
                semanticLabel: l10n.subTrackFormRateDecrease(unit),
              ),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
            Expanded(
              child: TextField(
                key: const ValueKey('subTrackFormRate'),
                controller: _rate,
                focusNode: _rateFocus,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                ],
                decoration: filled(
                  l10n.subTrackFormRateLabel(unit),
                  error: _errorText(l10n, errors, SchoolYearFormField.rate),
                  helper: perDay == null
                      ? null
                      : l10n.subTrackFormPerSchoolDay(
                          _approx(perDay),
                          unit.toLowerCase(),
                        ),
                ),
                onChanged: (_) => setState(() => _commandErrors = const {}),
              ),
            ),
            IconButton(
              onPressed: () => _stepRate(1),
              icon: Icon(
                Icons.add,
                semanticLabel: l10n.subTrackFormRateIncrease(unit),
              ),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('subTrackFormWeeks'),
          controller: _weeks,
          focusNode: _weeksFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
          ],
          decoration: filled(
            l10n.subTrackFormWeeksLabel,
            error: _errorText(l10n, errors, SchoolYearFormField.weeks),
            helper: l10n.subTrackFormWeeksHelper,
          ),
          onChanged: (_) => setState(() => _commandErrors = const {}),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsetsDirectional.zero,
          title: Text(l10n.subTrackFormShabbosLabel),
          subtitle: Text(l10n.subTrackFormShabbosHelper),
          value: _learnsOnShabbos,
          onChanged: (v) => setState(() => _learnsOnShabbos = v),
        ),
        const SizedBox(height: 12),
        InfoNote(text: l10n.subTrackFormGroundNote),
        if (showNoDeadlineNote) ...[
          const SizedBox(height: 12),
          NoDeadlineNote(onOpenGoalSetup: () => unawaited(_openGoalSetup())),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('subTrackFormSave'),
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
          ),
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.subTrackFormSave),
        ),
      ],
    );
  }

  bool _openingGoalSetup = false;

  /// The no-deadline link (AC-6): opens the existing goal setup, waits for
  /// its governed save and reports the outcome. The form keeps its values
  /// either way; a saved deadline arrives through the live intent read.
  Future<void> _openGoalSetup() async {
    if (_openingGoalSetup) return;
    final curriculum = CurriculumId.fromStorageKey(widget.curriculumId);
    if (curriculum == null) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final launch = ref.read(subTrackGoalSetupLauncherProvider);
    _openingGoalSetup = true;
    SubTrackGoalSetupOutcome outcome;
    try {
      outcome = await launch(context, ref, curriculum);
    } on Object catch (error, stack) {
      _log.error(
        event: 'sub_track_goal_setup_failed',
        fields: {'curriculum_id': widget.curriculumId},
        exception: error,
        stackTrace: stack,
      );
      outcome = SubTrackGoalSetupOutcome.failed;
    } finally {
      _openingGoalSetup = false;
    }
    if (!mounted) return;
    switch (outcome) {
      case SubTrackGoalSetupOutcome.saved:
        messenger.showSnackBar(SnackBar(content: Text(l10n.goalSavedSnack)));
      case SubTrackGoalSetupOutcome.failed:
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.subTrackGoalSaveFailed),
            action: SnackBarAction(
              label: l10n.actionRetry,
              onPressed: () => unawaited(_openGoalSetup()),
            ),
          ),
        );
      case SubTrackGoalSetupOutcome.cancelled:
        break;
    }
  }

  /// "2" for 2.0, "1.5" for 1.5, one decimal at most.
  static String _approx(double value) {
    final rounded = (value * 10).round() / 10;
    return formatFormNumber(rounded);
  }
}

/// The tablet summary panel next to the form (UX-DR-162): the curriculum's
/// non-ended sub-tracks, each with its capacity
/// "Capacity {n} … ({rate}/wk × {weeks} weeks)" from the learner state
/// (AD-44). No projections, badges or tips. Without a deadline capacity is
/// not computed, so only the rate plan shows.
class SubTrackSummaryPanel extends ConsumerWidget {
  const SubTrackSummaryPanel({
    required this.curriculumId,
    required this.subTracks,
    super.key,
  });

  /// The curriculum storage key.
  final String curriculumId;

  /// Every sub-track of the learner.
  final List<SubTrack> subTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final unit = subTrackLeafUnitLabel(ref, curriculumId);
    final state = ref.watch(activeLearnerStateProvider).value?[curriculumId];
    final live = [
      for (final s in subTracks)
        if (s.curriculumId == curriculumId && !s.isEnded) s,
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.brandCreamCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.brandOutline),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.subTrackSummaryTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (live.isEmpty)
                Text(
                  l10n.subTrackSummaryEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.brandInkMuted,
                  ),
                ),
              for (final s in live)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: theme.textTheme.titleSmall),
                      Text(
                        _planLine(
                          l10n,
                          s,
                          state?.subTracks[s.id]?.capacity,
                          unit,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.brandInkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _planLine(
    AppLocalizations l10n,
    SubTrack s,
    int? capacity,
    String unit,
  ) {
    final rate = formatFormNumber(s.ratePerWeek);
    final weeks = formatFormNumber(s.weeksPerYear);
    return capacity == null
        ? l10n.subTrackSummaryPlan(rate, weeks)
        : l10n.subTrackSummaryCapacity(
            capacity,
            unit.toLowerCase(),
            rate,
            weeks,
          );
  }
}
