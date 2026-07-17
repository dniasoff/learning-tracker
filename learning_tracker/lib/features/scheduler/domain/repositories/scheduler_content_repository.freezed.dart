// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduler_content_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SchedulerContentItem {

 String get sefariaRef; int get sortOrder; String? get level1; String? get level2; String? get level3; String? get level4;
/// Create a copy of SchedulerContentItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchedulerContentItemCopyWith<SchedulerContentItem> get copyWith => _$SchedulerContentItemCopyWithImpl<SchedulerContentItem>(this as SchedulerContentItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchedulerContentItem&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.level1, level1) || other.level1 == level1)&&(identical(other.level2, level2) || other.level2 == level2)&&(identical(other.level3, level3) || other.level3 == level3)&&(identical(other.level4, level4) || other.level4 == level4));
}


@override
int get hashCode => Object.hash(runtimeType,sefariaRef,sortOrder,level1,level2,level3,level4);

@override
String toString() {
  return 'SchedulerContentItem(sefariaRef: $sefariaRef, sortOrder: $sortOrder, level1: $level1, level2: $level2, level3: $level3, level4: $level4)';
}


}

/// @nodoc
abstract mixin class $SchedulerContentItemCopyWith<$Res>  {
  factory $SchedulerContentItemCopyWith(SchedulerContentItem value, $Res Function(SchedulerContentItem) _then) = _$SchedulerContentItemCopyWithImpl;
@useResult
$Res call({
 String sefariaRef, int sortOrder, String? level1, String? level2, String? level3, String? level4
});




}
/// @nodoc
class _$SchedulerContentItemCopyWithImpl<$Res>
    implements $SchedulerContentItemCopyWith<$Res> {
  _$SchedulerContentItemCopyWithImpl(this._self, this._then);

  final SchedulerContentItem _self;
  final $Res Function(SchedulerContentItem) _then;

/// Create a copy of SchedulerContentItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sefariaRef = null,Object? sortOrder = null,Object? level1 = freezed,Object? level2 = freezed,Object? level3 = freezed,Object? level4 = freezed,}) {
  return _then(_self.copyWith(
sefariaRef: null == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,level1: freezed == level1 ? _self.level1 : level1 // ignore: cast_nullable_to_non_nullable
as String?,level2: freezed == level2 ? _self.level2 : level2 // ignore: cast_nullable_to_non_nullable
as String?,level3: freezed == level3 ? _self.level3 : level3 // ignore: cast_nullable_to_non_nullable
as String?,level4: freezed == level4 ? _self.level4 : level4 // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SchedulerContentItem].
extension SchedulerContentItemPatterns on SchedulerContentItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchedulerContentItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchedulerContentItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchedulerContentItem value)  $default,){
final _that = this;
switch (_that) {
case _SchedulerContentItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchedulerContentItem value)?  $default,){
final _that = this;
switch (_that) {
case _SchedulerContentItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sefariaRef,  int sortOrder,  String? level1,  String? level2,  String? level3,  String? level4)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchedulerContentItem() when $default != null:
return $default(_that.sefariaRef,_that.sortOrder,_that.level1,_that.level2,_that.level3,_that.level4);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sefariaRef,  int sortOrder,  String? level1,  String? level2,  String? level3,  String? level4)  $default,) {final _that = this;
switch (_that) {
case _SchedulerContentItem():
return $default(_that.sefariaRef,_that.sortOrder,_that.level1,_that.level2,_that.level3,_that.level4);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sefariaRef,  int sortOrder,  String? level1,  String? level2,  String? level3,  String? level4)?  $default,) {final _that = this;
switch (_that) {
case _SchedulerContentItem() when $default != null:
return $default(_that.sefariaRef,_that.sortOrder,_that.level1,_that.level2,_that.level3,_that.level4);case _:
  return null;

}
}

}

/// @nodoc


class _SchedulerContentItem extends SchedulerContentItem {
  const _SchedulerContentItem({required this.sefariaRef, required this.sortOrder, this.level1, this.level2, this.level3, this.level4}): super._();
  

@override final  String sefariaRef;
@override final  int sortOrder;
@override final  String? level1;
@override final  String? level2;
@override final  String? level3;
@override final  String? level4;

/// Create a copy of SchedulerContentItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchedulerContentItemCopyWith<_SchedulerContentItem> get copyWith => __$SchedulerContentItemCopyWithImpl<_SchedulerContentItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchedulerContentItem&&(identical(other.sefariaRef, sefariaRef) || other.sefariaRef == sefariaRef)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.level1, level1) || other.level1 == level1)&&(identical(other.level2, level2) || other.level2 == level2)&&(identical(other.level3, level3) || other.level3 == level3)&&(identical(other.level4, level4) || other.level4 == level4));
}


@override
int get hashCode => Object.hash(runtimeType,sefariaRef,sortOrder,level1,level2,level3,level4);

@override
String toString() {
  return 'SchedulerContentItem(sefariaRef: $sefariaRef, sortOrder: $sortOrder, level1: $level1, level2: $level2, level3: $level3, level4: $level4)';
}


}

/// @nodoc
abstract mixin class _$SchedulerContentItemCopyWith<$Res> implements $SchedulerContentItemCopyWith<$Res> {
  factory _$SchedulerContentItemCopyWith(_SchedulerContentItem value, $Res Function(_SchedulerContentItem) _then) = __$SchedulerContentItemCopyWithImpl;
@override @useResult
$Res call({
 String sefariaRef, int sortOrder, String? level1, String? level2, String? level3, String? level4
});




}
/// @nodoc
class __$SchedulerContentItemCopyWithImpl<$Res>
    implements _$SchedulerContentItemCopyWith<$Res> {
  __$SchedulerContentItemCopyWithImpl(this._self, this._then);

  final _SchedulerContentItem _self;
  final $Res Function(_SchedulerContentItem) _then;

/// Create a copy of SchedulerContentItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sefariaRef = null,Object? sortOrder = null,Object? level1 = freezed,Object? level2 = freezed,Object? level3 = freezed,Object? level4 = freezed,}) {
  return _then(_SchedulerContentItem(
sefariaRef: null == sefariaRef ? _self.sefariaRef : sefariaRef // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,level1: freezed == level1 ? _self.level1 : level1 // ignore: cast_nullable_to_non_nullable
as String?,level2: freezed == level2 ? _self.level2 : level2 // ignore: cast_nullable_to_non_nullable
as String?,level3: freezed == level3 ? _self.level3 : level3 // ignore: cast_nullable_to_non_nullable
as String?,level4: freezed == level4 ? _self.level4 : level4 // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
