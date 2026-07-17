// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProfileSession {

 int? get profileId;
/// Create a copy of ProfileSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileSessionCopyWith<ProfileSession> get copyWith => _$ProfileSessionCopyWithImpl<ProfileSession>(this as ProfileSession, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileSession&&(identical(other.profileId, profileId) || other.profileId == profileId));
}


@override
int get hashCode => Object.hash(runtimeType,profileId);

@override
String toString() {
  return 'ProfileSession(profileId: $profileId)';
}


}

/// @nodoc
abstract mixin class $ProfileSessionCopyWith<$Res>  {
  factory $ProfileSessionCopyWith(ProfileSession value, $Res Function(ProfileSession) _then) = _$ProfileSessionCopyWithImpl;
@useResult
$Res call({
 int? profileId
});




}
/// @nodoc
class _$ProfileSessionCopyWithImpl<$Res>
    implements $ProfileSessionCopyWith<$Res> {
  _$ProfileSessionCopyWithImpl(this._self, this._then);

  final ProfileSession _self;
  final $Res Function(ProfileSession) _then;

/// Create a copy of ProfileSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = freezed,}) {
  return _then(_self.copyWith(
profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileSession].
extension ProfileSessionPatterns on ProfileSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileSession value)  $default,){
final _that = this;
switch (_that) {
case _ProfileSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileSession value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? profileId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileSession() when $default != null:
return $default(_that.profileId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? profileId)  $default,) {final _that = this;
switch (_that) {
case _ProfileSession():
return $default(_that.profileId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? profileId)?  $default,) {final _that = this;
switch (_that) {
case _ProfileSession() when $default != null:
return $default(_that.profileId);case _:
  return null;

}
}

}

/// @nodoc


class _ProfileSession extends ProfileSession {
  const _ProfileSession({required this.profileId}): super._();
  

@override final  int? profileId;

/// Create a copy of ProfileSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileSessionCopyWith<_ProfileSession> get copyWith => __$ProfileSessionCopyWithImpl<_ProfileSession>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileSession&&(identical(other.profileId, profileId) || other.profileId == profileId));
}


@override
int get hashCode => Object.hash(runtimeType,profileId);

@override
String toString() {
  return 'ProfileSession(profileId: $profileId)';
}


}

/// @nodoc
abstract mixin class _$ProfileSessionCopyWith<$Res> implements $ProfileSessionCopyWith<$Res> {
  factory _$ProfileSessionCopyWith(_ProfileSession value, $Res Function(_ProfileSession) _then) = __$ProfileSessionCopyWithImpl;
@override @useResult
$Res call({
 int? profileId
});




}
/// @nodoc
class __$ProfileSessionCopyWithImpl<$Res>
    implements _$ProfileSessionCopyWith<$Res> {
  __$ProfileSessionCopyWithImpl(this._self, this._then);

  final _ProfileSession _self;
  final $Res Function(_ProfileSession) _then;

/// Create a copy of ProfileSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = freezed,}) {
  return _then(_ProfileSession(
profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
