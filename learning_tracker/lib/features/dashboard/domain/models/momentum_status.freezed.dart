// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'momentum_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MomentumStatus {

/// Completions in the last 7 days.
 int get recentCount;/// Average completions per 7-day window over the last 30 days.
 double get personalAverage;/// Current momentum level.
 MomentumLevel get level;/// Days since the most recent completion. Null if completed today.
 int? get daysSinceLastCompletion;
/// Create a copy of MomentumStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MomentumStatusCopyWith<MomentumStatus> get copyWith => _$MomentumStatusCopyWithImpl<MomentumStatus>(this as MomentumStatus, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MomentumStatus&&(identical(other.recentCount, recentCount) || other.recentCount == recentCount)&&(identical(other.personalAverage, personalAverage) || other.personalAverage == personalAverage)&&(identical(other.level, level) || other.level == level)&&(identical(other.daysSinceLastCompletion, daysSinceLastCompletion) || other.daysSinceLastCompletion == daysSinceLastCompletion));
}


@override
int get hashCode => Object.hash(runtimeType,recentCount,personalAverage,level,daysSinceLastCompletion);

@override
String toString() {
  return 'MomentumStatus(recentCount: $recentCount, personalAverage: $personalAverage, level: $level, daysSinceLastCompletion: $daysSinceLastCompletion)';
}


}

/// @nodoc
abstract mixin class $MomentumStatusCopyWith<$Res>  {
  factory $MomentumStatusCopyWith(MomentumStatus value, $Res Function(MomentumStatus) _then) = _$MomentumStatusCopyWithImpl;
@useResult
$Res call({
 int recentCount, double personalAverage, MomentumLevel level, int? daysSinceLastCompletion
});




}
/// @nodoc
class _$MomentumStatusCopyWithImpl<$Res>
    implements $MomentumStatusCopyWith<$Res> {
  _$MomentumStatusCopyWithImpl(this._self, this._then);

  final MomentumStatus _self;
  final $Res Function(MomentumStatus) _then;

/// Create a copy of MomentumStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? recentCount = null,Object? personalAverage = null,Object? level = null,Object? daysSinceLastCompletion = freezed,}) {
  return _then(_self.copyWith(
recentCount: null == recentCount ? _self.recentCount : recentCount // ignore: cast_nullable_to_non_nullable
as int,personalAverage: null == personalAverage ? _self.personalAverage : personalAverage // ignore: cast_nullable_to_non_nullable
as double,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as MomentumLevel,daysSinceLastCompletion: freezed == daysSinceLastCompletion ? _self.daysSinceLastCompletion : daysSinceLastCompletion // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [MomentumStatus].
extension MomentumStatusPatterns on MomentumStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MomentumStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MomentumStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MomentumStatus value)  $default,){
final _that = this;
switch (_that) {
case _MomentumStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MomentumStatus value)?  $default,){
final _that = this;
switch (_that) {
case _MomentumStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int recentCount,  double personalAverage,  MomentumLevel level,  int? daysSinceLastCompletion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MomentumStatus() when $default != null:
return $default(_that.recentCount,_that.personalAverage,_that.level,_that.daysSinceLastCompletion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int recentCount,  double personalAverage,  MomentumLevel level,  int? daysSinceLastCompletion)  $default,) {final _that = this;
switch (_that) {
case _MomentumStatus():
return $default(_that.recentCount,_that.personalAverage,_that.level,_that.daysSinceLastCompletion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int recentCount,  double personalAverage,  MomentumLevel level,  int? daysSinceLastCompletion)?  $default,) {final _that = this;
switch (_that) {
case _MomentumStatus() when $default != null:
return $default(_that.recentCount,_that.personalAverage,_that.level,_that.daysSinceLastCompletion);case _:
  return null;

}
}

}

/// @nodoc


class _MomentumStatus implements MomentumStatus {
  const _MomentumStatus({required this.recentCount, required this.personalAverage, required this.level, this.daysSinceLastCompletion});
  

/// Completions in the last 7 days.
@override final  int recentCount;
/// Average completions per 7-day window over the last 30 days.
@override final  double personalAverage;
/// Current momentum level.
@override final  MomentumLevel level;
/// Days since the most recent completion. Null if completed today.
@override final  int? daysSinceLastCompletion;

/// Create a copy of MomentumStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MomentumStatusCopyWith<_MomentumStatus> get copyWith => __$MomentumStatusCopyWithImpl<_MomentumStatus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MomentumStatus&&(identical(other.recentCount, recentCount) || other.recentCount == recentCount)&&(identical(other.personalAverage, personalAverage) || other.personalAverage == personalAverage)&&(identical(other.level, level) || other.level == level)&&(identical(other.daysSinceLastCompletion, daysSinceLastCompletion) || other.daysSinceLastCompletion == daysSinceLastCompletion));
}


@override
int get hashCode => Object.hash(runtimeType,recentCount,personalAverage,level,daysSinceLastCompletion);

@override
String toString() {
  return 'MomentumStatus(recentCount: $recentCount, personalAverage: $personalAverage, level: $level, daysSinceLastCompletion: $daysSinceLastCompletion)';
}


}

/// @nodoc
abstract mixin class _$MomentumStatusCopyWith<$Res> implements $MomentumStatusCopyWith<$Res> {
  factory _$MomentumStatusCopyWith(_MomentumStatus value, $Res Function(_MomentumStatus) _then) = __$MomentumStatusCopyWithImpl;
@override @useResult
$Res call({
 int recentCount, double personalAverage, MomentumLevel level, int? daysSinceLastCompletion
});




}
/// @nodoc
class __$MomentumStatusCopyWithImpl<$Res>
    implements _$MomentumStatusCopyWith<$Res> {
  __$MomentumStatusCopyWithImpl(this._self, this._then);

  final _MomentumStatus _self;
  final $Res Function(_MomentumStatus) _then;

/// Create a copy of MomentumStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? recentCount = null,Object? personalAverage = null,Object? level = null,Object? daysSinceLastCompletion = freezed,}) {
  return _then(_MomentumStatus(
recentCount: null == recentCount ? _self.recentCount : recentCount // ignore: cast_nullable_to_non_nullable
as int,personalAverage: null == personalAverage ? _self.personalAverage : personalAverage // ignore: cast_nullable_to_non_nullable
as double,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as MomentumLevel,daysSinceLastCompletion: freezed == daysSinceLastCompletion ? _self.daysSinceLastCompletion : daysSinceLastCompletion // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
