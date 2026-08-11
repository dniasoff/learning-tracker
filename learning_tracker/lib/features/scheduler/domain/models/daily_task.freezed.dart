// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DailyTask {

 CurriculumId get curriculumId; String get contentItemSefariaRef; int get stageOrder; int get stageDefinitionId; DailyTaskPriority get priority; bool get isOverdue; String get reason; String get stageName;/// Display label for the track (e.g., "Daf Yomi", "Mishnayos - School").
 String get trackLabel;/// Estimated effort in minutes. Defaults based on priority:
/// newLearning = 5 min, chazara = 3 min.
 int get estimatedEffortMinutes;/// Seed-sourced day-level unit label in Hebrew (e.g. "חולין דף כ״ה" for a
/// Daf-Yomi day, "כלים 5:7-8" for a mishnayos range).
///
/// Populated at generation time for program tasks from the calendar
/// entry's `todayRefHe`. This is the *collapsed, type-aware* name for the
/// whole day's unit — a single daf rather than one amud breadcrumb. The
/// dashboard track card prefers this over re-deriving an expanded amud
/// label from [contentItemSefariaRef] at render time, which makes the
/// displayed unit reliable. Null for self-paced tasks and any program
/// entry whose seed lacks a Hebrew label.
 String? get unitDisplayHe;/// Seed-sourced day-level unit label in English (e.g. "Chullin 25",
/// "Kelim 5:7-8"). English counterpart of [unitDisplayHe]; null in the
/// same cases.
 String? get unitDisplayEn;
/// Create a copy of DailyTask
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyTaskCopyWith<DailyTask> get copyWith => _$DailyTaskCopyWithImpl<DailyTask>(this as DailyTask, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyTask&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.contentItemSefariaRef, contentItemSefariaRef) || other.contentItemSefariaRef == contentItemSefariaRef)&&(identical(other.stageOrder, stageOrder) || other.stageOrder == stageOrder)&&(identical(other.stageDefinitionId, stageDefinitionId) || other.stageDefinitionId == stageDefinitionId)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.isOverdue, isOverdue) || other.isOverdue == isOverdue)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.stageName, stageName) || other.stageName == stageName)&&(identical(other.trackLabel, trackLabel) || other.trackLabel == trackLabel)&&(identical(other.estimatedEffortMinutes, estimatedEffortMinutes) || other.estimatedEffortMinutes == estimatedEffortMinutes)&&(identical(other.unitDisplayHe, unitDisplayHe) || other.unitDisplayHe == unitDisplayHe)&&(identical(other.unitDisplayEn, unitDisplayEn) || other.unitDisplayEn == unitDisplayEn));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,contentItemSefariaRef,stageOrder,stageDefinitionId,priority,isOverdue,reason,stageName,trackLabel,estimatedEffortMinutes,unitDisplayHe,unitDisplayEn);

@override
String toString() {
  return 'DailyTask(curriculumId: $curriculumId, contentItemSefariaRef: $contentItemSefariaRef, stageOrder: $stageOrder, stageDefinitionId: $stageDefinitionId, priority: $priority, isOverdue: $isOverdue, reason: $reason, stageName: $stageName, trackLabel: $trackLabel, estimatedEffortMinutes: $estimatedEffortMinutes, unitDisplayHe: $unitDisplayHe, unitDisplayEn: $unitDisplayEn)';
}


}

/// @nodoc
abstract mixin class $DailyTaskCopyWith<$Res>  {
  factory $DailyTaskCopyWith(DailyTask value, $Res Function(DailyTask) _then) = _$DailyTaskCopyWithImpl;
@useResult
$Res call({
 CurriculumId curriculumId, String contentItemSefariaRef, int stageOrder, int stageDefinitionId, DailyTaskPriority priority, bool isOverdue, String reason, String stageName, String trackLabel, int estimatedEffortMinutes, String? unitDisplayHe, String? unitDisplayEn
});




}
/// @nodoc
class _$DailyTaskCopyWithImpl<$Res>
    implements $DailyTaskCopyWith<$Res> {
  _$DailyTaskCopyWithImpl(this._self, this._then);

  final DailyTask _self;
  final $Res Function(DailyTask) _then;

/// Create a copy of DailyTask
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? curriculumId = null,Object? contentItemSefariaRef = null,Object? stageOrder = null,Object? stageDefinitionId = null,Object? priority = null,Object? isOverdue = null,Object? reason = null,Object? stageName = null,Object? trackLabel = null,Object? estimatedEffortMinutes = null,Object? unitDisplayHe = freezed,Object? unitDisplayEn = freezed,}) {
  return _then(_self.copyWith(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,contentItemSefariaRef: null == contentItemSefariaRef ? _self.contentItemSefariaRef : contentItemSefariaRef // ignore: cast_nullable_to_non_nullable
as String,stageOrder: null == stageOrder ? _self.stageOrder : stageOrder // ignore: cast_nullable_to_non_nullable
as int,stageDefinitionId: null == stageDefinitionId ? _self.stageDefinitionId : stageDefinitionId // ignore: cast_nullable_to_non_nullable
as int,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as DailyTaskPriority,isOverdue: null == isOverdue ? _self.isOverdue : isOverdue // ignore: cast_nullable_to_non_nullable
as bool,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,stageName: null == stageName ? _self.stageName : stageName // ignore: cast_nullable_to_non_nullable
as String,trackLabel: null == trackLabel ? _self.trackLabel : trackLabel // ignore: cast_nullable_to_non_nullable
as String,estimatedEffortMinutes: null == estimatedEffortMinutes ? _self.estimatedEffortMinutes : estimatedEffortMinutes // ignore: cast_nullable_to_non_nullable
as int,unitDisplayHe: freezed == unitDisplayHe ? _self.unitDisplayHe : unitDisplayHe // ignore: cast_nullable_to_non_nullable
as String?,unitDisplayEn: freezed == unitDisplayEn ? _self.unitDisplayEn : unitDisplayEn // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyTask].
extension DailyTaskPatterns on DailyTask {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyTask value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyTask() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyTask value)  $default,){
final _that = this;
switch (_that) {
case _DailyTask():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyTask value)?  $default,){
final _that = this;
switch (_that) {
case _DailyTask() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CurriculumId curriculumId,  String contentItemSefariaRef,  int stageOrder,  int stageDefinitionId,  DailyTaskPriority priority,  bool isOverdue,  String reason,  String stageName,  String trackLabel,  int estimatedEffortMinutes,  String? unitDisplayHe,  String? unitDisplayEn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyTask() when $default != null:
return $default(_that.curriculumId,_that.contentItemSefariaRef,_that.stageOrder,_that.stageDefinitionId,_that.priority,_that.isOverdue,_that.reason,_that.stageName,_that.trackLabel,_that.estimatedEffortMinutes,_that.unitDisplayHe,_that.unitDisplayEn);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CurriculumId curriculumId,  String contentItemSefariaRef,  int stageOrder,  int stageDefinitionId,  DailyTaskPriority priority,  bool isOverdue,  String reason,  String stageName,  String trackLabel,  int estimatedEffortMinutes,  String? unitDisplayHe,  String? unitDisplayEn)  $default,) {final _that = this;
switch (_that) {
case _DailyTask():
return $default(_that.curriculumId,_that.contentItemSefariaRef,_that.stageOrder,_that.stageDefinitionId,_that.priority,_that.isOverdue,_that.reason,_that.stageName,_that.trackLabel,_that.estimatedEffortMinutes,_that.unitDisplayHe,_that.unitDisplayEn);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CurriculumId curriculumId,  String contentItemSefariaRef,  int stageOrder,  int stageDefinitionId,  DailyTaskPriority priority,  bool isOverdue,  String reason,  String stageName,  String trackLabel,  int estimatedEffortMinutes,  String? unitDisplayHe,  String? unitDisplayEn)?  $default,) {final _that = this;
switch (_that) {
case _DailyTask() when $default != null:
return $default(_that.curriculumId,_that.contentItemSefariaRef,_that.stageOrder,_that.stageDefinitionId,_that.priority,_that.isOverdue,_that.reason,_that.stageName,_that.trackLabel,_that.estimatedEffortMinutes,_that.unitDisplayHe,_that.unitDisplayEn);case _:
  return null;

}
}

}

/// @nodoc


class _DailyTask implements DailyTask {
  const _DailyTask({required this.curriculumId, required this.contentItemSefariaRef, required this.stageOrder, required this.stageDefinitionId, required this.priority, required this.isOverdue, required this.reason, required this.stageName, required this.trackLabel, this.estimatedEffortMinutes = 3, this.unitDisplayHe, this.unitDisplayEn});
  

@override final  CurriculumId curriculumId;
@override final  String contentItemSefariaRef;
@override final  int stageOrder;
@override final  int stageDefinitionId;
@override final  DailyTaskPriority priority;
@override final  bool isOverdue;
@override final  String reason;
@override final  String stageName;
/// Display label for the track (e.g., "Daf Yomi", "Mishnayos - School").
@override final  String trackLabel;
/// Estimated effort in minutes. Defaults based on priority:
/// newLearning = 5 min, chazara = 3 min.
@override@JsonKey() final  int estimatedEffortMinutes;
/// Seed-sourced day-level unit label in Hebrew (e.g. "חולין דף כ״ה" for a
/// Daf-Yomi day, "כלים 5:7-8" for a mishnayos range).
///
/// Populated at generation time for program tasks from the calendar
/// entry's `todayRefHe`. This is the *collapsed, type-aware* name for the
/// whole day's unit — a single daf rather than one amud breadcrumb. The
/// dashboard track card prefers this over re-deriving an expanded amud
/// label from [contentItemSefariaRef] at render time, which makes the
/// displayed unit reliable. Null for self-paced tasks and any program
/// entry whose seed lacks a Hebrew label.
@override final  String? unitDisplayHe;
/// Seed-sourced day-level unit label in English (e.g. "Chullin 25",
/// "Kelim 5:7-8"). English counterpart of [unitDisplayHe]; null in the
/// same cases.
@override final  String? unitDisplayEn;

/// Create a copy of DailyTask
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyTaskCopyWith<_DailyTask> get copyWith => __$DailyTaskCopyWithImpl<_DailyTask>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyTask&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.contentItemSefariaRef, contentItemSefariaRef) || other.contentItemSefariaRef == contentItemSefariaRef)&&(identical(other.stageOrder, stageOrder) || other.stageOrder == stageOrder)&&(identical(other.stageDefinitionId, stageDefinitionId) || other.stageDefinitionId == stageDefinitionId)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.isOverdue, isOverdue) || other.isOverdue == isOverdue)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.stageName, stageName) || other.stageName == stageName)&&(identical(other.trackLabel, trackLabel) || other.trackLabel == trackLabel)&&(identical(other.estimatedEffortMinutes, estimatedEffortMinutes) || other.estimatedEffortMinutes == estimatedEffortMinutes)&&(identical(other.unitDisplayHe, unitDisplayHe) || other.unitDisplayHe == unitDisplayHe)&&(identical(other.unitDisplayEn, unitDisplayEn) || other.unitDisplayEn == unitDisplayEn));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,contentItemSefariaRef,stageOrder,stageDefinitionId,priority,isOverdue,reason,stageName,trackLabel,estimatedEffortMinutes,unitDisplayHe,unitDisplayEn);

@override
String toString() {
  return 'DailyTask(curriculumId: $curriculumId, contentItemSefariaRef: $contentItemSefariaRef, stageOrder: $stageOrder, stageDefinitionId: $stageDefinitionId, priority: $priority, isOverdue: $isOverdue, reason: $reason, stageName: $stageName, trackLabel: $trackLabel, estimatedEffortMinutes: $estimatedEffortMinutes, unitDisplayHe: $unitDisplayHe, unitDisplayEn: $unitDisplayEn)';
}


}

/// @nodoc
abstract mixin class _$DailyTaskCopyWith<$Res> implements $DailyTaskCopyWith<$Res> {
  factory _$DailyTaskCopyWith(_DailyTask value, $Res Function(_DailyTask) _then) = __$DailyTaskCopyWithImpl;
@override @useResult
$Res call({
 CurriculumId curriculumId, String contentItemSefariaRef, int stageOrder, int stageDefinitionId, DailyTaskPriority priority, bool isOverdue, String reason, String stageName, String trackLabel, int estimatedEffortMinutes, String? unitDisplayHe, String? unitDisplayEn
});




}
/// @nodoc
class __$DailyTaskCopyWithImpl<$Res>
    implements _$DailyTaskCopyWith<$Res> {
  __$DailyTaskCopyWithImpl(this._self, this._then);

  final _DailyTask _self;
  final $Res Function(_DailyTask) _then;

/// Create a copy of DailyTask
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,Object? contentItemSefariaRef = null,Object? stageOrder = null,Object? stageDefinitionId = null,Object? priority = null,Object? isOverdue = null,Object? reason = null,Object? stageName = null,Object? trackLabel = null,Object? estimatedEffortMinutes = null,Object? unitDisplayHe = freezed,Object? unitDisplayEn = freezed,}) {
  return _then(_DailyTask(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,contentItemSefariaRef: null == contentItemSefariaRef ? _self.contentItemSefariaRef : contentItemSefariaRef // ignore: cast_nullable_to_non_nullable
as String,stageOrder: null == stageOrder ? _self.stageOrder : stageOrder // ignore: cast_nullable_to_non_nullable
as int,stageDefinitionId: null == stageDefinitionId ? _self.stageDefinitionId : stageDefinitionId // ignore: cast_nullable_to_non_nullable
as int,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as DailyTaskPriority,isOverdue: null == isOverdue ? _self.isOverdue : isOverdue // ignore: cast_nullable_to_non_nullable
as bool,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,stageName: null == stageName ? _self.stageName : stageName // ignore: cast_nullable_to_non_nullable
as String,trackLabel: null == trackLabel ? _self.trackLabel : trackLabel // ignore: cast_nullable_to_non_nullable
as String,estimatedEffortMinutes: null == estimatedEffortMinutes ? _self.estimatedEffortMinutes : estimatedEffortMinutes // ignore: cast_nullable_to_non_nullable
as int,unitDisplayHe: freezed == unitDisplayHe ? _self.unitDisplayHe : unitDisplayHe // ignore: cast_nullable_to_non_nullable
as String?,unitDisplayEn: freezed == unitDisplayEn ? _self.unitDisplayEn : unitDisplayEn // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
