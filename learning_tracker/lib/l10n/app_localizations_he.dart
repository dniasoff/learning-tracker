// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'מעקב לימוד תורה';

  @override
  String get dashboard => 'לוח בקרה';

  @override
  String get learn => 'לימוד';

  @override
  String get progress => 'התקדמות';

  @override
  String get settings => 'הגדרות';

  @override
  String get goodMorning => 'בוקר טוב';

  @override
  String get goodAfternoon => 'צהריים טובים';

  @override
  String get goodEvening => 'ערב טוב';

  @override
  String get streak => 'רצף';

  @override
  String get done => 'הושלם';

  @override
  String get points => 'נקודות';

  @override
  String get pages => 'עמודים';

  @override
  String get todaysLearning => 'הלימוד של היום';

  @override
  String remaining(int count) {
    return '$count נותרו';
  }

  @override
  String get allCaughtUp => 'הכל מעודכן!';

  @override
  String get noTasksRemaining => 'אין משימות נוספות להיום.';

  @override
  String get activeCurricula => 'תוכניות לימוד פעילות';

  @override
  String get continueLearning => 'המשך לימוד';

  @override
  String get recentActivity => 'פעילות אחרונה';

  @override
  String get myLearningJourney => 'מסע הלימוד שלי';

  @override
  String get seeLifetimeAchievements => 'הישגים לאורך כל הדרך';

  @override
  String get dailyProgress => 'התקדמות יומית';

  @override
  String get studyDay => 'יום לימוד';

  @override
  String get reviewDay => 'יום חזרה';

  @override
  String get mixedDay => 'משולב';

  @override
  String get restDay => 'יום מנוחה';

  @override
  String get overdue => 'באיחור';

  @override
  String moreTasks(int count) {
    return 'עוד $count משימות...';
  }

  @override
  String streakRecovery(int count) {
    return 'פספסת יום אחד אבל הרצף של $count ימים שמור!';
  }

  @override
  String get achievements => 'הישגים';

  @override
  String get activityCalendar => 'לוח פעילות';

  @override
  String get nextReward => 'הפרס הבא';

  @override
  String get earnedRewards => 'פרסים שהושגו';

  @override
  String get noRewardsYet => 'עדיין אין פרסים. המשיכו ללמוד!';

  @override
  String get mysteryReward => '!פרס מסתורי';

  @override
  String get totalPoints => 'סה״כ נקודות';

  @override
  String get complete => 'הושלם';

  @override
  String get gamification => 'הישגים ופרסים';

  @override
  String get rewardCatalog => 'קטלוג פרסים';

  @override
  String get noRewardsConfigured => 'עדיין לא הוגדרו פרסים';

  @override
  String get addReward => 'הוסף פרס';

  @override
  String get editReward => 'ערוך פרס';

  @override
  String get deleteReward => 'מחק פרס';

  @override
  String deleteRewardConfirm(String title) {
    return 'בטוח שברצונך למחוק את \"$title\"?';
  }

  @override
  String get cancel => 'ביטול';

  @override
  String get save => 'שמירה';

  @override
  String get add => 'הוספה';

  @override
  String get delete => 'מחיקה';

  @override
  String get reveal => 'חשיפה';

  @override
  String get revealed => 'נחשף';

  @override
  String get title => 'כותרת';

  @override
  String get description => 'תיאור';

  @override
  String get pointThreshold => 'סף נקודות';

  @override
  String get titleRequired => 'יש להזין כותרת';

  @override
  String get descriptionRequired => 'יש להזין תיאור';

  @override
  String get thresholdRequired => 'יש להזין סף';

  @override
  String get mustBePositive => 'חייב להיות מספר חיובי';

  @override
  String get milestoneType => 'סוג אבן דרך';

  @override
  String get pointsThreshold => 'סף נקודות';

  @override
  String get finishMasechta => 'סיום מסכת';

  @override
  String get finishSeder => 'סיום סדר';

  @override
  String get everyNItems => 'כל N פריטים';

  @override
  String get visibleToChild => 'גלוי לילד';

  @override
  String get childCanSee => 'הילד יכול לראות את הפרס';

  @override
  String get hiddenUntilEarned => 'מוסתר עד שנצבר (הפתעה)';

  @override
  String get onboarding => 'הגדרה ראשונית';

  @override
  String get getStarted => 'בואו נתחיל';

  @override
  String get alreadyHaveAccount => 'כבר יש לך חשבון?';

  @override
  String get whatsYourName => 'מה השם שלך?';

  @override
  String get adult => 'מבוגר';

  @override
  String get child => 'ילד';

  @override
  String get selectLanguage => 'בחר שפה';

  @override
  String get selectCurricula => 'בחר תוכניות לימוד';

  @override
  String get continueButton => 'המשך';

  @override
  String get skip => 'דלג';

  @override
  String get joinCalendarProgram => 'הצטרף לתוכנית לוח שנה';

  @override
  String get customTrack => 'מסלול מותאם אישית';

  @override
  String get joinCalendarDesc => 'עקוב אחרי לוח לימוד יומי כמו דף יומי';

  @override
  String get customTrackDesc => 'צור תוכנית לימוד משלך בקצב שלך';

  @override
  String get availablePrograms => 'תוכניות זמינות';

  @override
  String get todaysAssignment => 'המשימה של היום';

  @override
  String get startTrackingFrom => 'התחל מעקב מ';

  @override
  String get fromToday => 'מהיום';

  @override
  String get beginningOfPerek => 'תחילת הפרק הנוכחי';

  @override
  String get beginningOfMasechta => 'תחילת המסכת הנוכחית';

  @override
  String get specificDaf => 'מדף מסוים';

  @override
  String get setupComplete => '!ההגדרה הושלמה';

  @override
  String get addAnotherLearner => 'הוסף לומד נוסף';

  @override
  String get startLearning => 'התחל ללמוד';

  @override
  String get language => 'שפה';

  @override
  String get switchProfile => 'החלף פרופיל';

  @override
  String get notifications => 'התראות';

  @override
  String get retry => 'נסה שוב';

  @override
  String get error => 'שגיאה';

  @override
  String get loading => '...טוען';
}
