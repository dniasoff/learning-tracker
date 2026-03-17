// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reward_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RewardModel {

 int get id; String get title; String get description; int get pointsThreshold; bool get isEarned; bool get isRevealed; DateTime? get earnedAt; DateTime get createdAt;
/// Create a copy of RewardModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RewardModelCopyWith<RewardModel> get copyWith => _$RewardModelCopyWithImpl<RewardModel>(this as RewardModel, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RewardModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.pointsThreshold, pointsThreshold) || other.pointsThreshold == pointsThreshold)&&(identical(other.isEarned, isEarned) || other.isEarned == isEarned)&&(identical(other.isRevealed, isRevealed) || other.isRevealed == isRevealed)&&(identical(other.earnedAt, earnedAt) || other.earnedAt == earnedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,description,pointsThreshold,isEarned,isRevealed,earnedAt,createdAt);

@override
String toString() {
  return 'RewardModel(id: $id, title: $title, description: $description, pointsThreshold: $pointsThreshold, isEarned: $isEarned, isRevealed: $isRevealed, earnedAt: $earnedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $RewardModelCopyWith<$Res>  {
  factory $RewardModelCopyWith(RewardModel value, $Res Function(RewardModel) _then) = _$RewardModelCopyWithImpl;
@useResult
$Res call({
 int id, String title, String description, int pointsThreshold, bool isEarned, bool isRevealed, DateTime? earnedAt, DateTime createdAt
});




}
/// @nodoc
class _$RewardModelCopyWithImpl<$Res>
    implements $RewardModelCopyWith<$Res> {
  _$RewardModelCopyWithImpl(this._self, this._then);

  final RewardModel _self;
  final $Res Function(RewardModel) _then;

/// Create a copy of RewardModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = null,Object? pointsThreshold = null,Object? isEarned = null,Object? isRevealed = null,Object? earnedAt = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,pointsThreshold: null == pointsThreshold ? _self.pointsThreshold : pointsThreshold // ignore: cast_nullable_to_non_nullable
as int,isEarned: null == isEarned ? _self.isEarned : isEarned // ignore: cast_nullable_to_non_nullable
as bool,isRevealed: null == isRevealed ? _self.isRevealed : isRevealed // ignore: cast_nullable_to_non_nullable
as bool,earnedAt: freezed == earnedAt ? _self.earnedAt : earnedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [RewardModel].
extension RewardModelPatterns on RewardModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RewardModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RewardModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RewardModel value)  $default,){
final _that = this;
switch (_that) {
case _RewardModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RewardModel value)?  $default,){
final _that = this;
switch (_that) {
case _RewardModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String description,  int pointsThreshold,  bool isEarned,  bool isRevealed,  DateTime? earnedAt,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RewardModel() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.pointsThreshold,_that.isEarned,_that.isRevealed,_that.earnedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String description,  int pointsThreshold,  bool isEarned,  bool isRevealed,  DateTime? earnedAt,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _RewardModel():
return $default(_that.id,_that.title,_that.description,_that.pointsThreshold,_that.isEarned,_that.isRevealed,_that.earnedAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String description,  int pointsThreshold,  bool isEarned,  bool isRevealed,  DateTime? earnedAt,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _RewardModel() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.pointsThreshold,_that.isEarned,_that.isRevealed,_that.earnedAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _RewardModel implements RewardModel {
  const _RewardModel({required this.id, required this.title, required this.description, required this.pointsThreshold, required this.isEarned, required this.isRevealed, this.earnedAt, required this.createdAt});
  

@override final  int id;
@override final  String title;
@override final  String description;
@override final  int pointsThreshold;
@override final  bool isEarned;
@override final  bool isRevealed;
@override final  DateTime? earnedAt;
@override final  DateTime createdAt;

/// Create a copy of RewardModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RewardModelCopyWith<_RewardModel> get copyWith => __$RewardModelCopyWithImpl<_RewardModel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RewardModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.pointsThreshold, pointsThreshold) || other.pointsThreshold == pointsThreshold)&&(identical(other.isEarned, isEarned) || other.isEarned == isEarned)&&(identical(other.isRevealed, isRevealed) || other.isRevealed == isRevealed)&&(identical(other.earnedAt, earnedAt) || other.earnedAt == earnedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,description,pointsThreshold,isEarned,isRevealed,earnedAt,createdAt);

@override
String toString() {
  return 'RewardModel(id: $id, title: $title, description: $description, pointsThreshold: $pointsThreshold, isEarned: $isEarned, isRevealed: $isRevealed, earnedAt: $earnedAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$RewardModelCopyWith<$Res> implements $RewardModelCopyWith<$Res> {
  factory _$RewardModelCopyWith(_RewardModel value, $Res Function(_RewardModel) _then) = __$RewardModelCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String description, int pointsThreshold, bool isEarned, bool isRevealed, DateTime? earnedAt, DateTime createdAt
});




}
/// @nodoc
class __$RewardModelCopyWithImpl<$Res>
    implements _$RewardModelCopyWith<$Res> {
  __$RewardModelCopyWithImpl(this._self, this._then);

  final _RewardModel _self;
  final $Res Function(_RewardModel) _then;

/// Create a copy of RewardModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = null,Object? pointsThreshold = null,Object? isEarned = null,Object? isRevealed = null,Object? earnedAt = freezed,Object? createdAt = null,}) {
  return _then(_RewardModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,pointsThreshold: null == pointsThreshold ? _self.pointsThreshold : pointsThreshold // ignore: cast_nullable_to_non_nullable
as int,isEarned: null == isEarned ? _self.isEarned : isEarned // ignore: cast_nullable_to_non_nullable
as bool,isRevealed: null == isRevealed ? _self.isRevealed : isRevealed // ignore: cast_nullable_to_non_nullable
as bool,earnedAt: freezed == earnedAt ? _self.earnedAt : earnedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
