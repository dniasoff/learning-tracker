@Tags(['needs_flutter', 'gamification', 'reward_config'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_config_controller.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/reward_configuration_screen.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_form.dart';

import '../../../../helpers/pump_app.dart';

class _FakeController extends RewardConfigController {
  _FakeController({
    this.initial = const RewardForm(),
    this.result = const RewardSaveInvalidInput(),
    this.errorOnSave,
  });
  final RewardForm initial;
  final RewardSaveResult result;
  final String? errorOnSave;
  int saveCalls = 0;

  @override
  RewardForm build() => initial;

  @override
  Future<void> bootstrap() async {}

  @override
  Future<RewardSaveResult> saveReward() async {
    saveCalls++;
    if (errorOnSave != null) {
      state = state.copyWith(error: errorOnSave);
    }
    return result;
  }
}

void main() {
  testWidgets('renders the current global reward form', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          rewardConfigControllerProvider.overrideWith(
            () => _FakeController(
              initial: const RewardForm(name: 'Prize', pointsText: '50'),
            ),
          ),
        ],
        child: const RewardConfigurationScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final nameField = tester.widget<TextField>(find.byType(TextField).first);
    expect(nameField.controller?.text, 'Prize');
    expect(find.text('Save Reward'), findsOneWidget);
  });

  testWidgets('invalid save result leaves the form visible', (tester) async {
    final fake = _FakeController(
      initial: const RewardForm(name: 'Prize', pointsText: '50'),
    );
    await tester.pumpWidget(
      pumpApp(
        overrides: [rewardConfigControllerProvider.overrideWith(() => fake)],
        child: const RewardConfigurationScreen(),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Save Reward', skipOffstage: false),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save Reward'));
    await tester.pump();
    expect(fake.saveCalls, 1);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      'Prize',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      '50',
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Save Reward'), findsOneWidget);
  });

  testWidgets('save failure renders the localized error state', (tester) async {
    final fake = _FakeController(
      initial: const RewardForm(name: 'Prize', pointsText: '50'),
      result: const RewardSaveFailed(),
      errorOnSave: 'backend unavailable',
    );
    await tester.pumpWidget(
      pumpApp(
        overrides: [rewardConfigControllerProvider.overrideWith(() => fake)],
        child: const RewardConfigurationScreen(),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Save Reward', skipOffstage: false),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save Reward'));
    await tester.pump();

    expect(fake.saveCalls, 1);
    expect(find.text('Error: backend unavailable'), findsOneWidget);
    expect(find.text('Save Reward'), findsNothing);
  });
}
