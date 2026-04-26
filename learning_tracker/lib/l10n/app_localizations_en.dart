// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Torah Learning Tracker';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get learn => 'Learn';

  @override
  String get progress => 'Progress';

  @override
  String get settings => 'Settings';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get streak => 'STREAK';

  @override
  String get done => 'DONE';

  @override
  String get points => 'POINTS';

  @override
  String get pages => 'PAGES';

  @override
  String get todaysLearning => 'Today\'s Learning';

  @override
  String remaining(int count) {
    return '$count remaining';
  }

  @override
  String get allCaughtUp => 'All caught up!';

  @override
  String get noTasksRemaining => 'No tasks remaining for today.';

  @override
  String get activeCurricula => 'Active Curricula';

  @override
  String get continueLearning => 'Continue Learning';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get myLearningJourney => 'My Learning Journey';

  @override
  String get seeLifetimeAchievements => 'See your lifetime achievements';

  @override
  String get dailyProgress => 'DAILY PROGRESS';

  @override
  String get studyDay => 'Study Day';

  @override
  String get reviewDay => 'Review Day';

  @override
  String get mixedDay => 'Mixed';

  @override
  String get restDay => 'Rest Day';

  @override
  String get overdue => 'Overdue';

  @override
  String moreTasks(int count) {
    return '$count more tasks...';
  }

  @override
  String streakRecovery(int count) {
    return 'You missed 1 day but your $count-day streak is safe!';
  }

  @override
  String get achievements => 'Achievements';

  @override
  String get activityCalendar => 'Activity Calendar';

  @override
  String get nextReward => 'Next Reward';

  @override
  String get earnedRewards => 'Earned Rewards';

  @override
  String get noRewardsYet => 'No rewards earned yet. Keep learning!';

  @override
  String get mysteryReward => 'Mystery Reward!';

  @override
  String get totalPoints => 'Total Points';

  @override
  String get dashboardRewardsGallery => 'Rewards Gallery';

  @override
  String get dashboardSeeAllRewards => 'SEE ALL';

  @override
  String get dashboardMysteryChest => 'Mystery Chest';

  @override
  String dashboardTapToUnlockAtPts(String points) {
    return 'TAP TO UNLOCK AT $points PTS';
  }

  @override
  String dashboardPointsValue(String count) {
    return '$count Points';
  }

  @override
  String get dashboardBubbleDone => 'DONE';

  @override
  String get complete => 'complete';

  @override
  String get gamification => 'Gamification';

  @override
  String get rewardCatalog => 'Reward Catalog';

  @override
  String get noRewardsConfigured => 'No rewards configured yet';

  @override
  String get addReward => 'Add Reward';

  @override
  String get editReward => 'Edit Reward';

  @override
  String get deleteReward => 'Delete Reward';

  @override
  String deleteRewardConfirm(String title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get reveal => 'Reveal';

  @override
  String get revealed => 'Revealed';

  @override
  String get title => 'Title';

  @override
  String get description => 'Description';

  @override
  String get pointThreshold => 'Point Threshold';

  @override
  String get titleRequired => 'Title is required';

  @override
  String get descriptionRequired => 'Description is required';

  @override
  String get thresholdRequired => 'Threshold is required';

  @override
  String get mustBePositive => 'Must be a positive number';

  @override
  String get milestoneType => 'Milestone Type';

  @override
  String get pointsThreshold => 'Points threshold';

  @override
  String get finishMasechta => 'Finish masechta';

  @override
  String get finishSeder => 'Finish seder';

  @override
  String get everyNItems => 'Every N items';

  @override
  String get visibleToChild => 'Visible to child';

  @override
  String get childCanSee => 'Child can see this reward';

  @override
  String get hiddenUntilEarned => 'Hidden until earned (surprise)';

  @override
  String get onboarding => 'Onboarding';

  @override
  String get getStarted => 'Get Started';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get whatsYourName => 'What\'s your name?';

  @override
  String get adult => 'Adult';

  @override
  String get child => 'Child';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get selectCurricula => 'Select Curricula';

  @override
  String get continueButton => 'Continue';

  @override
  String get skip => 'Skip';

  @override
  String get joinCalendarProgram => 'Join a Calendar Program';

  @override
  String get customTrack => 'Custom Track';

  @override
  String get joinCalendarDesc =>
      'Follow a daily learning schedule like Daf Yomi';

  @override
  String get customTrackDesc =>
      'Create your own learning plan at your own pace';

  @override
  String get availablePrograms => 'Available Programs';

  @override
  String get todaysAssignment => 'Today\'s Assignment';

  @override
  String get startTrackingFrom => 'Start Tracking From';

  @override
  String get fromToday => 'From today';

  @override
  String get beginningOfPerek => 'Beginning of current perek';

  @override
  String get beginningOfMasechta => 'Beginning of current masechta';

  @override
  String get specificDaf => 'From a specific daf';

  @override
  String get setupComplete => 'Setup Complete!';

  @override
  String get addAnotherLearner => 'Add Another Learner';

  @override
  String get startLearning => 'Start Learning';

  @override
  String get language => 'Language';

  @override
  String get switchProfile => 'Switch profile';

  @override
  String get notifications => 'Notifications';

  @override
  String get retry => 'Retry';

  @override
  String get error => 'Error';

  @override
  String get loading => 'Loading...';

  @override
  String get manageTracks => 'Manage Tracks';

  @override
  String get manageTracksDetail => 'Create and edit your learning tracks';

  @override
  String get addTrack => 'Add Track';

  @override
  String get noActiveCurricula => 'No active curricula';

  @override
  String errorLoadingCurricula(String error) {
    return 'Error loading curricula: $error';
  }

  @override
  String trackCreated(String label) {
    return 'Track \"$label\" created';
  }

  @override
  String get learner => 'Learner';

  @override
  String get learningTracker => 'Learning Tracker';

  @override
  String get searchContent => 'Search content';

  @override
  String errorWithMessage(String error) {
    return 'Error: $error';
  }

  @override
  String errorLoadingTasks(String error) {
    return 'Error loading tasks: $error';
  }

  @override
  String get noActiveTracks => 'No active tracks';

  @override
  String get askGrownUpToAddTrack => 'Ask a grown-up to add a learning track.';

  @override
  String get addTrackToStart => 'Add a track to start learning.';

  @override
  String get todaysTasks => 'Today\'s Tasks';

  @override
  String get viewAll => 'View All';

  @override
  String get myCurricula => 'My Curricula';

  @override
  String percentComplete(int percent) {
    return '$percent% complete';
  }

  @override
  String get viewProgress => 'View progress';

  @override
  String get markComplete => 'Mark complete';

  @override
  String get noProjection => 'No projection';

  @override
  String get today => 'TODAY';

  @override
  String plusNMore(int count) {
    return '+$count more';
  }

  @override
  String get noTracksYet => 'No tracks yet';

  @override
  String get firstTrackPrompt =>
      'Add your first learning track to get started.';

  @override
  String paceAhead(int days) {
    return '${days}d ahead';
  }

  @override
  String paceBehind(int days) {
    return '${days}d behind';
  }

  @override
  String get paceOnPace => 'OK';

  @override
  String get progressNoDataTitle => 'No progress yet';

  @override
  String get progressNoDataSubtitle =>
      'Start learning to see your progress here.';

  @override
  String get statCompletions => 'COMPLETIONS';

  @override
  String get statUnitsDone => 'UNITS DONE';

  @override
  String get statDayStreak => 'DAY STREAK';

  @override
  String get statActiveTracks => 'ACTIVE TRACKS';

  @override
  String get progressChartsTile => 'Progress Charts';

  @override
  String get progressChartsTileSubtitle => 'Completions, trends, and more';

  @override
  String get curriculumMastery => 'Curriculum Mastery';

  @override
  String get masteryDoneBadge => 'DONE';

  @override
  String get learningLifetime => 'Learning Lifetime';

  @override
  String get learningLifetimeExpandHint =>
      'Per curriculum: expand to browse what you have learned';

  @override
  String get addWhatYouLearned => 'Add what you\'ve learned';

  @override
  String get addWhatYouLearnedSettingsSubtitle =>
      'Log custom Mitzvot or Torah studies';

  @override
  String get lifetimeLearning => 'Lifetime Learning';

  @override
  String get lifetimeAddHeaderTitle => 'Add what you\'ve learned';

  @override
  String get lifetimeAddHeaderSubtitle =>
      'Mark what you already studied — in print or anywhere — as lifetime learning.';

  @override
  String get lifetimeHowItWorksTitle => 'How it works';

  @override
  String get lifetimeHowItWorksBody =>
      'Open a curriculum, then use the folder list to select sections. Green = selected for saving; open a subfolder with the arrow when there is more inside.';

  @override
  String get lifetimeSelectScreenTitle => 'Select what you\'ve learned';

  @override
  String get lifetimeSelectScreenSubtitle =>
      'Check sections to include; open folders to go deeper.';

  @override
  String get lifetimeMarkAsLearnedTitle => 'Mark as lifetime learned';

  @override
  String lifetimeMarkAsLearnedLine(int count, int level) {
    return 'Selected: $count • level $level';
  }

  @override
  String get selectAllInThisList => 'Select all in this list';

  @override
  String get deselectAllInThisList => 'Deselect all in this list';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String contentLoadError(String error) {
    return 'Unable to load curriculum content: $error';
  }

  @override
  String get noItemsAtThisLevel => 'No items at this level';

  @override
  String get breadcrumbsRoot => 'Root';

  @override
  String lifetimeMarkSavedCount(int count) {
    return 'Marked $count lifetime selection(s).';
  }

  @override
  String lifetimeMarkSaveError(String error) {
    return 'Could not save lifetime marks: $error';
  }

  @override
  String get dashboardStats => 'STATS';

  @override
  String get learningLifetimeAllCurricula =>
      'Learning lifetime (all curricula)';

  @override
  String lifetimeSectionsSummary(String learned, String total, int n) {
    return '$learned / $total sections — $n curricula';
  }

  @override
  String greetingHelloName(String name) {
    return 'Shalom, $name!';
  }

  @override
  String get noFocusTag => 'NO FOCUS TAG';

  @override
  String get todaysMissions => 'Today’s Missions';

  @override
  String get noTasksInLane => 'No tasks in this lane';

  @override
  String get reviewSection => 'REVIEW SECTION';

  @override
  String get chazaraReview => 'Chazara/Review';

  @override
  String get urgent => 'URGENT';

  @override
  String get missedOverdue => 'Missed/Overdue';

  @override
  String get bubbleOverdue => 'OVERDUE';

  @override
  String get bubbleTodayDue => 'TODAY\nDUE';

  @override
  String get bubbleChazara => 'CHAZARA';

  @override
  String get mainFocus => 'MAIN FOCUS';

  @override
  String get carouselCompletion => 'Completion';

  @override
  String get continueCta => 'CONTINUE';

  @override
  String get tabSchedule => 'Schedule';

  @override
  String get dueToday => 'Due today';

  @override
  String get nothingDueInQueue => 'Nothing due in this queue right now.';

  @override
  String get selfPacedScopeTitle => 'All of it, or just a section?';

  @override
  String get learnEntireCurriculumCta => 'I want to learn everything!';

  @override
  String learnEntireCurriculumSubtitle(String name) {
    return 'Select the entire $name';
  }

  @override
  String get faster => 'FASTER!';

  @override
  String level1Selection(String name, String levelLabel) {
    return '$name → $levelLabel selection';
  }

  @override
  String get scopeSelectedBadge => 'SELECTED';

  @override
  String get selectAtLeastOne => 'Select at least one';

  @override
  String continueWithSelectionCount(int count) {
    return 'Continue with $count selected';
  }

  @override
  String get sectionLearning => 'LEARNING';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get notificationSettingsSubtitle =>
      'Push, email, and study sound alerts';

  @override
  String pointsAbbrev(int count) {
    return '$count pts';
  }

  @override
  String get sectionTracks => 'TRACKS';

  @override
  String get sectionAccount => 'ACCOUNT';

  @override
  String get sectionParentalControls => 'PARENTAL CONTROLS';

  @override
  String get changePassword => 'Change Password';

  @override
  String get signOut => 'Sign Out';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountSubtitle =>
      'Permanently remove this account and cloud data';

  @override
  String get settingsHandcraftedTagline => 'Handcrafted for your Torah journey';

  @override
  String get calendarPreference => 'Calendar Preference';

  @override
  String get calendarPreferenceSubtitle => 'Goals, deadlines, and date pickers';

  @override
  String get calendarGregorian => 'Gregorian';

  @override
  String get calendarHebrew => 'Hebrew';

  @override
  String get parentMode => 'Parent Mode';

  @override
  String get parentModeSubtitle => 'Switch to admin (PIN-guarded)';

  @override
  String get parentPin => 'Parent PIN';

  @override
  String get parentPinSubtitle => 'Change your security PIN';

  @override
  String get passwordChangedSuccessfully => 'Password changed successfully.';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get userFallbackDisplayName => 'User';

  @override
  String get proBadge => 'PRO';

  @override
  String get selfLearnerBadge => 'SELF-LEARNER';

  @override
  String get noBackup => 'No Backup';

  @override
  String get chooseLanguageTitle => 'Choose Language';

  @override
  String get preferredLanguageForContent => 'Preferred language for content';

  @override
  String get profilePickerTitle => 'Who is learning?';

  @override
  String get profilePickerSubtitle =>
      'Choose a profile to continue your\njourney';

  @override
  String get addProfile => 'Add Profile';

  @override
  String get createProfile => 'Create Profile';

  @override
  String get enterNameHint => 'Enter name';

  @override
  String get chooseMode => 'Choose Mode';

  @override
  String get childModeCardTitle => 'Child Mode';

  @override
  String get childModeCardSubtitleFunRewards => 'Fun & Rewards';

  @override
  String get adultModeCardTitle => 'Adult Mode';

  @override
  String get adultModeCardSubtitleDeepFocused => 'Deep & Focused';

  @override
  String get profileBadgeChildMode => 'CHILD MODE';

  @override
  String get profileBadgeAdultMode => 'ADULT MODE';

  @override
  String profileNameTaken(String name) {
    return 'A profile named \"$name\" already exists';
  }

  @override
  String get maxProfilesReached => 'Maximum 10 profiles reached';

  @override
  String get renameAction => 'Rename';

  @override
  String get mustKeepOneProfile => 'You must have at least one profile';

  @override
  String get profileNameAlreadyExists =>
      'A profile with this name already exists';

  @override
  String get renameProfileTitle => 'Rename Profile';

  @override
  String get displayName => 'Display Name';

  @override
  String get deleteProfileTitle => 'Delete Profile?';

  @override
  String deleteProfileConfirm(String name) {
    return 'Permanently delete \"$name\" and ALL associated learning data? This cannot be undone.';
  }

  @override
  String get cannotDeleteOnlyProfile => 'Cannot delete your only profile';

  @override
  String get tapToContinue => 'Tap to\ncontinue';

  @override
  String get maxProfilesLabel => 'Max Profiles';

  @override
  String get addProfileCardTitle => 'Add\nProfile';

  @override
  String get maxProfilesSubtitle => 'Maximum reached';

  @override
  String get createNewLearner => 'Create new\nlearner';

  @override
  String get profilesLabel => 'Profiles';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncScreenBody => 'Sync status and settings will appear here.';

  @override
  String get parentDashboard => 'Parent Dashboard';

  @override
  String get parentSettingsTitle => 'Parent Settings';

  @override
  String get addChildTooltip => 'Add Child';

  @override
  String errorLoadingDashboard(String error) {
    return 'Error loading dashboard: $error';
  }

  @override
  String get manageTracksForChildSubtitle =>
      'Add, edit, or archive your child\'s tracks';

  @override
  String get pointConfiguration => 'Point Configuration';

  @override
  String get pointConfigurationSubtitle =>
      'Set how many points activities are worth';

  @override
  String get parentDashboardCardSubtitle =>
      'See your child\'s learning progress at a glance';

  @override
  String get sectionAccountSafety => 'ACCOUNT SAFETY';

  @override
  String get bottomNavTracks => 'Tracks';

  @override
  String get bottomNavRewards => 'Rewards';

  @override
  String get bottomNavParent => 'Parent';

  @override
  String get enterParentPin => 'Enter Parent PIN';

  @override
  String get changeParentPin => 'Change Parent PIN';

  @override
  String get pinChangedSuccessfully => 'PIN changed successfully';

  @override
  String get deviceRestoreChecking => 'Checking device...';

  @override
  String get deviceRestoreComplete => 'Restore complete!';

  @override
  String get deviceRestoreFailed => 'Restore failed';

  @override
  String deviceRestoreStep(int completed, int total) {
    return 'Step $completed of $total';
  }

  @override
  String get skipAndContinue => 'Skip & continue';

  @override
  String get noActiveProfile => 'No active profile';

  @override
  String get incorrectPin => 'Incorrect PIN';

  @override
  String get enterCurrentPin => 'Enter Current PIN';

  @override
  String get enterNewPin => 'Enter New PIN';

  @override
  String get confirmNewPin => 'Confirm New PIN';

  @override
  String get pinsDoNotMatch => 'PINs do not match';
}
