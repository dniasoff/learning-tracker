import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/add_track_step.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/profile_creation_step.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:learning_tracker/features/onboarding/presentation/steps/profile_creation_step.dart'
    show childAwareText, kOnboardingComplete;

@RoutePage()
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// Shared mutable model passed between steps.
  late final OnboardingProfileData _data;

  // Track count state updated by OnboardingAddTrackStep callbacks.
  int _trackCount = 0;
  String? _lastTrackLabel;

  @override
  void initState() {
    super.initState();
    _data = OnboardingProfileData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = ref.read(authStateProvider);
      if (!authState.isSignedIn) {
        unawaited(context.router.replaceAll([const SignInRoute()]));
        return;
      }
      _initSteps();
    });
  }

  List<OnboardingStep> _buildSteps() {
    return [
      ProfileCreationStep(data: _data),
      if (_data.isChildMode) ParentPinSetupStep(data: _data),
      OnboardingAddTrackStep(
        data: _data,
        onTrackAdded: (AddTrackResult result) {
          setState(() {
            _trackCount++;
            _lastTrackLabel = result.label;
          });
        },
        onCancel: _handleAddTrackCancel,
      ),
      AddAnotherPromptStep(
        data: _data,
        trackCount: _trackCount,
        lastTrackLabel: _lastTrackLabel,
        onAddAnother: _handleAddAnotherTrack,
        onStartLearning: _handleStartLearning,
      ),
      if (_data.isChildMode)
        HandoffStep(
          data: _data,
          onStartLearning: _navigateToDashboard,
          onAddAnotherTrack: _handleAddAnotherTrack,
          onAddAnotherLearner: _handleAddAnotherLearner,
        ),
    ];
  }

  Future<void> _initSteps() async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    await controller.init(_buildSteps());
  }

  /// Rebuild the step list and jump to the step with the given [stepId].
  Future<void> _rebuildAndJumpTo(String stepId) async {
    final newSteps = _buildSteps();
    final controller = ref.read(onboardingControllerProvider.notifier);
    await controller.init(newSteps);
    final idx = newSteps.indexWhere((s) => s.id == stepId);
    if (idx > 0) await controller.jumpTo(idx);
  }

  // ── Callbacks ─────────────────────────────────────────────────────────────

  void _handleAddTrackCancel() {
    if (_data.createdProfileId == null) {
      _rebuildAndJumpTo('profileCreation');
      return;
    }
    if (_data.isChildMode) {
      _rebuildAndJumpTo('handoff');
    } else {
      _navigateToDashboard();
    }
  }

  void _handleAddAnotherTrack() {
    _rebuildAndJumpTo('addTrack');
  }

  void _handleStartLearning() {
    if (_data.isChildMode) {
      _rebuildAndJumpTo('handoff');
    } else {
      _navigateToDashboard();
    }
  }

  Future<void> _handleAddAnotherLearner() async {
    _data
      ..createdProfileId = null
      ..profileName = null
      ..profileMode = 'adult'
      ..showNikud = true;
    setState(() {
      _trackCount = 0;
      _lastTrackLabel = null;
    });
    await _rebuildAndJumpTo('profileCreation');
  }

  Future<void> _navigateToDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingComplete, true);
    if (!mounted) return;
    final repo = ref.read(profileRepositoryProvider);
    final profiles = await repo.getProfilesByAccount(
      ref.read(currentAccountIdProvider),
    );
    if (!mounted) return;
    if (profiles.length >= 2) {
      unawaited(context.router.replaceAll([const ProfilePickerRoute()]));
    } else {
      unawaited(context.router.replaceAll([const AppShellRoute()]));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  /// Returns the AppBar title widget for the given step, or null when the
  /// step manages its own app bar (e.g. AddTrackFlow).
  Widget? _appBarTitleFor(OnboardingStep step) {
    return switch (step.id) {
      'profileCreation' => null,
      'parentPinSetup' => const ParentPinSetupAppBarTitle(),
      'addTrack' => null, // AddTrackFlow has its own progress indicator.
      'addAnotherPrompt' => const AddAnotherPromptAppBarTitle(),
      'handoff' => const HandoffAppBarTitle(),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(onboardingControllerProvider);

    if (controllerState.steps.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentStep = controllerState.currentStep;
    final ctx = OnboardingStepContext(
      advance: () => ref.read(onboardingControllerProvider.notifier).advance(),
      retreat: () => ref.read(onboardingControllerProvider.notifier).retreat(),
      stepIndex: controllerState.currentIndex,
      totalSteps: controllerState.steps.length,
    );

    final appBarTitleWidget = _appBarTitleFor(currentStep);
    final showAppBar = appBarTitleWidget != null;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: appBarTitleWidget) : null,
      body: DecoratedBox(
        decoration: onboardingGradientDecoration(),
        child: SafeArea(child: currentStep.build(context, ref, ctx)),
      ),
    );
  }
}
