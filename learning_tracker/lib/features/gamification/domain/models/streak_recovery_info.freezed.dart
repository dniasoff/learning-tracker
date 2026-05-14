// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'streak_recovery_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StreakRecoveryInfo {

 bool get wasRecovered; int get currentStreak; DateTime? get missedDate;
/// Create a copy of StreakRecoveryInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StreakRecoveryInfoCopyWith<StreakRecoveryInfo> get copyWith => _$StreakRecoveryInfoCopyWithImpl<StreakRecoveryInfo>(this as StreakRecoveryInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StreakRecoveryInfo&&(identical(other.wasRecovered, wasRecovered) || other.wasRecovered == wasRecovered)&&(identical(other.currentStreak, currentStreak) || other.currentStreak == currentStreak)&&(identical(other.missedDate, missedDate) || other.missedDate == missedDate));
}


@override
int get hashCode => Object.hash(runtimeType,wasRecovered,currentStreak,missedDate);

@override
String toString() {
  return 'StreakRecoveryInfo(wasRecovered: $wasRecovered, currentStreak: $currentStreak, missedDate: $missedDate)';
}


}

/// @nodoc
abstract mixin class $StreakRecoveryInfoCopyWith<$Res>  {
  factory $StreakRecoveryInfoCopyWith(StreakRecoveryInfo value, $Res Function(StreakRecoveryInfo) _then) = _$StreakRecoveryInfoCopyWithImpl;
@useResult
$Res call({
 bool wasRecovered, int currentStreak, DateTime? missedDate
});




}
/// @nodoc
class _$StreakRecoveryInfoCopyWithImpl<$Res>
    implements $StreakRecoveryInfoCopyWith<$Res> {
  _$StreakRecoveryInfoCopyWithImpl(this._self, this._then);

  final StreakRecoveryInfo _self;
  final $Res Function(StreakRecoveryInfo) _then;

/// Create a copy of StreakRecoveryInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? wasRecovered = null,Object? currentStreak = null,Object? missedDate = freezed,}) {
  return _then(_self.copyWith(
wasRecovered: null == wasRecovered ? _self.wasRecovered : wasRecovered // ignore: cast_nullable_to_non_nullable
as bool,currentStreak: null == currentStreak ? _self.currentStreak : currentStreak // ignore: cast_nullable_to_non_nullable
as int,missedDate: freezed == missedDate ? _self.missedDate : missedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [StreakRecoveryInfo].
extension StreakRecoveryInfoPatterns on StreakRecoveryInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StreakRecoveryInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StreakRecoveryInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StreakRecoveryInfo value)  $default,){
final _that = this;
switch (_that) {
case _StreakRecoveryInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StreakRecoveryInfo value)?  $default,){
final _that = this;
switch (_that) {
case _StreakRecoveryInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool wasRecovered,  int currentStreak,  DateTime? missedDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StreakRecoveryInfo() when $default != null:
return $default(_that.wasRecovered,_that.currentStreak,_that.missedDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool wasRecovered,  int currentStreak,  DateTime? missedDate)  $default,) {final _that = this;
switch (_that) {
case _StreakRecoveryInfo():
return $default(_that.wasRecovered,_that.currentStreak,_that.missedDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool wasRecovered,  int currentStreak,  DateTime? missedDate)?  $default,) {final _that = this;
switch (_that) {
case _StreakRecoveryInfo() when $default != null:
return $default(_that.wasRecovered,_that.currentStreak,_that.missedDate);case _:
  return null;

}
}

}

/// @nodoc


class _StreakRecoveryInfo implements StreakRecoveryInfo {
  const _StreakRecoveryInfo({required this.wasRecovered, required this.currentStreak, this.missedDate});
  

@override final  bool wasRecovered;
@override final  int currentStreak;
@override final  DateTime? missedDate;

/// Create a copy of StreakRecoveryInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StreakRecoveryInfoCopyWith<_StreakRecoveryInfo> get copyWith => __$StreakRecoveryInfoCopyWithImpl<_StreakRecoveryInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StreakRecoveryInfo&&(identical(other.wasRecovered, wasRecovered) || other.wasRecovered == wasRecovered)&&(identical(other.currentStreak, currentStreak) || other.currentStreak == currentStreak)&&(identical(other.missedDate, missedDate) || other.missedDate == missedDate));
}


@override
int get hashCode => Object.hash(runtimeType,wasRecovered,currentStreak,missedDate);

@override
String toString() {
  return 'StreakRecoveryInfo(wasRecovered: $wasRecovered, currentStreak: $currentStreak, missedDate: $missedDate)';
}


}

/// @nodoc
abstract mixin class _$StreakRecoveryInfoCopyWith<$Res> implements $StreakRecoveryInfoCopyWith<$Res> {
  factory _$StreakRecoveryInfoCopyWith(_StreakRecoveryInfo value, $Res Function(_StreakRecoveryInfo) _then) = __$StreakRecoveryInfoCopyWithImpl;
@override @useResult
$Res call({
 bool wasRecovered, int currentStreak, DateTime? missedDate
});




}
/// @nodoc
class __$StreakRecoveryInfoCopyWithImpl<$Res>
    implements _$StreakRecoveryInfoCopyWith<$Res> {
  __$StreakRecoveryInfoCopyWithImpl(this._self, this._then);

  final _StreakRecoveryInfo _self;
  final $Res Function(_StreakRecoveryInfo) _then;

/// Create a copy of StreakRecoveryInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? wasRecovered = null,Object? currentStreak = null,Object? missedDate = freezed,}) {
  return _then(_StreakRecoveryInfo(
wasRecovered: null == wasRecovered ? _self.wasRecovered : wasRecovered // ignore: cast_nullable_to_non_nullable
as bool,currentStreak: null == currentStreak ? _self.currentStreak : currentStreak // ignore: cast_nullable_to_non_nullable
as int,missedDate: freezed == missedDate ? _self.missedDate : missedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
