import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Torah Learning Tracker'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @learn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learn;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'STREAK'**
  String get streak;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get done;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'POINTS'**
  String get points;

  /// No description provided for @pages.
  ///
  /// In en, this message translates to:
  /// **'PAGES'**
  String get pages;

  /// No description provided for @todaysLearning.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Learning'**
  String get todaysLearning;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'{count} remaining'**
  String remaining(int count);

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get allCaughtUp;

  /// No description provided for @noTasksRemaining.
  ///
  /// In en, this message translates to:
  /// **'No tasks remaining for today.'**
  String get noTasksRemaining;

  /// No description provided for @activeCurricula.
  ///
  /// In en, this message translates to:
  /// **'Active Curricula'**
  String get activeCurricula;

  /// No description provided for @activeTracks.
  ///
  /// In en, this message translates to:
  /// **'Active tracks'**
  String get activeTracks;

  /// No description provided for @activeTracksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep up the great work on your learning goals'**
  String get activeTracksSubtitle;

  /// No description provided for @activeTrackNextTask.
  ///
  /// In en, this message translates to:
  /// **'NEXT TASK'**
  String get activeTrackNextTask;

  /// No description provided for @activeTrackCurrentFocus.
  ///
  /// In en, this message translates to:
  /// **'CURRENT FOCUS'**
  String get activeTrackCurrentFocus;

  /// No description provided for @activeTrackPaceAhead.
  ///
  /// In en, this message translates to:
  /// **'Ahead {days}d'**
  String activeTrackPaceAhead(int days);

  /// No description provided for @activeTrackPaceBehind.
  ///
  /// In en, this message translates to:
  /// **'Behind {days}d'**
  String activeTrackPaceBehind(int days);

  /// No description provided for @activeTrackPaceOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get activeTrackPaceOk;

  /// No description provided for @activeTrackMetricChazara.
  ///
  /// In en, this message translates to:
  /// **'CHAZARA'**
  String get activeTrackMetricChazara;

  /// No description provided for @activeTrackMetricDueToday.
  ///
  /// In en, this message translates to:
  /// **'DUE TODAY'**
  String get activeTrackMetricDueToday;

  /// No description provided for @activeTrackMetricOverdue.
  ///
  /// In en, this message translates to:
  /// **'OVERDUE'**
  String get activeTrackMetricOverdue;

  /// No description provided for @trackLifetimeLearning.
  ///
  /// In en, this message translates to:
  /// **'Lifetime learning'**
  String get trackLifetimeLearning;

  /// No description provided for @continueLearning.
  ///
  /// In en, this message translates to:
  /// **'Continue Learning'**
  String get continueLearning;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @myLearningJourney.
  ///
  /// In en, this message translates to:
  /// **'My Learning Journey'**
  String get myLearningJourney;

  /// No description provided for @seeLifetimeAchievements.
  ///
  /// In en, this message translates to:
  /// **'See your lifetime achievements'**
  String get seeLifetimeAchievements;

  /// No description provided for @dailyProgress.
  ///
  /// In en, this message translates to:
  /// **'DAILY PROGRESS'**
  String get dailyProgress;

  /// No description provided for @studyDay.
  ///
  /// In en, this message translates to:
  /// **'Study Day'**
  String get studyDay;

  /// No description provided for @reviewDay.
  ///
  /// In en, this message translates to:
  /// **'Review Day'**
  String get reviewDay;

  /// No description provided for @mixedDay.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get mixedDay;

  /// No description provided for @restDay.
  ///
  /// In en, this message translates to:
  /// **'Rest Day'**
  String get restDay;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @moreTasks.
  ///
  /// In en, this message translates to:
  /// **'{count} more tasks...'**
  String moreTasks(int count);

  /// No description provided for @streakRecovery.
  ///
  /// In en, this message translates to:
  /// **'You missed 1 day but your {count}-day streak is safe!'**
  String streakRecovery(int count);

  /// No description provided for @achievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// No description provided for @activityCalendar.
  ///
  /// In en, this message translates to:
  /// **'Activity Calendar'**
  String get activityCalendar;

  /// No description provided for @nextReward.
  ///
  /// In en, this message translates to:
  /// **'Next Reward'**
  String get nextReward;

  /// No description provided for @earnedRewards.
  ///
  /// In en, this message translates to:
  /// **'Earned Rewards'**
  String get earnedRewards;

  /// No description provided for @noRewardsYet.
  ///
  /// In en, this message translates to:
  /// **'No rewards earned yet. Keep learning!'**
  String get noRewardsYet;

  /// No description provided for @mysteryReward.
  ///
  /// In en, this message translates to:
  /// **'Mystery Reward!'**
  String get mysteryReward;

  /// No description provided for @totalPoints.
  ///
  /// In en, this message translates to:
  /// **'Total Points'**
  String get totalPoints;

  /// No description provided for @dashboardRewardsGallery.
  ///
  /// In en, this message translates to:
  /// **'Rewards Gallery'**
  String get dashboardRewardsGallery;

  /// No description provided for @dashboardChildPointsTab.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get dashboardChildPointsTab;

  /// No description provided for @dashboardSeeAllRewards.
  ///
  /// In en, this message translates to:
  /// **'SEE ALL'**
  String get dashboardSeeAllRewards;

  /// No description provided for @dashboardMysteryChest.
  ///
  /// In en, this message translates to:
  /// **'Mystery Chest'**
  String get dashboardMysteryChest;

  /// No description provided for @dashboardTapToUnlockAtPts.
  ///
  /// In en, this message translates to:
  /// **'TAP TO UNLOCK AT {points} PTS'**
  String dashboardTapToUnlockAtPts(String points);

  /// No description provided for @dashboardPointsValue.
  ///
  /// In en, this message translates to:
  /// **'{count} Points'**
  String dashboardPointsValue(String count);

  /// No description provided for @dashboardBubbleDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get dashboardBubbleDone;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'complete'**
  String get complete;

  /// No description provided for @gamification.
  ///
  /// In en, this message translates to:
  /// **'Gamification'**
  String get gamification;

  /// No description provided for @myAchievementsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Achievements'**
  String get myAchievementsTitle;

  /// No description provided for @achievementsYourProgress.
  ///
  /// In en, this message translates to:
  /// **'YOUR PROGRESS'**
  String get achievementsYourProgress;

  /// No description provided for @achievementsRewardsCount.
  ///
  /// In en, this message translates to:
  /// **'{unlocked} / {total} Rewards'**
  String achievementsRewardsCount(int unlocked, int total);

  /// No description provided for @achievementsAcrossAllTracks.
  ///
  /// In en, this message translates to:
  /// **'Across all your tracks.'**
  String get achievementsAcrossAllTracks;

  /// No description provided for @achievementsEncouragement.
  ///
  /// In en, this message translates to:
  /// **'Keep it up, you\'re doing great!'**
  String get achievementsEncouragement;

  /// No description provided for @achievementsRewardsFraction.
  ///
  /// In en, this message translates to:
  /// **'{unlocked} / {total}'**
  String achievementsRewardsFraction(int unlocked, int total);

  /// No description provided for @achievementsRewardsLabelWord.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get achievementsRewardsLabelWord;

  /// No description provided for @achievementsMilestonePoints.
  ///
  /// In en, this message translates to:
  /// **'{points} PTS'**
  String achievementsMilestonePoints(String points);

  /// No description provided for @achievementsProgressPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String achievementsProgressPercent(int percent);

  /// No description provided for @achievementsTrackSection.
  ///
  /// In en, this message translates to:
  /// **'TRACK SELECTION'**
  String get achievementsTrackSection;

  /// No description provided for @achievementsAllTracks.
  ///
  /// In en, this message translates to:
  /// **'All Tracks'**
  String get achievementsAllTracks;

  /// No description provided for @achievementsStatusUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked!'**
  String get achievementsStatusUnlocked;

  /// No description provided for @achievementsStatusComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon!'**
  String get achievementsStatusComingSoon;

  /// No description provided for @achievementsStatusLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get achievementsStatusLocked;

  /// No description provided for @achievementsUnlockedAtPoints.
  ///
  /// In en, this message translates to:
  /// **'Unlocked at {points} points'**
  String achievementsUnlockedAtPoints(String points);

  /// No description provided for @achievementsUltimateGoal.
  ///
  /// In en, this message translates to:
  /// **'The Ultimate Goal.'**
  String get achievementsUltimateGoal;

  /// No description provided for @achievementsProTipTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro Tip!'**
  String get achievementsProTipTitle;

  /// No description provided for @achievementsProTipBody.
  ///
  /// In en, this message translates to:
  /// **'Keep learning on your tracks to climb the reward ladder.'**
  String get achievementsProTipBody;

  /// No description provided for @achievementsActivityAndPoints.
  ///
  /// In en, this message translates to:
  /// **'Activity & points'**
  String get achievementsActivityAndPoints;

  /// No description provided for @achievementsUnlockPartyTitle.
  ///
  /// In en, this message translates to:
  /// **'Wow! Amazing!'**
  String get achievementsUnlockPartyTitle;

  /// No description provided for @achievementsUnlockPartyMessage.
  ///
  /// In en, this message translates to:
  /// **'Congratulations, {name}! You unlocked {milestone} on your {track} track — keep going!'**
  String achievementsUnlockPartyMessage(
    String name,
    String milestone,
    String track,
  );

  /// No description provided for @achievementsUnlockPartyButton.
  ///
  /// In en, this message translates to:
  /// **'Yay! Let\'s go!'**
  String get achievementsUnlockPartyButton;

  /// No description provided for @achievementsUnlockPartyNameFallback.
  ///
  /// In en, this message translates to:
  /// **'friend'**
  String get achievementsUnlockPartyNameFallback;

  /// No description provided for @rewardCatalog.
  ///
  /// In en, this message translates to:
  /// **'Reward Catalog'**
  String get rewardCatalog;

  /// No description provided for @noRewardsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No rewards configured yet'**
  String get noRewardsConfigured;

  /// No description provided for @addReward.
  ///
  /// In en, this message translates to:
  /// **'Add Reward'**
  String get addReward;

  /// No description provided for @editReward.
  ///
  /// In en, this message translates to:
  /// **'Edit Reward'**
  String get editReward;

  /// No description provided for @deleteReward.
  ///
  /// In en, this message translates to:
  /// **'Delete Reward'**
  String get deleteReward;

  /// No description provided for @deleteRewardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String deleteRewardConfirm(String title);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @reveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get reveal;

  /// No description provided for @revealed.
  ///
  /// In en, this message translates to:
  /// **'Revealed'**
  String get revealed;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @pointThreshold.
  ///
  /// In en, this message translates to:
  /// **'Point Threshold'**
  String get pointThreshold;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleRequired;

  /// No description provided for @descriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Description is required'**
  String get descriptionRequired;

  /// No description provided for @thresholdRequired.
  ///
  /// In en, this message translates to:
  /// **'Threshold is required'**
  String get thresholdRequired;

  /// No description provided for @mustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Must be a positive number'**
  String get mustBePositive;

  /// No description provided for @milestoneType.
  ///
  /// In en, this message translates to:
  /// **'Milestone Type'**
  String get milestoneType;

  /// No description provided for @pointsThreshold.
  ///
  /// In en, this message translates to:
  /// **'Points threshold'**
  String get pointsThreshold;

  /// No description provided for @finishMasechta.
  ///
  /// In en, this message translates to:
  /// **'Finish masechta'**
  String get finishMasechta;

  /// No description provided for @finishSeder.
  ///
  /// In en, this message translates to:
  /// **'Finish seder'**
  String get finishSeder;

  /// No description provided for @everyNItems.
  ///
  /// In en, this message translates to:
  /// **'Every N items'**
  String get everyNItems;

  /// No description provided for @visibleToChild.
  ///
  /// In en, this message translates to:
  /// **'Visible to child'**
  String get visibleToChild;

  /// No description provided for @childCanSee.
  ///
  /// In en, this message translates to:
  /// **'Child can see this reward'**
  String get childCanSee;

  /// No description provided for @hiddenUntilEarned.
  ///
  /// In en, this message translates to:
  /// **'Hidden until earned (surprise)'**
  String get hiddenUntilEarned;

  /// No description provided for @onboarding.
  ///
  /// In en, this message translates to:
  /// **'Onboarding'**
  String get onboarding;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @whatsYourName.
  ///
  /// In en, this message translates to:
  /// **'What\'s your name?'**
  String get whatsYourName;

  /// No description provided for @adult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get adult;

  /// No description provided for @child.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get child;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @selectCurricula.
  ///
  /// In en, this message translates to:
  /// **'Select Curricula'**
  String get selectCurricula;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @joinCalendarProgram.
  ///
  /// In en, this message translates to:
  /// **'Join a Calendar Program'**
  String get joinCalendarProgram;

  /// No description provided for @customTrack.
  ///
  /// In en, this message translates to:
  /// **'Custom Track'**
  String get customTrack;

  /// No description provided for @joinCalendarDesc.
  ///
  /// In en, this message translates to:
  /// **'Follow a daily learning schedule like Daf Yomi'**
  String get joinCalendarDesc;

  /// No description provided for @customTrackDesc.
  ///
  /// In en, this message translates to:
  /// **'Create your own learning plan at your own pace'**
  String get customTrackDesc;

  /// No description provided for @availablePrograms.
  ///
  /// In en, this message translates to:
  /// **'Available Programs'**
  String get availablePrograms;

  /// No description provided for @todaysAssignment.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Assignment'**
  String get todaysAssignment;

  /// No description provided for @startTrackingFrom.
  ///
  /// In en, this message translates to:
  /// **'Start Tracking From'**
  String get startTrackingFrom;

  /// No description provided for @fromToday.
  ///
  /// In en, this message translates to:
  /// **'From today'**
  String get fromToday;

  /// No description provided for @beginningOfPerek.
  ///
  /// In en, this message translates to:
  /// **'Beginning of current perek'**
  String get beginningOfPerek;

  /// No description provided for @beginningOfMasechta.
  ///
  /// In en, this message translates to:
  /// **'Beginning of current masechta'**
  String get beginningOfMasechta;

  /// No description provided for @specificDaf.
  ///
  /// In en, this message translates to:
  /// **'From a specific daf'**
  String get specificDaf;

  /// No description provided for @setupComplete.
  ///
  /// In en, this message translates to:
  /// **'Setup Complete!'**
  String get setupComplete;

  /// No description provided for @addAnotherLearner.
  ///
  /// In en, this message translates to:
  /// **'Add Another Learner'**
  String get addAnotherLearner;

  /// No description provided for @startLearning.
  ///
  /// In en, this message translates to:
  /// **'Start Learning'**
  String get startLearning;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @switchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch profile'**
  String get switchProfile;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @manageTracks.
  ///
  /// In en, this message translates to:
  /// **'Manage Tracks'**
  String get manageTracks;

  /// No description provided for @manageTracksDetail.
  ///
  /// In en, this message translates to:
  /// **'Create and edit your learning tracks'**
  String get manageTracksDetail;

  /// No description provided for @addTrackGoalTapToUseDeadline.
  ///
  /// In en, this message translates to:
  /// **'Target pace is on — tap here to use a deadline instead'**
  String get addTrackGoalTapToUseDeadline;

  /// No description provided for @addTrackGoalTapToUsePace.
  ///
  /// In en, this message translates to:
  /// **'Deadline is on — tap here to use target pace instead'**
  String get addTrackGoalTapToUsePace;

  /// No description provided for @addTrackGoalDeadlinePaceLine.
  ///
  /// In en, this message translates to:
  /// **'About {items} {unit} per study day, across {studyDays} study days to finish the scope by the deadline (≈{totalItems} items).'**
  String addTrackGoalDeadlinePaceLine(
    int items,
    String unit,
    int studyDays,
    int totalItems,
  );

  /// No description provided for @addTrackGoalDeadlineNoStudyDaysInWindow.
  ///
  /// In en, this message translates to:
  /// **'No study day in your week falls in the range to this deadline. Add study days or move the deadline later.'**
  String get addTrackGoalDeadlineNoStudyDaysInWindow;

  /// No description provided for @addTrackGoalDeadlinePaceLineLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading scope size to estimate per study day…'**
  String get addTrackGoalDeadlinePaceLineLoading;

  /// No description provided for @addTrack.
  ///
  /// In en, this message translates to:
  /// **'Add Track'**
  String get addTrack;

  /// No description provided for @noActiveCurricula.
  ///
  /// In en, this message translates to:
  /// **'No active curricula'**
  String get noActiveCurricula;

  /// No description provided for @errorLoadingCurricula.
  ///
  /// In en, this message translates to:
  /// **'Error loading curricula: {error}'**
  String errorLoadingCurricula(String error);

  /// No description provided for @trackCreated.
  ///
  /// In en, this message translates to:
  /// **'Track \"{label}\" created'**
  String trackCreated(String label);

  /// No description provided for @learner.
  ///
  /// In en, this message translates to:
  /// **'Learner'**
  String get learner;

  /// No description provided for @learningTracker.
  ///
  /// In en, this message translates to:
  /// **'Learning Tracker'**
  String get learningTracker;

  /// No description provided for @searchContent.
  ///
  /// In en, this message translates to:
  /// **'Search content'**
  String get searchContent;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithMessage(String error);

  /// No description provided for @errorLoadingTasks.
  ///
  /// In en, this message translates to:
  /// **'Error loading tasks: {error}'**
  String errorLoadingTasks(String error);

  /// No description provided for @noActiveTracks.
  ///
  /// In en, this message translates to:
  /// **'No active tracks'**
  String get noActiveTracks;

  /// No description provided for @askGrownUpToAddTrack.
  ///
  /// In en, this message translates to:
  /// **'Ask a grown-up to add a learning track.'**
  String get askGrownUpToAddTrack;

  /// No description provided for @addTrackToStart.
  ///
  /// In en, this message translates to:
  /// **'Add a track to start learning.'**
  String get addTrackToStart;

  /// No description provided for @todaysTasks.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Tasks'**
  String get todaysTasks;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @myCurricula.
  ///
  /// In en, this message translates to:
  /// **'My Curricula'**
  String get myCurricula;

  /// No description provided for @percentComplete.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String percentComplete(int percent);

  /// No description provided for @viewProgress.
  ///
  /// In en, this message translates to:
  /// **'View progress'**
  String get viewProgress;

  /// No description provided for @markComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark complete'**
  String get markComplete;

  /// No description provided for @textReaderNextDailyTask.
  ///
  /// In en, this message translates to:
  /// **'Next daily task'**
  String get textReaderNextDailyTask;

  /// No description provided for @noProjection.
  ///
  /// In en, this message translates to:
  /// **'No projection'**
  String get noProjection;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get today;

  /// No description provided for @plusNMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String plusNMore(int count);

  /// No description provided for @noTracksYet.
  ///
  /// In en, this message translates to:
  /// **'No tracks yet'**
  String get noTracksYet;

  /// No description provided for @firstTrackPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add your first learning track to get started.'**
  String get firstTrackPrompt;

  /// No description provided for @paceAhead.
  ///
  /// In en, this message translates to:
  /// **'{days}d ahead'**
  String paceAhead(int days);

  /// No description provided for @paceBehind.
  ///
  /// In en, this message translates to:
  /// **'{days}d behind'**
  String paceBehind(int days);

  /// No description provided for @paceOnPace.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get paceOnPace;

  /// No description provided for @progressNoDataTitle.
  ///
  /// In en, this message translates to:
  /// **'No progress yet'**
  String get progressNoDataTitle;

  /// No description provided for @progressNoDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start learning to see your progress here.'**
  String get progressNoDataSubtitle;

  /// No description provided for @statCompletions.
  ///
  /// In en, this message translates to:
  /// **'COMPLETIONS'**
  String get statCompletions;

  /// No description provided for @statUnitsDone.
  ///
  /// In en, this message translates to:
  /// **'UNITS DONE'**
  String get statUnitsDone;

  /// No description provided for @statDayStreak.
  ///
  /// In en, this message translates to:
  /// **'DAY STREAK'**
  String get statDayStreak;

  /// No description provided for @statActiveTracks.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE TRACKS'**
  String get statActiveTracks;

  /// No description provided for @progressChartsTile.
  ///
  /// In en, this message translates to:
  /// **'Progress Charts'**
  String get progressChartsTile;

  /// No description provided for @progressChartsTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completions, trends, and more'**
  String get progressChartsTileSubtitle;

  /// No description provided for @learningLifetime.
  ///
  /// In en, this message translates to:
  /// **'Learning Lifetime'**
  String get learningLifetime;

  /// No description provided for @learningLifetimeExpandHint.
  ///
  /// In en, this message translates to:
  /// **'Per curriculum: expand to browse what you have learned'**
  String get learningLifetimeExpandHint;

  /// No description provided for @addWhatYouLearned.
  ///
  /// In en, this message translates to:
  /// **'Add what you\'ve learned'**
  String get addWhatYouLearned;

  /// No description provided for @addWhatYouLearnedSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log custom Mitzvot or Torah studies'**
  String get addWhatYouLearnedSettingsSubtitle;

  /// No description provided for @lifetimeLearning.
  ///
  /// In en, this message translates to:
  /// **'Lifetime Learning'**
  String get lifetimeLearning;

  /// No description provided for @lifetimeLearningHubSection.
  ///
  /// In en, this message translates to:
  /// **'LEARNING HUB'**
  String get lifetimeLearningHubSection;

  /// No description provided for @lifetimeXpTotal.
  ///
  /// In en, this message translates to:
  /// **'{points} XP Total'**
  String lifetimeXpTotal(String points);

  /// No description provided for @lifetimeStartAdding.
  ///
  /// In en, this message translates to:
  /// **'Start Adding'**
  String get lifetimeStartAdding;

  /// No description provided for @lifetimeBrowseFullLibrary.
  ///
  /// In en, this message translates to:
  /// **'Browse Full Library'**
  String get lifetimeBrowseFullLibrary;

  /// No description provided for @lifetimeHowItWorksStep1.
  ///
  /// In en, this message translates to:
  /// **'Select a category from the library grid to see all available tracks.'**
  String get lifetimeHowItWorksStep1;

  /// No description provided for @lifetimeHowItWorksStep2.
  ///
  /// In en, this message translates to:
  /// **'Toggle units you\'ve finished to update your lifetime progress map.'**
  String get lifetimeHowItWorksStep2;

  /// No description provided for @lifetimeHowItWorksStep3.
  ///
  /// In en, this message translates to:
  /// **'Earn special milestone badges for completing whole volumes or tractates.'**
  String get lifetimeHowItWorksStep3;

  /// No description provided for @lifetimeNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get lifetimeNotStarted;

  /// No description provided for @lifetimeAddHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Add what you\'ve learned'**
  String get lifetimeAddHeaderTitle;

  /// No description provided for @lifetimeAddHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mark what you\'ve already studied — in print or anywhere — as lifetime learning.'**
  String get lifetimeAddHeaderSubtitle;

  /// No description provided for @lifetimeHowItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get lifetimeHowItWorksTitle;

  /// No description provided for @lifetimeHowItWorksBody.
  ///
  /// In en, this message translates to:
  /// **'Open a curriculum, then use the folder list to select sections. Green = selected for saving; open a subfolder with the arrow when there is more inside.'**
  String get lifetimeHowItWorksBody;

  /// No description provided for @lifetimeSelectScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Select what you\'ve learned'**
  String get lifetimeSelectScreenTitle;

  /// No description provided for @lifetimeSelectScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check sections to include; open folders to go deeper.'**
  String get lifetimeSelectScreenSubtitle;

  /// No description provided for @lifetimeMarkAsLearnedTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as lifetime learned'**
  String get lifetimeMarkAsLearnedTitle;

  /// No description provided for @lifetimeMarkAsLearnedLine.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count} • level {level}'**
  String lifetimeMarkAsLearnedLine(int count, int level);

  /// No description provided for @selectAllInThisList.
  ///
  /// In en, this message translates to:
  /// **'Select all in this list'**
  String get selectAllInThisList;

  /// No description provided for @deselectAllInThisList.
  ///
  /// In en, this message translates to:
  /// **'Deselect all in this list'**
  String get deselectAllInThisList;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @contentLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load curriculum content: {error}'**
  String contentLoadError(String error);

  /// No description provided for @noItemsAtThisLevel.
  ///
  /// In en, this message translates to:
  /// **'No items at this level'**
  String get noItemsAtThisLevel;

  /// No description provided for @breadcrumbsRoot.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get breadcrumbsRoot;

  /// No description provided for @lifetimeMarkSavedCount.
  ///
  /// In en, this message translates to:
  /// **'Marked {count} lifetime selection(s).'**
  String lifetimeMarkSavedCount(int count);

  /// No description provided for @lifetimeMarkSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save lifetime marks: {error}'**
  String lifetimeMarkSaveError(String error);

  /// No description provided for @dashboardStats.
  ///
  /// In en, this message translates to:
  /// **'STATS'**
  String get dashboardStats;

  /// No description provided for @learningLifetimeAllCurricula.
  ///
  /// In en, this message translates to:
  /// **'Learning lifetime (all curricula)'**
  String get learningLifetimeAllCurricula;

  /// No description provided for @lifetimeSectionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{learned} / {total} sections — {n} curricula'**
  String lifetimeSectionsSummary(String learned, String total, int n);

  /// No description provided for @greetingHelloName.
  ///
  /// In en, this message translates to:
  /// **'Shalom, {name}!'**
  String greetingHelloName(String name);

  /// No description provided for @noFocusTag.
  ///
  /// In en, this message translates to:
  /// **'NO FOCUS TAG'**
  String get noFocusTag;

  /// No description provided for @todaysMissions.
  ///
  /// In en, this message translates to:
  /// **'Today’s Missions'**
  String get todaysMissions;

  /// No description provided for @noTasksInLane.
  ///
  /// In en, this message translates to:
  /// **'No tasks in this lane'**
  String get noTasksInLane;

  /// No description provided for @reviewSection.
  ///
  /// In en, this message translates to:
  /// **'REVIEW SECTION'**
  String get reviewSection;

  /// No description provided for @chazaraReview.
  ///
  /// In en, this message translates to:
  /// **'Chazara/Review'**
  String get chazaraReview;

  /// No description provided for @activeTrackChazaraLabel.
  ///
  /// In en, this message translates to:
  /// **'Chazara'**
  String get activeTrackChazaraLabel;

  /// No description provided for @urgent.
  ///
  /// In en, this message translates to:
  /// **'URGENT'**
  String get urgent;

  /// No description provided for @missedOverdue.
  ///
  /// In en, this message translates to:
  /// **'Missed/Overdue'**
  String get missedOverdue;

  /// No description provided for @bubbleOverdue.
  ///
  /// In en, this message translates to:
  /// **'OVERDUE'**
  String get bubbleOverdue;

  /// No description provided for @bubbleTodayDue.
  ///
  /// In en, this message translates to:
  /// **'TODAY\nDUE'**
  String get bubbleTodayDue;

  /// No description provided for @bubbleChazara.
  ///
  /// In en, this message translates to:
  /// **'CHAZARA'**
  String get bubbleChazara;

  /// No description provided for @mainFocus.
  ///
  /// In en, this message translates to:
  /// **'MAIN FOCUS'**
  String get mainFocus;

  /// No description provided for @carouselCompletion.
  ///
  /// In en, this message translates to:
  /// **'Completion'**
  String get carouselCompletion;

  /// No description provided for @continueCta.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get continueCta;

  /// No description provided for @tabSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get tabSchedule;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday;

  /// No description provided for @nothingDueInQueue.
  ///
  /// In en, this message translates to:
  /// **'Nothing due in this queue right now.'**
  String get nothingDueInQueue;

  /// No description provided for @selfPacedScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'All of it, or just a section?'**
  String get selfPacedScopeTitle;

  /// No description provided for @learnEntireCurriculumCta.
  ///
  /// In en, this message translates to:
  /// **'I want to learn everything!'**
  String get learnEntireCurriculumCta;

  /// No description provided for @learnEntireCurriculumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the entire {name}'**
  String learnEntireCurriculumSubtitle(String name);

  /// No description provided for @faster.
  ///
  /// In en, this message translates to:
  /// **'FASTER!'**
  String get faster;

  /// No description provided for @level1Selection.
  ///
  /// In en, this message translates to:
  /// **'{name} → {levelLabel} selection'**
  String level1Selection(String name, String levelLabel);

  /// No description provided for @scopeSelectedBadge.
  ///
  /// In en, this message translates to:
  /// **'SELECTED'**
  String get scopeSelectedBadge;

  /// No description provided for @selectAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Select at least one'**
  String get selectAtLeastOne;

  /// No description provided for @continueWithSelectionCount.
  ///
  /// In en, this message translates to:
  /// **'Continue with {count} selected'**
  String continueWithSelectionCount(int count);

  /// No description provided for @sectionLearning.
  ///
  /// In en, this message translates to:
  /// **'LEARNING'**
  String get sectionLearning;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @notificationSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Push, email, and study sound alerts'**
  String get notificationSettingsSubtitle;

  /// No description provided for @pointsAbbrev.
  ///
  /// In en, this message translates to:
  /// **'{count} pts'**
  String pointsAbbrev(int count);

  /// No description provided for @sectionTracks.
  ///
  /// In en, this message translates to:
  /// **'TRACKS'**
  String get sectionTracks;

  /// No description provided for @sectionAccount.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get sectionAccount;

  /// No description provided for @sectionParentalControls.
  ///
  /// In en, this message translates to:
  /// **'PARENTAL CONTROLS'**
  String get sectionParentalControls;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove this account and cloud data'**
  String get deleteAccountSubtitle;

  /// No description provided for @settingsHandcraftedTagline.
  ///
  /// In en, this message translates to:
  /// **'Handcrafted for your Torah journey'**
  String get settingsHandcraftedTagline;

  /// No description provided for @calendarPreference.
  ///
  /// In en, this message translates to:
  /// **'Calendar Preference'**
  String get calendarPreference;

  /// No description provided for @calendarPreferenceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Goals, deadlines, and date pickers'**
  String get calendarPreferenceSubtitle;

  /// No description provided for @calendarGregorian.
  ///
  /// In en, this message translates to:
  /// **'Gregorian'**
  String get calendarGregorian;

  /// No description provided for @calendarHebrew.
  ///
  /// In en, this message translates to:
  /// **'Hebrew'**
  String get calendarHebrew;

  /// No description provided for @parentMode.
  ///
  /// In en, this message translates to:
  /// **'Parent Mode'**
  String get parentMode;

  /// No description provided for @parentModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to admin (PIN-guarded)'**
  String get parentModeSubtitle;

  /// No description provided for @parentPin.
  ///
  /// In en, this message translates to:
  /// **'Parent PIN'**
  String get parentPin;

  /// No description provided for @parentPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change your security PIN'**
  String get parentPinSubtitle;

  /// No description provided for @passwordChangedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully.'**
  String get passwordChangedSuccessfully;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @userFallbackDisplayName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userFallbackDisplayName;

  /// No description provided for @proBadge.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get proBadge;

  /// No description provided for @selfLearnerBadge.
  ///
  /// In en, this message translates to:
  /// **'SELF-LEARNER'**
  String get selfLearnerBadge;

  /// No description provided for @noBackup.
  ///
  /// In en, this message translates to:
  /// **'No Backup'**
  String get noBackup;

  /// No description provided for @chooseLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get chooseLanguageTitle;

  /// No description provided for @preferredLanguageForContent.
  ///
  /// In en, this message translates to:
  /// **'Preferred language for content'**
  String get preferredLanguageForContent;

  /// No description provided for @profilePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Who is learning?'**
  String get profilePickerTitle;

  /// No description provided for @profilePickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a profile to continue your\njourney'**
  String get profilePickerSubtitle;

  /// No description provided for @addProfile.
  ///
  /// In en, this message translates to:
  /// **'Add Profile'**
  String get addProfile;

  /// No description provided for @createProfile.
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get createProfile;

  /// No description provided for @enterNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get enterNameHint;

  /// No description provided for @chooseMode.
  ///
  /// In en, this message translates to:
  /// **'Choose Mode'**
  String get chooseMode;

  /// No description provided for @childModeCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Child Mode'**
  String get childModeCardTitle;

  /// No description provided for @childModeCardSubtitleFunRewards.
  ///
  /// In en, this message translates to:
  /// **'Fun & Rewards'**
  String get childModeCardSubtitleFunRewards;

  /// No description provided for @adultModeCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Adult Mode'**
  String get adultModeCardTitle;

  /// No description provided for @adultModeCardSubtitleDeepFocused.
  ///
  /// In en, this message translates to:
  /// **'Deep & Focused'**
  String get adultModeCardSubtitleDeepFocused;

  /// No description provided for @profileBadgeChildMode.
  ///
  /// In en, this message translates to:
  /// **'CHILD MODE'**
  String get profileBadgeChildMode;

  /// No description provided for @profileBadgeAdultMode.
  ///
  /// In en, this message translates to:
  /// **'ADULT MODE'**
  String get profileBadgeAdultMode;

  /// No description provided for @profileNameTaken.
  ///
  /// In en, this message translates to:
  /// **'A profile named \"{name}\" already exists'**
  String profileNameTaken(String name);

  /// No description provided for @maxProfilesReached.
  ///
  /// In en, this message translates to:
  /// **'Maximum 10 profiles reached'**
  String get maxProfilesReached;

  /// No description provided for @renameAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameAction;

  /// No description provided for @mustKeepOneProfile.
  ///
  /// In en, this message translates to:
  /// **'You must have at least one profile'**
  String get mustKeepOneProfile;

  /// No description provided for @profileNameAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'A profile with this name already exists'**
  String get profileNameAlreadyExists;

  /// No description provided for @renameProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Profile'**
  String get renameProfileTitle;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @deleteProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Profile?'**
  String get deleteProfileTitle;

  /// No description provided for @deleteProfileConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete \"{name}\" and ALL associated learning data? This cannot be undone.'**
  String deleteProfileConfirm(String name);

  /// No description provided for @cannotDeleteOnlyProfile.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete your only profile'**
  String get cannotDeleteOnlyProfile;

  /// No description provided for @tapToContinue.
  ///
  /// In en, this message translates to:
  /// **'Tap to\ncontinue'**
  String get tapToContinue;

  /// No description provided for @maxProfilesLabel.
  ///
  /// In en, this message translates to:
  /// **'Max Profiles'**
  String get maxProfilesLabel;

  /// No description provided for @addProfileCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Add\nProfile'**
  String get addProfileCardTitle;

  /// No description provided for @maxProfilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Maximum reached'**
  String get maxProfilesSubtitle;

  /// No description provided for @createNewLearner.
  ///
  /// In en, this message translates to:
  /// **'Create new\nlearner'**
  String get createNewLearner;

  /// No description provided for @profilesLabel.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profilesLabel;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @syncScreenBody.
  ///
  /// In en, this message translates to:
  /// **'Sync status and settings will appear here.'**
  String get syncScreenBody;

  /// No description provided for @parentSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent Settings'**
  String get parentSettingsTitle;

  /// No description provided for @manageTracksForChildSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add, edit, or archive your child\'s tracks'**
  String get manageTracksForChildSubtitle;

  /// No description provided for @pointConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Point Configuration'**
  String get pointConfiguration;

  /// No description provided for @pointConfigurationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set how many points activities are worth'**
  String get pointConfigurationSubtitle;

  /// No description provided for @pointConfigPerTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Points per completed task'**
  String get pointConfigPerTaskTitle;

  /// No description provided for @pointConfigPerTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'For each active learning track, set how many points your child earns when they complete one task from their daily list. The amount depends on the task stage (for example first learn vs review).'**
  String get pointConfigPerTaskDescription;

  /// No description provided for @pointConfigNoActiveTracksBody.
  ///
  /// In en, this message translates to:
  /// **'No active learning tracks with stages were found for this child. Turn on curricula and set up tracks in Manage Tracks, then return here to choose points per task.'**
  String get pointConfigNoActiveTracksBody;

  /// No description provided for @pointSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Point Settings'**
  String get pointSettingsTitle;

  /// No description provided for @pointSettingsConfigurationLabel.
  ///
  /// In en, this message translates to:
  /// **'CONFIGURATION'**
  String get pointSettingsConfigurationLabel;

  /// No description provided for @pointSettingsRewardsStrategyTitle.
  ///
  /// In en, this message translates to:
  /// **'Rewards Strategy'**
  String get pointSettingsRewardsStrategyTitle;

  /// No description provided for @pointSettingsRewardsStrategySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust how many points your child earns for each sacred milestone.'**
  String get pointSettingsRewardsStrategySubtitle;

  /// No description provided for @pointSettingsActiveCurricula.
  ///
  /// In en, this message translates to:
  /// **'Active Curricula'**
  String get pointSettingsActiveCurricula;

  /// No description provided for @pointSettingsPointsPerTask.
  ///
  /// In en, this message translates to:
  /// **'Points per Task'**
  String get pointSettingsPointsPerTask;

  /// No description provided for @pointSettingsPts.
  ///
  /// In en, this message translates to:
  /// **'PTS'**
  String get pointSettingsPts;

  /// No description provided for @pointSettingsActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get pointSettingsActiveBadge;

  /// No description provided for @pointSettingsSaveAll.
  ///
  /// In en, this message translates to:
  /// **'Save All Changes'**
  String get pointSettingsSaveAll;

  /// No description provided for @pointSettingsSaveFooter.
  ///
  /// In en, this message translates to:
  /// **'Point changes will sync instantly to the Child\'s dashboard.'**
  String get pointSettingsSaveFooter;

  /// No description provided for @pointSettingsSavedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Changes saved and synced.'**
  String get pointSettingsSavedSnackbar;

  /// No description provided for @pointSettingsNothingToSaveSnackbar.
  ///
  /// In en, this message translates to:
  /// **'No changes to save.'**
  String get pointSettingsNothingToSaveSnackbar;

  /// No description provided for @pointSettingsOtherStages.
  ///
  /// In en, this message translates to:
  /// **'Other stages (reviews)'**
  String get pointSettingsOtherStages;

  /// No description provided for @pointSettingsResetTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get pointSettingsResetTrackTitle;

  /// No description provided for @pointSettingsResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get pointSettingsResetConfirm;

  /// No description provided for @pointSettingsResetTrackMessage.
  ///
  /// In en, this message translates to:
  /// **'Reset all point values for this track to the default ladder?'**
  String get pointSettingsResetTrackMessage;

  /// No description provided for @pointSettingsResetAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset all tracks'**
  String get pointSettingsResetAllTitle;

  /// No description provided for @pointSettingsResetAllMessage.
  ///
  /// In en, this message translates to:
  /// **'Reset point values for every active track to defaults?'**
  String get pointSettingsResetAllMessage;

  /// No description provided for @pointSettingsMenuResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all tracks…'**
  String get pointSettingsMenuResetAll;

  /// No description provided for @pointSettingsPrimaryStageLabel.
  ///
  /// In en, this message translates to:
  /// **'First completion (daily task)'**
  String get pointSettingsPrimaryStageLabel;

  /// No description provided for @sectionAccountSafety.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT SAFETY'**
  String get sectionAccountSafety;

  /// No description provided for @bottomNavTracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get bottomNavTracks;

  /// No description provided for @bottomNavRewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get bottomNavRewards;

  /// No description provided for @bottomNavParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get bottomNavParent;

  /// No description provided for @addProfileDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a name and select Child mode or Adult mode.'**
  String get addProfileDialogSubtitle;

  /// No description provided for @setParentPinDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Parent PIN'**
  String get setParentPinDialogTitle;

  /// No description provided for @setParentPinDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set a 4-digit PIN to access parent controls for {name}. The PIN is stored only on this device.'**
  String setParentPinDialogSubtitle(String name);

  /// No description provided for @enterParentPin.
  ///
  /// In en, this message translates to:
  /// **'Enter Parent PIN'**
  String get enterParentPin;

  /// No description provided for @enterParentPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4-digit PIN to access parent settings.'**
  String get enterParentPinSubtitle;

  /// No description provided for @enterNewPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new 4-digit PIN.'**
  String get enterNewPinSubtitle;

  /// No description provided for @confirmNewPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the same PIN again to confirm.'**
  String get confirmNewPinSubtitle;

  /// No description provided for @changeParentPin.
  ///
  /// In en, this message translates to:
  /// **'Change Parent PIN'**
  String get changeParentPin;

  /// No description provided for @pinChangedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'PIN changed successfully'**
  String get pinChangedSuccessfully;

  /// No description provided for @deviceRestoreChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking device...'**
  String get deviceRestoreChecking;

  /// No description provided for @deviceRestoreComplete.
  ///
  /// In en, this message translates to:
  /// **'Restore complete!'**
  String get deviceRestoreComplete;

  /// No description provided for @deviceRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get deviceRestoreFailed;

  /// No description provided for @deviceRestoreStep.
  ///
  /// In en, this message translates to:
  /// **'Step {completed} of {total}'**
  String deviceRestoreStep(int completed, int total);

  /// No description provided for @skipAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Skip & continue'**
  String get skipAndContinue;

  /// No description provided for @noActiveProfile.
  ///
  /// In en, this message translates to:
  /// **'No active profile'**
  String get noActiveProfile;

  /// No description provided for @incorrectPin.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get incorrectPin;

  /// No description provided for @enterCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Enter Current PIN'**
  String get enterCurrentPin;

  /// No description provided for @enterNewPin.
  ///
  /// In en, this message translates to:
  /// **'Enter New PIN'**
  String get enterNewPin;

  /// No description provided for @confirmNewPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm New PIN'**
  String get confirmNewPin;

  /// No description provided for @pinsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get pinsDoNotMatch;

  /// No description provided for @tabBarDashboard.
  ///
  /// In en, this message translates to:
  /// **'DASHBOARD'**
  String get tabBarDashboard;

  /// No description provided for @tabBarLearn.
  ///
  /// In en, this message translates to:
  /// **'LEARN'**
  String get tabBarLearn;

  /// No description provided for @tabBarProgress.
  ///
  /// In en, this message translates to:
  /// **'PROGRESS'**
  String get tabBarProgress;

  /// No description provided for @tabBarSettings.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get tabBarSettings;

  /// No description provided for @errorLoadingCalendar.
  ///
  /// In en, this message translates to:
  /// **'Error loading calendar'**
  String get errorLoadingCalendar;

  /// No description provided for @journeyByCurriculum.
  ///
  /// In en, this message translates to:
  /// **'By Curriculum'**
  String get journeyByCurriculum;

  /// No description provided for @journeyTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get journeyTimeline;

  /// No description provided for @journeyTitleNamed.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Learning Journey'**
  String journeyTitleNamed(String name);

  /// No description provided for @loadingYourJourney.
  ///
  /// In en, this message translates to:
  /// **'Loading your journey...'**
  String get loadingYourJourney;

  /// No description provided for @failedToLoadJourney.
  ///
  /// In en, this message translates to:
  /// **'Failed to load journey: {error}'**
  String failedToLoadJourney(String error);

  /// No description provided for @journeyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your learning journey starts here!'**
  String get journeyEmptyTitle;

  /// No description provided for @journeyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Complete your first masechta to see it recorded forever.'**
  String get journeyEmptyBody;

  /// No description provided for @progressChartsTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress Charts'**
  String get progressChartsTitle;

  /// No description provided for @chartCompletionsOverTime.
  ///
  /// In en, this message translates to:
  /// **'Completions Over Time'**
  String get chartCompletionsOverTime;

  /// No description provided for @chartDailyActivity.
  ///
  /// In en, this message translates to:
  /// **'DAILY ACTIVITY'**
  String get chartDailyActivity;

  /// No description provided for @chartCumulativeProgress.
  ///
  /// In en, this message translates to:
  /// **'Cumulative Progress'**
  String get chartCumulativeProgress;

  /// No description provided for @chartCumulativeProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'+12% vs last week'**
  String get chartCumulativeProgressSubtitle;

  /// No description provided for @chartPointsEarned.
  ///
  /// In en, this message translates to:
  /// **'Points Earned'**
  String get chartPointsEarned;

  /// No description provided for @chartTotalTorahPoints.
  ///
  /// In en, this message translates to:
  /// **'TOTAL TORAH POINTS'**
  String get chartTotalTorahPoints;

  /// No description provided for @chartLearningJourney.
  ///
  /// In en, this message translates to:
  /// **'Learning Journey'**
  String get chartLearningJourney;

  /// No description provided for @chartJourneyMotivation.
  ///
  /// In en, this message translates to:
  /// **'Keep the flame alive every day!'**
  String get chartJourneyMotivation;

  /// No description provided for @chartSevenDayStreak.
  ///
  /// In en, this message translates to:
  /// **'7 DAY STREAK!'**
  String get chartSevenDayStreak;

  /// No description provided for @chartLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get chartLast7Days;

  /// No description provided for @chartLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30\nDays'**
  String get chartLast30Days;

  /// No description provided for @chartAllTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get chartAllTime;

  /// No description provided for @chartFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get chartFilterAll;

  /// No description provided for @notifAppBarSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get notifAppBarSettings;

  /// No description provided for @notifHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifHeroTitle;

  /// No description provided for @notifHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your Torah journey on track!'**
  String get notifHeroSubtitle;

  /// No description provided for @notifDailyReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily Reminder'**
  String get notifDailyReminder;

  /// No description provided for @notifDailyReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Don\'t forget to learn today!'**
  String get notifDailyReminderSubtitle;

  /// No description provided for @notifReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder Time'**
  String get notifReminderTime;

  /// No description provided for @notifStreakAlert.
  ///
  /// In en, this message translates to:
  /// **'Streak Alert'**
  String get notifStreakAlert;

  /// No description provided for @notifStreakAlertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your fire burning!'**
  String get notifStreakAlertSubtitle;

  /// No description provided for @notifHotStreakBadge.
  ///
  /// In en, this message translates to:
  /// **'HOT STREAK'**
  String get notifHotStreakBadge;

  /// No description provided for @notifStreakAlertTime.
  ///
  /// In en, this message translates to:
  /// **'Streak Alert Time'**
  String get notifStreakAlertTime;

  /// No description provided for @notifRewardNotifications.
  ///
  /// In en, this message translates to:
  /// **'Reward Notifications'**
  String get notifRewardNotifications;

  /// No description provided for @notifRewardNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When you earn Mitzvah Points!'**
  String get notifRewardNotificationsSubtitle;

  /// No description provided for @notifSacredTime.
  ///
  /// In en, this message translates to:
  /// **'SACRED TIME'**
  String get notifSacredTime;

  /// No description provided for @notifShabbosYomTovMode.
  ///
  /// In en, this message translates to:
  /// **'Shabbos / Yom Tov\nMode'**
  String get notifShabbosYomTovMode;

  /// No description provided for @notifShabbosModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quiet learning during holy days'**
  String get notifShabbosModeSubtitle;

  /// No description provided for @notifUseLocationForTimes.
  ///
  /// In en, this message translates to:
  /// **'Use Location for Times'**
  String get notifUseLocationForTimes;

  /// No description provided for @notifQuietStart.
  ///
  /// In en, this message translates to:
  /// **'QUIET START'**
  String get notifQuietStart;

  /// No description provided for @notifQuietEnd.
  ///
  /// In en, this message translates to:
  /// **'QUIET END'**
  String get notifQuietEnd;

  /// No description provided for @notifCandleLighting.
  ///
  /// In en, this message translates to:
  /// **'Candle lighting'**
  String get notifCandleLighting;

  /// No description provided for @notifHavdalah.
  ///
  /// In en, this message translates to:
  /// **'Havdalah'**
  String get notifHavdalah;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get authPasswordRequired;

  /// No description provided for @authLocalDataMissing.
  ///
  /// In en, this message translates to:
  /// **'This account\'s local data is missing. Connect to the internet to restore it.'**
  String get authLocalDataMissing;

  /// No description provided for @authEmailOfflineUnreachable.
  ///
  /// In en, this message translates to:
  /// **'This email isn\'t on this device and we can\'t reach the cloud. Try again when online.'**
  String get authEmailOfflineUnreachable;

  /// No description provided for @authIncorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get authIncorrectPassword;

  /// No description provided for @authSignInFailedError.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {error}'**
  String authSignInFailedError(String error);

  /// No description provided for @authVerifyEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to your inbox. Please check your email to continue.'**
  String get authVerifyEmailBody;

  /// No description provided for @authIveVerified.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified'**
  String get authIveVerified;

  /// No description provided for @authVerificationEmailSentAgain.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent again.'**
  String get authVerificationEmailSentAgain;

  /// No description provided for @authEmailStillUnverified.
  ///
  /// In en, this message translates to:
  /// **'Email is still unverified. Check your inbox first.'**
  String get authEmailStillUnverified;

  /// No description provided for @authMaxDeviceAccounts.
  ///
  /// In en, this message translates to:
  /// **'Maximum {count} device accounts reached. Remove one to add another.'**
  String authMaxDeviceAccounts(int count);

  /// No description provided for @authOfflineUseUpgrade.
  ///
  /// In en, this message translates to:
  /// **'An offline account with this email exists on this device. Use the Upgrade to Cloud option in Settings instead.'**
  String get authOfflineUseUpgrade;

  /// No description provided for @authGoogleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In failed. Please try again.'**
  String get authGoogleSignInFailed;

  /// No description provided for @authErrUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email.'**
  String get authErrUserNotFound;

  /// No description provided for @authErrWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get authErrWrongPassword;

  /// No description provided for @authErrInvalidCredential.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password. Please try again.'**
  String get authErrInvalidCredential;

  /// No description provided for @authErrUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get authErrUserDisabled;

  /// No description provided for @authErrTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get authErrTooManyRequests;

  /// No description provided for @authErrInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get authErrInvalidEmail;

  /// No description provided for @authErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get authErrNetwork;

  /// No description provided for @authErrSignInGeneric.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get authErrSignInGeneric;

  /// No description provided for @authTierCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get authTierCloud;

  /// No description provided for @authTierLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get authTierLocal;

  /// No description provided for @authFoundOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Found on this device ({tier})'**
  String authFoundOnDevice(String tier);

  /// No description provided for @authNotOnDeviceCheckCloud.
  ///
  /// In en, this message translates to:
  /// **'Not on this device — we\'ll check the cloud'**
  String get authNotOnDeviceCheckCloud;

  /// No description provided for @authNotOnDeviceOffline.
  ///
  /// In en, this message translates to:
  /// **'Not on this device (offline — only device accounts available)'**
  String get authNotOnDeviceOffline;

  /// No description provided for @authModeCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud account: your data is backed up and syncs across devices.'**
  String get authModeCloud;

  /// No description provided for @authModeCloudOffline.
  ///
  /// In en, this message translates to:
  /// **'Cloud account is offline right now. We will try local cached data until internet returns.'**
  String get authModeCloudOffline;

  /// No description provided for @authModeLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Local account only: no cloud backup and no device sync.'**
  String get authModeLocalTitle;

  /// No description provided for @authModeLocalBody.
  ///
  /// In en, this message translates to:
  /// **'No cloud backup or device sync. Your data stays only on this device.'**
  String get authModeLocalBody;

  /// No description provided for @signInWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get signInWelcomeBack;

  /// No description provided for @signInReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for your next learning adventure?'**
  String get signInReady;

  /// No description provided for @signInYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Your Email'**
  String get signInYourEmail;

  /// No description provided for @signInEmailHint.
  ///
  /// In en, this message translates to:
  /// **'yourname@quest.com'**
  String get signInEmailHint;

  /// No description provided for @signInPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret Key'**
  String get signInPasswordLabel;

  /// No description provided for @signInPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'••••••••'**
  String get signInPasswordHint;

  /// No description provided for @signInKeepMeSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Keep me signed in'**
  String get signInKeepMeSignedIn;

  /// No description provided for @signInCta.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInCta;

  /// No description provided for @signInWithGoogleCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogleCta;

  /// No description provided for @signInNewToQuest.
  ///
  /// In en, this message translates to:
  /// **'New to the Quest? '**
  String get signInNewToQuest;

  /// No description provided for @signInRegisterHere.
  ///
  /// In en, this message translates to:
  /// **'Register Here'**
  String get signInRegisterHere;

  /// No description provided for @chartFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get chartFailedToLoad;

  /// No description provided for @accountPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an Account'**
  String get accountPickerTitle;

  /// No description provided for @accountPickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a learner to continue your journey'**
  String get accountPickerSubtitle;

  /// No description provided for @accountPickerMaxAccountsShort.
  ///
  /// In en, this message translates to:
  /// **'Maximum {count} device accounts reached'**
  String accountPickerMaxAccountsShort(int count);

  /// No description provided for @accountPickerPrivacyFooter.
  ///
  /// In en, this message translates to:
  /// **'Manage your privacy and security in Settings'**
  String get accountPickerPrivacyFooter;

  /// No description provided for @accountRemoveFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove from device'**
  String get accountRemoveFromDevice;

  /// No description provided for @accountDeleteAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteAccountAction;

  /// No description provided for @badgeLocalAccount.
  ///
  /// In en, this message translates to:
  /// **'LOCAL ACCOUNT'**
  String get badgeLocalAccount;

  /// No description provided for @badgeSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN AGAIN'**
  String get badgeSignInAgain;

  /// No description provided for @badgeCloudAccount.
  ///
  /// In en, this message translates to:
  /// **'CLOUD ACCOUNT'**
  String get badgeCloudAccount;

  /// No description provided for @accountRemoveFromDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from device?'**
  String get accountRemoveFromDeviceTitle;

  /// No description provided for @accountDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get accountDeleteAccountTitle;

  /// No description provided for @accountRemoveFromDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'Your cloud data is safe — you can sign back in anytime.'**
  String get accountRemoveFromDeviceBody;

  /// No description provided for @accountDeleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'All learning data will be permanently lost. This cannot be undone.'**
  String get accountDeleteAccountBody;

  /// No description provided for @accountRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get accountRemove;

  /// No description provided for @accountDeleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete Forever'**
  String get accountDeleteForever;

  /// No description provided for @accountPickerAddAnother.
  ///
  /// In en, this message translates to:
  /// **'+1   Add another account ({remaining} slots remaining)'**
  String accountPickerAddAnother(int remaining);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
