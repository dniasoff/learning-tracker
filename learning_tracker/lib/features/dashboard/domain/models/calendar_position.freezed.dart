// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'calendar_position.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CalendarPosition {

/// User's actual position in the cycle (1-based day number).
 int get currentDay;/// Total days in the program cycle.
 int get totalDays;/// Sefaria ref for today's scheduled item.
 String get todayRef;/// Hebrew display text for today's item.
 String get todayDisplayHe;/// Signed distance from expected position.
/// Positive = ahead, negative = behind, zero = caught up.
 int get delta;/// Derived status from [delta].
 CalendarStatus get status;
/// Create a copy of CalendarPosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CalendarPositionCopyWith<CalendarPosition> get copyWith => _$CalendarPositionCopyWithImpl<CalendarPosition>(this as CalendarPosition, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CalendarPosition&&(identical(other.currentDay, currentDay) || other.currentDay == currentDay)&&(identical(other.totalDays, totalDays) || other.totalDays == totalDays)&&(identical(other.todayRef, todayRef) || other.todayRef == todayRef)&&(identical(other.todayDisplayHe, todayDisplayHe) || other.todayDisplayHe == todayDisplayHe)&&(identical(other.delta, delta) || other.delta == delta)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,currentDay,totalDays,todayRef,todayDisplayHe,delta,status);

@override
String toString() {
  return 'CalendarPosition(currentDay: $currentDay, totalDays: $totalDays, todayRef: $todayRef, todayDisplayHe: $todayDisplayHe, delta: $delta, status: $status)';
}


}

/// @nodoc
abstract mixin class $CalendarPositionCopyWith<$Res>  {
  factory $CalendarPositionCopyWith(CalendarPosition value, $Res Function(CalendarPosition) _then) = _$CalendarPositionCopyWithImpl;
@useResult
$Res call({
 int currentDay, int totalDays, String todayRef, String todayDisplayHe, int delta, CalendarStatus status
});




}
/// @nodoc
class _$CalendarPositionCopyWithImpl<$Res>
    implements $CalendarPositionCopyWith<$Res> {
  _$CalendarPositionCopyWithImpl(this._self, this._then);

  final CalendarPosition _self;
  final $Res Function(CalendarPosition) _then;

/// Create a copy of CalendarPosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentDay = null,Object? totalDays = null,Object? todayRef = null,Object? todayDisplayHe = null,Object? delta = null,Object? status = null,}) {
  return _then(_self.copyWith(
currentDay: null == currentDay ? _self.currentDay : currentDay // ignore: cast_nullable_to_non_nullable
as int,totalDays: null == totalDays ? _self.totalDays : totalDays // ignore: cast_nullable_to_non_nullable
as int,todayRef: null == todayRef ? _self.todayRef : todayRef // ignore: cast_nullable_to_non_nullable
as String,todayDisplayHe: null == todayDisplayHe ? _self.todayDisplayHe : todayDisplayHe // ignore: cast_nullable_to_non_nullable
as String,delta: null == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CalendarStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [CalendarPosition].
extension CalendarPositionPatterns on CalendarPosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CalendarPosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CalendarPosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CalendarPosition value)  $default,){
final _that = this;
switch (_that) {
case _CalendarPosition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CalendarPosition value)?  $default,){
final _that = this;
switch (_that) {
case _CalendarPosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int currentDay,  int totalDays,  String todayRef,  String todayDisplayHe,  int delta,  CalendarStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CalendarPosition() when $default != null:
return $default(_that.currentDay,_that.totalDays,_that.todayRef,_that.todayDisplayHe,_that.delta,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int currentDay,  int totalDays,  String todayRef,  String todayDisplayHe,  int delta,  CalendarStatus status)  $default,) {final _that = this;
switch (_that) {
case _CalendarPosition():
return $default(_that.currentDay,_that.totalDays,_that.todayRef,_that.todayDisplayHe,_that.delta,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int currentDay,  int totalDays,  String todayRef,  String todayDisplayHe,  int delta,  CalendarStatus status)?  $default,) {final _that = this;
switch (_that) {
case _CalendarPosition() when $default != null:
return $default(_that.currentDay,_that.totalDays,_that.todayRef,_that.todayDisplayHe,_that.delta,_that.status);case _:
  return null;

}
}

}

/// @nodoc


class _CalendarPosition implements CalendarPosition {
  const _CalendarPosition({required this.currentDay, required this.totalDays, required this.todayRef, required this.todayDisplayHe, required this.delta, required this.status});
  

/// User's actual position in the cycle (1-based day number).
@override final  int currentDay;
/// Total days in the program cycle.
@override final  int totalDays;
/// Sefaria ref for today's scheduled item.
@override final  String todayRef;
/// Hebrew display text for today's item.
@override final  String todayDisplayHe;
/// Signed distance from expected position.
/// Positive = ahead, negative = behind, zero = caught up.
@override final  int delta;
/// Derived status from [delta].
@override final  CalendarStatus status;

/// Create a copy of CalendarPosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CalendarPositionCopyWith<_CalendarPosition> get copyWith => __$CalendarPositionCopyWithImpl<_CalendarPosition>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CalendarPosition&&(identical(other.currentDay, currentDay) || other.currentDay == currentDay)&&(identical(other.totalDays, totalDays) || other.totalDays == totalDays)&&(identical(other.todayRef, todayRef) || other.todayRef == todayRef)&&(identical(other.todayDisplayHe, todayDisplayHe) || other.todayDisplayHe == todayDisplayHe)&&(identical(other.delta, delta) || other.delta == delta)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,currentDay,totalDays,todayRef,todayDisplayHe,delta,status);

@override
String toString() {
  return 'CalendarPosition(currentDay: $currentDay, totalDays: $totalDays, todayRef: $todayRef, todayDisplayHe: $todayDisplayHe, delta: $delta, status: $status)';
}


}

/// @nodoc
abstract mixin class _$CalendarPositionCopyWith<$Res> implements $CalendarPositionCopyWith<$Res> {
  factory _$CalendarPositionCopyWith(_CalendarPosition value, $Res Function(_CalendarPosition) _then) = __$CalendarPositionCopyWithImpl;
@override @useResult
$Res call({
 int currentDay, int totalDays, String todayRef, String todayDisplayHe, int delta, CalendarStatus status
});




}
/// @nodoc
class __$CalendarPositionCopyWithImpl<$Res>
    implements _$CalendarPositionCopyWith<$Res> {
  __$CalendarPositionCopyWithImpl(this._self, this._then);

  final _CalendarPosition _self;
  final $Res Function(_CalendarPosition) _then;

/// Create a copy of CalendarPosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentDay = null,Object? totalDays = null,Object? todayRef = null,Object? todayDisplayHe = null,Object? delta = null,Object? status = null,}) {
  return _then(_CalendarPosition(
currentDay: null == currentDay ? _self.currentDay : currentDay // ignore: cast_nullable_to_non_nullable
as int,totalDays: null == totalDays ? _self.totalDays : totalDays // ignore: cast_nullable_to_non_nullable
as int,todayRef: null == todayRef ? _self.todayRef : todayRef // ignore: cast_nullable_to_non_nullable
as String,todayDisplayHe: null == todayDisplayHe ? _self.todayDisplayHe : todayDisplayHe // ignore: cast_nullable_to_non_nullable
as String,delta: null == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CalendarStatus,
  ));
}


}

// dart format on
