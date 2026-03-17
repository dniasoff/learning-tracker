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

 CurriculumId get curriculumId;/// Goal deadline for completing the curriculum. Null means no deadline.
 DateTime? get goalDeadline;/// The current date (UTC) for scheduling calculations.
 DateTime get currentDate;/// Default number of new items per day when no deadline is set.
 int get defaultNewItemsPerDay;
/// Create a copy of ScheduleConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleConfigCopyWith<ScheduleConfig> get copyWith => _$ScheduleConfigCopyWithImpl<ScheduleConfig>(this as ScheduleConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleConfig&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.goalDeadline, goalDeadline) || other.goalDeadline == goalDeadline)&&(identical(other.currentDate, currentDate) || other.currentDate == currentDate)&&(identical(other.defaultNewItemsPerDay, defaultNewItemsPerDay) || other.defaultNewItemsPerDay == defaultNewItemsPerDay));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,goalDeadline,currentDate,defaultNewItemsPerDay);

@override
String toString() {
  return 'ScheduleConfig(curriculumId: $curriculumId, goalDeadline: $goalDeadline, currentDate: $currentDate, defaultNewItemsPerDay: $defaultNewItemsPerDay)';
}


}

/// @nodoc
abstract mixin class $ScheduleConfigCopyWith<$Res>  {
  factory $ScheduleConfigCopyWith(ScheduleConfig value, $Res Function(ScheduleConfig) _then) = _$ScheduleConfigCopyWithImpl;
@useResult
$Res call({
 CurriculumId curriculumId, DateTime? goalDeadline, DateTime currentDate, int defaultNewItemsPerDay
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
@pragma('vm:prefer-inline') @override $Res call({Object? curriculumId = null,Object? goalDeadline = freezed,Object? currentDate = null,Object? defaultNewItemsPerDay = null,}) {
  return _then(_self.copyWith(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,goalDeadline: freezed == goalDeadline ? _self.goalDeadline : goalDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,currentDate: null == currentDate ? _self.currentDate : currentDate // ignore: cast_nullable_to_non_nullable
as DateTime,defaultNewItemsPerDay: null == defaultNewItemsPerDay ? _self.defaultNewItemsPerDay : defaultNewItemsPerDay // ignore: cast_nullable_to_non_nullable
as int,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CurriculumId curriculumId,  DateTime? goalDeadline,  DateTime currentDate,  int defaultNewItemsPerDay)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduleConfig() when $default != null:
return $default(_that.curriculumId,_that.goalDeadline,_that.currentDate,_that.defaultNewItemsPerDay);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CurriculumId curriculumId,  DateTime? goalDeadline,  DateTime currentDate,  int defaultNewItemsPerDay)  $default,) {final _that = this;
switch (_that) {
case _ScheduleConfig():
return $default(_that.curriculumId,_that.goalDeadline,_that.currentDate,_that.defaultNewItemsPerDay);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CurriculumId curriculumId,  DateTime? goalDeadline,  DateTime currentDate,  int defaultNewItemsPerDay)?  $default,) {final _that = this;
switch (_that) {
case _ScheduleConfig() when $default != null:
return $default(_that.curriculumId,_that.goalDeadline,_that.currentDate,_that.defaultNewItemsPerDay);case _:
  return null;

}
}

}

/// @nodoc


class _ScheduleConfig implements ScheduleConfig {
  const _ScheduleConfig({required this.curriculumId, this.goalDeadline, required this.currentDate, this.defaultNewItemsPerDay = 5});
  

@override final  CurriculumId curriculumId;
/// Goal deadline for completing the curriculum. Null means no deadline.
@override final  DateTime? goalDeadline;
/// The current date (UTC) for scheduling calculations.
@override final  DateTime currentDate;
/// Default number of new items per day when no deadline is set.
@override@JsonKey() final  int defaultNewItemsPerDay;

/// Create a copy of ScheduleConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduleConfigCopyWith<_ScheduleConfig> get copyWith => __$ScheduleConfigCopyWithImpl<_ScheduleConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduleConfig&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.goalDeadline, goalDeadline) || other.goalDeadline == goalDeadline)&&(identical(other.currentDate, currentDate) || other.currentDate == currentDate)&&(identical(other.defaultNewItemsPerDay, defaultNewItemsPerDay) || other.defaultNewItemsPerDay == defaultNewItemsPerDay));
}


@override
int get hashCode => Object.hash(runtimeType,curriculumId,goalDeadline,currentDate,defaultNewItemsPerDay);

@override
String toString() {
  return 'ScheduleConfig(curriculumId: $curriculumId, goalDeadline: $goalDeadline, currentDate: $currentDate, defaultNewItemsPerDay: $defaultNewItemsPerDay)';
}


}

/// @nodoc
abstract mixin class _$ScheduleConfigCopyWith<$Res> implements $ScheduleConfigCopyWith<$Res> {
  factory _$ScheduleConfigCopyWith(_ScheduleConfig value, $Res Function(_ScheduleConfig) _then) = __$ScheduleConfigCopyWithImpl;
@override @useResult
$Res call({
 CurriculumId curriculumId, DateTime? goalDeadline, DateTime currentDate, int defaultNewItemsPerDay
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
@override @pragma('vm:prefer-inline') $Res call({Object? curriculumId = null,Object? goalDeadline = freezed,Object? currentDate = null,Object? defaultNewItemsPerDay = null,}) {
  return _then(_ScheduleConfig(
curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,goalDeadline: freezed == goalDeadline ? _self.goalDeadline : goalDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,currentDate: null == currentDate ? _self.currentDate : currentDate // ignore: cast_nullable_to_non_nullable
as DateTime,defaultNewItemsPerDay: null == defaultNewItemsPerDay ? _self.defaultNewItemsPerDay : defaultNewItemsPerDay // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
