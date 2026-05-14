// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chazara_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChazaraStatus {

/// Number of chazara tasks due today.
 int get dueToday;/// Number of chazara tasks past their due date.
 int get overdue;/// True when no reviews are due or overdue.
 bool get isCaughtUp;/// Whether chazara stages are program-prescribed or user-configured.
 ChazaraSource get source;
/// Create a copy of ChazaraStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChazaraStatusCopyWith<ChazaraStatus> get copyWith => _$ChazaraStatusCopyWithImpl<ChazaraStatus>(this as ChazaraStatus, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChazaraStatus&&(identical(other.dueToday, dueToday) || other.dueToday == dueToday)&&(identical(other.overdue, overdue) || other.overdue == overdue)&&(identical(other.isCaughtUp, isCaughtUp) || other.isCaughtUp == isCaughtUp)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,dueToday,overdue,isCaughtUp,source);

@override
String toString() {
  return 'ChazaraStatus(dueToday: $dueToday, overdue: $overdue, isCaughtUp: $isCaughtUp, source: $source)';
}


}

/// @nodoc
abstract mixin class $ChazaraStatusCopyWith<$Res>  {
  factory $ChazaraStatusCopyWith(ChazaraStatus value, $Res Function(ChazaraStatus) _then) = _$ChazaraStatusCopyWithImpl;
@useResult
$Res call({
 int dueToday, int overdue, bool isCaughtUp, ChazaraSource source
});




}
/// @nodoc
class _$ChazaraStatusCopyWithImpl<$Res>
    implements $ChazaraStatusCopyWith<$Res> {
  _$ChazaraStatusCopyWithImpl(this._self, this._then);

  final ChazaraStatus _self;
  final $Res Function(ChazaraStatus) _then;

/// Create a copy of ChazaraStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? dueToday = null,Object? overdue = null,Object? isCaughtUp = null,Object? source = null,}) {
  return _then(_self.copyWith(
dueToday: null == dueToday ? _self.dueToday : dueToday // ignore: cast_nullable_to_non_nullable
as int,overdue: null == overdue ? _self.overdue : overdue // ignore: cast_nullable_to_non_nullable
as int,isCaughtUp: null == isCaughtUp ? _self.isCaughtUp : isCaughtUp // ignore: cast_nullable_to_non_nullable
as bool,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ChazaraSource,
  ));
}

}


/// Adds pattern-matching-related methods to [ChazaraStatus].
extension ChazaraStatusPatterns on ChazaraStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChazaraStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChazaraStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChazaraStatus value)  $default,){
final _that = this;
switch (_that) {
case _ChazaraStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChazaraStatus value)?  $default,){
final _that = this;
switch (_that) {
case _ChazaraStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int dueToday,  int overdue,  bool isCaughtUp,  ChazaraSource source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChazaraStatus() when $default != null:
return $default(_that.dueToday,_that.overdue,_that.isCaughtUp,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int dueToday,  int overdue,  bool isCaughtUp,  ChazaraSource source)  $default,) {final _that = this;
switch (_that) {
case _ChazaraStatus():
return $default(_that.dueToday,_that.overdue,_that.isCaughtUp,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int dueToday,  int overdue,  bool isCaughtUp,  ChazaraSource source)?  $default,) {final _that = this;
switch (_that) {
case _ChazaraStatus() when $default != null:
return $default(_that.dueToday,_that.overdue,_that.isCaughtUp,_that.source);case _:
  return null;

}
}

}

/// @nodoc


class _ChazaraStatus implements ChazaraStatus {
  const _ChazaraStatus({required this.dueToday, required this.overdue, required this.isCaughtUp, required this.source});
  

/// Number of chazara tasks due today.
@override final  int dueToday;
/// Number of chazara tasks past their due date.
@override final  int overdue;
/// True when no reviews are due or overdue.
@override final  bool isCaughtUp;
/// Whether chazara stages are program-prescribed or user-configured.
@override final  ChazaraSource source;

/// Create a copy of ChazaraStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChazaraStatusCopyWith<_ChazaraStatus> get copyWith => __$ChazaraStatusCopyWithImpl<_ChazaraStatus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChazaraStatus&&(identical(other.dueToday, dueToday) || other.dueToday == dueToday)&&(identical(other.overdue, overdue) || other.overdue == overdue)&&(identical(other.isCaughtUp, isCaughtUp) || other.isCaughtUp == isCaughtUp)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,dueToday,overdue,isCaughtUp,source);

@override
String toString() {
  return 'ChazaraStatus(dueToday: $dueToday, overdue: $overdue, isCaughtUp: $isCaughtUp, source: $source)';
}


}

/// @nodoc
abstract mixin class _$ChazaraStatusCopyWith<$Res> implements $ChazaraStatusCopyWith<$Res> {
  factory _$ChazaraStatusCopyWith(_ChazaraStatus value, $Res Function(_ChazaraStatus) _then) = __$ChazaraStatusCopyWithImpl;
@override @useResult
$Res call({
 int dueToday, int overdue, bool isCaughtUp, ChazaraSource source
});




}
/// @nodoc
class __$ChazaraStatusCopyWithImpl<$Res>
    implements _$ChazaraStatusCopyWith<$Res> {
  __$ChazaraStatusCopyWithImpl(this._self, this._then);

  final _ChazaraStatus _self;
  final $Res Function(_ChazaraStatus) _then;

/// Create a copy of ChazaraStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? dueToday = null,Object? overdue = null,Object? isCaughtUp = null,Object? source = null,}) {
  return _then(_ChazaraStatus(
dueToday: null == dueToday ? _self.dueToday : dueToday // ignore: cast_nullable_to_non_nullable
as int,overdue: null == overdue ? _self.overdue : overdue // ignore: cast_nullable_to_non_nullable
as int,isCaughtUp: null == isCaughtUp ? _self.isCaughtUp : isCaughtUp // ignore: cast_nullable_to_non_nullable
as bool,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ChazaraSource,
  ));
}


}

// dart format on
