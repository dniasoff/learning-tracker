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
}
