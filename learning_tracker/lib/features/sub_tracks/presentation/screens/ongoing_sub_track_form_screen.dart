import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ongoing_sub_track_form_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ongoing_sub_track_form_validation.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ongoing_sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_editor_session.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart'
    show TutorDisabledControl, TutorWriteNote;
import 'package:learning_tracker/l10n/app_localizations.dart';

final _log = AppLogger.instance;

/// The rate a new ongoing form opens with ([ASSUMPTION per mock] screen
/// #06 shows 5 leaf units per week).
const kOngoingDefaultRatePerWeek = 5;

/// Width at and above which the form uses the tablet composition
/// (UX-DR-164).
const kOngoingFormTabletBreakpoint = 600.0;

/// A successful save, returned when the form closes.
final class OngoingSubTrackSaved {
  /// Creates the outcome.
  const OngoingSubTrackSaved({
    required this.scope,
    this.queued = false,
    this.changeIds = const [],
  });

  /// The learner the write was made for. A later rejection of a queued
  /// write is announced only while this learner is still the active one.
  final LearnerScope scope;

  /// Whether the write is queued offline (AD-54); a later permanent
  /// rejection rolls it back (UX-DR-121).
  final bool queued;

  /// The change-log entries written; matched against pending failures.
  final List<String> changeIds;
}

/// The ongoing sub-track create/edit form (Story 2.5 / DNI-496,
/// screens.md #06, UX-DR-31/52/80).
///
/// Fields: name, a rate stepper in the curriculum's leaf units, the
/// bein-hazmanim switch that only prefills weeks, weeks per year, optional
/// start and end dates, the shabbos / yom tov switch, the five-track limit
/// line and *Save sub-track*. Writes go through `LearningCommands`
/// `createSubTrack` / `editSubTrack` only; the engine derives everything
/// else (activity, capacity, target) from the stored values.
///
/// An edit is opened by sub-track id only. The form resolves the row from
/// the bound learner's current read and edits it only while it is a
/// non-ended ongoing sub-track of [OngoingSubTrackFormScreen.curriculumId]
/// (see [OngoingSubTrackContext.editableOngoing]); a stale or hand-made
/// route for a missing, ended, school-year or other-curriculum row closes
/// without writing. The same check runs again right before the write.
///
/// The form is bound to the learner it was opened for: it shows only while
/// [ongoingSubTrackWriteScopeProvider] grants that learner (a parent
/// session), closes itself when the active profile changes or the parent
/// session ends, and re-checks the grant right before every write, so a
/// direct push or a profile switch never writes to another learner.
///
/// A failed save keeps every entered value and offers a retry
/// (UX-DR-120). At ≥ 600dp the form is capped at 600px beside a summary of
/// the learner's sub-tracks (UX-DR-164).
class OngoingSubTrackFormScreen extends ConsumerStatefulWidget {
  const OngoingSubTrackFormScreen({
    super.key,
    required this.curriculumId,
    this.subTrackId,
  });

  /// The curriculum's storage key.
  final String curriculumId;

  /// The id of the sub-track being edited, or null for a new one.
  final String? subTrackId;

  @override
  ConsumerState<OngoingSubTrackFormScreen> createState() =>
      _OngoingSubTrackFormScreenState();
}

class _OngoingSubTrackFormScreenState
    extends ConsumerState<OngoingSubTrackFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _rate;
  late final TextEditingController _weeksText;
  late OngoingWeeksPrefill _weeks;
  CivilDate? _start;
  CivilDate? _end;
  late bool _shabbos;

  final _focus = {
    OngoingFormField.name: FocusNode(),
    OngoingFormField.rate: FocusNode(),
    OngoingFormField.weeks: FocusNode(),
  };
  final Set<OngoingFormField> _touched = {};
  Map<OngoingFormField, OngoingFormError> _commandErrors = const {};
  bool _submitted = false;
  bool _saving = false;
  bool _limitBlocked = false;

  /// The learner this form writes for: the first scope the write gate
  /// granted. Null until then.
  LearnerScope? _boundScope;

  /// Set once the form is closing because its grant was lost.
  bool _closing = false;

  /// The edited sub-track as resolved from the bound learner's read; null
  /// for a create, and for an edit until the read arrives. It is the
  /// baseline the parent's edits are measured from: only fields changed
  /// from it are written.
  SubTrack? _existing;

  bool get _isEdit => widget.subTrackId != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _rate = TextEditingController(text: '$kOngoingDefaultRatePerWeek');
    _weeks = const OngoingWeeksPrefill.initial();
    _weeksText = TextEditingController(text: _weeks.weeksText);
    _shabbos = false;
    for (final MapEntry(key: field, value: node) in _focus.entries) {
      node.addListener(() {
        if (!node.hasFocus && mounted) setState(() => _touched.add(field));
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _weeksText.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Fills the fields from [existing], once, when an edit resolves.
  void _prefill(SubTrack existing) {
    _existing = existing;
    _name.text = existing.name;
    _rate.text = formatOngoingNumber(existing.ratePerWeek);
    _weeks = OngoingWeeksPrefill.forStored(existing.weeksPerYear);
    _weeksText.text = _weeks.weeksText;
    _start = existing.windowStart;
    _end = existing.windowEnd;
    _shabbos = existing.learnsOnShabbos;
  }

  /// The row this edit may write, from [read]: null when [read] is another
  /// learner's, or the row is missing, ended, not ongoing or of another
  /// curriculum.
  SubTrack? _editable(OngoingSubTrackContext read) =>
      _isBound(read.scope) ? read.editableOngoing(widget.subTrackId!) : null;

  bool _isBound(LearnerScope? scope) =>
      scope != null && _boundScope != null && scope == _boundScope;

  /// Whether the parent session still grants the bound learner, read fresh
  /// (fails closed on any error).
  Future<bool> _writeStillGranted() async {
    try {
      return _isBound(await ref.read(ongoingSubTrackWriteScopeProvider.future));
    } on Object catch (error, stack) {
      _log.error(
        event: 'ongoing_sub_track_write_gate_failed',
        exception: error,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Leaves the form without saving: its learner or parent session is gone.
  void _close() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route == null) return;
        final navigator = Navigator.of(context);
        if (route.isCurrent) {
          navigator.pop();
        } else {
          // A picker is open above the form: drop the form under it.
          navigator.removeRoute(route);
        }
      })
      ..scheduleFrame();
  }

  OngoingFormValidation _validate(CivilDate today) =>
      validateOngoingSubTrackForm(
        OngoingSubTrackFormInput(
          name: _name.text,
          rateText: _rate.text,
          weeksText: _weeksText.text,
          start: _start,
          end: _end,
          learnsOnShabbos: _shabbos,
        ),
        today: today,
      );

  /// The inline error of [field]: a command-side error, else the local
  /// rule once the field was left (blur) or a save was tried (UX-DR-80).
  String? _errorText(
    AppLocalizations l10n,
    OngoingFormValidation validation,
    OngoingFormField field,
  ) {
    final error =
        _commandErrors[field] ??
        (_submitted || _touched.contains(field)
            ? validation.errors[field]
            : null);
    return switch (error) {
      null => null,
      OngoingFormError.nameRequired => l10n.ongoingSubTrackNameRequired,
      OngoingFormError.notPositive => l10n.ongoingSubTrackPositiveNumber,
      OngoingFormError.endBeforeStart => l10n.ongoingSubTrackEndBeforeStart,
    };
  }

  void _clearCommandError(OngoingFormField field) {
    if (_commandErrors.containsKey(field)) {
      _commandErrors = {..._commandErrors}..remove(field);
    }
  }

  void _toggleBeinHazmanim(bool on) {
    setState(() {
      _weeks = _weeks.toggleBeinHazmanim(on: on);
      if (_weeksText.text != _weeks.weeksText) {
        _weeksText.text = _weeks.weeksText;
      }
    });
  }

  void _stepRate(int delta) {
    final current = parsePositiveOngoingNumber(_rate.text);
    final next = current == null
        ? 1.0
        : (current + delta).clamp(1, double.infinity).toDouble();
    setState(() {
      _rate.text = formatOngoingNumber(next);
      _touched.add(OngoingFormField.rate);
      _clearCommandError(OngoingFormField.rate);
    });
  }

  Future<void> _pickDate({
    required CivilDate? current,
    required CivilDate today,
    required ValueChanged<CivilDate> onPicked,
  }) async {
    final initial = parseCivilDay(current ?? today);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(
      () => onPicked(
        formatCivilDay(DateTime.utc(picked.year, picked.month, picked.day)),
      ),
    );
  }

  Future<void> _save(OngoingSubTrackContext read) async {
    if (_saving) return;
    // Judge the save on the learner's civil today now, not when the form
    // was read: a form left open across midnight must not default the
    // start to yesterday or count the limit on a stale day (AD-41, AC-3).
    final data = read.atDay(
      read.todayAt(ref.read(localDayClockProvider).nowUtc()),
    );
    final shared = ongoingSubTrackContextProvider(widget.curriculumId);
    final sharedToday = ref.read(shared).value?.today;
    if (sharedToday != null && sharedToday != data.today) {
      // The midnight re-read was late (a suspended app): refresh the hub.
      ref.invalidate(shared);
    }
    final validation = _validate(data.today);
    setState(() {
      _submitted = true;
      _commandErrors = const {};
    });
    if (!validation.isValid) return;
    final values = validation.values!;
    final bound = _boundScope;
    if (bound == null || !_isBound(data.scope)) {
      _close();
      return;
    }
    // An edit writes only against the row as the bound learner's current
    // read holds it; one that is gone, ended or no longer ongoing is not
    // written (a stale route never edits another row).
    final existing = _isEdit ? _editable(data) : null;
    if (_isEdit && existing == null) {
      _close();
      return;
    }
    if (existing == null && !ongoingCreateAllowed(data.ongoingInUse())) {
      setState(() => _limitBlocked = true);
      return;
    }
    if (existing != null &&
        values.editFrom(existing, opened: _existing) == null) {
      Navigator.of(context).pop(OngoingSubTrackSaved(scope: bound));
      return;
    }
    setState(() => _saving = true);
    CaptureResult? result;
    var unchanged = false;
    try {
      final commands = await ref.read(learningCommandsProvider.future);
      // Re-gate right before the write: the profile may have switched or
      // the parent PIN session ended while the form was open.
      if (!await _writeStillGranted()) {
        result = null;
      } else if (commands == null) {
        result = const CaptureResult.onlineRequired();
      } else if (existing == null) {
        result = await commands.createSubTrack(
          values.toDraft(widget.curriculumId),
        );
      } else {
        // Re-resolve the row from the latest read right before the write:
        // it may have been ended or changed elsewhere since the tap.
        final latest = await ref.read(
          ongoingSubTrackContextProvider(widget.curriculumId).future,
        );
        final current = latest == null ? null : _editable(latest);
        // Only the fields the parent changed from the row the form opened
        // with are sent, so a change made elsewhere while the form was
        // open is kept unless the parent edited that same field.
        final latestEdit = current == null
            ? null
            : values.editFrom(current, opened: _existing);
        if (current == null) {
          result = null;
        } else if (latestEdit == null) {
          unchanged = true;
        } else {
          result = await commands.editSubTrack(current.id, latestEdit);
        }
      }
    } on Object catch (error, stack) {
      _log.error(
        event: 'ongoing_sub_track_save_failed',
        exception: error,
        stackTrace: stack,
      );
      result = const CaptureResult.onlineRequired();
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (unchanged) {
      Navigator.of(context).pop(OngoingSubTrackSaved(scope: bound));
      return;
    }
    if (result == null) {
      _close();
      return;
    }
    switch (result) {
      case CaptureSuccess(:final queued, :final changeIds):
        Navigator.of(context).pop(
          OngoingSubTrackSaved(
            scope: bound,
            queued: queued,
            changeIds: changeIds,
          ),
        );
      case CaptureRejected(:final violations) when violations.isNotEmpty:
        _showViolations(violations, data);
      default:
        _showSaveFailed(data);
    }
  }

  void _showViolations(
    List<SubTrackViolation> violations,
    OngoingSubTrackContext data,
  ) {
    final errors = <OngoingFormField, OngoingFormError>{};
    var limit = false;
    for (final v in violations) {
      if (v.limit == SubTrackLimit.ongoingLimit) limit = true;
      final field = ongoingFieldForViolation(v.limit);
      if (field != null) {
        errors[field] = field == OngoingFormField.end
            ? OngoingFormError.endBeforeStart
            : OngoingFormError.notPositive;
      }
    }
    setState(() {
      _commandErrors = errors;
      _limitBlocked = limit;
    });
    if (errors.isEmpty && !limit) _showSaveFailed(data);
  }

  void _showSaveFailed(OngoingSubTrackContext data) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.ongoingSubTrackSaveFailed),
          action: SnackBarAction(
            label: l10n.actionRetry,
            // Retry with the values still in the form (UX-DR-120) against
            // the latest sub-track read.
            onPressed: () => unawaited(
              _save(
                ref
                        .read(
                          ongoingSubTrackContextProvider(widget.curriculumId),
                        )
                        .value ??
                    data,
              ),
            ),
          ),
        ),
      );
  }

  String _leafUnit() {
    final id = CurriculumId.fromStorageKey(widget.curriculumId);
    if (id == null) return widget.curriculumId;
    return CurriculumLabels.leaf(id).inLanguage(
      useHebrew: domainTermLabels(ref).isHebrew,
      plural: true,
      variant: ref.watch(currentTransliterationVariantProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final gate = ref.watch(ongoingSubTrackWriteScopeProvider);
    final granted = gate.hasError ? null : gate.value;
    if (_boundScope == null && granted != null && !gate.isLoading) {
      _boundScope = granted;
    }
    // Fail closed: an error, or a settled grant for no learner or another
    // learner (a direct push without a parent session, a profile switch, a
    // cleared PIN) closes the form; a reload keeps the bound learner.
    var revoked =
        _closing ||
        gate.hasError ||
        (gate.hasValue && !gate.isLoading && !_isBound(granted));
    final dataAsync = ref.watch(
      ongoingSubTrackContextProvider(widget.curriculumId),
    );
    // An edit resolves its row from the bound learner's settled read, and
    // closes when that read has no editable row of that id (UX: the route
    // was stale or never valid).
    final read = dataAsync.hasError ? null : dataAsync.value;
    var unresolved = false;
    if (_isEdit && _boundScope != null && read != null) {
      if (_isBound(read.scope)) {
        final row = _editable(read);
        if (row == null) {
          if (!dataAsync.isLoading) revoked = true;
          unresolved = true;
        } else if (_existing == null) {
          _prefill(row);
        }
      } else {
        unresolved = true; // another learner's read, mid switch
      }
    } else if (_isEdit && _existing == null) {
      unresolved = true;
    }
    if (revoked) _close();
    final title = !_isEdit
        ? l10n.ongoingSubTrackFormTitle
        : l10n.ongoingSubTrackEditTitle;
    return Scaffold(
      backgroundColor: context.colors.surfaceF5,
      appBar: AppBar(
        backgroundColor: context.colors.surfaceF5,
        elevation: 0,
        centerTitle: false,
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.colors.brandBlueDeep,
          ),
        ),
      ),
      body: switch (dataAsync) {
        _ when revoked => const SizedBox.shrink(),
        _ when _boundScope == null || (unresolved && _existing == null) =>
          const Center(child: CircularProgressIndicator()),
        // A reload (new rows, the learner's midnight) keeps the form on
        // screen with the previous read instead of flashing a spinner.
        AsyncValue(value: final read?) when !dataAsync.hasError =>
          LayoutBuilder(
            builder: (context, constraints) {
              // Every rebuild judges the form on the learner's civil today
              // now, so validation and the limit line never lag midnight.
              final data = read.atDay(
                read.todayAt(ref.read(localDayClockProvider).nowUtc()),
              );
              final form = _buildForm(context, l10n, data);
              if (constraints.maxWidth < kOngoingFormTabletBreakpoint) {
                return form;
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: form,
                  ),
                  Expanded(
                    child: _SubTrackSummaryPanel(
                      subTracks: data.liveSubTracks,
                      editingId: widget.subTrackId,
                    ),
                  ),
                ],
              );
            },
          ),
        AsyncError(:final error, :final stackTrace) => AppErrorView(
          error: error,
          stackTrace: stackTrace,
          onRetry: () => ref.invalidate(
            ongoingSubTrackContextProvider(widget.curriculumId),
          ),
        ),
        AsyncData() => AppErrorView(
          error: StateError('no active learner'),
          onRetry: () => ref.invalidate(
            ongoingSubTrackContextProvider(widget.curriculumId),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    OngoingSubTrackContext data,
  ) {
    final validation = _validate(data.today);
    final unit = _leafUnit();
    final theme = Theme.of(context);
    final inUse = data.ongoingInUse();
    final blocked = ref.watch(subTrackWritesBlockedProvider);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
      children: [
        TextFormField(
          key: const ValueKey('ongoingSubTrackName'),
          controller: _name,
          focusNode: _focus[OngoingFormField.name],
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            filled: true,
            labelText: l10n.ongoingSubTrackNameLabel,
            prefixIcon: const Icon(Icons.menu_book_outlined),
            errorText: _errorText(l10n, validation, OngoingFormField.name),
          ),
          onChanged: (_) =>
              setState(() => _clearCommandError(OngoingFormField.name)),
        ),
        const SizedBox(height: 16),
        _RateStepper(
          controller: _rate,
          focusNode: _focus[OngoingFormField.rate]!,
          label: l10n.ongoingSubTrackRateLabel(unit),
          decreaseLabel: l10n.ongoingSubTrackRateDecrease(unit),
          increaseLabel: l10n.ongoingSubTrackRateIncrease(unit),
          errorText: _errorText(l10n, validation, OngoingFormField.rate),
          canDecrease: (parsePositiveOngoingNumber(_rate.text) ?? 0) > 1,
          onStep: _stepRate,
          onChanged: () =>
              setState(() => _clearCommandError(OngoingFormField.rate)),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const ValueKey('ongoingSubTrackBeinHazmanim'),
          contentPadding: EdgeInsetsDirectional.zero,
          title: Text(l10n.ongoingSubTrackBeinHazmanimLabel),
          subtitle: Text(l10n.ongoingSubTrackBeinHazmanimHelper),
          value: _weeks.notLearningBeinHazmanim,
          onChanged: _toggleBeinHazmanim,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('ongoingSubTrackWeeks'),
          controller: _weeksText,
          focusNode: _focus[OngoingFormField.weeks],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
          ],
          decoration: InputDecoration(
            filled: true,
            labelText: l10n.ongoingSubTrackWeeksLabel,
            helperText: _weeks.showsPrefillHelper
                ? l10n.ongoingSubTrackWeeksPrefillHelper
                : null,
            helperMaxLines: 2,
            errorText: _errorText(l10n, validation, OngoingFormField.weeks),
          ),
          onChanged: (text) => setState(() {
            _weeks = _weeks.editWeeks(text);
            _clearCommandError(OngoingFormField.weeks);
          }),
        ),
        const SizedBox(height: 16),
        _DateField(
          key: const ValueKey('ongoingSubTrackStart'),
          label: l10n.ongoingSubTrackStartLabel,
          icon: Icons.calendar_today_outlined,
          value: _start,
          clearLabel: l10n.ongoingSubTrackClearDate,
          onTap: () => _pickDate(
            current: _start,
            today: data.today,
            onPicked: (d) {
              _start = d;
              // A new start re-checks an end already chosen (UX-DR-80).
              if (_end != null) _touched.add(OngoingFormField.end);
              _clearCommandError(OngoingFormField.end);
            },
          ),
          onClear: () => setState(() => _start = null),
        ),
        const SizedBox(height: 16),
        _DateField(
          key: const ValueKey('ongoingSubTrackEnd'),
          label: l10n.ongoingSubTrackEndLabel,
          icon: Icons.event_outlined,
          value: _end,
          clearLabel: l10n.ongoingSubTrackClearDate,
          errorText: _errorText(l10n, validation, OngoingFormField.end),
          onTap: () => _pickDate(
            current: _end ?? _start,
            today: data.today,
            onPicked: (d) {
              _end = d;
              _touched.add(OngoingFormField.end);
              _clearCommandError(OngoingFormField.end);
            },
          ),
          onClear: () => setState(() {
            _end = null;
            _clearCommandError(OngoingFormField.end);
          }),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const ValueKey('ongoingSubTrackShabbos'),
          contentPadding: EdgeInsetsDirectional.zero,
          title: Text(l10n.ongoingSubTrackShabbosLabel),
          subtitle: Text(l10n.ongoingSubTrackShabbosHelper),
          value: _shabbos,
          onChanged: (on) => setState(() => _shabbos = on),
        ),
        const SizedBox(height: 12),
        _InfoNote(
          key: const ValueKey('ongoingSubTrackLimitLine'),
          text: l10n.ongoingSubTrackLimitLine(inUse),
        ),
        if (_limitBlocked) ...[
          const SizedBox(height: 8),
          Text(
            l10n.ongoingSubTrackLimitReached,
            key: const ValueKey('ongoingSubTrackLimitReached'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 24),
        // Story 4.2 (AC-4, AC-5, AC-6): progress and held while saving;
        // visible but disabled, with one note, while a tutor may not write.
        if (blocked) const TutorWriteNote(padding: EdgeInsets.only(bottom: 12)),
        TutorDisabledControl(
          blocked: blocked,
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              key: const ValueKey('ongoingSubTrackSave'),
              onPressed: _saving || blocked
                  ? null
                  : () => unawaited(_save(data)),
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(l10n.ongoingSubTrackSave),
            ),
          ),
        ),
      ],
    );
  }
}

/// The leaf-unit rate stepper: − / value / +, each at least 48dp.
class _RateStepper extends StatelessWidget {
  const _RateStepper({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.decreaseLabel,
    required this.increaseLabel,
    required this.errorText,
    required this.canDecrease,
    required this.onStep,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String decreaseLabel;
  final String increaseLabel;
  final String? errorText;
  final bool canDecrease;
  final ValueChanged<int> onStep;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 4),
          child: IconButton.filledTonal(
            key: const ValueKey('ongoingSubTrackRateDecrease'),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: decreaseLabel,
            onPressed: canDecrease ? () => onStep(-1) : null,
            icon: Icon(Icons.remove, semanticLabel: decreaseLabel),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: const ValueKey('ongoingSubTrackRate'),
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
            ],
            decoration: InputDecoration(
              filled: true,
              labelText: label,
              errorText: errorText,
              errorMaxLines: 2,
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 4),
          child: IconButton.filledTonal(
            key: const ValueKey('ongoingSubTrackRateIncrease'),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: increaseLabel,
            onPressed: () => onStep(1),
            icon: Icon(Icons.add, semanticLabel: increaseLabel),
          ),
        ),
      ],
    );
  }
}

/// An optional civil-date field: tap to pick, a clear button when set.
class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.clearLabel,
    required this.onTap,
    required this.onClear,
    this.errorText,
  });

  final String label;
  final IconData icon;
  final CivilDate? value;
  final String clearLabel;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final date = value;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Semantics(
      button: true,
      label: label,
      value: date == null
          ? null
          : DateFormat.yMMMd(locale).format(parseCivilDay(date)),
      excludeSemantics: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          isEmpty: date == null,
          decoration: InputDecoration(
            filled: true,
            labelText: label,
            prefixIcon: Icon(icon),
            errorText: errorText,
            errorMaxLines: 2,
            suffixIcon: date == null
                ? null
                : IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: clearLabel,
                    onPressed: onClear,
                    icon: Icon(Icons.close, semanticLabel: clearLabel),
                  ),
          ),
          child: Text(
            date == null
                ? ''
                : DateFormat.yMMMd(locale).format(parseCivilDay(date)),
          ),
        ),
      ),
    );
  }
}

/// The info note under the form (UX-DR-31).
class _InfoNote extends StatelessWidget {
  const _InfoNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: context.colors.brandBlueSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.brandOutline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: context.colors.brandBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.colors.brandInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The tablet summary of the learner's sub-tracks on this curriculum:
/// names and their rate × weeks only (no projections, badges or tips).
class _SubTrackSummaryPanel extends StatelessWidget {
  const _SubTrackSummaryPanel({required this.subTracks, this.editingId});

  final List<SubTrack> subTracks;
  final String? editingId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 16),
      child: Card(
        key: const ValueKey('ongoingSubTrackTabletSummary'),
        elevation: 0,
        color: context.colors.brandCreamCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.colors.brandOutline),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.ongoingSubTrackTabletSummaryTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.brandInk,
                ),
              ),
              const SizedBox(height: 8),
              if (subTracks.isEmpty)
                Text(l10n.ongoingSubTrackTabletSummaryEmpty)
              else
                for (final s in subTracks)
                  ListTile(
                    contentPadding: EdgeInsetsDirectional.zero,
                    selected: s.id == editingId,
                    title: Text(s.name),
                    subtitle: Text(
                      l10n.ongoingSubTrackRateSummary(
                        formatOngoingNumber(s.ratePerWeek),
                        formatOngoingNumber(s.weeksPerYear),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
