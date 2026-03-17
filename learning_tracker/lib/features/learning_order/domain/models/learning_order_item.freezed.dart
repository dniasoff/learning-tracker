// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'learning_order_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LearningOrderItem {

 String get sefariaRef; String get displayNameHe; String get displayNameEn; int get userSortOrder;/// False if this item is using fallback sort from content_items.sort_order.
 bool get isCustomOrdered;
/// Create a copy of LearningOrderItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LearningOrderItemCopyWith<LearningOrderItem> get copyWith => _$LearningOrderItemCopyWithImpl<LearningOrderItem>(this as LearningOrderItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LearningOrderItem&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.displayNameHe, displayNameHe) || other.displayNameHe == displayNameHe)&&(identical(other.displayNameEn, displayNameEn) || other.displayNameEn == displayNameEn)&&(identical(other.userSortOrder, userSortOrder) || other.userSortOrder == userSortOrder)&&(identical(other.isCustomOrdered, isCustomOrdered) || other.isCustomOrdered == isCustomOrdered));
}


@override
int get hashCode => Object.hash(runtimeType,sefariaRef,displayNameHe,displayNameEn,userSortOrder,isCustomOrdered);

@override
String toString() {
  return 'LearningOrderItem(sefariaRef: $sefariaRef, displayNameHe: $displayNameHe, displayNameEn: $displayNameEn, userSortOrder: $userSortOrder, isCustomOrdered: $isCustomOrdered)';
}


}

/// @nodoc
abstract mixin class $LearningOrderItemCopyWith<$Res>  {
  factory $LearningOrderItemCopyWith(LearningOrderItem value, $Res Function(LearningOrderItem) _then) = _$LearningOrderItemCopyWithImpl;
@useResult
$Res call({
 String sefariaRef, String displayNameHe, String displayNameEn, int userSortOrder, bool isCustomOrdered
});




}
/// @nodoc
class _$LearningOrderItemCopyWithImpl<$Res>
    implements $LearningOrderItemCopyWith<$Res> {
  _$LearningOrderItemCopyWithImpl(this._self, this._then);

  final LearningOrderItem _self;
  final $Res Function(LearningOrderItem) _then;

/// Create a copy of LearningOrderItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sefariaRef = null,Object? displayNameHe = null,Object? displayNameEn = null,Object? userSortOrder = null,Object? isCustomOrdered = null,}) {
  return _then(_self.copyWith(
sefariaRef: null == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String,displayNameHe: null == displayNameHe ? _self.displayNameHe : displayNameHe // ignore: cast_nullable_to_non_nullable
as String,displayNameEn: null == displayNameEn ? _self.displayNameEn : displayNameEn // ignore: cast_nullable_to_non_nullable
as String,userSortOrder: null == userSortOrder ? _self.userSortOrder : userSortOrder // ignore: cast_nullable_to_non_nullable
as int,isCustomOrdered: null == isCustomOrdered ? _self.isCustomOrdered : isCustomOrdered // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LearningOrderItem].
extension LearningOrderItemPatterns on LearningOrderItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LearningOrderItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LearningOrderItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LearningOrderItem value)  $default,){
final _that = this;
switch (_that) {
case _LearningOrderItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LearningOrderItem value)?  $default,){
final _that = this;
switch (_that) {
case _LearningOrderItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sefariaRef,  String displayNameHe,  String displayNameEn,  int userSortOrder,  bool isCustomOrdered)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LearningOrderItem() when $default != null:
return $default(_that.sefariaRef,_that.displayNameHe,_that.displayNameEn,_that.userSortOrder,_that.isCustomOrdered);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sefariaRef,  String displayNameHe,  String displayNameEn,  int userSortOrder,  bool isCustomOrdered)  $default,) {final _that = this;
switch (_that) {
case _LearningOrderItem():
return $default(_that.sefariaRef,_that.displayNameHe,_that.displayNameEn,_that.userSortOrder,_that.isCustomOrdered);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sefariaRef,  String displayNameHe,  String displayNameEn,  int userSortOrder,  bool isCustomOrdered)?  $default,) {final _that = this;
switch (_that) {
case _LearningOrderItem() when $default != null:
return $default(_that.sefariaRef,_that.displayNameHe,_that.displayNameEn,_that.userSortOrder,_that.isCustomOrdered);case _:
  return null;

}
}

}

/// @nodoc


class _LearningOrderItem implements LearningOrderItem {
  const _LearningOrderItem({required this.sefariaRef, required this.displayNameHe, required this.displayNameEn, required this.userSortOrder, this.isCustomOrdered = false});
  

@override final  String sefariaRef;
@override final  String displayNameHe;
@override final  String displayNameEn;
@override final  int userSortOrder;
/// False if this item is using fallback sort from content_items.sort_order.
@override@JsonKey() final  bool isCustomOrdered;

/// Create a copy of LearningOrderItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LearningOrderItemCopyWith<_LearningOrderItem> get copyWith => __$LearningOrderItemCopyWithImpl<_LearningOrderItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LearningOrderItem&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.displayNameHe, displayNameHe) || other.displayNameHe == displayNameHe)&&(identical(other.displayNameEn, displayNameEn) || other.displayNameEn == displayNameEn)&&(identical(other.userSortOrder, userSortOrder) || other.userSortOrder == userSortOrder)&&(identical(other.isCustomOrdered, isCustomOrdered) || other.isCustomOrdered == isCustomOrdered));
}


@override
int get hashCode => Object.hash(runtimeType,sefariaRef,displayNameHe,displayNameEn,userSortOrder,isCustomOrdered);

@override
String toString() {
  return 'LearningOrderItem(sefariaRef: $sefariaRef, displayNameHe: $displayNameHe, displayNameEn: $displayNameEn, userSortOrder: $userSortOrder, isCustomOrdered: $isCustomOrdered)';
}


}

/// @nodoc
abstract mixin class _$LearningOrderItemCopyWith<$Res> implements $LearningOrderItemCopyWith<$Res> {
  factory _$LearningOrderItemCopyWith(_LearningOrderItem value, $Res Function(_LearningOrderItem) _then) = __$LearningOrderItemCopyWithImpl;
@override @useResult
$Res call({
 String sefariaRef, String displayNameHe, String displayNameEn, int userSortOrder, bool isCustomOrdered
});




}
/// @nodoc
class __$LearningOrderItemCopyWithImpl<$Res>
    implements _$LearningOrderItemCopyWith<$Res> {
  __$LearningOrderItemCopyWithImpl(this._self, this._then);

  final _LearningOrderItem _self;
  final $Res Function(_LearningOrderItem) _then;

/// Create a copy of LearningOrderItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sefariaRef = null,Object? displayNameHe = null,Object? displayNameEn = null,Object? userSortOrder = null,Object? isCustomOrdered = null,}) {
  return _then(_LearningOrderItem(
sefariaRef: null == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String,displayNameHe: null == displayNameHe ? _self.displayNameHe : displayNameHe // ignore: cast_nullable_to_non_nullable
as String,displayNameEn: null == displayNameEn ? _self.displayNameEn : displayNameEn // ignore: cast_nullable_to_non_nullable
as String,userSortOrder: null == userSortOrder ? _self.userSortOrder : userSortOrder // ignore: cast_nullable_to_non_nullable
as int,isCustomOrdered: null == isCustomOrdered ? _self.isCustomOrdered : isCustomOrdered // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
