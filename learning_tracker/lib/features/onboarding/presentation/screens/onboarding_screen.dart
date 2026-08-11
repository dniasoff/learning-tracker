import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/account/account.dart'; // W6.1
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_resume_store.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_add_another_prompt_step.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_done_step.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_handoff_step.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_parent_pin_step.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_profile_creation_step.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/add_track_flow_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Re-export the completion constant so existing callers don't break.
export 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_resume_store.dart'
    show kOnboardingComplete;

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

/// Slim onboarding phases — global settings only.
///
/// Per-track configuration is delegated to [AddTrackFlow] (Story 18.1).
enum _ScreenPhase {
  profileCreation,
  parentPinSetup,
  // W6.1: branch chooser — "track my learning" / "join to tutor" / "skip"
  intentChooser,
  addTrack,
  addAnotherPrompt,
  permissionPrompt,
  handoff,
  done,
}

/// Phase router for the onboarding flow.
///
/// Thin orchestrator: owns phase transitions, save/restore of in-progress
/// state via [OnboardingResumeStore], and navigation. Per-phase UI is
/// delegated to dedicated step widgets in `steps/`.
@RoutePage()
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _store = OnboardingResumeStore();

  var _phase = _ScreenPhase.profileCreation;

  // Profile identity (set after profile creation step completes)
  int? _createdProfileId;
  String? _profileName;
  bool _isChildMode = false;

  // Display-preference state (populated by OnboardingProfileCreationStep callback)
  bool _useHebrewCalendar = true;
  bool _useHebrewTerms = true;
  bool _showNikud = true;
  TransliterationVariant _transliterationVariant =
      TransliterationVariant.ashkenazi;
  String _profileMode = 'adult';

  // Track count for "add another" prompt
  int _trackCount = 0;
  String? _lastTrackLabel;

  @override
  void initState() {
    super.initState();
    _tryResumeFromSavedState();
    // Epic 20.6: onboarding is only reachable after signup. If the
    // user somehow lands here without a live AuthState session
    // (signedOut / initializing fallthrough), bounce them back to
    // the sign-in screen so they can sign up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = ref.read(authStateProvider);
      if (!authState.isSignedIn) {
        unawaited(context.router.replaceAll([const SignInRoute()]));
      }
    });
  }

  // ── State Persistence ──────────────────────────────────────────────────────

  Future<void> _tryResumeFromSavedState() async {
    final snapshot = await _store.load();
    if (snapshot == null) return;

    if (snapshot.profileId != null) _createdProfileId = snapshot.profileId;
    if (snapshot.profileName != null) _profileName = snapshot.profileName;
    if (snapshot.profileMode != null) {
      _profileMode = snapshot.profileMode!;
      _isChildMode = _profileMode == 'child';
    }
    _useHebrewCalendar = snapshot.useHebrewCalendar;
    _useHebrewTerms = snapshot.useHebrewTerms;
    _showNikud = snapshot.showNikud;
    if (snapshot.transliterationVariant == 'sephardi') {
      _transliterationVariant = TransliterationVariant.sephardi;
    }

    // If the user already advanced this session (e.g., tapped Continue
    // quickly), don't let a delayed restore overwrite the newer phase.
    if (!mounted || _phase != _ScreenPhase.profileCreation) return;

    // Legacy: older builds created the profile row before the calendar step.
    if (snapshot.profileId != null && snapshot.phase == 'calendarPreference') {
      setState(() => _phase = _ScreenPhase.addTrack);
      return;
    }

    final phase = _ScreenPhase.values.where((p) => p.name == snapshot.phase);
    if (phase.isNotEmpty) {
      setState(() => _phase = phase.first);
    }
  }

  Future<void> _saveState() async {
    await _store.save(
      phase: _phase.name,
      profileId: _createdProfileId,
      profileName: _profileName,
      profileMode: _profileMode,
      useHebrewCalendar: _useHebrewCalendar,
      useHebrewTerms: _useHebrewTerms,
      showNikud: _showNikud,
      transliterationVariant: _transliterationVariant.name,
    );
  }

  Future<void> _clearSavedState() => _store.clear();

  // ── Phase Transitions ──────────────────────────────────────────────────────

  void _onProfileCreated({
    required ProfileModel profile,
    required bool isChildMode,
    required bool useHebrewCalendar,
    required bool useHebrewTerms,
    required bool showNikud,
    required TransliterationVariant transliterationVariant,
  }) {
    _createdProfileId = profile.id;
    // Firestore-rewrite (docs/firestore-rewrite-map.md): every profile-scoped
    // repository now reads the ACTIVE profile
    // (`selectedProfileIdProvider`/`activeProfileIdProvider`), not an id
    // threaded through call parameters. Without this, a just-created child's
    // profile id was passed into the add-track step (see `_onAddTrackComplete`
    // and `AddTrackFlow.profileId` below) while the session's active profile
    // stayed on whatever was selected before onboarding started — so bulk-mark
    // and track-creation writes landed on the WRONG profile for a multi-child
    // add-another-learner flow. Selecting here mirrors every other place a
    // freshly created/fetched [ProfileModel] is adopted (`profile_providers.dart`'s
    // `AutoSelectedProfileId._resolveSelection`, the profile switcher).
    ref
        .read(selectedProfileIdProvider.notifier)
        .select(profile.id, ulid: profile.ulid);
    _profileName = profile.displayName;
    _isChildMode = isChildMode;
    _useHebrewCalendar = useHebrewCalendar;
    _useHebrewTerms = useHebrewTerms;
    _showNikud = showNikud;
    _transliterationVariant = transliterationVariant;
    _profileMode = isChildMode ? 'child' : 'adult';

    // W6.1: child mode still routes through PIN setup first; then to the
    // intent chooser. Adult mode goes directly to the intent chooser.
    setState(
      () => _phase = _isChildMode
          ? _ScreenPhase.parentPinSetup
          : _ScreenPhase.intentChooser,
    );
    unawaited(_saveState());
  }

  void _onPinSetupComplete() {
    // Child profiles always go straight to track setup. The intent chooser
    // (Track / Join to tutor / Skip) is adult-only — a child profile has no
    // use for "Join to tutor" (only adults can be tutors) and no reason to
    // skip onboarding before adding a track.
    setState(() => _phase = _ScreenPhase.addTrack);
    unawaited(_saveState());
  }

  void _onAddTrackComplete(AddTrackResult result) {
    _trackCount++;
    _lastTrackLabel = result.label;
    setState(() => _phase = _ScreenPhase.addAnotherPrompt);
    unawaited(_saveState());
  }

  void _onAddTrackCancel() {
    // If the learner row is not committed yet, return to the combined form.
    if (_createdProfileId == null) {
      setState(() => _phase = _ScreenPhase.profileCreation);
      return;
    }
    // Profile + prefs already saved — cannot re-use the create form.
    if (_isChildMode) {
      setState(() => _phase = _ScreenPhase.handoff);
    } else {
      unawaited(_navigateToDashboard());
    }
  }

  void _onAddAnotherTrack() {
    setState(() => _phase = _ScreenPhase.addTrack);
    unawaited(_saveState());
  }

  void _onStartLearning() {
    // Both adult and child modes go through the permission prompt — device-level
    // permissions (notifications, location) apply to the whole app, not a
    // profile. After permissions the child path continues to the handoff screen.
    setState(() => _phase = _ScreenPhase.permissionPrompt);
    unawaited(_saveState());
  }

  Future<void> _addAnotherLearner() async {
    _createdProfileId = null;
    _profileName = null;
    _profileMode = 'adult';
    _isChildMode = false;
    _useHebrewCalendar = true;
    _trackCount = 0;
    _lastTrackLabel = null;
    setState(() => _phase = _ScreenPhase.profileCreation);
    await _saveState();
  }

  Future<void> _navigateToDashboard() async {
    await _clearSavedState();
    await _store.markComplete();
    if (!mounted) return;
    final repo = ref.read(profileRepositoryProvider);
    final profiles = await repo.getProfilesByAccount(
      ref.read(currentAccountIdProvider),
    );
    if (!mounted) return;
    if (profiles.length >= 2) {
      // Multiple profiles on this account: let the user pick which learner to
      // open. Clear any stale in-memory selection so ProfileGuard surfaces the
      // picker rather than short-circuiting onto a leftover id.
      ref.read(selectedProfileIdProvider.notifier).clear();
      unawaited(context.router.replaceAll([const ProfilePickerRoute()]));
    } else {
      // Single profile (the normal fresh-signup case): select the just-created
      // profile in-memory BEFORE navigating so the AppShellRoute guard chain
      // lets the dashboard through directly. Without this the guards re-resolve
      // against unset session state and AuthGuard bounces a brand-new user to
      // the "Choose an Account" picker — an extra, confusing tap right after
      // "Start Learning". Mirrors the account-picker / sign-in landing paths,
      // which all assert the active profile before replaceAll([AppShellRoute]).
      final landingProfile =
          profiles.where((p) => p.id == _createdProfileId).firstOrNull ??
          profiles.firstOrNull;
      if (landingProfile != null) {
        ref
            .read(selectedProfileIdProvider.notifier)
            .select(landingProfile.id, ulid: landingProfile.ulid);
      }
      unawaited(context.router.replaceAll([const AppShellRoute()]));
    }
  }

  Future<void> _navigateToDashboardSkipped({
    required bool joinedToTutor,
  }) async {
    await _clearSavedState();
    await _store.markComplete(skipped: true, joinedToTutor: joinedToTutor);
    if (!mounted) return;

    // Tutor-join: no own profile is expected — EmptyLoginRoute is the correct
    // zero-profile landing surface.
    if (joinedToTutor) {
      unawaited(context.router.replaceAll([const EmptyLoginRoute()]));
      return;
    }

    // WS2.skip/WS2.surface: route to the empty-login surface for genuine
    // zero-profile skips. BUT if a profile was already created during this
    // onboarding session (e.g. user created a profile then chose "Skip for
    // now" at the intent chooser), route into the app just like
    // _navigateToDashboard does — routing to EmptyLoginRoute would dead-end
    // the user with no bottom nav and no way back (confirmed P1 regression).
    final repo = ref.read(profileRepositoryProvider);
    final profiles = await repo.getProfilesByAccount(
      ref.read(currentAccountIdProvider),
    );
    if (!mounted) return;

    if (profiles.isEmpty) {
      // Genuine zero-profile skip (e.g. user skipped profile creation itself).
      unawaited(context.router.replaceAll([const EmptyLoginRoute()]));
    } else if (profiles.length >= 2) {
      ref.read(selectedProfileIdProvider.notifier).clear();
      unawaited(context.router.replaceAll([const ProfilePickerRoute()]));
    } else {
      final landingProfile =
          profiles.where((p) => p.id == _createdProfileId).firstOrNull ??
          profiles.firstOrNull;
      if (landingProfile != null) {
        ref
            .read(selectedProfileIdProvider.notifier)
            .select(landingProfile.id, ulid: landingProfile.ulid);
      }
      unawaited(context.router.replaceAll([const AppShellRoute()]));
    }
  }

  // ── Build — OnboardingPhaseRouter ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isCombinedProfilePhase = _phase == _ScreenPhase.profileCreation;

    final appBarTitle = switch (_phase) {
      _ScreenPhase.profileCreation => const SizedBox.shrink(),
      _ScreenPhase.parentPinSetup => AppBarTitle(
        text: l10n.setParentPinDialogTitle,
      ),
      // W6.1: intent chooser — no app-bar title (header is inside the step)
      _ScreenPhase.intentChooser => const SizedBox.shrink(),
      _ScreenPhase.addTrack => AppBarTitle(
        text: l10n.onboardingSetUpTrackTitle,
      ),
      _ScreenPhase.addAnotherPrompt => AppBarTitle(
        text: l10n.onboardingTrackReadyTitle,
      ),
      _ScreenPhase.permissionPrompt => AppBarTitle(
        text: l10n.permissionPromptTitleOnboarding,
      ),
      _ScreenPhase.handoff => AppBarTitle(text: l10n.setupComplete),
      _ScreenPhase.done => AppBarTitle(text: l10n.onboardingAllSetTitle),
    };

    // Hide app bar during AddTrackFlow (it has its own progress indicator).
    // Combined profile step has no app bar (back lives in the scroll content).
    // Permission prompt pushes its own full-screen route.
    // W6.1: intent chooser also hides the app bar (header is in the step body).
    final showAppBar =
        _phase != _ScreenPhase.addTrack &&
        _phase != _ScreenPhase.permissionPrompt &&
        _phase != _ScreenPhase.intentChooser &&
        !isCombinedProfilePhase;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: showAppBar ? AppBar(title: appBarTitle) : null,
      body: Builder(
        builder: (context) => DecoratedBox(
          decoration: isDark
              ? const BoxDecoration()
              : BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.colors.brandCreamCard,
                      context.colors.brandBlueSoft.withValues(alpha: 0.2),
                      context.colors.brandCream,
                    ],
                  ),
                ),
          child: SafeArea(
            child: switch (_phase) {
              _ScreenPhase.profileCreation => OnboardingProfileCreationStep(
                onCreated:
                    ({
                      required profile,
                      required isChildMode,
                      required useHebrewCalendar,
                      required useHebrewTerms,
                      required showNikud,
                      required transliterationVariant,
                    }) => _onProfileCreated(
                      profile: profile,
                      isChildMode: isChildMode,
                      useHebrewCalendar: useHebrewCalendar,
                      useHebrewTerms: useHebrewTerms,
                      showNikud: showNikud,
                      transliterationVariant: transliterationVariant,
                    ),
                // WS2.skip: wire skip at the profile-creation phase so the user
                // can bypass profile creation entirely and land on the
                // empty-login surface.
                onSkipProfileCreation: () => unawaited(
                  _navigateToDashboardSkipped(joinedToTutor: false),
                ),
              ),
              _ScreenPhase.parentPinSetup => OnboardingParentPinStep(
                profileId: _createdProfileId ?? 0,
                childName: _profileName ?? '',
                onComplete: _onPinSetupComplete,
              ),
              // W6.1: branch chooser
              _ScreenPhase.intentChooser => OnboardingIntentStep(
                onChosen: (intent) {
                  switch (intent) {
                    case OnboardingIntent.trackMyLearning:
                      setState(() => _phase = _ScreenPhase.addTrack);
                      unawaited(_saveState());
                    case OnboardingIntent.joiningToTutor:
                      unawaited(
                        _navigateToDashboardSkipped(joinedToTutor: true),
                      );
                    case OnboardingIntent.skipForNow:
                      unawaited(
                        _navigateToDashboardSkipped(joinedToTutor: false),
                      );
                  }
                },
              ),
              _ScreenPhase.addTrack => AddTrackFlow(
                isOnboarding: true,
                onComplete: _onAddTrackComplete,
                onCancel: _onAddTrackCancel,
              ),
              _ScreenPhase.addAnotherPrompt => OnboardingAddAnotherPromptStep(
                trackCount: _trackCount,
                lastTrackLabel: _lastTrackLabel,
                onStartLearning: _onStartLearning,
                onAddAnotherTrack: _onAddAnotherTrack,
              ),
              _ScreenPhase.permissionPrompt => _PermissionPromptPhase(
                isChildMode: _isChildMode,
                onChildModeComplete: () {
                  setState(() => _phase = _ScreenPhase.handoff);
                  unawaited(_saveState());
                },
                onAdultModeComplete: _navigateToDashboard,
              ),
              _ScreenPhase.handoff => OnboardingHandoffStep(
                profileName: _profileName,
                onStartLearning: _navigateToDashboard,
                onAddAnotherTrack: _onAddAnotherTrack,
                onAddAnotherLearner: _addAnotherLearner,
              ),
              _ScreenPhase.done => const OnboardingDoneStep(),
            },
          ),
        ),
      ),
    );
  }
}

/// Internal widget that handles the permission-prompt push and waits for pop.
///
/// Extracted so the `addPostFrameCallback` side-effect is not inlined in the
/// main `switch` expression.
class _PermissionPromptPhase extends StatefulWidget {
  const _PermissionPromptPhase({
    required this.isChildMode,
    required this.onChildModeComplete,
    required this.onAdultModeComplete,
  });

  final bool isChildMode;
  final VoidCallback onChildModeComplete;
  final Future<void> Function() onAdultModeComplete;

  @override
  State<_PermissionPromptPhase> createState() => _PermissionPromptPhaseState();
}

class _PermissionPromptPhaseState extends State<_PermissionPromptPhase> {
  @override
  void initState() {
    super.initState();
    // Push the standalone PermissionPromptScreen; on pop continue to the
    // correct destination: handoff (child) or dashboard (adult).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // The first-run intro flow (AppIntroScreen) now requests these same
      // device-level permissions before sign-in. If it already did, skip the
      // push so a brand-new user is not prompted twice — just continue.
      final prefs = await SharedPreferences.getInstance();
      final alreadyPrompted = prefs.getBool(kPermissionsPrompted) ?? false;
      if (!mounted) return;
      if (!alreadyPrompted) {
        await context.pushRoute(PermissionPromptRoute(isOnboarding: true));
      }
      if (!mounted) return;
      if (widget.isChildMode) {
        widget.onChildModeComplete();
      } else {
        await widget.onAdultModeComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Placeholder shown for the single frame before the route is pushed.
    return const SizedBox.shrink();
  }
}
