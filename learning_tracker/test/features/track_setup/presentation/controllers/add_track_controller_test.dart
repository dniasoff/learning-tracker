import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/presentation/controllers/add_track_controller.dart';
import 'package:learning_tracker/features/track_setup/presentation/controllers/add_track_flow_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _makeContainer() => ProviderContainer();

AddTrackControllerProvider _provider(ProviderContainer c) =>
    addTrackControllerProvider(1, isOnboarding: false);

AddTrackController _notifier(ProviderContainer c) =>
    c.read(_provider(c).notifier);

AddTrackFlowState _state(ProviderContainer c) => c.read(_provider(c));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AddTrackController — initial state', () {
    test('starts at CurriculumChoiceState', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      expect(_state(c), isA<CurriculumChoiceState>());
    });

    test('formData has no curriculumId on init', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      expect(_state(c).formData.curriculumId, isNull);
    });
  });

  group('AddTrackController — curriculum selection', () {
    test('onCurriculumSelected moves to ProgramChoiceState for Bavli', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      _notifier(c).onCurriculumSelected(CurriculumId.bavli);
      expect(_state(c), isA<ProgramChoiceState>());
      expect(_state(c).formData.curriculumId, CurriculumId.bavli);
    });

    test(
      'onCurriculumSelected moves to ScopeChoiceState for curriculum without programs',
      () {
        // parsha has no seeded programs
        final c = _makeContainer();
        addTearDown(c.dispose);
        _notifier(c).onCurriculumSelected(CurriculumId.chumash);
        expect(_state(c), isA<ScopeChoiceState>());
      },
    );

    test('onCurriculumSelected clears stale program data', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      // First pick mishnayos (has programs) and select a program
      _notifier(c).onCurriculumSelected(CurriculumId.mishnayos);
      _notifier(c).onProgramSelected(42, 'Daf Yomi', null);
      // Now switch to another curriculum — program data should clear
      _notifier(c).onCurriculumSelected(CurriculumId.bavli);
      expect(_state(c).formData.programId, isNull);
    });
  });

  group('AddTrackController — program selection', () {
    test('onProgramSelected with programId moves to StudyDaysState', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      _notifier(c).onCurriculumSelected(CurriculumId.bavli);
      _notifier(c).onProgramSelected(1, 'Daf Yomi', null);
      expect(_state(c), isA<StudyDaysState>());
      expect(_state(c).formData.programId, 1);
      expect(_state(c).formData.programName, 'Daf Yomi');
    });

    test('onProgramSelected with null programId moves to ScopeChoiceState', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      _notifier(c).onCurriculumSelected(CurriculumId.bavli);
      _notifier(c).onProgramSelected(null, null, null);
      expect(_state(c), isA<ScopeChoiceState>());
    });
  });

  group('AddTrackController — goBack()', () {
    test('returns false from CurriculumChoiceState (first step)', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      expect(_notifier(c).goBack(), isFalse);
    });

    test('returns true and goes back from ProgramChoiceState', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      _notifier(c).onCurriculumSelected(CurriculumId.bavli);
      expect(_state(c), isA<ProgramChoiceState>());
      expect(_notifier(c).goBack(), isTrue);
      expect(_state(c), isA<CurriculumChoiceState>());
    });

    test(
      'returns true and goes back from ScopeChoiceState (no program step)',
      () {
        final c = _makeContainer();
        addTearDown(c.dispose);
        _notifier(c).onCurriculumSelected(CurriculumId.chumash);
        expect(_state(c), isA<ScopeChoiceState>());
        expect(_notifier(c).goBack(), isTrue);
        expect(_state(c), isA<CurriculumChoiceState>());
      },
    );

    test('returns true and goes back from StudyDaysState (program track)', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      _notifier(c).onCurriculumSelected(CurriculumId.bavli);
      _notifier(c).onProgramSelected(1, 'Daf Yomi', null);
      expect(_state(c), isA<StudyDaysState>());
      expect(_notifier(c).goBack(), isTrue);
      expect(_state(c), isA<ProgramChoiceState>());
    });

    test('returns false from CompleteState', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      // Build a completed result and mark it
      _notifier(c).onCurriculumSelected(CurriculumId.chumash);
      const fakeResult = AddTrackResult(
        curriculumId: CurriculumId.chumash,
        label: 'test',
        studyDays: {1: 'sun', 2: 'mon'},
      );
      _notifier(c).markComplete(fakeResult);
      expect(_state(c), isA<CompleteState>());
      expect(_notifier(c).goBack(), isFalse);
    });
  });

  group('AddTrackController — full self-paced flow', () {
    test(
      'self-paced path: curriculum → scope → studyDays → stages → goal → confirmation',
      () {
        final c = _makeContainer();
        addTearDown(c.dispose);

        _notifier(c).onCurriculumSelected(CurriculumId.chumash);
        expect(_state(c), isA<ScopeChoiceState>());

        _notifier(
          c,
        ).onScopeComplete([const ScopeEntry(level: 1, value: 'Bereshit')]);
        expect(_state(c), isA<StudyDaysState>());

        _notifier(c).onStudyDaysComplete({1: 'sun', 2: 'mon'});
        expect(_state(c), isA<StagesChoiceState>());

        _notifier(c).onStagesComplete(null);
        expect(_state(c), isA<GoalChoiceState>());

        _notifier(c).onGoalComplete(null);
        expect(_state(c), isA<ConfirmationState>());
      },
    );

    test(
      'program path: curriculum → program → studyDays → stages → confirmation (skips scope and goal)',
      () {
        final c = _makeContainer();
        addTearDown(c.dispose);

        _notifier(c).onCurriculumSelected(CurriculumId.bavli);
        expect(_state(c), isA<ProgramChoiceState>());

        _notifier(c).onProgramSelected(1, 'Daf Yomi', null);
        expect(_state(c), isA<StudyDaysState>());

        _notifier(c).onStudyDaysComplete({1: 'sun', 2: 'mon'});
        expect(_state(c), isA<StagesChoiceState>());

        _notifier(c).onStagesComplete(null);
        expect(_state(c), isA<ConfirmationState>());
      },
    );
  });

  group('AddTrackController — buildResult()', () {
    test('buildResult returns correct AddTrackResult for self-paced track', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).onCurriculumSelected(CurriculumId.chumash);
      _notifier(
        c,
      ).onScopeComplete([const ScopeEntry(level: 1, value: 'Bereshit')]);
      _notifier(c).onStudyDaysComplete({1: 'sun', 2: 'mon'});
      _notifier(c).onStagesComplete(null);
      _notifier(c).onGoalComplete(null);

      // Simulate reaching ConfirmationState
      expect(_state(c), isA<ConfirmationState>());

      final result = _notifier(c).buildResult();
      expect(result.curriculumId, CurriculumId.chumash);
      expect(result.label, 'Bereshit'); // last scope entry value
      expect(result.programId, isNull);
      expect(result.studyDays, {1: 'sun', 2: 'mon'});
    });

    test('buildResult uses programName as label for program tracks', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).onCurriculumSelected(CurriculumId.bavli);
      _notifier(c).onProgramSelected(1, 'Daf Yomi', null);
      _notifier(c).onStudyDaysComplete({1: 'sun', 2: 'mon'});
      _notifier(c).onStagesComplete(null);

      final result = _notifier(c).buildResult();
      expect(result.label, 'Daf Yomi');
      expect(result.programId, 1);
    });
  });

  group('AddTrackController — markComplete()', () {
    test('moves to CompleteState with result', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      _notifier(c).onCurriculumSelected(CurriculumId.chumash);
      const fakeResult = AddTrackResult(
        curriculumId: CurriculumId.chumash,
        label: 'Bereshit',
        studyDays: {1: 'sun'},
      );
      _notifier(c).markComplete(fakeResult);
      final s = _state(c);
      expect(s, isA<CompleteState>());
      expect((s as CompleteState).result, fakeResult);
    });
  });

  group('AddTrackController — progress metrics', () {
    test('stepNumber and totalSteps are consistent throughout flow', () {
      final c = _makeContainer();
      addTearDown(c.dispose);

      // CurriculumChoiceState — step 1
      expect(_state(c).stepNumber, 1);

      _notifier(c).onCurriculumSelected(CurriculumId.chumash);
      final total = _state(c).totalSteps;
      expect(total, greaterThan(1));

      // stepNumber never exceeds totalSteps
      _notifier(c).onScopeComplete(null);
      expect(_state(c).stepNumber, lessThanOrEqualTo(total));

      _notifier(c).onStudyDaysComplete({1: 'sun'});
      expect(_state(c).stepNumber, lessThanOrEqualTo(total));
    });

    test('progressFraction is between 0 and 1', () {
      final c = _makeContainer();
      addTearDown(c.dispose);
      expect(_state(c).progressFraction, inInclusiveRange(0.0, 1.0));
      _notifier(c).onCurriculumSelected(CurriculumId.chumash);
      expect(_state(c).progressFraction, inInclusiveRange(0.0, 1.0));
    });
  });
}
