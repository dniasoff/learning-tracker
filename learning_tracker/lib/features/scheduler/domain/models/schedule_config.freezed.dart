// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScheduleConfig {

 CurriculumId get curriculumId;/// Display label for the track.
 String get trackLabel;/// Goal deadline for completing the curriculum. Null means no deadline.
 DateTime? get goalDeadline;/// The current date (UTC) for scheduling calculations.
 DateTime get currentDate;/// Default number of new items per day when no deadline is set.
 int get defaultNewItemsPerDay;/// Items per day for pace-based goals. Null means use deadline or default.
 double? get pacePerDay;/// Whether today is a study day. False suppresses new learning tasks.
 bool get isStudyDay;/// Number of study days per week (1-7). Used for legacy fallback pacing.
 int get studyDaysPerWeek;/// Inclusive count of future study days from "today" through the goal
/// deadline, per the track's study-day pattern. When set, deadline
/// pacing divides remaining items by this count instead of approximating
/// with [studyDaysPerWeek].
 int? get studyDaysInDeadlineWindow;/// When the track was activated. Used by the self-paced new-learning
/// path to back-fill snapshots for days the app didn't run, then to
/// determine which prior-day items are overdue today.
 DateTime? get trackStartedAt;/// Refs that have appeared in any prior-day snapshot for this track
/// (including synthetic back-fill snapshots). Resolved by the
/// repository before the engine runs. The engine uses this to:
///   (a) treat any uncompleted ref in this set as overdue today, and
///   (b) skip already-shown refs when picking today's new-learning
///       batch from the current ordered list.
 Set<String> get priorlyShownRefs;/// The coarse/leaf unit the user picked in goal setup ('daf', 'amud',
/// 'perek', 'mishna', 'pasuk', 'siman', 'seif', 'halacha'). When this
/// names a coarse level (e.g. 'perek' on Mishnayos), the engine
/// emits **all leaves under the next N coarse units** for today's
/// new-learning batch — so "1 perek/day" means a whole perek, not
/// 1 mishna. When `null` or naming the curriculum's leaf, the engine
/// uses the leaf-counted pace as before.
 String? get paceGranularity;
/// Create a copy of ScheduleConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleConfigCopyWith<ScheduleConfig> get copyWith => _$ScheduleConfigCopyWithImpl<ScheduleConfig>(this as ScheduleConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleConfig&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.trackLabel, trackLabel) || other.trackLabel == trackLabel)&&(identical(other.goalDeadline, goalDeadline) || other.goalDeadline == goalDeadline)&&(identical(other.currentDate, currentDate) || other.currentDate == currentDate)&&(identical(other.defaultNewItemsPerDay, defaultNewItemsPerDay) || other.defaultNewItemsPerDay == defaultNewItemsPerDay)&&(identical(other.pacePerDay, pacePerDay) || other.pacePerDay == pacePerDay)&&(identical(other.isStudyDay, isStudyDay) || other.isStudyDay == isStudyDay)&&(identical(other.studyDaysPerWeek, studyDaysPerWeek) || other.studyDaysPerWeek == studyDaysPerWeek)&&(identical(other.studyDaysInDeadlineWindow, studyDaysInDeadlineWindow) || other.studyDaysInDeadlineWindow == studyDaysInDeadlineWindow)&&(identical(other.trackStartedAt, trackStartedAt) || other.trackStartedAt == trackStartedAt)&&const DeepCollectionEquality().equals(other.priorlyShownRefs, priorlyShownRefs)&&(identical(other.paceGranularity, paceGranularity) || other.paceGranularity == paceGranularity));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,trackLabel,goalDeadline,currentDate,defaultNewItemsPerDay,pacePerDay,isStudyDay,studyDaysPerWeek,studyDaysInDeadlineWindow,trackStartedAt,const DeepCollectionEquality().hash(priorlyShownRefs),paceGranularity);

@override
String toString() {
  return 'ScheduleConfig(curriculumId: $curriculumId, trackLabel: $trackLabel, goalDeadline: $goalDeadline, currentDate: $currentDate, defaultNewItemsPerDay: $defaultNewItemsPerDay, pacePerDay: $pacePerDay, isStudyDay: $isStudyDay, studyDaysPerWeek: $studyDaysPerWeek, studyDaysInDeadlineWindow: $studyDaysInDeadlineWindow, trackStartedAt: $trackStartedAt, priorlyShownRefs: $priorlyShownRefs, paceGranularity: $paceGranularity)';
}


}

/// @nodoc
abstract mixin class $ScheduleConfigCopyWith<$Res>  {
  factory $ScheduleConfigCopyWith(ScheduleConfig value, $Res Function(ScheduleConfig) _then) = _$ScheduleConfigCopyWithImpl;
@useResult
$Res call({
 CurriculumId curriculumId, String trackLabel, DateTime? goalDeadline, DateTime currentDate, int defaultNewItemsPerDay, double? pacePerDay, bool isStudyDay, int studyDaysPerWeek, int? studyDaysInDeadlineWindow, DateTime? trackStartedAt, Set<String> priorlyShownRefs, String? paceGranularity
});




}
/// @nodoc
class _$ScheduleConfigCopyWithImpl<$Res>
    implements $ScheduleConfigCopyWith<$Res> {
  _$ScheduleConfigCopyWithImpl(this._self, this._then);

  final ScheduleConfig _self;
  final $Res Function(ScheduleConfig) _then;

/// Create a copy of ScheduleConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? curriculumId = null,Object? trackLabel = null,Object? goalDeadline = freezed,Object? currentDate = null,Object? defaultNewItemsPerDay = null,Object? pacePerDay = freezed,Object? isStudyDay = null,Object? studyDaysPerWeek = null,Object? studyDaysInDeadlineWindow = freezed,Object? trackStartedAt = freezed,Object? priorlyShownRefs = null,Object? paceGranularity = freezed,}) {
  return _then(_self.copyWith(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,trackLabel: null == trackLabel ? _self.trackLabel : trackLabel // ignore: cast_nullable_to_non_nullable
as String,goalDeadline: freezed == goalDeadline ? _self.goalDeadline : goalDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,currentDate: null == currentDate ? _self.currentDate : currentDate // ignore: cast_nullable_to_non_nullable
as DateTime,defaultNewItemsPerDay: null == defaultNewItemsPerDay ? _self.defaultNewItemsPerDay : defaultNewItemsPerDay // ignore: cast_nullable_to_non_nullable
as int,pacePerDay: freezed == pacePerDay ? _self.pacePerDay : pacePerDay // ignore: cast_nullable_to_non_nullable
as double?,isStudyDay: null == isStudyDay ? _self.isStudyDay : isStudyDay // ignore: cast_nullable_to_non_nullable
as bool,studyDaysPerWeek: null == studyDaysPerWeek ? _self.studyDaysPerWeek : studyDaysPerWeek // ignore: cast_nullable_to_non_nullable
as int,studyDaysInDeadlineWindow: freezed == studyDaysInDeadlineWindow ? _self.studyDaysInDeadlineWindow : studyDaysInDeadlineWindow // ignore: cast_nullable_to_non_nullable
as int?,trackStartedAt: freezed == trackStartedAt ? _self.trackStartedAt : trackStartedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,priorlyShownRefs: null == priorlyShownRefs ? _self.priorlyShownRefs : priorlyShownRefs // ignore: cast_nullable_to_non_nullable
as Set<String>,paceGranularity: freezed == paceGranularity ? _self.paceGranularity : paceGranularity // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ScheduleConfig].
extension ScheduleConfigPatterns on ScheduleConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScheduleConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScheduleConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScheduleConfig value)  $default,){
final _that = this;
switch (_that) {
case _ScheduleConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScheduleConfig value)?  $default,){
final _that = this;
switch (_that) {
case _ScheduleConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CurriculumId curriculumId,  String trackLabel,  DateTime? goalDeadline,  DateTime currentDate,  int defaultNewItemsPerDay,  double? pacePerDay,  bool isStudyDay,  int studyDaysPerWeek,  int? studyDaysInDeadlineWindow,  DateTime? trackStartedAt,  Set<String> priorlyShownRefs,  String? paceGranularity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduleConfig() when $default != null:
return $default(_that.curriculumId,_that.trackLabel,_that.goalDeadline,_that.currentDate,_that.defaultNewItemsPerDay,_that.pacePerDay,_that.isStudyDay,_that.studyDaysPerWeek,_that.studyDaysInDeadlineWindow,_that.trackStartedAt,_that.priorlyShownRefs,_that.paceGranularity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CurriculumId curriculumId,  String trackLabel,  DateTime? goalDeadline,  DateTime currentDate,  int defaultNewItemsPerDay,  double? pacePerDay,  bool isStudyDay,  int studyDaysPerWeek,  int? studyDaysInDeadlineWindow,  DateTime? trackStartedAt,  Set<String> priorlyShownRefs,  String? paceGranularity)  $default,) {final _that = this;
switch (_that) {
case _ScheduleConfig():
return $default(_that.curriculumId,_that.trackLabel,_that.goalDeadline,_that.currentDate,_that.defaultNewItemsPerDay,_that.pacePerDay,_that.isStudyDay,_that.studyDaysPerWeek,_that.studyDaysInDeadlineWindow,_that.trackStartedAt,_that.priorlyShownRefs,_that.paceGranularity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CurriculumId curriculumId,  String trackLabel,  DateTime? goalDeadline,  DateTime currentDate,  int defaultNewItemsPerDay,  double? pacePerDay,  bool isStudyDay,  int studyDaysPerWeek,  int? studyDaysInDeadlineWindow,  DateTime? trackStartedAt,  Set<String> priorlyShownRefs,  String? paceGranularity)?  $default,) {final _that = this;
switch (_that) {
case _ScheduleConfig() when $default != null:
return $default(_that.curriculumId,_that.trackLabel,_that.goalDeadline,_that.currentDate,_that.defaultNewItemsPerDay,_that.pacePerDay,_that.isStudyDay,_that.studyDaysPerWeek,_that.studyDaysInDeadlineWindow,_that.trackStartedAt,_that.priorlyShownRefs,_that.paceGranularity);case _:
  return null;

}
}

}

/// @nodoc


class _ScheduleConfig implements ScheduleConfig {
  const _ScheduleConfig({required this.curriculumId, required this.trackLabel, this.goalDeadline, required this.currentDate, this.defaultNewItemsPerDay = 5, this.pacePerDay, this.isStudyDay = true, this.studyDaysPerWeek = 7, this.studyDaysInDeadlineWindow, this.trackStartedAt, final  Set<String> priorlyShownRefs = const <String>{}, this.paceGranularity}): _priorlyShownRefs = priorlyShownRefs;
  

@override final  CurriculumId curriculumId;
/// Display label for the track.
@override final  String trackLabel;
/// Goal deadline for completing the curriculum. Null means no deadline.
@override final  DateTime? goalDeadline;
/// The current date (UTC) for scheduling calculations.
@override final  DateTime currentDate;
/// Default number of new items per day when no deadline is set.
@override@JsonKey() final  int defaultNewItemsPerDay;
/// Items per day for pace-based goals. Null means use deadline or default.
@override final  double? pacePerDay;
/// Whether today is a study day. False suppresses new learning tasks.
@override@JsonKey() final  bool isStudyDay;
/// Number of study days per week (1-7). Used for legacy fallback pacing.
@override@JsonKey() final  int studyDaysPerWeek;
/// Inclusive count of future study days from "today" through the goal
/// deadline, per the track's study-day pattern. When set, deadline
/// pacing divides remaining items by this count instead of approximating
/// with [studyDaysPerWeek].
@override final  int? studyDaysInDeadlineWindow;
/// When the track was activated. Used by the self-paced new-learning
/// path to back-fill snapshots for days the app didn't run, then to
/// determine which prior-day items are overdue today.
@override final  DateTime? trackStartedAt;
/// Refs that have appeared in any prior-day snapshot for this track
/// (including synthetic back-fill snapshots). Resolved by the
/// repository before the engine runs. The engine uses this to:
///   (a) treat any uncompleted ref in this set as overdue today, and
///   (b) skip already-shown refs when picking today's new-learning
///       batch from the current ordered list.
 final  Set<String> _priorlyShownRefs;
/// Refs that have appeared in any prior-day snapshot for this track
/// (including synthetic back-fill snapshots). Resolved by the
/// repository before the engine runs. The engine uses this to:
///   (a) treat any uncompleted ref in this set as overdue today, and
///   (b) skip already-shown refs when picking today's new-learning
///       batch from the current ordered list.
@override@JsonKey() Set<String> get priorlyShownRefs {
  if (_priorlyShownRefs is EqualUnmodifiableSetView) return _priorlyShownRefs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_priorlyShownRefs);
}

/// The coarse/leaf unit the user picked in goal setup ('daf', 'amud',
/// 'perek', 'mishna', 'pasuk', 'siman', 'seif', 'halacha'). When this
/// names a coarse level (e.g. 'perek' on Mishnayos), the engine
/// emits **all leaves under the next N coarse units** for today's
/// new-learning batch — so "1 perek/day" means a whole perek, not
/// 1 mishna. When `null` or naming the curriculum's leaf, the engine
/// uses the leaf-counted pace as before.
@override final  String? paceGranularity;

/// Create a copy of ScheduleConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduleConfigCopyWith<_ScheduleConfig> get copyWith => __$ScheduleConfigCopyWithImpl<_ScheduleConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduleConfig&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.trackLabel, trackLabel) || other.trackLabel == trackLabel)&&(identical(other.goalDeadline, goalDeadline) || other.goalDeadline == goalDeadline)&&(identical(other.currentDate, currentDate) || other.currentDate == currentDate)&&(identical(other.defaultNewItemsPerDay, defaultNewItemsPerDay) || other.defaultNewItemsPerDay == defaultNewItemsPerDay)&&(identical(other.pacePerDay, pacePerDay) || other.pacePerDay == pacePerDay)&&(identical(other.isStudyDay, isStudyDay) || other.isStudyDay == isStudyDay)&&(identical(other.studyDaysPerWeek, studyDaysPerWeek) || other.studyDaysPerWeek == studyDaysPerWeek)&&(identical(other.studyDaysInDeadlineWindow, studyDaysInDeadlineWindow) || other.studyDaysInDeadlineWindow == studyDaysInDeadlineWindow)&&(identical(other.trackStartedAt, trackStartedAt) || other.trackStartedAt == trackStartedAt)&&const DeepCollectionEquality().equals(other._priorlyShownRefs, _priorlyShownRefs)&&(identical(other.paceGranularity, paceGranularity) || other.paceGranularity == paceGranularity));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,trackLabel,goalDeadline,currentDate,defaultNewItemsPerDay,pacePerDay,isStudyDay,studyDaysPerWeek,studyDaysInDeadlineWindow,trackStartedAt,const DeepCollectionEquality().hash(_priorlyShownRefs),paceGranularity);

@override
String toString() {
  return 'ScheduleConfig(curriculumId: $curriculumId, trackLabel: $trackLabel, goalDeadline: $goalDeadline, currentDate: $currentDate, defaultNewItemsPerDay: $defaultNewItemsPerDay, pacePerDay: $pacePerDay, isStudyDay: $isStudyDay, studyDaysPerWeek: $studyDaysPerWeek, studyDaysInDeadlineWindow: $studyDaysInDeadlineWindow, trackStartedAt: $trackStartedAt, priorlyShownRefs: $priorlyShownRefs, paceGranularity: $paceGranularity)';
}


}

/// @nodoc
abstract mixin class _$ScheduleConfigCopyWith<$Res> implements $ScheduleConfigCopyWith<$Res> {
  factory _$ScheduleConfigCopyWith(_ScheduleConfig value, $Res Function(_ScheduleConfig) _then) = __$ScheduleConfigCopyWithImpl;
@override @useResult
$Res call({
 CurriculumId curriculumId, String trackLabel, DateTime? goalDeadline, DateTime currentDate, int defaultNewItemsPerDay, double? pacePerDay, bool isStudyDay, int studyDaysPerWeek, int? studyDaysInDeadlineWindow, DateTime? trackStartedAt, Set<String> priorlyShownRefs, String? paceGranularity
});




}
/// @nodoc
class __$ScheduleConfigCopyWithImpl<$Res>
    implements _$ScheduleConfigCopyWith<$Res> {
  __$ScheduleConfigCopyWithImpl(this._self, this._then);

  final _ScheduleConfig _self;
  final $Res Function(_ScheduleConfig) _then;

/// Create a copy of ScheduleConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,Object? trackLabel = null,Object? goalDeadline = freezed,Object? currentDate = null,Object? defaultNewItemsPerDay = null,Object? pacePerDay = freezed,Object? isStudyDay = null,Object? studyDaysPerWeek = null,Object? studyDaysInDeadlineWindow = freezed,Object? trackStartedAt = freezed,Object? priorlyShownRefs = null,Object? paceGranularity = freezed,}) {
  return _then(_ScheduleConfig(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,trackLabel: null == trackLabel ? _self.trackLabel : trackLabel // ignore: cast_nullable_to_non_nullable
as String,goalDeadline: freezed == goalDeadline ? _self.goalDeadline : goalDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,currentDate: null == currentDate ? _self.currentDate : currentDate // ignore: cast_nullable_to_non_nullable
as DateTime,defaultNewItemsPerDay: null == defaultNewItemsPerDay ? _self.defaultNewItemsPerDay : defaultNewItemsPerDay // ignore: cast_nullable_to_non_nullable
as int,pacePerDay: freezed == pacePerDay ? _self.pacePerDay : pacePerDay // ignore: cast_nullable_to_non_nullable
as double?,isStudyDay: null == isStudyDay ? _self.isStudyDay : isStudyDay // ignore: cast_nullable_to_non_nullable
as bool,studyDaysPerWeek: null == studyDaysPerWeek ? _self.studyDaysPerWeek : studyDaysPerWeek // ignore: cast_nullable_to_non_nullable
as int,studyDaysInDeadlineWindow: freezed == studyDaysInDeadlineWindow ? _self.studyDaysInDeadlineWindow : studyDaysInDeadlineWindow // ignore: cast_nullable_to_non_nullable
as int?,trackStartedAt: freezed == trackStartedAt ? _self.trackStartedAt : trackStartedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,priorlyShownRefs: null == priorlyShownRefs ? _self._priorlyShownRefs : priorlyShownRefs // ignore: cast_nullable_to_non_nullable
as Set<String>,paceGranularity: freezed == paceGranularity ? _self.paceGranularity : paceGranularity // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
