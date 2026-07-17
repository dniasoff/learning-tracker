// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pace_calculator.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProgressPaceCalculator {

// -------------------------------------------------------------------------
// Inputs
// -------------------------------------------------------------------------
/// Total number of items in the track (e.g. total mishnayos).
 int get totalItems;/// Items completed before [trackStartDate] via bulk-mark (sentinel date).
 int get bulkBaseline;/// Items completed on or after [trackStartDate] (live progress).
 int get liveProgress;/// The date the track was created/configured by the user (local-day
/// midnight).
 DateTime get trackStartDate;/// The user-set finish date (local-day midnight).
 DateTime get targetDate;/// Today's date (local-day midnight).
 DateTime get today;// -------------------------------------------------------------------------
// Derived fields — computed once in [ProgressPaceCalculator.compute]
// -------------------------------------------------------------------------
/// Items to complete per calendar day to finish on [targetDate].
///
/// 0.0 when [targetDate] == [trackStartDate] (degenerate range).
 double get requiredVelocity;/// Items completed per calendar day since [trackStartDate].
///
/// 0.0 when [today] == [trackStartDate] (day 0 — no elapsed time).
 double get actualVelocity;/// How many items should have been done by today at the required
/// velocity.
 double get expectedProgressToday;/// Signed difference between live progress and expected progress.
///
/// Positive = ahead of schedule. Negative = behind schedule.
 double get paceVariance;/// [paceVariance] expressed in calendar days.
///
/// Positive = ahead, negative = behind. 0.0 when [requiredVelocity] is 0.
 double get paceVarianceInDays;/// True when the track is within the [kPaceGraceWindowDays] window.
 bool get isInGraceWindow;/// The overall pace status derived from the inputs and computed fields.
 ProgressPaceStatus get paceStatus;
/// Create a copy of ProgressPaceCalculator
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProgressPaceCalculatorCopyWith<ProgressPaceCalculator> get copyWith => _$ProgressPaceCalculatorCopyWithImpl<ProgressPaceCalculator>(this as ProgressPaceCalculator, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProgressPaceCalculator&&(identical(other.totalItems, totalItems) || other.totalItems == totalItems)&&(identical(other.bulkBaseline, bulkBaseline) || other.bulkBaseline == bulkBaseline)&&(identical(other.liveProgress, liveProgress) || other.liveProgress == liveProgress)&&(identical(other.trackStartDate, trackStartDate) || other.trackStartDate == trackStartDate)&&(identical(other.targetDate, targetDate) || other.targetDate == targetDate)&&(identical(other.today, today) || other.today == today)&&(identical(other.requiredVelocity, requiredVelocity) || other.requiredVelocity == requiredVelocity)&&(identical(other.actualVelocity, actualVelocity) || other.actualVelocity == actualVelocity)&&(identical(other.expectedProgressToday, expectedProgressToday) || other.expectedProgressToday == expectedProgressToday)&&(identical(other.paceVariance, paceVariance) || other.paceVariance == paceVariance)&&(identical(other.paceVarianceInDays, paceVarianceInDays) || other.paceVarianceInDays == paceVarianceInDays)&&(identical(other.isInGraceWindow, isInGraceWindow) || other.isInGraceWindow == isInGraceWindow)&&(identical(other.paceStatus, paceStatus) || other.paceStatus == paceStatus));
}


@override
int get hashCode => Object.hash(runtimeType,totalItems,bulkBaseline,liveProgress,trackStartDate,targetDate,today,requiredVelocity,actualVelocity,expectedProgressToday,paceVariance,paceVarianceInDays,isInGraceWindow,paceStatus);



}

/// @nodoc
abstract mixin class $ProgressPaceCalculatorCopyWith<$Res>  {
  factory $ProgressPaceCalculatorCopyWith(ProgressPaceCalculator value, $Res Function(ProgressPaceCalculator) _then) = _$ProgressPaceCalculatorCopyWithImpl;
@useResult
$Res call({
 int totalItems, int bulkBaseline, int liveProgress, DateTime trackStartDate, DateTime targetDate, DateTime today, double requiredVelocity, double actualVelocity, double expectedProgressToday, double paceVariance, double paceVarianceInDays, bool isInGraceWindow, ProgressPaceStatus paceStatus
});




}
/// @nodoc
class _$ProgressPaceCalculatorCopyWithImpl<$Res>
    implements $ProgressPaceCalculatorCopyWith<$Res> {
  _$ProgressPaceCalculatorCopyWithImpl(this._self, this._then);

  final ProgressPaceCalculator _self;
  final $Res Function(ProgressPaceCalculator) _then;

/// Create a copy of ProgressPaceCalculator
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalItems = null,Object? bulkBaseline = null,Object? liveProgress = null,Object? trackStartDate = null,Object? targetDate = null,Object? today = null,Object? requiredVelocity = null,Object? actualVelocity = null,Object? expectedProgressToday = null,Object? paceVariance = null,Object? paceVarianceInDays = null,Object? isInGraceWindow = null,Object? paceStatus = null,}) {
  return _then(_self.copyWith(
totalItems: null == totalItems ? _self.totalItems : totalItems // ignore: cast_nullable_to_non_nullable
as int,bulkBaseline: null == bulkBaseline ? _self.bulkBaseline : bulkBaseline // ignore: cast_nullable_to_non_nullable
as int,liveProgress: null == liveProgress ? _self.liveProgress : liveProgress // ignore: cast_nullable_to_non_nullable
as int,trackStartDate: null == trackStartDate ? _self.trackStartDate : trackStartDate // ignore: cast_nullable_to_non_nullable
as DateTime,targetDate: null == targetDate ? _self.targetDate : targetDate // ignore: cast_nullable_to_non_nullable
as DateTime,today: null == today ? _self.today : today // ignore: cast_nullable_to_non_nullable
as DateTime,requiredVelocity: null == requiredVelocity ? _self.requiredVelocity : requiredVelocity // ignore: cast_nullable_to_non_nullable
as double,actualVelocity: null == actualVelocity ? _self.actualVelocity : actualVelocity // ignore: cast_nullable_to_non_nullable
as double,expectedProgressToday: null == expectedProgressToday ? _self.expectedProgressToday : expectedProgressToday // ignore: cast_nullable_to_non_nullable
as double,paceVariance: null == paceVariance ? _self.paceVariance : paceVariance // ignore: cast_nullable_to_non_nullable
as double,paceVarianceInDays: null == paceVarianceInDays ? _self.paceVarianceInDays : paceVarianceInDays // ignore: cast_nullable_to_non_nullable
as double,isInGraceWindow: null == isInGraceWindow ? _self.isInGraceWindow : isInGraceWindow // ignore: cast_nullable_to_non_nullable
as bool,paceStatus: null == paceStatus ? _self.paceStatus : paceStatus // ignore: cast_nullable_to_non_nullable
as ProgressPaceStatus,
  ));
}

}



/// @nodoc


class _ProgressPaceCalculator extends ProgressPaceCalculator {
  const _ProgressPaceCalculator({required this.totalItems, required this.bulkBaseline, required this.liveProgress, required this.trackStartDate, required this.targetDate, required this.today, required this.requiredVelocity, required this.actualVelocity, required this.expectedProgressToday, required this.paceVariance, required this.paceVarianceInDays, required this.isInGraceWindow, required this.paceStatus}): super._();
  

// -------------------------------------------------------------------------
// Inputs
// -------------------------------------------------------------------------
/// Total number of items in the track (e.g. total mishnayos).
@override final  int totalItems;
/// Items completed before [trackStartDate] via bulk-mark (sentinel date).
@override final  int bulkBaseline;
/// Items completed on or after [trackStartDate] (live progress).
@override final  int liveProgress;
/// The date the track was created/configured by the user (local-day
/// midnight).
@override final  DateTime trackStartDate;
/// The user-set finish date (local-day midnight).
@override final  DateTime targetDate;
/// Today's date (local-day midnight).
@override final  DateTime today;
// -------------------------------------------------------------------------
// Derived fields — computed once in [ProgressPaceCalculator.compute]
// -------------------------------------------------------------------------
/// Items to complete per calendar day to finish on [targetDate].
///
/// 0.0 when [targetDate] == [trackStartDate] (degenerate range).
@override final  double requiredVelocity;
/// Items completed per calendar day since [trackStartDate].
///
/// 0.0 when [today] == [trackStartDate] (day 0 — no elapsed time).
@override final  double actualVelocity;
/// How many items should have been done by today at the required
/// velocity.
@override final  double expectedProgressToday;
/// Signed difference between live progress and expected progress.
///
/// Positive = ahead of schedule. Negative = behind schedule.
@override final  double paceVariance;
/// [paceVariance] expressed in calendar days.
///
/// Positive = ahead, negative = behind. 0.0 when [requiredVelocity] is 0.
@override final  double paceVarianceInDays;
/// True when the track is within the [kPaceGraceWindowDays] window.
@override final  bool isInGraceWindow;
/// The overall pace status derived from the inputs and computed fields.
@override final  ProgressPaceStatus paceStatus;

/// Create a copy of ProgressPaceCalculator
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProgressPaceCalculatorCopyWith<_ProgressPaceCalculator> get copyWith => __$ProgressPaceCalculatorCopyWithImpl<_ProgressPaceCalculator>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProgressPaceCalculator&&(identical(other.totalItems, totalItems) || other.totalItems == totalItems)&&(identical(other.bulkBaseline, bulkBaseline) || other.bulkBaseline == bulkBaseline)&&(identical(other.liveProgress, liveProgress) || other.liveProgress == liveProgress)&&(identical(other.trackStartDate, trackStartDate) || other.trackStartDate == trackStartDate)&&(identical(other.targetDate, targetDate) || other.targetDate == targetDate)&&(identical(other.today, today) || other.today == today)&&(identical(other.requiredVelocity, requiredVelocity) || other.requiredVelocity == requiredVelocity)&&(identical(other.actualVelocity, actualVelocity) || other.actualVelocity == actualVelocity)&&(identical(other.expectedProgressToday, expectedProgressToday) || other.expectedProgressToday == expectedProgressToday)&&(identical(other.paceVariance, paceVariance) || other.paceVariance == paceVariance)&&(identical(other.paceVarianceInDays, paceVarianceInDays) || other.paceVarianceInDays == paceVarianceInDays)&&(identical(other.isInGraceWindow, isInGraceWindow) || other.isInGraceWindow == isInGraceWindow)&&(identical(other.paceStatus, paceStatus) || other.paceStatus == paceStatus));
}


@override
int get hashCode => Object.hash(runtimeType,totalItems,bulkBaseline,liveProgress,trackStartDate,targetDate,today,requiredVelocity,actualVelocity,expectedProgressToday,paceVariance,paceVarianceInDays,isInGraceWindow,paceStatus);



}

/// @nodoc
abstract mixin class _$ProgressPaceCalculatorCopyWith<$Res> implements $ProgressPaceCalculatorCopyWith<$Res> {
  factory _$ProgressPaceCalculatorCopyWith(_ProgressPaceCalculator value, $Res Function(_ProgressPaceCalculator) _then) = __$ProgressPaceCalculatorCopyWithImpl;
@override @useResult
$Res call({
 int totalItems, int bulkBaseline, int liveProgress, DateTime trackStartDate, DateTime targetDate, DateTime today, double requiredVelocity, double actualVelocity, double expectedProgressToday, double paceVariance, double paceVarianceInDays, bool isInGraceWindow, ProgressPaceStatus paceStatus
});




}
/// @nodoc
class __$ProgressPaceCalculatorCopyWithImpl<$Res>
    implements _$ProgressPaceCalculatorCopyWith<$Res> {
  __$ProgressPaceCalculatorCopyWithImpl(this._self, this._then);

  final _ProgressPaceCalculator _self;
  final $Res Function(_ProgressPaceCalculator) _then;

/// Create a copy of ProgressPaceCalculator
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalItems = null,Object? bulkBaseline = null,Object? liveProgress = null,Object? trackStartDate = null,Object? targetDate = null,Object? today = null,Object? requiredVelocity = null,Object? actualVelocity = null,Object? expectedProgressToday = null,Object? paceVariance = null,Object? paceVarianceInDays = null,Object? isInGraceWindow = null,Object? paceStatus = null,}) {
  return _then(_ProgressPaceCalculator(
totalItems: null == totalItems ? _self.totalItems : totalItems // ignore: cast_nullable_to_non_nullable
as int,bulkBaseline: null == bulkBaseline ? _self.bulkBaseline : bulkBaseline // ignore: cast_nullable_to_non_nullable
as int,liveProgress: null == liveProgress ? _self.liveProgress : liveProgress // ignore: cast_nullable_to_non_nullable
as int,trackStartDate: null == trackStartDate ? _self.trackStartDate : trackStartDate // ignore: cast_nullable_to_non_nullable
as DateTime,targetDate: null == targetDate ? _self.targetDate : targetDate // ignore: cast_nullable_to_non_nullable
as DateTime,today: null == today ? _self.today : today // ignore: cast_nullable_to_non_nullable
as DateTime,requiredVelocity: null == requiredVelocity ? _self.requiredVelocity : requiredVelocity // ignore: cast_nullable_to_non_nullable
as double,actualVelocity: null == actualVelocity ? _self.actualVelocity : actualVelocity // ignore: cast_nullable_to_non_nullable
as double,expectedProgressToday: null == expectedProgressToday ? _self.expectedProgressToday : expectedProgressToday // ignore: cast_nullable_to_non_nullable
as double,paceVariance: null == paceVariance ? _self.paceVariance : paceVariance // ignore: cast_nullable_to_non_nullable
as double,paceVarianceInDays: null == paceVarianceInDays ? _self.paceVarianceInDays : paceVarianceInDays // ignore: cast_nullable_to_non_nullable
as double,isInGraceWindow: null == isInGraceWindow ? _self.isInGraceWindow : isInGraceWindow // ignore: cast_nullable_to_non_nullable
as bool,paceStatus: null == paceStatus ? _self.paceStatus : paceStatus // ignore: cast_nullable_to_non_nullable
as ProgressPaceStatus,
  ));
}


}

// dart format on
