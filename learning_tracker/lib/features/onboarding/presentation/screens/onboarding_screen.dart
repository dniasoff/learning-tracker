import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/suggested_thresholds_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/learning_process_wizard_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/rewards_setup_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/scope_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Returns child-aware text based on profile mode.
///
/// In adult mode, returns [adultText]. In child mode, replaces `{name}`
/// in [childTemplate] with [childName].
String childAwareText(
  String adultText,
  String childTemplate,
  String? childName, {
  bool isChildMode = false,
}) {
  if (!isChildMode || childName == null) return adultText;
  return childTemplate.replaceAll('{name}', childName);
}

@RoutePage()
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _ScreenPhase {
  profileCreation,
  languageSelection,
  selection,
  importing,
  scopeSelection,
  learningProcessWizard,
  bulkMark,
  goalSetup,
  rewardsSetup,
  handoff,
  done,
  error,
}

enum _CurriculumStatus { notStarted, importing, done, failed }

// SharedPreferences keys for onboarding state persistence
const _kOnboardingPhase = 'onboarding_phase';
const _kOnboardingProfileId = 'onboarding_profile_id';
const _kOnboardingProfileName = 'onboarding_profile_name';
const _kOnboardingProfileMode = 'onboarding_profile_mode';
const _kOnboardingSelectedCurricula = 'onboarding_selected_curricula';
const _kOnboardingLanguage = 'onboarding_language';

/// Supported content languages.
const _supportedLanguages = <String, String>{
  'he': 'עברית (Hebrew with nikud)',
  'he_plain': 'עברית (Hebrew without nikud)',
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
  'it': 'Italiano',
};

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _selected = <CurriculumId>{};
  String _selectedLanguage = 'he';
  var _phase = _ScreenPhase.profileCreation;
  CurriculumImportProgress? _importProgress;
  List<CurriculumImportResult> _failures = [];
  int _originalTotal = 0;
  final _curriculumStatuses = <CurriculumId, _CurriculumStatus>{};

  // Profile creation state
  final _nameController = TextEditingController();
  String _profileMode = 'adult'; // 'adult' or 'child'
  int? _createdProfileId;
  String? _profileName;

  void _updateStatuses(CurriculumImportProgress progress) {
    for (final result in progress.results) {
      _curriculumStatuses[result.curriculumId] = result.success
          ? _CurriculumStatus.done
          : _CurriculumStatus.failed;
    }
    if (!progress.results.any(
      (r) => r.curriculumId == progress.currentCurriculum,
    )) {
      _curriculumStatuses[progress.currentCurriculum] =
          _CurriculumStatus.importing;
    }
  }

  // Scope selection state
  late List<CurriculumId> _scopeQueue;
  int _scopeIndex = 0;

  // Wizard state
  late List<CurriculumId> _wizardQueue;
  int _wizardIndex = 0;
  bool _wizardLaunched = false;

  // Bulk mark state
  late List<CurriculumId> _bulkMarkQueue;
  int _bulkMarkIndex = 0;
  bool _bulkMarkLaunched = false;

  // Goal setup state
  late List<CurriculumId> _goalSetupQueue;
  int _goalSetupIndex = 0;

  bool get _isChildMode => _profileMode == 'child';

  @override
  void initState() {
    super.initState();
    _tryResumeFromSavedState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _tryResumeFromSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhase = prefs.getString(_kOnboardingPhase);
    if (savedPhase == null) return;

    final profileId = prefs.getInt(_kOnboardingProfileId);
    final profileName = prefs.getString(_kOnboardingProfileName);
    final profileMode = prefs.getString(_kOnboardingProfileMode);
    final curriculaJson = prefs.getString(_kOnboardingSelectedCurricula);

    if (profileId != null) _createdProfileId = profileId;
    if (profileName != null) _profileName = profileName;
    if (profileMode != null) _profileMode = profileMode;

    if (curriculaJson != null) {
      final list = (jsonDecode(curriculaJson) as List<dynamic>).cast<String>();
      for (final name in list) {
        final match = CurriculumId.values.where((c) => c.name == name);
        if (match.isNotEmpty) _selected.add(match.first);
      }
    }

    final savedLanguage = prefs.getString(_kOnboardingLanguage);
    if (savedLanguage != null) _selectedLanguage = savedLanguage;

    final phase = _ScreenPhase.values.where((p) => p.name == savedPhase);
    if (phase.isNotEmpty && mounted) {
      final resumedPhase = phase.first;

      // Reinitialize queues so late variables are available after resume.
      final selectedList = _selected.toList();
      if (resumedPhase == _ScreenPhase.scopeSelection ||
          resumedPhase == _ScreenPhase.learningProcessWizard ||
          resumedPhase == _ScreenPhase.bulkMark ||
          resumedPhase == _ScreenPhase.goalSetup) {
        _scopeQueue = selectedList;
        _scopeIndex = 0;
        _wizardQueue = selectedList;
        _wizardIndex = 0;
        _bulkMarkQueue = selectedList;
        _bulkMarkIndex = 0;
        _goalSetupQueue = selectedList;
        _goalSetupIndex = 0;
      }

      setState(() => _phase = resumedPhase);
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOnboardingPhase, _phase.name);
    if (_createdProfileId != null) {
      await prefs.setInt(_kOnboardingProfileId, _createdProfileId!);
    }
    if (_profileName != null) {
      await prefs.setString(_kOnboardingProfileName, _profileName!);
    }
    await prefs.setString(_kOnboardingProfileMode, _profileMode);
    await prefs.setString(
      _kOnboardingSelectedCurricula,
      jsonEncode(_selected.map((c) => c.name).toList()),
    );
    await prefs.setString(_kOnboardingLanguage, _selectedLanguage);
  }

  Future<void> _clearSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOnboardingPhase);
    await prefs.remove(_kOnboardingProfileId);
    await prefs.remove(_kOnboardingProfileName);
    await prefs.remove(_kOnboardingProfileMode);
    await prefs.remove(_kOnboardingSelectedCurricula);
    await prefs.remove(_kOnboardingLanguage);
  }

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final repo = ref.read(profileRepositoryProvider);
    final profile = await repo.createProfile(
      accountId: 1,
      displayName: name,
      mode: _profileMode,
    );

    // Set user mode via profile service
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user != null) {
      final profileService = ref.read(userProfileServiceProvider);
      await profileService.setUserMode(
        firebaseUid: user.uid,
        displayName: name,
        mode: _profileMode == 'child' ? UserMode.child : UserMode.adult,
      );
    }

    _createdProfileId = profile.id;
    _profileName = name;
    ref.read(activeProfileIdProvider.notifier).switchTo(profile.id);

    setState(() => _phase = _ScreenPhase.languageSelection);
    await _saveState();
  }

  void _onLanguageSelected() {
    setState(() => _phase = _ScreenPhase.selection);
    _saveState();
  }

  Future<void> _startImport() async {
    if (_selected.isEmpty) return;

    setState(() {
      _phase = _ScreenPhase.importing;
      _originalTotal = _selected.length;
      for (final id in _selected) {
        _curriculumStatuses[id] = _CurriculumStatus.notStarted;
      }
    });
    await _saveState();

    final service = ref.read(curriculumImportServiceProvider);

    await for (final progress in service.importAll(_selected.toList())) {
      if (!mounted) return;
      setState(() {
        _importProgress = progress;
        _updateStatuses(progress);
      });
    }

    if (!mounted) return;

    final failures = _importProgress?.failures ?? [];
    if (failures.isEmpty) {
      _startLearningProcessWizard();
    } else {
      setState(() {
        _phase = _ScreenPhase.error;
        _failures = failures;
      });
    }
  }

  Future<void> _retryFailed() async {
    if (_failures.isEmpty) return;

    setState(() {
      _phase = _ScreenPhase.importing;
      for (final f in _failures) {
        _curriculumStatuses[f.curriculumId] = _CurriculumStatus.notStarted;
      }
    });

    final service = ref.read(curriculumImportServiceProvider);
    final failedIds = _failures.map((f) => f.curriculumId).toList();

    await for (final progress in service.importAll(failedIds)) {
      if (!mounted) return;
      setState(() {
        _importProgress = progress;
        _updateStatuses(progress);
      });
    }

    if (!mounted) return;

    final newFailures = _importProgress?.failures ?? [];
    if (newFailures.isEmpty) {
      _startLearningProcessWizard();
    } else {
      setState(() {
        _phase = _ScreenPhase.error;
        _failures = newFailures;
      });
    }
  }

  void _startLearningProcessWizard() {
    _wizardQueue = _selected.toList();
    _wizardIndex = 0;
    if (_wizardQueue.isEmpty) {
      _startScopeSelection();
      return;
    }
    setState(() => _phase = _ScreenPhase.learningProcessWizard);
    _saveState();
  }

  Future<void> _onWizardResult(LearningProcessWizardResult? result) async {
    if (result != null) {
      final wizardService = ref.read(learningProcessWizardServiceProvider);
      await wizardService.applyWizardResult(
        result.wizardResult,
        profileId: _createdProfileId!,
      );
    }
    _wizardIndex++;
    if (_wizardIndex >= _wizardQueue.length) {
      _startScopeSelection();
    } else {
      _wizardLaunched = false;
      setState(() {});
    }
  }

  void _startScopeSelection() {
    _scopeQueue = _selected.toList();
    _scopeIndex = 0;
    if (_scopeQueue.isEmpty) {
      _startBulkMark();
      return;
    }
    setState(() => _phase = _ScreenPhase.scopeSelection);
    _saveState();
  }

  void _onScopeSelectionDone() {
    _scopeIndex++;
    if (_scopeIndex >= _scopeQueue.length) {
      _startBulkMark();
    } else {
      setState(() {});
    }
  }

  void _startBulkMark() {
    _bulkMarkQueue = _selected.toList();
    _bulkMarkIndex = 0;
    if (_bulkMarkQueue.isEmpty) {
      _startGoalSetup();
      return;
    }
    setState(() => _phase = _ScreenPhase.bulkMark);
    _saveState();
  }

  Future<void> _onBulkMarkResult(BulkMarkResult? result) async {
    _bulkMarkIndex++;
    if (_bulkMarkIndex >= _bulkMarkQueue.length) {
      _startGoalSetup();
    } else {
      setState(() {});
    }
  }

  void _startGoalSetup() {
    _goalSetupQueue = _selected.toList();
    _goalSetupIndex = 0;
    if (_goalSetupQueue.isEmpty) {
      _afterGoalSetup();
      return;
    }
    setState(() => _phase = _ScreenPhase.goalSetup);
    _saveState();
  }

  Future<void> _onGoalResult(GoalFormResult? result) async {
    if (result != null) {
      final goalRepo = ref.read(goalRepositoryProvider);
      await goalRepo.createGoal(
        curriculumId: _goalSetupQueue[_goalSetupIndex],
        targetPercent: result.targetPercent,
        targetDate: result.targetDate,
        description: result.description,
        dateType: result.dateType,
        goalType: result.goalType,
        paceValue: result.paceValue,
        paceUnit: result.paceUnit,
      );
      ref.invalidate(allDailyTasksProvider);
    }
    _goalSetupIndex++;
    if (_goalSetupIndex >= _goalSetupQueue.length) {
      _afterGoalSetup();
    } else {
      setState(() {});
    }
  }

  void _afterGoalSetup() {
    if (_isChildMode) {
      unawaited(
        _startRewardsSetup().catchError((Object e) {
          AppLogger.instance.error('Failed to start rewards setup: $e');
        }),
      );
    } else {
      // Adult mode: skip rewards and handoff, go straight to done
      _finishOnboarding();
    }
  }

  Future<void> _startRewardsSetup() async {
    setState(() => _phase = _ScreenPhase.rewardsSetup);
    await _saveState();
  }

  Future<void> _onRewardsResult(RewardSetupResult? result) async {
    if (result != null && result.rewards.isNotEmpty) {
      final rewardService = ref.read(rewardServiceProvider);
      for (final entry in result.rewards) {
        await rewardService.addReward(
          title: entry.title,
          description: entry.description,
          pointsThreshold: entry.pointsThreshold,
        );
      }
    }
    // Child mode goes to handoff screen
    setState(() => _phase = _ScreenPhase.handoff);
    await _saveState();
  }

  List<int> _computeSuggestedThresholds() {
    // After import, content is cached in the repository. Try to read
    // totalItems from already-imported results; fall back to defaults.
    var totalItems = 0;
    for (final result in _curriculumStatuses.entries) {
      if (result.value == _CurriculumStatus.done) {
        // Use import result item counts if available
        final importResult = _importProgress?.results
            .where((r) => r.curriculumId == result.key && r.success)
            .firstOrNull;
        totalItems += importResult?.itemCount ?? 0;
      }
    }
    final dailyPace = totalItems > 0 ? (totalItems / 365).ceil() : 5;
    return SuggestedThresholdsService.calculate(
      totalItems: totalItems,
      dailyPace: dailyPace,
    );
  }

  Future<void> _finishOnboarding() async {
    setState(() => _phase = _ScreenPhase.done);
    await _clearSavedState();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      unawaited(context.router.replaceAll([const AppShellRoute()]));
    }
  }

  Future<void> _addAnotherLearner() async {
    // Reset state for a new profile but keep the flow going
    _nameController.clear();
    _selected.clear();
    _createdProfileId = null;
    _profileName = null;
    _profileMode = 'adult';
    setState(() => _phase = _ScreenPhase.profileCreation);
    await _saveState();
  }

  Future<void> _startLearningFromHandoff() async {
    await _clearSavedState();
    if (!mounted) return;
    // If 2+ profiles, go to profile picker; otherwise dashboard
    final repo = ref.read(profileRepositoryProvider);
    final profiles = await repo.getProfilesByAccount(1);
    if (!mounted) return;
    if (profiles.length >= 2) {
      unawaited(context.router.replaceAll([const ProfilePickerRoute()]));
    } else {
      unawaited(context.router.replaceAll([const AppShellRoute()]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final showAppBar = _phase != _ScreenPhase.selection;
    final appBarTitle = switch (_phase) {
      _ScreenPhase.profileCreation => 'Add a Learner',
      _ScreenPhase.languageSelection => 'Choose Language',
      _ScreenPhase.handoff => 'Setup Complete!',
      _ => 'Onboarding',
    };

    return Scaffold(
      appBar: showAppBar ? AppBar(title: AppBarTitle(text: appBarTitle)) : null,
      body: SafeArea(
        child: switch (_phase) {
          _ScreenPhase.profileCreation => _buildProfileCreation(theme),
          _ScreenPhase.languageSelection => _buildLanguageSelection(theme),
          _ScreenPhase.selection => _buildSelection(theme),
          _ScreenPhase.importing => _buildImporting(theme),
          _ScreenPhase.scopeSelection => _buildScopeSelection(theme),
          _ScreenPhase.learningProcessWizard => _buildLearningProcessWizard(
            theme,
          ),
          _ScreenPhase.bulkMark => _buildBulkMark(theme),
          _ScreenPhase.goalSetup => _buildGoalSetup(theme),
          _ScreenPhase.rewardsSetup => _buildRewardsSetup(theme),
          _ScreenPhase.handoff => _buildHandoff(theme),
          _ScreenPhase.done => _buildDone(theme),
          _ScreenPhase.error => _buildError(theme),
        },
      ),
    );
  }

  Widget _buildProfileCreation(ThemeData theme) {
    final prompt = _profileMode == 'child'
        ? 'What is your child\'s name?'
        : 'What\'s your name?';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              prompt,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'adult', label: Text('Adult')),
                ButtonSegment(value: 'child', label: Text('Child')),
              ],
              selected: {_profileMode},
              onSelectionChanged: (value) {
                setState(() => _profileMode = value.first);
              },
            ),
            const Spacer(),
            FilledButton(
              onPressed: _nameController.text.trim().isNotEmpty
                  ? _createProfile
                  : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'Choose your preferred language for content',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'You can change this later in Settings.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _supportedLanguages.length,
            itemBuilder: (context, index) {
              final entry = _supportedLanguages.entries.elementAt(index);
              final isSelected = _selectedLanguage == entry.key;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Card(
                  elevation: isSelected ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _selectedLanguage = entry.key),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.value,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : null,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            )
                          else
                            Icon(
                              Icons.circle_outlined,
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: FilledButton(
            onPressed: _onLanguageSelected,
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _buildSelection(ThemeData theme) {
    const green = Color(0xFF4ADE80);
    final isEnabled = _selected.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button and step indicator
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: IconButton(
                      onPressed: () => setState(
                        () => _phase = _ScreenPhase.languageSelection,
                      ),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 14),
                      style:
                          IconButton.styleFrom(foregroundColor: Colors.white),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Step 2 of 3',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Fancy progress bar with glow
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: 2 / 3,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF22C55E),
                              green,
                              Color(0xFF86EFAC),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: green.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Choose Your\nLearning Path',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Select the areas of Torah you wish to track.\nYou can select multiple options.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: CurriculumId.values.length,
            itemBuilder: (context, index) {
              final curriculum = CurriculumId.values[index];
              return _CurriculumCard(
                curriculum: curriculum,
                isSelected: _selected.contains(curriculum),
                onTap: () {
                  setState(() {
                    if (_selected.contains(curriculum)) {
                      _selected.remove(curriculum);
                    } else {
                      _selected.add(curriculum);
                    }
                  });
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'You can add or remove curricula anytime.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: isEnabled
                  ? const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
                    )
                  : null,
              color: isEnabled ? null : Colors.white.withValues(alpha: 0.08),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: green.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isEnabled ? _startImport : null,
                borderRadius: BorderRadius.circular(28),
                child: Center(
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      color: isEnabled
                          ? Colors.black
                          : Colors.white.withValues(alpha: 0.3),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImporting(ThemeData theme) {
    final progress = _importProgress;
    final doneCount = _curriculumStatuses.values
        .where((s) => s == _CurriculumStatus.done)
        .length;
    final fraction = _originalTotal > 0 ? doneCount / _originalTotal : 0.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Importing curricula...', style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            if (progress != null) ...[
              LinearProgressIndicator(value: fraction),
              const SizedBox(height: 16),
              Text(
                '$doneCount/$_originalTotal complete',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              for (final id in _selected)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          id.displayNameEn,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: LinearProgressIndicator(
                          value: switch (_curriculumStatuses[id]) {
                            _CurriculumStatus.done => 1.0,
                            _CurriculumStatus.failed => 1.0,
                            _CurriculumStatus.importing => null,
                            _ => 0.0,
                          },
                          color:
                              _curriculumStatuses[id] ==
                                  _CurriculumStatus.failed
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: switch (_curriculumStatuses[id]) {
                          _CurriculumStatus.done => Icon(
                            Icons.check_circle,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          _CurriculumStatus.failed => Icon(
                            Icons.error,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          _CurriculumStatus.importing => const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          _ => const SizedBox.shrink(),
                        },
                      ),
                    ],
                  ),
                ),
            ] else ...[
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSelection(ThemeData theme) {
    final curriculum = _scopeQueue[_scopeIndex];
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'Set Learning Scope',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Choose which parts of ${curriculum.displayNameEn} to track, '
              'or skip to track everything.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              '${_scopeIndex + 1} of ${_scopeQueue.length}',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(child: ScopeSelectionScreen(curriculumId: curriculum)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onScopeSelectionDone,
                    child: const Text('Skip (Track All)'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _onScopeSelectionDone,
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningProcessWizard(ThemeData theme) {
    final curriculum = _wizardQueue[_wizardIndex];

    if (!_wizardLaunched) {
      _wizardLaunched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final wizardService = ref.read(learningProcessWizardServiceProvider);
        final presets = await wizardService.getPresetsForCurriculum(curriculum);
        if (!mounted) return;

        if (!mounted) return;
        final result = await Navigator.of(context)
            .push<LearningProcessWizardResult>(
              MaterialPageRoute<LearningProcessWizardResult>(
                builder: (_) => LearningProcessWizardScreen(
                  curriculumId: curriculum,
                  presets: presets,
                  isChildMode: _isChildMode,
                  childName: _isChildMode ? _profileName : null,
                ),
              ),
            );
        if (mounted) {
          _wizardLaunched = false;
          await _onWizardResult(result);
        }
      });
    }

    final headerText = childAwareText(
      'Set up review schedule for ${curriculum.displayNameEn}',
      'How does {name} review ${curriculum.displayNameEn}?',
      _profileName,
      isChildMode: _isChildMode,
    );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            headerText,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${_wizardIndex + 1} of ${_wizardQueue.length}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBulkMark(ThemeData theme) {
    final curriculum = _bulkMarkQueue[_bulkMarkIndex];

    if (!_bulkMarkLaunched) {
      _bulkMarkLaunched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final result = await Navigator.of(context).push<BulkMarkResult>(
          MaterialPageRoute<BulkMarkResult>(
            builder: (_) => BulkMarkScreen(curriculumId: curriculum),
          ),
        );
        if (mounted) {
          _bulkMarkLaunched = false;
          await _onBulkMarkResult(result);
        }
      });
    }

    final headerText = childAwareText(
      'Mark prior completions for ${curriculum.displayNameEn}',
      'Mark what {name} has completed in ${curriculum.displayNameEn}',
      _profileName,
      isChildMode: _isChildMode,
    );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            headerText,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${_bulkMarkIndex + 1} of ${_bulkMarkQueue.length}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSetup(ThemeData theme) {
    final curriculum = _goalSetupQueue[_goalSetupIndex];
    // Try to get totalItems from already-downloaded content
    final contentAsync = ref.watch(curriculumContentProvider(curriculum));
    final totalItems = contentAsync.whenOrNull<int>(
      data: (items) => items.where((i) => i.isLeaf).length,
    );

    const green = Color(0xFF4ADE80);

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button row
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon:
                            const Icon(Icons.arrow_back_ios_new, size: 14),
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const Spacer(),
                    // Step counter badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: green.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        '${_goalSetupIndex + 1} of ${_goalSetupQueue.length}',
                        style: const TextStyle(
                          color: green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: 1.0, // Step 3 of 3
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF22C55E),
                                green,
                                Color(0xFF86EFAC),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: green.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Set Your\nLearning Goal',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  childAwareText(
                    'How much do you want to learn?',
                    'How much should {name} learn?',
                    _profileName,
                    isChildMode: _isChildMode,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Goal setup card
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Daily Page Goal card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.auto_stories,
                                color: green,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Daily Page Goal',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Fix a set amount to learn every day.',
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.4),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF22C55E),
                                    green,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: green.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.black,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Curriculum info badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: green.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: green.withValues(alpha: 0.7),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            totalItems != null
                                ? 'Setting goal for ${curriculum.displayNameEn} ($totalItems items)'
                                : 'Setting goal for ${curriculum.displayNameEn}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Set Goal button
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: green.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final result = await Navigator.of(context)
                            .push<GoalFormResult>(
                          MaterialPageRoute<GoalFormResult>(
                            builder: (_) => GoalSetupScreen(
                              curriculumId: curriculum,
                              totalItems: totalItems,
                            ),
                          ),
                        );
                        if (mounted) {
                          await _onGoalResult(result);
                        }
                      },
                      borderRadius: BorderRadius.circular(28),
                      child: const Center(
                        child: Text(
                          'Set Goal',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Skip button
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onGoalResult(null),
                      borderRadius: BorderRadius.circular(28),
                      child: Center(
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsSetup(ThemeData theme) {
    final thresholds = _computeSuggestedThresholds();
    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Set up mystery rewards',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Add rewards your child can earn by learning!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  final result = await Navigator.of(context)
                      .push<RewardSetupResult>(
                        MaterialPageRoute<RewardSetupResult>(
                          builder: (_) => RewardsSetupScreen(
                            suggestedThresholds: thresholds,
                          ),
                        ),
                      );
                  if (mounted) {
                    await _onRewardsResult(result);
                  }
                },
                child: const Text('Set Up Rewards'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _onRewardsResult(null),
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandoff(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                "${_profileName ?? 'Your child'}'s learning is all set up",
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Hand the device to ${_profileName ?? 'your child'} to start learning',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: _startLearningFromHandoff,
                child: const Text('Start Learning'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _addAnotherLearner,
                child: const Text('Add Another Learner'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDone(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('All set!', style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Some imports failed', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final failure in _failures)
              Text(
                '${failure.curriculumId.displayNameEn}: ${failure.error}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _retryFailed,
              child: const Text('Retry Failed'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurriculumCard extends StatelessWidget {
  const _CurriculumCard({
    required this.curriculum,
    required this.isSelected,
    required this.onTap,
  });

  final CurriculumId curriculum;
  final bool isSelected;
  final VoidCallback onTap;

  String get _description => switch (curriculum) {
    CurriculumId.mishnayos => 'Six orders of the oral law.',
    CurriculumId.bavli => 'The Babylonian Talmud.',
    CurriculumId.yerushalmi => 'The Jerusalem Talmud.',
    CurriculumId.mishnaBerurah => 'Halachic commentary on Orach Chayim.',
    CurriculumId.chumash => 'The Five Books of Moses.',
    CurriculumId.torah => 'The Written Torah.',
    CurriculumId.tanach => 'Torah, Prophets, and Writings.',
    CurriculumId.nach => 'Prophets and Writings.',
    CurriculumId.mussar => 'Ethical and moral teachings.',
  };

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF4ADE80);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected
                ? green.withValues(alpha: 0.06)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(
                color: isSelected
                    ? green
                    : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 3.5 : 3,
              ),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: green.withValues(alpha: 0.12),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      curriculum.displayNameHe,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'NotoSansHebrew',
                      ),
                    ),
                    Text(
                      curriculum.displayNameEn,
                      style: TextStyle(
                        color: isSelected
                            ? green
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: isSelected
                    ? Container(
                        key: const ValueKey('checked'),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF22C55E), green],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: green.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.black,
                          size: 16,
                        ),
                      )
                    : Container(
                        key: const ValueKey('unchecked'),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
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
