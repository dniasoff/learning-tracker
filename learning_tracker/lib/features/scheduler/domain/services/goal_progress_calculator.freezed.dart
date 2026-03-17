// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal_progress_calculator.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GoalProgress {

/// Percentage of target completed (0.0 to 100.0+).
 double get percentComplete;/// Days remaining until deadline. Null if no deadline set.
 int? get daysRemaining;/// Items per day needed to meet the goal. Null if no deadline set.
 double? get itemsPerDay;/// Total items in the curriculum.
 int get totalItems;/// Number of items completed.
 int get completedItems;/// Number of items still needed to reach the target.
 int get remainingItems;
/// Create a copy of GoalProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalProgressCopyWith<GoalProgress> get copyWith => _$GoalProgressCopyWithImpl<GoalProgress>(this as GoalProgress, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalProgress&&(identical(other.percentComplete, percentComplete) || other.percentComplete == percentComplete)&&(identical(other.daysRemaining, daysRemaining) || other.daysRemaining == daysRemaining)&&(identical(other.itemsPerDay, itemsPerDay) || other.itemsPerDay == itemsPerDay)&&(identical(other.totalItems, totalItems) || other.totalItems == totalItems)&&(identical(other.completedItems, completedItems) || other.completedItems == completedItems)&&(identical(other.remainingItems, remainingItems) || other.remainingItems == remainingItems));
}


@override
int get hashCode => Object.hash(runtimeType,percentComplete,daysRemaining,itemsPerDay,totalItems,completedItems,remainingItems);

@override
String toString() {
  return 'GoalProgress(percentComplete: $percentComplete, daysRemaining: $daysRemaining, itemsPerDay: $itemsPerDay, totalItems: $totalItems, completedItems: $completedItems, remainingItems: $remainingItems)';
}


}

/// @nodoc
abstract mixin class $GoalProgressCopyWith<$Res>  {
  factory $GoalProgressCopyWith(GoalProgress value, $Res Function(GoalProgress) _then) = _$GoalProgressCopyWithImpl;
@useResult
$Res call({
 double percentComplete, int? daysRemaining, double? itemsPerDay, int totalItems, int completedItems, int remainingItems
});




}
/// @nodoc
class _$GoalProgressCopyWithImpl<$Res>
    implements $GoalProgressCopyWith<$Res> {
  _$GoalProgressCopyWithImpl(this._self, this._then);

  final GoalProgress _self;
  final $Res Function(GoalProgress) _then;

/// Create a copy of GoalProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? percentComplete = null,Object? daysRemaining = freezed,Object? itemsPerDay = freezed,Object? totalItems = null,Object? completedItems = null,Object? remainingItems = null,}) {
  return _then(_self.copyWith(
percentComplete: null == percentComplete ? _self.percentComplete : percentComplete // ignore: cast_nullable_to_non_nullable
as double,daysRemaining: freezed == daysRemaining ? _self.daysRemaining : daysRemaining // ignore: cast_nullable_to_non_nullable
as int?,itemsPerDay: freezed == itemsPerDay ? _self.itemsPerDay : itemsPerDay // ignore: cast_nullable_to_non_nullable
as double?,totalItems: null == totalItems ? _self.totalItems : totalItems // ignore: cast_nullable_to_non_nullable
as int,completedItems: null == completedItems ? _self.completedItems : completedItems // ignore: cast_nullable_to_non_nullable
as int,remainingItems: null == remainingItems ? _self.remainingItems : remainingItems // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [GoalProgress].
extension GoalProgressPatterns on GoalProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoalProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoalProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoalProgress value)  $default,){
final _that = this;
switch (_that) {
case _GoalProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoalProgress value)?  $default,){
final _that = this;
switch (_that) {
case _GoalProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double percentComplete,  int? daysRemaining,  double? itemsPerDay,  int totalItems,  int completedItems,  int remainingItems)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoalProgress() when $default != null:
return $default(_that.percentComplete,_that.daysRemaining,_that.itemsPerDay,_that.totalItems,_that.completedItems,_that.remainingItems);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double percentComplete,  int? daysRemaining,  double? itemsPerDay,  int totalItems,  int completedItems,  int remainingItems)  $default,) {final _that = this;
switch (_that) {
case _GoalProgress():
return $default(_that.percentComplete,_that.daysRemaining,_that.itemsPerDay,_that.totalItems,_that.completedItems,_that.remainingItems);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double percentComplete,  int? daysRemaining,  double? itemsPerDay,  int totalItems,  int completedItems,  int remainingItems)?  $default,) {final _that = this;
switch (_that) {
case _GoalProgress() when $default != null:
return $default(_that.percentComplete,_that.daysRemaining,_that.itemsPerDay,_that.totalItems,_that.completedItems,_that.remainingItems);case _:
  return null;

}
}

}

/// @nodoc


class _GoalProgress implements GoalProgress {
  const _GoalProgress({required this.percentComplete, this.daysRemaining, this.itemsPerDay, required this.totalItems, required this.completedItems, required this.remainingItems});
  

/// Percentage of target completed (0.0 to 100.0+).
@override final  double percentComplete;
/// Days remaining until deadline. Null if no deadline set.
@override final  int? daysRemaining;
/// Items per day needed to meet the goal. Null if no deadline set.
@override final  double? itemsPerDay;
/// Total items in the curriculum.
@override final  int totalItems;
/// Number of items completed.
@override final  int completedItems;
/// Number of items still needed to reach the target.
@override final  int remainingItems;

/// Create a copy of GoalProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalProgressCopyWith<_GoalProgress> get copyWith => __$GoalProgressCopyWithImpl<_GoalProgress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoalProgress&&(identical(other.percentComplete, percentComplete) || other.percentComplete == percentComplete)&&(identical(other.daysRemaining, daysRemaining) || other.daysRemaining == daysRemaining)&&(identical(other.itemsPerDay, itemsPerDay) || other.itemsPerDay == itemsPerDay)&&(identical(other.totalItems, totalItems) || other.totalItems == totalItems)&&(identical(other.completedItems, completedItems) || other.completedItems == completedItems)&&(identical(other.remainingItems, remainingItems) || other.remainingItems == remainingItems));
}


@override
int get hashCode => Object.hash(runtimeType,percentComplete,daysRemaining,itemsPerDay,totalItems,completedItems,remainingItems);

@override
String toString() {
  return 'GoalProgress(percentComplete: $percentComplete, daysRemaining: $daysRemaining, itemsPerDay: $itemsPerDay, totalItems: $totalItems, completedItems: $completedItems, remainingItems: $remainingItems)';
}


}

/// @nodoc
abstract mixin class _$GoalProgressCopyWith<$Res> implements $GoalProgressCopyWith<$Res> {
  factory _$GoalProgressCopyWith(_GoalProgress value, $Res Function(_GoalProgress) _then) = __$GoalProgressCopyWithImpl;
@override @useResult
$Res call({
 double percentComplete, int? daysRemaining, double? itemsPerDay, int totalItems, int completedItems, int remainingItems
});




}
/// @nodoc
class __$GoalProgressCopyWithImpl<$Res>
    implements _$GoalProgressCopyWith<$Res> {
  __$GoalProgressCopyWithImpl(this._self, this._then);

  final _GoalProgress _self;
  final $Res Function(_GoalProgress) _then;

/// Create a copy of GoalProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? percentComplete = null,Object? daysRemaining = freezed,Object? itemsPerDay = freezed,Object? totalItems = null,Object? completedItems = null,Object? remainingItems = null,}) {
  return _then(_GoalProgress(
percentComplete: null == percentComplete ? _self.percentComplete : percentComplete // ignore: cast_nullable_to_non_nullable
as double,daysRemaining: freezed == daysRemaining ? _self.daysRemaining : daysRemaining // ignore: cast_nullable_to_non_nullable
as int?,itemsPerDay: freezed == itemsPerDay ? _self.itemsPerDay : itemsPerDay // ignore: cast_nullable_to_non_nullable
as double?,totalItems: null == totalItems ? _self.totalItems : totalItems // ignore: cast_nullable_to_non_nullable
as int,completedItems: null == completedItems ? _self.completedItems : completedItems // ignore: cast_nullable_to_non_nullable
as int,remainingItems: null == remainingItems ? _self.remainingItems : remainingItems // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
