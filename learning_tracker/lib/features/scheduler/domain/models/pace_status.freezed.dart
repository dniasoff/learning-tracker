// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pace_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PaceStatus {

/// Whether the user is ahead, on-pace, or behind.
 PaceStatusType get status;/// For deadline goals: number of days ahead (+) or behind (−) schedule.
/// For pace goals: weekly item surplus (+) or deficit (−), i.e.
/// `((rollingAverage − targetPacePerDay) * 7).round()`.
/// Zero when on-pace.
///
/// Deprecated in favour of [delta]. UIs MUST switch on [delta] to render
/// a correct label — [daysDelta] is ambiguous between calendar-days and
/// items-per-week.
 int get daysDelta;/// Typed delta: [DateScheduleDelta] for deadline goals (calendar days),
/// [PaceScheduleDelta] for pace goals (items per week).
///
/// UIs MUST pattern-match on this to display the correct unit label.
/// [daysDelta] carries the raw integer for backward compatibility only.
 ScheduleDelta get delta;/// Projected completion date based on rolling 7-day average.
/// Null if no completions in the last 7 days (cannot project).
 DateTime? get projectedCompletionDate;/// Rolling 7-day average of daily completions.
 double get rollingAverage;
/// Create a copy of PaceStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaceStatusCopyWith<PaceStatus> get copyWith => _$PaceStatusCopyWithImpl<PaceStatus>(this as PaceStatus, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaceStatus&&(identical(other.status, status) || other.status == status)&&(identical(other.daysDelta, daysDelta) || other.daysDelta == daysDelta)&&(identical(other.delta, delta) || other.delta == delta)&&(identical(other.projectedCompletionDate, projectedCompletionDate) || other.projectedCompletionDate == projectedCompletionDate)&&(identical(other.rollingAverage, rollingAverage) || other.rollingAverage == rollingAverage));
}


@override
int get hashCode => Object.hash(runtimeType,status,daysDelta,delta,projectedCompletionDate,rollingAverage);

@override
String toString() {
  return 'PaceStatus(status: $status, daysDelta: $daysDelta, delta: $delta, projectedCompletionDate: $projectedCompletionDate, rollingAverage: $rollingAverage)';
}


}

/// @nodoc
abstract mixin class $PaceStatusCopyWith<$Res>  {
  factory $PaceStatusCopyWith(PaceStatus value, $Res Function(PaceStatus) _then) = _$PaceStatusCopyWithImpl;
@useResult
$Res call({
 PaceStatusType status, int daysDelta, ScheduleDelta delta, DateTime? projectedCompletionDate, double rollingAverage
});




}
/// @nodoc
class _$PaceStatusCopyWithImpl<$Res>
    implements $PaceStatusCopyWith<$Res> {
  _$PaceStatusCopyWithImpl(this._self, this._then);

  final PaceStatus _self;
  final $Res Function(PaceStatus) _then;

/// Create a copy of PaceStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? daysDelta = null,Object? delta = null,Object? projectedCompletionDate = freezed,Object? rollingAverage = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaceStatusType,daysDelta: null == daysDelta ? _self.daysDelta : daysDelta // ignore: cast_nullable_to_non_nullable
as int,delta: null == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as ScheduleDelta,projectedCompletionDate: freezed == projectedCompletionDate ? _self.projectedCompletionDate : projectedCompletionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rollingAverage: null == rollingAverage ? _self.rollingAverage : rollingAverage // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [PaceStatus].
extension PaceStatusPatterns on PaceStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaceStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaceStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaceStatus value)  $default,){
final _that = this;
switch (_that) {
case _PaceStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaceStatus value)?  $default,){
final _that = this;
switch (_that) {
case _PaceStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PaceStatusType status,  int daysDelta,  ScheduleDelta delta,  DateTime? projectedCompletionDate,  double rollingAverage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaceStatus() when $default != null:
return $default(_that.status,_that.daysDelta,_that.delta,_that.projectedCompletionDate,_that.rollingAverage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PaceStatusType status,  int daysDelta,  ScheduleDelta delta,  DateTime? projectedCompletionDate,  double rollingAverage)  $default,) {final _that = this;
switch (_that) {
case _PaceStatus():
return $default(_that.status,_that.daysDelta,_that.delta,_that.projectedCompletionDate,_that.rollingAverage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PaceStatusType status,  int daysDelta,  ScheduleDelta delta,  DateTime? projectedCompletionDate,  double rollingAverage)?  $default,) {final _that = this;
switch (_that) {
case _PaceStatus() when $default != null:
return $default(_that.status,_that.daysDelta,_that.delta,_that.projectedCompletionDate,_that.rollingAverage);case _:
  return null;

}
}

}

/// @nodoc


class _PaceStatus implements PaceStatus {
  const _PaceStatus({required this.status, required this.daysDelta, required this.delta, this.projectedCompletionDate, required this.rollingAverage});
  

/// Whether the user is ahead, on-pace, or behind.
@override final  PaceStatusType status;
/// For deadline goals: number of days ahead (+) or behind (−) schedule.
/// For pace goals: weekly item surplus (+) or deficit (−), i.e.
/// `((rollingAverage − targetPacePerDay) * 7).round()`.
/// Zero when on-pace.
///
/// Deprecated in favour of [delta]. UIs MUST switch on [delta] to render
/// a correct label — [daysDelta] is ambiguous between calendar-days and
/// items-per-week.
@override final  int daysDelta;
/// Typed delta: [DateScheduleDelta] for deadline goals (calendar days),
/// [PaceScheduleDelta] for pace goals (items per week).
///
/// UIs MUST pattern-match on this to display the correct unit label.
/// [daysDelta] carries the raw integer for backward compatibility only.
@override final  ScheduleDelta delta;
/// Projected completion date based on rolling 7-day average.
/// Null if no completions in the last 7 days (cannot project).
@override final  DateTime? projectedCompletionDate;
/// Rolling 7-day average of daily completions.
@override final  double rollingAverage;

/// Create a copy of PaceStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaceStatusCopyWith<_PaceStatus> get copyWith => __$PaceStatusCopyWithImpl<_PaceStatus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaceStatus&&(identical(other.status, status) || other.status == status)&&(identical(other.daysDelta, daysDelta) || other.daysDelta == daysDelta)&&(identical(other.delta, delta) || other.delta == delta)&&(identical(other.projectedCompletionDate, projectedCompletionDate) || other.projectedCompletionDate == projectedCompletionDate)&&(identical(other.rollingAverage, rollingAverage) || other.rollingAverage == rollingAverage));
}


@override
int get hashCode => Object.hash(runtimeType,status,daysDelta,delta,projectedCompletionDate,rollingAverage);

@override
String toString() {
  return 'PaceStatus(status: $status, daysDelta: $daysDelta, delta: $delta, projectedCompletionDate: $projectedCompletionDate, rollingAverage: $rollingAverage)';
}


}

/// @nodoc
abstract mixin class _$PaceStatusCopyWith<$Res> implements $PaceStatusCopyWith<$Res> {
  factory _$PaceStatusCopyWith(_PaceStatus value, $Res Function(_PaceStatus) _then) = __$PaceStatusCopyWithImpl;
@override @useResult
$Res call({
 PaceStatusType status, int daysDelta, ScheduleDelta delta, DateTime? projectedCompletionDate, double rollingAverage
});




}
/// @nodoc
class __$PaceStatusCopyWithImpl<$Res>
    implements _$PaceStatusCopyWith<$Res> {
  __$PaceStatusCopyWithImpl(this._self, this._then);

  final _PaceStatus _self;
  final $Res Function(_PaceStatus) _then;

/// Create a copy of PaceStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? daysDelta = null,Object? delta = null,Object? projectedCompletionDate = freezed,Object? rollingAverage = null,}) {
  return _then(_PaceStatus(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaceStatusType,daysDelta: null == daysDelta ? _self.daysDelta : daysDelta // ignore: cast_nullable_to_non_nullable
as int,delta: null == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as ScheduleDelta,projectedCompletionDate: freezed == projectedCompletionDate ? _self.projectedCompletionDate : projectedCompletionDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rollingAverage: null == rollingAverage ? _self.rollingAverage : rollingAverage // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
