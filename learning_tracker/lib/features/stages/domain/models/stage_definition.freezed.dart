// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stage_definition.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StageDefinition {

 int get id; CurriculumId get curriculumId; int get stageOrder; String get stageName; int get delayDays; bool get isDefault; ScheduleType get scheduleType; List<int>? get daysOfWeek; int? get rollingWindowSize;
/// Create a copy of StageDefinition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StageDefinitionCopyWith<StageDefinition> get copyWith => _$StageDefinitionCopyWithImpl<StageDefinition>(this as StageDefinition, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StageDefinition&&(identical(other.id, id) || other.id == id)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.stageOrder, stageOrder) || other.stageOrder == stageOrder)&&(identical(other.stageName, stageName) || other.stageName == stageName)&&(identical(other.delayDays, delayDays) || other.delayDays == delayDays)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.scheduleType, scheduleType) || other.scheduleType == scheduleType)&&const DeepCollectionEquality().equals(other.daysOfWeek, daysOfWeek)&&(identical(other.rollingWindowSize, rollingWindowSize) || other.rollingWindowSize == rollingWindowSize));
}


@override
int get hashCode => Object.hash(runtimeType,id,curriculumId,stageOrder,stageName,delayDays,isDefault,scheduleType,const DeepCollectionEquality().hash(daysOfWeek),rollingWindowSize);

@override
String toString() {
  return 'StageDefinition(id: $id, curriculumId: $curriculumId, stageOrder: $stageOrder, stageName: $stageName, delayDays: $delayDays, isDefault: $isDefault, scheduleType: $scheduleType, daysOfWeek: $daysOfWeek, rollingWindowSize: $rollingWindowSize)';
}


}

/// @nodoc
abstract mixin class $StageDefinitionCopyWith<$Res>  {
  factory $StageDefinitionCopyWith(StageDefinition value, $Res Function(StageDefinition) _then) = _$StageDefinitionCopyWithImpl;
@useResult
$Res call({
 int id, CurriculumId curriculumId, int stageOrder, String stageName, int delayDays, bool isDefault, ScheduleType scheduleType, List<int>? daysOfWeek, int? rollingWindowSize
});




}
/// @nodoc
class _$StageDefinitionCopyWithImpl<$Res>
    implements $StageDefinitionCopyWith<$Res> {
  _$StageDefinitionCopyWithImpl(this._self, this._then);

  final StageDefinition _self;
  final $Res Function(StageDefinition) _then;

/// Create a copy of StageDefinition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? curriculumId = null,Object? stageOrder = null,Object? stageName = null,Object? delayDays = null,Object? isDefault = null,Object? scheduleType = null,Object? daysOfWeek = freezed,Object? rollingWindowSize = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,stageOrder: null == stageOrder ? _self.stageOrder : stageOrder // ignore: cast_nullable_to_non_nullable
as int,stageName: null == stageName ? _self.stageName : stageName // ignore: cast_nullable_to_non_nullable
as String,delayDays: null == delayDays ? _self.delayDays : delayDays // ignore: cast_nullable_to_non_nullable
as int,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,scheduleType: null == scheduleType ? _self.scheduleType : scheduleType // ignore: cast_nullable_to_non_nullable
as ScheduleType,daysOfWeek: freezed == daysOfWeek ? _self.daysOfWeek : daysOfWeek // ignore: cast_nullable_to_non_nullable
as List<int>?,rollingWindowSize: freezed == rollingWindowSize ? _self.rollingWindowSize : rollingWindowSize // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [StageDefinition].
extension StageDefinitionPatterns on StageDefinition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StageDefinition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StageDefinition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StageDefinition value)  $default,){
final _that = this;
switch (_that) {
case _StageDefinition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StageDefinition value)?  $default,){
final _that = this;
switch (_that) {
case _StageDefinition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  CurriculumId curriculumId,  int stageOrder,  String stageName,  int delayDays,  bool isDefault,  ScheduleType scheduleType,  List<int>? daysOfWeek,  int? rollingWindowSize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StageDefinition() when $default != null:
return $default(_that.id,_that.curriculumId,_that.stageOrder,_that.stageName,_that.delayDays,_that.isDefault,_that.scheduleType,_that.daysOfWeek,_that.rollingWindowSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  CurriculumId curriculumId,  int stageOrder,  String stageName,  int delayDays,  bool isDefault,  ScheduleType scheduleType,  List<int>? daysOfWeek,  int? rollingWindowSize)  $default,) {final _that = this;
switch (_that) {
case _StageDefinition():
return $default(_that.id,_that.curriculumId,_that.stageOrder,_that.stageName,_that.delayDays,_that.isDefault,_that.scheduleType,_that.daysOfWeek,_that.rollingWindowSize);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  CurriculumId curriculumId,  int stageOrder,  String stageName,  int delayDays,  bool isDefault,  ScheduleType scheduleType,  List<int>? daysOfWeek,  int? rollingWindowSize)?  $default,) {final _that = this;
switch (_that) {
case _StageDefinition() when $default != null:
return $default(_that.id,_that.curriculumId,_that.stageOrder,_that.stageName,_that.delayDays,_that.isDefault,_that.scheduleType,_that.daysOfWeek,_that.rollingWindowSize);case _:
  return null;

}
}

}

/// @nodoc


class _StageDefinition implements StageDefinition {
  const _StageDefinition({required this.id, required this.curriculumId, required this.stageOrder, required this.stageName, required this.delayDays, required this.isDefault, this.scheduleType = ScheduleType.delay, final  List<int>? daysOfWeek, this.rollingWindowSize}): _daysOfWeek = daysOfWeek;
  

@override final  int id;
@override final  CurriculumId curriculumId;
@override final  int stageOrder;
@override final  String stageName;
@override final  int delayDays;
@override final  bool isDefault;
@override@JsonKey() final  ScheduleType scheduleType;
 final  List<int>? _daysOfWeek;
@override List<int>? get daysOfWeek {
  final value = _daysOfWeek;
  if (value == null) return null;
  if (_daysOfWeek is EqualUnmodifiableListView) return _daysOfWeek;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  int? rollingWindowSize;

/// Create a copy of StageDefinition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StageDefinitionCopyWith<_StageDefinition> get copyWith => __$StageDefinitionCopyWithImpl<_StageDefinition>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StageDefinition&&(identical(other.id, id) || other.id == id)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId)&&(identical(other.stageOrder, stageOrder) || other.stageOrder == stageOrder)&&(identical(other.stageName, stageName) || other.stageName == stageName)&&(identical(other.delayDays, delayDays) || other.delayDays == delayDays)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.scheduleType, scheduleType) || other.scheduleType == scheduleType)&&const DeepCollectionEquality().equals(other._daysOfWeek, _daysOfWeek)&&(identical(other.rollingWindowSize, rollingWindowSize) || other.rollingWindowSize == rollingWindowSize));
}


@override
int get hashCode => Object.hash(runtimeType,id,curriculumId,stageOrder,stageName,delayDays,isDefault,scheduleType,const DeepCollectionEquality().hash(_daysOfWeek),rollingWindowSize);

@override
String toString() {
  return 'StageDefinition(id: $id, curriculumId: $curriculumId, stageOrder: $stageOrder, stageName: $stageName, delayDays: $delayDays, isDefault: $isDefault, scheduleType: $scheduleType, daysOfWeek: $daysOfWeek, rollingWindowSize: $rollingWindowSize)';
}


}

/// @nodoc
abstract mixin class _$StageDefinitionCopyWith<$Res> implements $StageDefinitionCopyWith<$Res> {
  factory _$StageDefinitionCopyWith(_StageDefinition value, $Res Function(_StageDefinition) _then) = __$StageDefinitionCopyWithImpl;
@override @useResult
$Res call({
 int id, CurriculumId curriculumId, int stageOrder, String stageName, int delayDays, bool isDefault, ScheduleType scheduleType, List<int>? daysOfWeek, int? rollingWindowSize
});




}
/// @nodoc
class __$StageDefinitionCopyWithImpl<$Res>
    implements _$StageDefinitionCopyWith<$Res> {
  __$StageDefinitionCopyWithImpl(this._self, this._then);

  final _StageDefinition _self;
  final $Res Function(_StageDefinition) _then;

/// Create a copy of StageDefinition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? curriculumId = null,Object? stageOrder = null,Object? stageName = null,Object? delayDays = null,Object? isDefault = null,Object? scheduleType = null,Object? daysOfWeek = freezed,Object? rollingWindowSize = freezed,}) {
  return _then(_StageDefinition(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,curriculumId: null == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as CurriculumId,stageOrder: null == stageOrder ? _self.stageOrder : stageOrder // ignore: cast_nullable_to_non_nullable
as int,stageName: null == stageName ? _self.stageName : stageName // ignore: cast_nullable_to_non_nullable
as String,delayDays: null == delayDays ? _self.delayDays : delayDays // ignore: cast_nullable_to_non_nullable
as int,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,scheduleType: null == scheduleType ? _self.scheduleType : scheduleType // ignore: cast_nullable_to_non_nullable
as ScheduleType,daysOfWeek: freezed == daysOfWeek ? _self._daysOfWeek : daysOfWeek // ignore: cast_nullable_to_non_nullable
as List<int>?,rollingWindowSize: freezed == rollingWindowSize ? _self.rollingWindowSize : rollingWindowSize // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
