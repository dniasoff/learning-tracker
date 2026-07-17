// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduler_completion_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SchedulerCompletion {

 String get sefariaRef; int get stageOrder; String get trackType; DateTime get completedAt;
/// Create a copy of SchedulerCompletion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchedulerCompletionCopyWith<SchedulerCompletion> get copyWith => _$SchedulerCompletionCopyWithImpl<SchedulerCompletion>(this as SchedulerCompletion, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchedulerCompletion&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.stageOrder, stageOrder) || other.stageOrder == stageOrder)&&(identical(other.trackType, trackType) || other.trackType == trackType)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}


@override
int get hashCode => Object.hash(runtimeType,sefariaRef,stageOrder,trackType,completedAt);

@override
String toString() {
  return 'SchedulerCompletion(sefariaRef: $sefariaRef, stageOrder: $stageOrder, trackType: $trackType, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class $SchedulerCompletionCopyWith<$Res>  {
  factory $SchedulerCompletionCopyWith(SchedulerCompletion value, $Res Function(SchedulerCompletion) _then) = _$SchedulerCompletionCopyWithImpl;
@useResult
$Res call({
 String sefariaRef, int stageOrder, String trackType, DateTime completedAt
});




}
/// @nodoc
class _$SchedulerCompletionCopyWithImpl<$Res>
    implements $SchedulerCompletionCopyWith<$Res> {
  _$SchedulerCompletionCopyWithImpl(this._self, this._then);

  final SchedulerCompletion _self;
  final $Res Function(SchedulerCompletion) _then;

/// Create a copy of SchedulerCompletion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sefariaRef = null,Object? stageOrder = null,Object? trackType = null,Object? completedAt = null,}) {
  return _then(_self.copyWith(
sefariaRef: null == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String,stageOrder: null == stageOrder ? _self.stageOrder : stageOrder // ignore: cast_nullable_to_non_nullable
as int,trackType: null == trackType ? _self.trackType : trackType // ignore: cast_nullable_to_non_nullable
as String,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SchedulerCompletion].
extension SchedulerCompletionPatterns on SchedulerCompletion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchedulerCompletion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchedulerCompletion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchedulerCompletion value)  $default,){
final _that = this;
switch (_that) {
case _SchedulerCompletion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchedulerCompletion value)?  $default,){
final _that = this;
switch (_that) {
case _SchedulerCompletion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sefariaRef,  int stageOrder,  String trackType,  DateTime completedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchedulerCompletion() when $default != null:
return $default(_that.sefariaRef,_that.stageOrder,_that.trackType,_that.completedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sefariaRef,  int stageOrder,  String trackType,  DateTime completedAt)  $default,) {final _that = this;
switch (_that) {
case _SchedulerCompletion():
return $default(_that.sefariaRef,_that.stageOrder,_that.trackType,_that.completedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sefariaRef,  int stageOrder,  String trackType,  DateTime completedAt)?  $default,) {final _that = this;
switch (_that) {
case _SchedulerCompletion() when $default != null:
return $default(_that.sefariaRef,_that.stageOrder,_that.trackType,_that.completedAt);case _:
  return null;

}
}

}

/// @nodoc


class _SchedulerCompletion implements SchedulerCompletion {
  const _SchedulerCompletion({required this.sefariaRef, required this.stageOrder, required this.trackType, required this.completedAt});
  

@override final  String sefariaRef;
@override final  int stageOrder;
@override final  String trackType;
@override final  DateTime completedAt;

/// Create a copy of SchedulerCompletion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchedulerCompletionCopyWith<_SchedulerCompletion> get copyWith => __$SchedulerCompletionCopyWithImpl<_SchedulerCompletion>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchedulerCompletion&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.stageOrder, stageOrder) || other.stageOrder == stageOrder)&&(identical(other.trackType, trackType) || other.trackType == trackType)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}


@override
int get hashCode => Object.hash(runtimeType,sefariaRef,stageOrder,trackType,completedAt);

@override
String toString() {
  return 'SchedulerCompletion(sefariaRef: $sefariaRef, stageOrder: $stageOrder, trackType: $trackType, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class _$SchedulerCompletionCopyWith<$Res> implements $SchedulerCompletionCopyWith<$Res> {
  factory _$SchedulerCompletionCopyWith(_SchedulerCompletion value, $Res Function(_SchedulerCompletion) _then) = __$SchedulerCompletionCopyWithImpl;
@override @useResult
$Res call({
 String sefariaRef, int stageOrder, String trackType, DateTime completedAt
});




}
/// @nodoc
class __$SchedulerCompletionCopyWithImpl<$Res>
    implements _$SchedulerCompletionCopyWith<$Res> {
  __$SchedulerCompletionCopyWithImpl(this._self, this._then);

  final _SchedulerCompletion _self;
  final $Res Function(_SchedulerCompletion) _then;

/// Create a copy of SchedulerCompletion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sefariaRef = null,Object? stageOrder = null,Object? trackType = null,Object? completedAt = null,}) {
  return _then(_SchedulerCompletion(
sefariaRef: null == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String,stageOrder: null == stageOrder ? _self.stageOrder : stageOrder // ignore: cast_nullable_to_non_nullable
as int,trackType: null == trackType ? _self.trackType : trackType // ignore: cast_nullable_to_non_nullable
as String,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
