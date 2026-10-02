/// The *Add next year* school-year form (Story 2.8 / DNI-499, AC-1):
/// prefilled from the source sub-track for `academic_year + 1` with empty
/// ground; name, rate, weeks per year, the Shabbos flag and the start and
/// end months stay editable. *Save sub-track* creates a NEW sub-track
/// through `LearningCommands.createSubTrack` (a new ULID; the source is
/// never edited). A refusal (e.g. another device took the year first,
/// AD-45) keeps the input and says why.
///
/// INTERIM (DNI-499 seam): Story 2.4 / DNI-495 owns the full school-year
/// form, which is not on `integ/sub-tracks` yet. [subTrackNextYearFormProvider]
/// opens this screen until DNI-495 binds its form there with the same
/// prefill ([nextYearSubTrackDraft]); this screen is then deleted (bead
/// learning-tracker-fyh.208).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_lifecycle.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Opens the *Add next year* form for [source]; completes with true when a
/// new sub-track was saved.
typedef SubTrackNextYearForm =
    Future<bool> Function(BuildContext context, SubTrack source);

/// The form behind *Add next year*. Story 2.4 (DNI-495) overrides it with
/// its school-year form prefilled from [nextYearSubTrackDraft].
final subTrackNextYearFormProvider = Provider<SubTrackNextYearForm>(
  (ref) =>
      (context, source) async =>
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => NextYearSubTrackFormScreen(source: source),
            ),
          ) ??
          false,
);

/// The prefilled next-year form of school-year [source].
class NextYearSubTrackFormScreen extends ConsumerStatefulWidget {
  /// Creates the form.
  const NextYearSubTrackFormScreen({super.key, required this.source});

  /// The school-year sub-track being rolled over (never edited).
  final SubTrack source;

  @override
  ConsumerState<NextYearSubTrackFormScreen> createState() =>
      _NextYearSubTrackFormScreenState();
}

class _NextYearSubTrackFormScreenState
    extends ConsumerState<NextYearSubTrackFormScreen> {
  final _form = GlobalKey<FormState>();
  late final SubTrackDraft _prefill = nextYearSubTrackDraft(widget.source);
  late final _name = TextEditingController(text: _prefill.name);
  late final _rate = TextEditingController(text: _num(_prefill.ratePerWeek));
  late final _weeks = TextEditingController(text: _num(_prefill.weeksPerYear));
  late bool _shabbos = _prefill.learnsOnShabbos;
  late int _startMonth = subTrackMonthOf(_prefill.windowStart);
  late int? _endMonth = switch (_prefill.windowEnd) {
    final end? => subTrackMonthOf(end),
    null => null,
  };
  bool _saving = false;
  bool _reversed = false;

  int get _year => _prefill.academicYear!;

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _weeks.dispose();
    super.dispose();
  }

  String? _positive(String? text, AppLocalizations l10n) {
    final value = double.tryParse((text ?? '').trim());
    return value == null || !value.isFinite || value <= 0
        ? l10n.subTrackLifecyclePositiveNumber
        : null;
  }

  SubTrackDraft _draft() {
    final end = _endMonth;
    return SubTrackDraft(
      curriculumId: _prefill.curriculumId,
      name: _name.text.trim(),
      type: SubTrackType.schoolYear,
      academicYear: _year,
      windowStart: schoolYearWindowStartOf(_year, _startMonth),
      windowEnd: end == null ? null : schoolYearWindowEndOf(_year, end),
      ratePerWeek: double.parse(_rate.text.trim()),
      weeksPerYear: double.parse(_weeks.text.trim()),
      learnsOnShabbos: _shabbos,
      ground: const [],
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!(_form.currentState?.validate() ?? false)) return;
    final draft = _draft();
    final end = draft.windowEnd;
    setState(
      () => _reversed = end != null && end.compareTo(draft.windowStart) < 0,
    );
    if (_reversed) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    CaptureResult? result;
    try {
      final commands = await ref.read(learningCommandsProvider.future);
      result = await commands?.createSubTrack(draft, addNextYear: true);
    } on Object {
      result = null;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    final yearLabel = subTrackAcademicYearLabel(_year);
    if (result is CaptureSuccess) {
      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.subTrackLifecycleNextYearSaved(draft.name, yearLabel),
          ),
        ),
      );
      return;
    }
    final yearTaken =
        result is CaptureRejected &&
        result.violations.any(
          (v) =>
              v.limit == SubTrackLimit.schoolYearDuplicate ||
              v.limit == SubTrackLimit.schoolYearOverlap,
        );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          yearTaken
              ? l10n.subTrackLifecycleAddNextYearUsed(yearLabel)
              : l10n.subTrackLifecycleSaveFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final monthName = DateFormat.MMMM(
      Localizations.localeOf(context).toString(),
    );
    final months = [
      // The academic year's order: September first.
      for (var i = 0; i < 12; i++)
        (kSubTrackAcademicYearFirstMonth - 1 + i) % 12 + 1,
    ];
    String label(int month) => monthName.format(DateTime(2000, month));
    final numberFormatters = [
      FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
    ];
    return Scaffold(
      backgroundColor: colors.surfaceF5,
      appBar: AppBar(
        backgroundColor: colors.surfaceF5,
        elevation: 0,
        title: Text(l10n.subTrackLifecycleNextYearTitle),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
          children: [
            Text(
              l10n.subTrackLifecycleNextYearFor(
                subTrackAcademicYearLabel(_year),
              ),
              key: const ValueKey('subTrackNextYearYear'),
              style: text.titleMedium?.copyWith(
                color: colors.brandInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('subTrackNextYearName'),
              controller: _name,
              decoration: InputDecoration(
                labelText: l10n.subTrackLifecycleFieldName,
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? l10n.subTrackLifecycleNameRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('subTrackNextYearRate'),
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: numberFormatters,
              decoration: InputDecoration(
                labelText: l10n.subTrackLifecycleFieldRate,
              ),
              validator: (v) => _positive(v, l10n),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('subTrackNextYearWeeks'),
              controller: _weeks,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: numberFormatters,
              decoration: InputDecoration(
                labelText: l10n.subTrackLifecycleFieldWeeks,
              ),
              validator: (v) => _positive(v, l10n),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const ValueKey('subTrackNextYearStartMonth'),
              initialValue: _startMonth,
              decoration: InputDecoration(
                labelText: l10n.subTrackLifecycleFieldStartMonth,
              ),
              items: [
                for (final m in months)
                  DropdownMenuItem(value: m, child: Text(label(m))),
              ],
              onChanged: (m) => setState(() => _startMonth = m ?? _startMonth),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              key: const ValueKey('subTrackNextYearEndMonth'),
              initialValue: _endMonth,
              decoration: InputDecoration(
                labelText: l10n.subTrackLifecycleFieldEndMonth,
                errorText: _reversed
                    ? l10n.subTrackLifecycleWindowReversed
                    : null,
              ),
              items: [
                for (final m in months)
                  DropdownMenuItem(value: m, child: Text(label(m))),
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.subTrackLifecycleNoEndMonth),
                ),
              ],
              onChanged: (m) => setState(() {
                _endMonth = m;
                _reversed = false;
              }),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              key: const ValueKey('subTrackNextYearShabbos'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.subTrackLifecycleFieldShabbos),
              value: _shabbos,
              onChanged: (v) => setState(() => _shabbos = v),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('subTrackNextYearSave'),
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.subTrackLifecycleSave),
            ),
          ],
        ),
      ),
    );
  }
}
