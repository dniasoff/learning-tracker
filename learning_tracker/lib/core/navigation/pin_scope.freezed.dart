// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pin_scope.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PinScope {

 int get profileId;
/// Create a copy of PinScope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PinScopeCopyWith<PinScope> get copyWith => _$PinScopeCopyWithImpl<PinScope>(this as PinScope, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PinScope&&(identical(other.profileId, profileId) || other.profileId == profileId));
}


@override
int get hashCode => Object.hash(runtimeType,profileId);

@override
String toString() {
  return 'PinScope(profileId: $profileId)';
}


}

/// @nodoc
abstract mixin class $PinScopeCopyWith<$Res>  {
  factory $PinScopeCopyWith(PinScope value, $Res Function(PinScope) _then) = _$PinScopeCopyWithImpl;
@useResult
$Res call({
 int profileId
});




}
/// @nodoc
class _$PinScopeCopyWithImpl<$Res>
    implements $PinScopeCopyWith<$Res> {
  _$PinScopeCopyWithImpl(this._self, this._then);

  final PinScope _self;
  final $Res Function(PinScope) _then;

/// Create a copy of PinScope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profileId = null,}) {
  return _then(_self.copyWith(
profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PinScope].
extension PinScopePatterns on PinScope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PinScopeParent value)?  parent,TResult Function( PinScopeTutor value)?  tutor,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PinScopeParent() when parent != null:
return parent(_that);case PinScopeTutor() when tutor != null:
return tutor(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PinScopeParent value)  parent,required TResult Function( PinScopeTutor value)  tutor,}){
final _that = this;
switch (_that) {
case PinScopeParent():
return parent(_that);case PinScopeTutor():
return tutor(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PinScopeParent value)?  parent,TResult? Function( PinScopeTutor value)?  tutor,}){
final _that = this;
switch (_that) {
case PinScopeParent() when parent != null:
return parent(_that);case PinScopeTutor() when tutor != null:
return tutor(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int profileId)?  parent,TResult Function( int profileId)?  tutor,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PinScopeParent() when parent != null:
return parent(_that.profileId);case PinScopeTutor() when tutor != null:
return tutor(_that.profileId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int profileId)  parent,required TResult Function( int profileId)  tutor,}) {final _that = this;
switch (_that) {
case PinScopeParent():
return parent(_that.profileId);case PinScopeTutor():
return tutor(_that.profileId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int profileId)?  parent,TResult? Function( int profileId)?  tutor,}) {final _that = this;
switch (_that) {
case PinScopeParent() when parent != null:
return parent(_that.profileId);case PinScopeTutor() when tutor != null:
return tutor(_that.profileId);case _:
  return null;

}
}

}

/// @nodoc


class PinScopeParent implements PinScope {
  const PinScopeParent(this.profileId);
  

@override final  int profileId;

/// Create a copy of PinScope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PinScopeParentCopyWith<PinScopeParent> get copyWith => _$PinScopeParentCopyWithImpl<PinScopeParent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PinScopeParent&&(identical(other.profileId, profileId) || other.profileId == profileId));
}


@override
int get hashCode => Object.hash(runtimeType,profileId);

@override
String toString() {
  return 'PinScope.parent(profileId: $profileId)';
}


}

/// @nodoc
abstract mixin class $PinScopeParentCopyWith<$Res> implements $PinScopeCopyWith<$Res> {
  factory $PinScopeParentCopyWith(PinScopeParent value, $Res Function(PinScopeParent) _then) = _$PinScopeParentCopyWithImpl;
@override @useResult
$Res call({
 int profileId
});




}
/// @nodoc
class _$PinScopeParentCopyWithImpl<$Res>
    implements $PinScopeParentCopyWith<$Res> {
  _$PinScopeParentCopyWithImpl(this._self, this._then);

  final PinScopeParent _self;
  final $Res Function(PinScopeParent) _then;

/// Create a copy of PinScope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = null,}) {
  return _then(PinScopeParent(
null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class PinScopeTutor implements PinScope {
  const PinScopeTutor(this.profileId);
  

@override final  int profileId;

/// Create a copy of PinScope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PinScopeTutorCopyWith<PinScopeTutor> get copyWith => _$PinScopeTutorCopyWithImpl<PinScopeTutor>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PinScopeTutor&&(identical(other.profileId, profileId) || other.profileId == profileId));
}


@override
int get hashCode => Object.hash(runtimeType,profileId);

@override
String toString() {
  return 'PinScope.tutor(profileId: $profileId)';
}


}

/// @nodoc
abstract mixin class $PinScopeTutorCopyWith<$Res> implements $PinScopeCopyWith<$Res> {
  factory $PinScopeTutorCopyWith(PinScopeTutor value, $Res Function(PinScopeTutor) _then) = _$PinScopeTutorCopyWithImpl;
@override @useResult
$Res call({
 int profileId
});




}
/// @nodoc
class _$PinScopeTutorCopyWithImpl<$Res>
    implements $PinScopeTutorCopyWith<$Res> {
  _$PinScopeTutorCopyWithImpl(this._self, this._then);

  final PinScopeTutor _self;
  final $Res Function(PinScopeTutor) _then;

/// Create a copy of PinScope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profileId = null,}) {
  return _then(PinScopeTutor(
null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
