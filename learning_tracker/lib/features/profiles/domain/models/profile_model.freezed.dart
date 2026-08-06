// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProfileModel {

 int get id; int get accountId; String get displayName; String get mode;// 'child' or 'adult' — raw storage key
 int get avatarIndex; DateTime get createdAt; DateTime get updatedAt;// Firestore-native profile identity, minted eagerly and unconditionally
// at creation (`ProfileRepositoryImpl`, P2-2) — never null, never
// cleared. This field disappears along with the Drift-backed [id] once
// the app is fully cut over to Firestore-native profile identity.
 String get ulid;
/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileModelCopyWith<ProfileModel> get copyWith => _$ProfileModelCopyWithImpl<ProfileModel>(this as ProfileModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileModel&&(identical(other.id, id) || other.id == id)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.avatarIndex, avatarIndex) || other.avatarIndex == avatarIndex)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.ulid, ulid) || other.ulid == ulid));
}


@override
int get hashCode => Object.hash(runtimeType,id,accountId,displayName,mode,avatarIndex,createdAt,updatedAt,ulid);

@override
String toString() {
  return 'ProfileModel(id: $id, accountId: $accountId, displayName: $displayName, mode: $mode, avatarIndex: $avatarIndex, createdAt: $createdAt, updatedAt: $updatedAt, ulid: $ulid)';
}


}

/// @nodoc
abstract mixin class $ProfileModelCopyWith<$Res>  {
  factory $ProfileModelCopyWith(ProfileModel value, $Res Function(ProfileModel) _then) = _$ProfileModelCopyWithImpl;
@useResult
$Res call({
 int id, int accountId, String displayName, String mode, int avatarIndex, DateTime createdAt, DateTime updatedAt, String ulid
});




}
/// @nodoc
class _$ProfileModelCopyWithImpl<$Res>
    implements $ProfileModelCopyWith<$Res> {
  _$ProfileModelCopyWithImpl(this._self, this._then);

  final ProfileModel _self;
  final $Res Function(ProfileModel) _then;

/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? accountId = null,Object? displayName = null,Object? mode = null,Object? avatarIndex = null,Object? createdAt = null,Object? updatedAt = null,Object? ulid = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,avatarIndex: null == avatarIndex ? _self.avatarIndex : avatarIndex // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,ulid: null == ulid ? _self.ulid : ulid // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileModel].
extension ProfileModelPatterns on ProfileModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileModel value)  $default,){
final _that = this;
switch (_that) {
case _ProfileModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileModel value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int accountId,  String displayName,  String mode,  int avatarIndex,  DateTime createdAt,  DateTime updatedAt,  String ulid)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileModel() when $default != null:
return $default(_that.id,_that.accountId,_that.displayName,_that.mode,_that.avatarIndex,_that.createdAt,_that.updatedAt,_that.ulid);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int accountId,  String displayName,  String mode,  int avatarIndex,  DateTime createdAt,  DateTime updatedAt,  String ulid)  $default,) {final _that = this;
switch (_that) {
case _ProfileModel():
return $default(_that.id,_that.accountId,_that.displayName,_that.mode,_that.avatarIndex,_that.createdAt,_that.updatedAt,_that.ulid);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int accountId,  String displayName,  String mode,  int avatarIndex,  DateTime createdAt,  DateTime updatedAt,  String ulid)?  $default,) {final _that = this;
switch (_that) {
case _ProfileModel() when $default != null:
return $default(_that.id,_that.accountId,_that.displayName,_that.mode,_that.avatarIndex,_that.createdAt,_that.updatedAt,_that.ulid);case _:
  return null;

}
}

}

/// @nodoc


class _ProfileModel extends ProfileModel {
  const _ProfileModel({required this.id, required this.accountId, required this.displayName, required this.mode, required this.avatarIndex, required this.createdAt, required this.updatedAt, required this.ulid}): super._();
  

@override final  int id;
@override final  int accountId;
@override final  String displayName;
@override final  String mode;
// 'child' or 'adult' — raw storage key
@override final  int avatarIndex;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
// Firestore-native profile identity, minted eagerly and unconditionally
// at creation (`ProfileRepositoryImpl`, P2-2) — never null, never
// cleared. This field disappears along with the Drift-backed [id] once
// the app is fully cut over to Firestore-native profile identity.
@override final  String ulid;

/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileModelCopyWith<_ProfileModel> get copyWith => __$ProfileModelCopyWithImpl<_ProfileModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileModel&&(identical(other.id, id) || other.id == id)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.avatarIndex, avatarIndex) || other.avatarIndex == avatarIndex)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.ulid, ulid) || other.ulid == ulid));
}


@override
int get hashCode => Object.hash(runtimeType,id,accountId,displayName,mode,avatarIndex,createdAt,updatedAt,ulid);

@override
String toString() {
  return 'ProfileModel(id: $id, accountId: $accountId, displayName: $displayName, mode: $mode, avatarIndex: $avatarIndex, createdAt: $createdAt, updatedAt: $updatedAt, ulid: $ulid)';
}


}

/// @nodoc
abstract mixin class _$ProfileModelCopyWith<$Res> implements $ProfileModelCopyWith<$Res> {
  factory _$ProfileModelCopyWith(_ProfileModel value, $Res Function(_ProfileModel) _then) = __$ProfileModelCopyWithImpl;
@override @useResult
$Res call({
 int id, int accountId, String displayName, String mode, int avatarIndex, DateTime createdAt, DateTime updatedAt, String ulid
});




}
/// @nodoc
class __$ProfileModelCopyWithImpl<$Res>
    implements _$ProfileModelCopyWith<$Res> {
  __$ProfileModelCopyWithImpl(this._self, this._then);

  final _ProfileModel _self;
  final $Res Function(_ProfileModel) _then;

/// Create a copy of ProfileModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? accountId = null,Object? displayName = null,Object? mode = null,Object? avatarIndex = null,Object? createdAt = null,Object? updatedAt = null,Object? ulid = null,}) {
  return _then(_ProfileModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as int,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,avatarIndex: null == avatarIndex ? _self.avatarIndex : avatarIndex // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,ulid: null == ulid ? _self.ulid : ulid // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
