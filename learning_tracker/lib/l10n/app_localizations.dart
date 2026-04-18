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
