// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduler_learning_order_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SchedulerOrderItem {

 String get sefariaRef; int get userSortOrder;
/// Create a copy of SchedulerOrderItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchedulerOrderItemCopyWith<SchedulerOrderItem> get copyWith => _$SchedulerOrderItemCopyWithImpl<SchedulerOrderItem>(this as SchedulerOrderItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchedulerOrderItem&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.userSortOrder, userSortOrder) || other.userSortOrder == userSortOrder));
}


@override
int get hashCode => Object.hash(runtimeType,sefariaRef,userSortOrder);

@override
String toString() {
  return 'SchedulerOrderItem(sefariaRef: $sefariaRef, userSortOrder: $userSortOrder)';
}


}

/// @nodoc
abstract mixin class $SchedulerOrderItemCopyWith<$Res>  {
  factory $SchedulerOrderItemCopyWith(SchedulerOrderItem value, $Res Function(SchedulerOrderItem) _then) = _$SchedulerOrderItemCopyWithImpl;
@useResult
$Res call({
 String sefariaRef, int userSortOrder
});




}
/// @nodoc
class _$SchedulerOrderItemCopyWithImpl<$Res>
    implements $SchedulerOrderItemCopyWith<$Res> {
  _$SchedulerOrderItemCopyWithImpl(this._self, this._then);

  final SchedulerOrderItem _self;
  final $Res Function(SchedulerOrderItem) _then;

/// Create a copy of SchedulerOrderItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sefariaRef = null,Object? userSortOrder = null,}) {
  return _then(_self.copyWith(
sefariaRef: null == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String,userSortOrder: null == userSortOrder ? _self.userSortOrder : userSortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SchedulerOrderItem].
extension SchedulerOrderItemPatterns on SchedulerOrderItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchedulerOrderItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchedulerOrderItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchedulerOrderItem value)  $default,){
final _that = this;
switch (_that) {
case _SchedulerOrderItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchedulerOrderItem value)?  $default,){
final _that = this;
switch (_that) {
case _SchedulerOrderItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sefariaRef,  int userSortOrder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchedulerOrderItem() when $default != null:
return $default(_that.sefariaRef,_that.userSortOrder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sefariaRef,  int userSortOrder)  $default,) {final _that = this;
switch (_that) {
case _SchedulerOrderItem():
return $default(_that.sefariaRef,_that.userSortOrder);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sefariaRef,  int userSortOrder)?  $default,) {final _that = this;
switch (_that) {
case _SchedulerOrderItem() when $default != null:
return $default(_that.sefariaRef,_that.userSortOrder);case _:
  return null;

}
}

}

/// @nodoc


class _SchedulerOrderItem implements SchedulerOrderItem {
  const _SchedulerOrderItem({required this.sefariaRef, required this.userSortOrder});
  

@override final  String sefariaRef;
@override final  int userSortOrder;

/// Create a copy of SchedulerOrderItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchedulerOrderItemCopyWith<_SchedulerOrderItem> get copyWith => __$SchedulerOrderItemCopyWithImpl<_SchedulerOrderItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchedulerOrderItem&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.userSortOrder, userSortOrder) || other.userSortOrder == userSortOrder));
}


@override
int get hashCode => Object.hash(runtimeType,sefariaRef,userSortOrder);

@override
String toString() {
  return 'SchedulerOrderItem(sefariaRef: $sefariaRef, userSortOrder: $userSortOrder)';
}


}

/// @nodoc
abstract mixin class _$SchedulerOrderItemCopyWith<$Res> implements $SchedulerOrderItemCopyWith<$Res> {
  factory _$SchedulerOrderItemCopyWith(_SchedulerOrderItem value, $Res Function(_SchedulerOrderItem) _then) = __$SchedulerOrderItemCopyWithImpl;
@override @useResult
$Res call({
 String sefariaRef, int userSortOrder
});




}
/// @nodoc
class __$SchedulerOrderItemCopyWithImpl<$Res>
    implements _$SchedulerOrderItemCopyWith<$Res> {
  __$SchedulerOrderItemCopyWithImpl(this._self, this._then);

  final _SchedulerOrderItem _self;
  final $Res Function(_SchedulerOrderItem) _then;

/// Create a copy of SchedulerOrderItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sefariaRef = null,Object? userSortOrder = null,}) {
  return _then(_SchedulerOrderItem(
sefariaRef: null == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String,userSortOrder: null == userSortOrder ? _self.userSortOrder : userSortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
