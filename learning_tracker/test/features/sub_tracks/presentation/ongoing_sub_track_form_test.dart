// DNI-496 (Story 2.5): the ongoing sub-track create/edit form — fields and
// defaults (AC-1), the weeks prefill (AC-2), optional dates (AC-3), future
// start (AC-4, form side), the five-track limit (AC-5, form side), edits
// (AC-6), failure recovery, dark, tablet, large text and RTL (AC-7) and the
// edge table. Commands are the C0 fakes (DNI-524).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ongoing_sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/ongoing_sub_track_form_route.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/ongoing_sub_track_form_screen.dart';

import '../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../helpers/pump_app.dart';

const _curriculum = 'mishnayos';
const _today = '2026-09-07';

String _ulid(int n) => '01J${n.toString().padLeft(23, '0')}';

SubTrack _track(
  int id, {
  String name = 'Rebbe Cohen',
  String start = '2026-09-01',
  String? end,
  bool ended = false,
}) => SubTrack(
  id: _ulid(id),
  curriculumId: _curriculum,
  name: name,
  type: SubTrackType.ongoing,
  windowStart: start,
  windowEnd: end,
  ratePerWeek: 5,
  weeksPerYear: 52,
  learnsOnShabbos: false,
  ground: const [],
  lastChangeId: _ulid(id + 500),
  endedAt: ended ? DateTime.utc(2026, 9, 2) : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

OngoingSubTrackContext _context(List<SubTrack> tracks) =>
    OngoingSubTrackContext(
      curriculumId: _curriculum,
      today: _today,
      subTracks: tracks,
      calendarProgram: false,
    );

/// Opens the form from a button so its pop result is observable.
class _Host extends StatefulWidget {
  const _Host({this.existing});

  final SubTrack? existing;

  @override
  State<_Host> createState() => _HostState();
}

OngoingSubTrackSaved? _lastResult;
bool _closed = false;

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          _lastResult = await openOngoingSubTrackForm(
            context,
            curriculumId: _curriculum,
            existing: widget.existing,
          );
          _closed = true;
        },
        child: const Text('open'),
      ),
    ),
  );
}

late FakeLearningCommands _commands;

/// English unit words, so the leaf-unit label is deterministic.
class _EnglishTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

List<Override> _overrides(List<SubTrack> tracks) => [
  useHebrewTermsProvider.overrideWith(_EnglishTerms.new),
  ongoingSubTrackContextProvider(
    _curriculum,
  ).overrideWith((ref) async => _context(tracks)),
  learningCommandsProvider.overrideWith((ref) async => _commands),
];

Future<void> _open(
  WidgetTester tester, {
  List<SubTrack> tracks = const [],
  SubTrack? existing,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  Size size = const Size(400, 900),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      overrides: _overrides(tracks),
      locale: locale,
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      child: _Host(existing: existing),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _field(String key) => find.byKey(ValueKey(key));

String _fieldText(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(of: _field(key), matching: find.byType(EditableText)),
    )
    .controller
    .text;

bool _switchValue(WidgetTester tester, String key) =>
    tester.widget<SwitchListTile>(_field(key)).value;

/// Scrolls the lazily built form until [key] is built and on screen.
Future<void> _reveal(WidgetTester tester, String key) async {
  await tester.dragUntilVisible(
    _field(key),
    find.byType(ListView).first,
    const Offset(0, -150),
  );
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await _reveal(tester, 'ongoingSubTrackSave');
  await tester.tap(_field('ongoingSubTrackSave'));
  await tester.pumpAndSettle();
}

Future<void> _pickDay(WidgetTester tester, String fieldKey, int day) async {
  await _reveal(tester, fieldKey);
  await tester.tap(_field(fieldKey));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text('$day'),
    ),
  );
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

SubTrackDraft _lastDraft() =>
    _commands.calls.lastWhere((c) => c.name == 'createSubTrack').args['draft']!
        as SubTrackDraft;

String get _leafUnit => CurriculumLabels.leaf(
  CurriculumId.mishnayos,
).inLanguage(useHebrew: false, plural: true);

void main() {
  setUp(() {
    _commands = FakeLearningCommands();
    _lastResult = null;
    _closed = false;
  });

  group('AC-1: the create form', () {
    testWidgets('shows every field with its default', (tester) async {
      await _open(tester, tracks: [_track(1), _track(2)]);
      expect(find.text('Ongoing sub-track'), findsOneWidget);
      expect(find.text('Sub-track name'), findsOneWidget);
      expect(find.text('$_leafUnit per week'), findsOneWidget);
      expect(_fieldText(tester, 'ongoingSubTrackRate'), '5');
      expect(find.text('Not learning during bein hazmanim'), findsOneWidget);
      expect(find.text('Lowers weeks per year'), findsOneWidget);
      expect(_switchValue(tester, 'ongoingSubTrackBeinHazmanim'), isFalse);
      expect(find.text('Weeks per year'), findsOneWidget);
      expect(_fieldText(tester, 'ongoingSubTrackWeeks'), '52');
      expect(find.text('Start date (optional)'), findsOneWidget);
      expect(find.text('End date (optional)'), findsOneWidget);
      expect(find.text('Learns on shabbos / yom tov'), findsOneWidget);
      expect(_switchValue(tester, 'ongoingSubTrackShabbos'), isFalse);
      expect(
        find.text('You can have up to 5 ongoing sub-tracks. 2 in use.'),
        findsOneWidget,
      );
      expect(find.text('Save sub-track'), findsOneWidget);
    });

    testWidgets('has no school-year-only fields', (tester) async {
      await _open(tester);
      expect(find.textContaining('Academic year'), findsNothing);
      expect(find.textContaining('Start month'), findsNothing);
      expect(find.textContaining('End month'), findsNothing);
    });

    testWidgets('usage line counts 0, 4 and excludes ended and expired', (
      tester,
    ) async {
      await _open(tester);
      expect(
        find.text('You can have up to 5 ongoing sub-tracks. 0 in use.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await _open(
        tester,
        tracks: [
          for (var i = 1; i <= 4; i++) _track(i),
          _track(10, ended: true),
          _track(11, end: '2026-09-01'),
        ],
      );
      expect(
        find.text('You can have up to 5 ongoing sub-tracks. 4 in use.'),
        findsOneWidget,
      );
    });
  });

  group('AC-2: the weeks prefill', () {
    testWidgets('untouched weeks follow the switch, with the helper', (
      tester,
    ) async {
      await _open(tester);
      const helper = 'Prefilled from bein hazmanim toggle — edit if needed';
      expect(find.text(helper), findsOneWidget);
      await tester.tap(_field('ongoingSubTrackBeinHazmanim'));
      await tester.pumpAndSettle();
      expect(_fieldText(tester, 'ongoingSubTrackWeeks'), '44');
      expect(find.text(helper), findsOneWidget);
      await tester.tap(_field('ongoingSubTrackBeinHazmanim'));
      await tester.pumpAndSettle();
      expect(_fieldText(tester, 'ongoingSubTrackWeeks'), '52');
    });

    testWidgets('a typed weeks value is never overwritten, and is saved', (
      tester,
    ) async {
      await _open(tester);
      await tester.enterText(_field('ongoingSubTrackName'), 'Chavrusa');
      await tester.enterText(_field('ongoingSubTrackWeeks'), '47');
      await tester.pump();
      expect(
        find.text('Prefilled from bein hazmanim toggle — edit if needed'),
        findsNothing,
      );
      await tester.tap(_field('ongoingSubTrackBeinHazmanim'));
      await tester.pumpAndSettle();
      expect(_fieldText(tester, 'ongoingSubTrackWeeks'), '47');
      await _save(tester);
      expect(_lastDraft().weeksPerYear, 47);
    });

    testWidgets('the switch on, untouched, saves 44 and nothing else', (
      tester,
    ) async {
      await _open(tester);
      await tester.enterText(_field('ongoingSubTrackName'), 'Rebbe');
      await tester.tap(_field('ongoingSubTrackBeinHazmanim'));
      await tester.pumpAndSettle();
      await _save(tester);
      final draft = _lastDraft();
      expect(draft.weeksPerYear, 44);
      expect(draft.type, SubTrackType.ongoing);
      expect(draft.academicYear, isNull);
      expect(draft.ground, isEmpty);
      expect(draft.curriculumId, _curriculum);
    });
  });

  group('AC-3: optional dates', () {
    testWidgets('no dates → start is the learner civil today, end open', (
      tester,
    ) async {
      await _open(tester);
      await tester.enterText(_field('ongoingSubTrackName'), 'Rebbe');
      await _save(tester);
      final draft = _lastDraft();
      expect(draft.windowStart, _today);
      expect(draft.windowEnd, isNull);
      expect(draft.ratePerWeek, 5);
      expect(draft.learnsOnShabbos, isFalse);
      expect(_closed, isTrue);
      expect(_lastResult, isNotNull);
      expect(_lastResult!.queued, isFalse);
    });

    testWidgets('an end before the start blocks save on the end field', (
      tester,
    ) async {
      await _open(tester);
      await tester.enterText(_field('ongoingSubTrackName'), 'Rebbe');
      await _pickDay(tester, 'ongoingSubTrackStart', 20);
      await _pickDay(tester, 'ongoingSubTrackEnd', 10);
      expect(
        find.text("The end date can't be before the start date"),
        findsOneWidget,
      );
      await _save(tester);
      expect(_commands.calls.where((c) => c.name == 'createSubTrack'), isEmpty);
      // Correcting the end clears the error and saves.
      await _pickDay(tester, 'ongoingSubTrackEnd', 20);
      expect(
        find.text("The end date can't be before the start date"),
        findsNothing,
      );
      await _save(tester);
      expect(_lastDraft().windowStart, '2026-09-20');
      expect(_lastDraft().windowEnd, '2026-09-20');
    });
  });

  group('AC-4: future start', () {
    testWidgets('a future start is written unchanged', (tester) async {
      await _open(tester);
      await tester.enterText(_field('ongoingSubTrackName'), 'Summer shiur');
      await _pickDay(tester, 'ongoingSubTrackStart', 28);
      await _save(tester);
      expect(_lastDraft().windowStart, '2026-09-28');
    });
  });

  group('AC-5: the limit on the form', () {
    testWidgets('a create at five in use is refused with no write', (
      tester,
    ) async {
      await _open(tester, tracks: [for (var i = 1; i <= 5; i++) _track(i)]);
      await tester.enterText(_field('ongoingSubTrackName'), 'Sixth');
      await _save(tester);
      expect(_commands.calls.where((c) => c.name == 'createSubTrack'), isEmpty);
      expect(_field('ongoingSubTrackLimitReached'), findsOneWidget);
    });

    testWidgets('a command-side ongoing_limit shows the limit message', (
      tester,
    ) async {
      _commands.nextResult = const CaptureResult.rejected(
        CaptureRejection.invalid,
        violations: [SubTrackViolation(SubTrackLimit.ongoingLimit)],
      );
      await _open(tester, tracks: [for (var i = 1; i <= 4; i++) _track(i)]);
      await tester.enterText(_field('ongoingSubTrackName'), 'Fifth');
      await _save(tester);
      expect(_field('ongoingSubTrackLimitReached'), findsOneWidget);
      expect(_closed, isFalse);
      expect(_fieldText(tester, 'ongoingSubTrackName'), 'Fifth');
    });

    testWidgets('editing one of five is not a create', (tester) async {
      final tracks = [for (var i = 1; i <= 5; i++) _track(i)];
      await _open(tester, tracks: tracks, existing: tracks.first);
      await tester.enterText(_field('ongoingSubTrackName'), 'Renamed');
      await _save(tester);
      final call = _commands.calls.single;
      expect(call.name, 'editSubTrack');
      expect((call.args['edit']! as SubTrackEdit).name, 'Renamed');
    });
  });

  group('AC-6: edit', () {
    testWidgets('a past end date goes alone through editSubTrack', (
      tester,
    ) async {
      final existing = _track(1);
      await _open(tester, tracks: [existing], existing: existing);
      expect(find.text('Edit ongoing sub-track'), findsOneWidget);
      expect(_fieldText(tester, 'ongoingSubTrackName'), 'Rebbe Cohen');
      await _pickDay(tester, 'ongoingSubTrackEnd', 5);
      await _save(tester);
      final call = _commands.calls.single;
      expect(call.name, 'editSubTrack');
      expect(call.args['subTrackId'], existing.id);
      final edit = call.args['edit']! as SubTrackEdit;
      expect(edit.windowEnd, '2026-09-05');
      expect(edit.name, isNull);
      expect(edit.ratePerWeek, isNull);
      expect(edit.weeksPerYear, isNull);
      expect(edit.windowStart, isNull);
      expect(edit.learnsOnShabbos, isNull);
      expect(_closed, isTrue);
    });

    testWidgets('saving an unchanged edit writes nothing and closes', (
      tester,
    ) async {
      final existing = _track(1);
      await _open(tester, tracks: [existing], existing: existing);
      await _save(tester);
      expect(_commands.calls, isEmpty);
      expect(_closed, isTrue);
    });

    testWidgets('the switch never overwrites the stored weeks', (tester) async {
      final existing = _track(1);
      await _open(tester, tracks: [existing], existing: existing);
      await tester.tap(_field('ongoingSubTrackBeinHazmanim'));
      await tester.pumpAndSettle();
      expect(_fieldText(tester, 'ongoingSubTrackWeeks'), '52');
    });
  });

  group('AC-7: failure recovery', () {
    testWidgets('an online failure keeps the values and retries them', (
      tester,
    ) async {
      _commands.nextResult = const CaptureResult.onlineRequired();
      await _open(tester);
      await tester.enterText(_field('ongoingSubTrackName'), 'Rebbe Levi');
      await tester.enterText(_field('ongoingSubTrackRate'), '3');
      await _pickDay(tester, 'ongoingSubTrackStart', 21);
      await _save(tester);
      expect(
        find.text("Couldn't save the sub-track. Your entries are kept."),
        findsOneWidget,
      );
      expect(_closed, isFalse);
      expect(_fieldText(tester, 'ongoingSubTrackName'), 'Rebbe Levi');
      expect(_fieldText(tester, 'ongoingSubTrackRate'), '3');
      final first = _lastDraft();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      final creates = _commands.calls.where((c) => c.name == 'createSubTrack');
      expect(creates, hasLength(2));
      final retried = _lastDraft();
      expect(retried.name, first.name);
      expect(retried.ratePerWeek, 3);
      expect(retried.windowStart, '2026-09-21');
      expect(_closed, isTrue);
    });

    testWidgets('a throwing command is a retryable failure', (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        pumpApp(
          overrides: [
            ongoingSubTrackContextProvider(
              _curriculum,
            ).overrideWith((ref) async => _context(const [])),
            learningCommandsProvider.overrideWith(
              (ref) async => throw StateError('offline'),
            ),
          ],
          child: const OngoingSubTrackFormScreen(curriculumId: _curriculum),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_field('ongoingSubTrackName'), 'Rebbe');
      await _save(tester);
      expect(
        find.text("Couldn't save the sub-track. Your entries are kept."),
        findsOneWidget,
      );
      expect(_fieldText(tester, 'ongoingSubTrackName'), 'Rebbe');
    });

    testWidgets('a queued offline save closes with queued and its ids', (
      tester,
    ) async {
      _commands.nextResult = const CaptureResult.success(
        changeIds: ['01JQUEUED00000000000000001'],
        queued: true,
      );
      await _open(tester);
      await tester.enterText(_field('ongoingSubTrackName'), 'Rebbe');
      await _save(tester);
      expect(_lastResult!.queued, isTrue);
      expect(_lastResult!.changeIds, ['01JQUEUED00000000000000001']);
    });

    testWidgets('a reversed window from the command marks the end field', (
      tester,
    ) async {
      _commands.nextResult = const CaptureResult.rejected(
        CaptureRejection.invalid,
        violations: [SubTrackViolation(SubTrackLimit.windowReversed)],
      );
      await _open(tester);
      await tester.enterText(_field('ongoingSubTrackName'), 'Rebbe');
      await _save(tester);
      expect(
        find.text("The end date can't be before the start date"),
        findsOneWidget,
      );
    });

    testWidgets('a load error offers retry', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          overrides: [
            ongoingSubTrackContextProvider(
              _curriculum,
            ).overrideWith((ref) async => throw StateError('read failed')),
          ],
          child: const OngoingSubTrackFormScreen(curriculumId: _curriculum),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Retry'), findsWidgets);
    });
  });

  group('edge: validation', () {
    testWidgets('blank name and zero rate block save with inline errors', (
      tester,
    ) async {
      await _open(tester);
      await tester.enterText(_field('ongoingSubTrackName'), '   ');
      await tester.enterText(_field('ongoingSubTrackRate'), '0');
      await tester.enterText(_field('ongoingSubTrackWeeks'), '0');
      await _save(tester);
      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Enter a number above 0'), findsNWidgets(2));
      expect(_commands.calls, isEmpty);
      await tester.enterText(_field('ongoingSubTrackName'), 'Rebbe');
      await tester.enterText(_field('ongoingSubTrackRate'), '2');
      await tester.enterText(_field('ongoingSubTrackWeeks'), '40');
      await tester.pump();
      expect(find.text('Enter a name'), findsNothing);
      await _save(tester);
      expect(_lastDraft().ratePerWeek, 2);
      expect(_lastDraft().weeksPerYear, 40);
    });

    testWidgets('a blurred blank name shows its error before save', (
      tester,
    ) async {
      await _open(tester);
      await tester.tap(_field('ongoingSubTrackName'));
      await tester.pump();
      await tester.tap(_field('ongoingSubTrackWeeks'));
      await tester.pump();
      expect(find.text('Enter a name'), findsOneWidget);
    });

    testWidgets('the stepper steps by one and never below one', (tester) async {
      await _open(tester);
      await tester.tap(_field('ongoingSubTrackRateIncrease'));
      await tester.pump();
      expect(_fieldText(tester, 'ongoingSubTrackRate'), '6');
      await tester.enterText(_field('ongoingSubTrackRate'), '1');
      await tester.pump();
      final decrease = tester.widget<IconButton>(
        _field('ongoingSubTrackRateDecrease'),
      );
      expect(decrease.onPressed, isNull);
      // Disabled, still in the semantics tree.
      expect(find.bySemanticsLabel('Fewer $_leafUnit per week'), findsWidgets);
    });

    testWidgets('a cleared end date reopens the window', (tester) async {
      final existing = _track(1, end: '2027-01-01');
      await _open(tester, tracks: [existing], existing: existing);
      await _reveal(tester, 'ongoingSubTrackEnd');
      await tester.tap(
        find.descendant(
          of: _field('ongoingSubTrackEnd'),
          matching: find.byTooltip('Clear date'),
        ),
      );
      await tester.pumpAndSettle();
      await _save(tester);
      final edit = _commands.calls.single.args['edit']! as SubTrackEdit;
      expect(edit.clearWindowEnd, isTrue);
    });
  });

  group('AC-7: dark, tablet, large text and RTL', () {
    testWidgets('steppers and the save pill are at least 48dp', (tester) async {
      await _open(tester);
      for (final key in [
        'ongoingSubTrackRateDecrease',
        'ongoingSubTrackRateIncrease',
        'ongoingSubTrackSave',
      ]) {
        final size = tester.getSize(_field(key));
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
      }
    });

    testWidgets('tablet: form capped at 600px beside the summary panel', (
      tester,
    ) async {
      await _open(
        tester,
        tracks: [
          _track(1, name: 'Rebbe Cohen'),
          _track(2, name: 'Chavrusa'),
        ],
        size: const Size(1280, 900),
        theme: AppTheme.themeFor(brightness: Brightness.dark),
      );
      expect(_field('ongoingSubTrackTabletSummary'), findsOneWidget);
      expect(find.text("This learner's sub-tracks"), findsOneWidget);
      expect(find.text('5/wk × 52 weeks'), findsNWidgets(2));
      expect(
        tester.getSize(find.byType(ListView).first).width,
        lessThanOrEqualTo(600),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark theme renders the form without errors', (tester) async {
      await _open(
        tester,
        theme: AppTheme.themeFor(brightness: Brightness.dark),
      );
      expect(
        Theme.of(tester.element(_field('ongoingSubTrackName'))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text at phone width does not overflow', (tester) async {
      await _open(tester, size: const Size(360, 800), textScale: 2);
      expect(tester.takeException(), isNull);
      await _reveal(tester, 'ongoingSubTrackSave');
      expect(_field('ongoingSubTrackSave'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hebrew renders right-to-left with Hebrew labels', (
      tester,
    ) async {
      await _open(tester, locale: const Locale('he'));
      expect(find.text('שם תת-המסלול'), findsOneWidget);
      expect(find.text('שמירת תת-המסלול'), findsOneWidget);
      expect(
        Directionality.of(tester.element(_field('ongoingSubTrackName'))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
