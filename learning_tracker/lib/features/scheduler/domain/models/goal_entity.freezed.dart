// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GoalEntity {

 int? get id; CurriculumId get curriculumId; double get targetPercent; DateTime? get targetDate; String get description;/// Whether the goal deadline uses Hebrew or Gregorian calendar.
/// Values: 'hebrew' or 'gregorian' (default).
 String get dateType; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of GoalEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalEntityCopyWith<GoalEntity> get copyWith => _$GoalEntityCopyWithImpl<GoalEntity>(this as GoalEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.targetPercent, targetPercent) || other.targetPercent == targetPercent)&&(identical(other.targetDate, targetDate) || other.targetDate == targetDate)&&(identical(other.description, description) || other.description == description)&&(identical(other.dateType, dateType) || other.dateType == dateType)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,curriculumId,targetPercent,targetDate,description,dateType,createdAt,updatedAt);

@override
String toString() {
  return 'GoalEntity(id: $id, curriculumId: $curriculumId, targetPercent: $targetPercent, targetDate: $targetDate, description: $description, dateType: $dateType, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $GoalEntityCopyWith<$Res>  {
  factory $GoalEntityCopyWith(GoalEntity value, $Res Function(GoalEntity) _then) = _$GoalEntityCopyWithImpl;
@useResult
$Res call({
 int? id, CurriculumId curriculumId, double targetPercent, DateTime? targetDate, String description, String dateType, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$GoalEntityCopyWithImpl<$Res>
    implements $GoalEntityCopyWith<$Res> {
  _$GoalEntityCopyWithImpl(this._self, this._then);

  final GoalEntity _self;
  final $Res Function(GoalEntity) _then;

/// Create a copy of GoalEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? curriculumId = null,Object? targetPercent = null,Object? targetDate = freezed,Object? description = null,Object? dateType = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,targetPercent: null == targetPercent ? _self.targetPercent : targetPercent // ignore: cast_nullable_to_non_nullable
as double,targetDate: freezed == targetDate ? _self.targetDate : targetDate // ignore: cast_nullable_to_non_nullable
as DateTime?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,dateType: null == dateType ? _self.dateType : dateType // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [GoalEntity].
extension GoalEntityPatterns on GoalEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoalEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoalEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoalEntity value)  $default,){
final _that = this;
switch (_that) {
case _GoalEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoalEntity value)?  $default,){
final _that = this;
switch (_that) {
case _GoalEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  CurriculumId curriculumId,  double targetPercent,  DateTime? targetDate,  String description,  String dateType,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoalEntity() when $default != null:
return $default(_that.id,_that.curriculumId,_that.targetPercent,_that.targetDate,_that.description,_that.dateType,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  CurriculumId curriculumId,  double targetPercent,  DateTime? targetDate,  String description,  String dateType,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _GoalEntity():
return $default(_that.id,_that.curriculumId,_that.targetPercent,_that.targetDate,_that.description,_that.dateType,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  CurriculumId curriculumId,  double targetPercent,  DateTime? targetDate,  String description,  String dateType,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _GoalEntity() when $default != null:
return $default(_that.id,_that.curriculumId,_that.targetPercent,_that.targetDate,_that.description,_that.dateType,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _GoalEntity extends GoalEntity {
  const _GoalEntity({this.id, required this.curriculumId, this.targetPercent = 100.0, this.targetDate, this.description = '', this.dateType = 'gregorian', required this.createdAt, required this.updatedAt}): super._();
  

@override final  int? id;
@override final  CurriculumId curriculumId;
@override@JsonKey() final  double targetPercent;
@override final  DateTime? targetDate;
@override@JsonKey() final  String description;
/// Whether the goal deadline uses Hebrew or Gregorian calendar.
/// Values: 'hebrew' or 'gregorian' (default).
@override@JsonKey() final  String dateType;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of GoalEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalEntityCopyWith<_GoalEntity> get copyWith => __$GoalEntityCopyWithImpl<_GoalEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoalEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.targetPercent, targetPercent) || other.targetPercent == targetPercent)&&(identical(other.targetDate, targetDate) || other.targetDate == targetDate)&&(identical(other.description, description) || other.description == description)&&(identical(other.dateType, dateType) || other.dateType == dateType)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,curriculumId,targetPercent,targetDate,description,dateType,createdAt,updatedAt);

@override
String toString() {
  return 'GoalEntity(id: $id, curriculumId: $curriculumId, targetPercent: $targetPercent, targetDate: $targetDate, description: $description, dateType: $dateType, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$GoalEntityCopyWith<$Res> implements $GoalEntityCopyWith<$Res> {
  factory _$GoalEntityCopyWith(_GoalEntity value, $Res Function(_GoalEntity) _then) = __$GoalEntityCopyWithImpl;
@override @useResult
$Res call({
 int? id, CurriculumId curriculumId, double targetPercent, DateTime? targetDate, String description, String dateType, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$GoalEntityCopyWithImpl<$Res>
    implements _$GoalEntityCopyWith<$Res> {
  __$GoalEntityCopyWithImpl(this._self, this._then);

  final _GoalEntity _self;
  final $Res Function(_GoalEntity) _then;

/// Create a copy of GoalEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? curriculumId = null,Object? targetPercent = null,Object? targetDate = freezed,Object? description = null,Object? dateType = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_GoalEntity(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,targetPercent: null == targetPercent ? _self.targetPercent : targetPercent // ignore: cast_nullable_to_non_nullable
as double,targetDate: freezed == targetDate ? _self.targetDate : targetDate // ignore: cast_nullable_to_non_nullable
as DateTime?,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,dateType: null == dateType ? _self.dateType : dateType // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
