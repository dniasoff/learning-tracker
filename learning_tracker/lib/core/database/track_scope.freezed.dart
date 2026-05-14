// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'track_scope.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TrackScope {

 int get profileId; int get trackId; CurriculumId get curriculumId;
/// Create a copy of TrackScope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackScopeCopyWith<TrackScope> get copyWith => _$TrackScopeCopyWithImpl<TrackScope>(this as TrackScope, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackScope&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId));
}


@override
int get hashCode => Object.hash(runtimeType,profileId,trackId,curriculumId);

@override
String toString() {
  return 'TrackScope(profileId: $profileId, trackId: $trackId, curriculumId: $curriculumId)';
}


}

/// @nodoc
abstract mixin class $TrackScopeCopyWith<$Res>  {
  factory $TrackScopeCopyWith(TrackScope value, $Res Function(TrackScope) _then) = _$TrackScopeCopyWithImpl;
@useResult
$Res call({
 int profileId, int trackId, CurriculumId curriculumId
});




}
/// @nodoc
class _$TrackScopeCopyWithImpl<$Res>
    implements $TrackScopeCopyWith<$Res> {
  _$TrackScopeCopyWithImpl(this._self, this._then);

  final TrackScope _self;
  final $Res Function(TrackScope) _then;

/// Create a copy of TrackScope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = null,Object? trackId = null,Object? curriculumId = null,}) {
  return _then(_self.copyWith(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,
  ));
}

}


/// Adds pattern-matching-related methods to [TrackScope].
extension TrackScopePatterns on TrackScope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackScope value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackScope() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackScope value)  $default,){
final _that = this;
switch (_that) {
case _TrackScope():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackScope value)?  $default,){
final _that = this;
switch (_that) {
case _TrackScope() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int profileId,  int trackId,  CurriculumId curriculumId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackScope() when $default != null:
return $default(_that.profileId,_that.trackId,_that.curriculumId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int profileId,  int trackId,  CurriculumId curriculumId)  $default,) {final _that = this;
switch (_that) {
case _TrackScope():
return $default(_that.profileId,_that.trackId,_that.curriculumId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int profileId,  int trackId,  CurriculumId curriculumId)?  $default,) {final _that = this;
switch (_that) {
case _TrackScope() when $default != null:
return $default(_that.profileId,_that.trackId,_that.curriculumId);case _:
  return null;

}
}

}

/// @nodoc


class _TrackScope implements TrackScope {
  const _TrackScope({required this.profileId, required this.trackId, required this.curriculumId});
  

@override final  int profileId;
@override final  int trackId;
@override final  CurriculumId curriculumId;

/// Create a copy of TrackScope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackScopeCopyWith<_TrackScope> get copyWith => __$TrackScopeCopyWithImpl<_TrackScope>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackScope&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId));
}


@override
int get hashCode => Object.hash(runtimeType,profileId,trackId,curriculumId);

@override
String toString() {
  return 'TrackScope(profileId: $profileId, trackId: $trackId, curriculumId: $curriculumId)';
}


}

/// @nodoc
abstract mixin class _$TrackScopeCopyWith<$Res> implements $TrackScopeCopyWith<$Res> {
  factory _$TrackScopeCopyWith(_TrackScope value, $Res Function(_TrackScope) _then) = __$TrackScopeCopyWithImpl;
@override @useResult
$Res call({
 int profileId, int trackId, CurriculumId curriculumId
});




}
/// @nodoc
class __$TrackScopeCopyWithImpl<$Res>
    implements _$TrackScopeCopyWith<$Res> {
  __$TrackScopeCopyWithImpl(this._self, this._then);

  final _TrackScope _self;
  final $Res Function(_TrackScope) _then;

/// Create a copy of TrackScope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = null,Object? trackId = null,Object? curriculumId = null,}) {
  return _then(_TrackScope(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,
  ));
}


}

// dart format on
