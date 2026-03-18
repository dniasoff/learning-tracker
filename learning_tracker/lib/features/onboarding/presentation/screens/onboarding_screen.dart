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
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
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
      setState(() => _phase = phase.first);
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
      await wizardService.applyWizardResult(result.wizardResult);
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

    final appBarTitle = switch (_phase) {
      _ScreenPhase.profileCreation => 'Add a Learner',
      _ScreenPhase.languageSelection => 'Choose Language',
      _ScreenPhase.selection => childAwareText(
          'Select Curricula',
          'What is {name} learning?',
          _profileName,
          isChildMode: _isChildMode,
        ),
      _ScreenPhase.handoff => 'Setup Complete!',
      _ => 'Onboarding',
    };

    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: appBarTitle)),
      body: SafeArea(
        child: switch (_phase) {
        _ScreenPhase.profileCreation => _buildProfileCreation(theme),
        _ScreenPhase.languageSelection => _buildLanguageSelection(theme),
        _ScreenPhase.selection => _buildSelection(theme),
        _ScreenPhase.importing => _buildImporting(theme),
        _ScreenPhase.scopeSelection => _buildScopeSelection(theme),
        _ScreenPhase.learningProcessWizard =>
          _buildLearningProcessWizard(theme),
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
                                fontWeight:
                                    isSelected ? FontWeight.bold : null,
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
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.5),
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
    final header = childAwareText(
      'Choose which curricula to track',
      'What is {name} learning?',
      _profileName,
      isChildMode: _isChildMode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            header,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'You can add more later from Settings.',
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
          padding: const EdgeInsets.all(24),
          child: FilledButton(
            onPressed: _selected.isNotEmpty ? _startImport : null,
            child: const Text('Continue'),
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
        Expanded(
          child: ScopeSelectionScreen(curriculumId: curriculum),
        ),
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
        final result = await Navigator.of(
          context,
        ).push<LearningProcessWizardResult>(
          MaterialPageRoute<LearningProcessWizardResult>(
            builder: (_) => LearningProcessWizardScreen(
              curriculumId: curriculum,
              presets: presets,
              isChildMode: _isChildMode,
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
    final contentAsync = ref.watch(
      curriculumContentProvider(curriculum),
    );
    final totalItems = contentAsync.whenOrNull<int>(
      data: (items) => items.where((i) => i.isLeaf).length,
    );

    final headerText = childAwareText(
      'Set a goal for ${curriculum.displayNameEn}',
      'Set a learning goal for {name} in ${curriculum.displayNameEn}',
      _profileName,
      isChildMode: _isChildMode,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              headerText,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${_goalSetupIndex + 1} of ${_goalSetupQueue.length}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (totalItems != null) ...[
            const SizedBox(height: 4),
            Text(
              '$totalItems items',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const Spacer(),
          FilledButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<GoalFormResult>(
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
            child: const Text('Set Goal'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _onGoalResult(null),
            child: const Text('Skip'),
          ),
        ],
      ),
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
                        builder: (_) =>
                            RewardsSetupScreen(suggestedThresholds: thresholds),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.getCurriculumColor(curriculum);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        elevation: isSelected ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? color
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.menu_book, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    curriculum.displayNameEn,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : null,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: color)
                else
                  Icon(
                    Icons.circle_outlined,
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
