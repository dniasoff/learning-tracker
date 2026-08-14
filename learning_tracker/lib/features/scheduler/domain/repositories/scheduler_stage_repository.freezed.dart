// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduler_stage_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SchedulerStage {

 int get stageOrder; String get stageName; int get delayDays; ScheduleType get scheduleType; List<int>? get daysOfWeek; int? get rollingWindowSize;
/// Create a copy of SchedulerStage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchedulerStageCopyWith<SchedulerStage> get copyWith => _$SchedulerStageCopyWithImpl<SchedulerStage>(this as SchedulerStage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchedulerStage&&(identical(other.stageOrder, stageOrder) || other.stageOrder == stageOrder)&&(identical(other.stageName, stageName) || other.stageName == stageName)&&(identical(other.delayDays, delayDays) || other.delayDays == delayDays)&&(identical(other.scheduleType, scheduleType) || other.scheduleType == scheduleType)&&const DeepCollectionEquality().equals(other.daysOfWeek, daysOfWeek)&&(identical(other.rollingWindowSize, rollingWindowSize) || other.rollingWindowSize == rollingWindowSize));
}


@override
int get hashCode => Object.hash(runtimeType,stageOrder,stageName,delayDays,scheduleType,const DeepCollectionEquality().hash(daysOfWeek),rollingWindowSize);

@override
String toString() {
  return 'SchedulerStage(stageOrder: $stageOrder, stageName: $stageName, delayDays: $delayDays, scheduleType: $scheduleType, daysOfWeek: $daysOfWeek, rollingWindowSize: $rollingWindowSize)';
}


}

/// @nodoc
abstract mixin class $SchedulerStageCopyWith<$Res>  {
  factory $SchedulerStageCopyWith(SchedulerStage value, $Res Function(SchedulerStage) _then) = _$SchedulerStageCopyWithImpl;
@useResult
$Res call({
 int stageOrder, String stageName, int delayDays, ScheduleType scheduleType, List<int>? daysOfWeek, int? rollingWindowSize
});




}
/// @nodoc
class _$SchedulerStageCopyWithImpl<$Res>
    implements $SchedulerStageCopyWith<$Res> {
  _$SchedulerStageCopyWithImpl(this._self, this._then);

  final SchedulerStage _self;
  final $Res Function(SchedulerStage) _then;

/// Create a copy of SchedulerStage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stageOrder = null,Object? stageName = null,Object? delayDays = null,Object? scheduleType = null,Object? daysOfWeek = freezed,Object? rollingWindowSize = freezed,}) {
  return _then(_self.copyWith(
stageOrder: null == stageOrder ? _self.stageOrder : stageOrder // ignore: cast_nullable_to_non_nullable
as int,stageName: null == stageName ? _self.stageName : stageName // ignore: cast_nullable_to_non_nullable
as String,delayDays: null == delayDays ? _self.delayDays : delayDays // ignore: cast_nullable_to_non_nullable
as int,scheduleType: null == scheduleType ? _self.scheduleType : scheduleType // ignore: cast_nullable_to_non_nullable
as ScheduleType,daysOfWeek: freezed == daysOfWeek ? _self.daysOfWeek : daysOfWeek // ignore: cast_nullable_to_non_nullable
as List<int>?,rollingWindowSize: freezed == rollingWindowSize ? _self.rollingWindowSize : rollingWindowSize // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [SchedulerStage].
extension SchedulerStagePatterns on SchedulerStage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchedulerStage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchedulerStage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchedulerStage value)  $default,){
final _that = this;
switch (_that) {
case _SchedulerStage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchedulerStage value)?  $default,){
final _that = this;
switch (_that) {
case _SchedulerStage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int stageOrder,  String stageName,  int delayDays,  ScheduleType scheduleType,  List<int>? daysOfWeek,  int? rollingWindowSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchedulerStage() when $default != null:
return $default(_that.stageOrder,_that.stageName,_that.delayDays,_that.scheduleType,_that.daysOfWeek,_that.rollingWindowSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int stageOrder,  String stageName,  int delayDays,  ScheduleType scheduleType,  List<int>? daysOfWeek,  int? rollingWindowSize)  $default,) {final _that = this;
switch (_that) {
case _SchedulerStage():
return $default(_that.stageOrder,_that.stageName,_that.delayDays,_that.scheduleType,_that.daysOfWeek,_that.rollingWindowSize);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int stageOrder,  String stageName,  int delayDays,  ScheduleType scheduleType,  List<int>? daysOfWeek,  int? rollingWindowSize)?  $default,) {final _that = this;
switch (_that) {
case _SchedulerStage() when $default != null:
return $default(_that.stageOrder,_that.stageName,_that.delayDays,_that.scheduleType,_that.daysOfWeek,_that.rollingWindowSize);case _:
  return null;

}
}

}

/// @nodoc


class _SchedulerStage implements SchedulerStage {
  const _SchedulerStage({required this.stageOrder, required this.stageName, required this.delayDays, this.scheduleType = ScheduleType.delay, final  List<int>? daysOfWeek, this.rollingWindowSize}): _daysOfWeek = daysOfWeek;
  

@override final  int stageOrder;
@override final  String stageName;
@override final  int delayDays;
@override@JsonKey() final  ScheduleType scheduleType;
 final  List<int>? _daysOfWeek;
@override List<int>? get daysOfWeek {
  final value = _daysOfWeek;
  if (value == null) return null;
  if (_daysOfWeek is EqualUnmodifiableListView) return _daysOfWeek;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  int? rollingWindowSize;

/// Create a copy of SchedulerStage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchedulerStageCopyWith<_SchedulerStage> get copyWith => __$SchedulerStageCopyWithImpl<_SchedulerStage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchedulerStage&&(identical(other.stageOrder, stageOrder) || other.stageOrder == stageOrder)&&(identical(other.stageName, stageName) || other.stageName == stageName)&&(identical(other.delayDays, delayDays) || other.delayDays == delayDays)&&(identical(other.scheduleType, scheduleType) || other.scheduleType == scheduleType)&&const DeepCollectionEquality().equals(other._daysOfWeek, _daysOfWeek)&&(identical(other.rollingWindowSize, rollingWindowSize) || other.rollingWindowSize == rollingWindowSize));
}


@override
int get hashCode => Object.hash(runtimeType,stageOrder,stageName,delayDays,scheduleType,const DeepCollectionEquality().hash(_daysOfWeek),rollingWindowSize);

@override
String toString() {
  return 'SchedulerStage(stageOrder: $stageOrder, stageName: $stageName, delayDays: $delayDays, scheduleType: $scheduleType, daysOfWeek: $daysOfWeek, rollingWindowSize: $rollingWindowSize)';
}


}

/// @nodoc
abstract mixin class _$SchedulerStageCopyWith<$Res> implements $SchedulerStageCopyWith<$Res> {
  factory _$SchedulerStageCopyWith(_SchedulerStage value, $Res Function(_SchedulerStage) _then) = __$SchedulerStageCopyWithImpl;
@override @useResult
$Res call({
 int stageOrder, String stageName, int delayDays, ScheduleType scheduleType, List<int>? daysOfWeek, int? rollingWindowSize
});




}
/// @nodoc
class __$SchedulerStageCopyWithImpl<$Res>
    implements _$SchedulerStageCopyWith<$Res> {
  __$SchedulerStageCopyWithImpl(this._self, this._then);

  final _SchedulerStage _self;
  final $Res Function(_SchedulerStage) _then;

/// Create a copy of SchedulerStage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stageOrder = null,Object? stageName = null,Object? delayDays = null,Object? scheduleType = null,Object? daysOfWeek = freezed,Object? rollingWindowSize = freezed,}) {
  return _then(_SchedulerStage(
stageOrder: null == stageOrder ? _self.stageOrder : stageOrder // ignore: cast_nullable_to_non_nullable
as int,stageName: null == stageName ? _self.stageName : stageName // ignore: cast_nullable_to_non_nullable
as String,delayDays: null == delayDays ? _self.delayDays : delayDays // ignore: cast_nullable_to_non_nullable
as int,scheduleType: null == scheduleType ? _self.scheduleType : scheduleType // ignore: cast_nullable_to_non_nullable
as ScheduleType,daysOfWeek: freezed == daysOfWeek ? _self._daysOfWeek : daysOfWeek // ignore: cast_nullable_to_non_nullable
as List<int>?,rollingWindowSize: freezed == rollingWindowSize ? _self.rollingWindowSize : rollingWindowSize // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
