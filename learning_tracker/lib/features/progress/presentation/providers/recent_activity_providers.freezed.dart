// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recent_activity_providers.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RecentActivityWindow {

 DateTime get startDate; DateTime get endDate; String? get curriculumId;
/// Create a copy of RecentActivityWindow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecentActivityWindowCopyWith<RecentActivityWindow> get copyWith => _$RecentActivityWindowCopyWithImpl<RecentActivityWindow>(this as RecentActivityWindow, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecentActivityWindow&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId));
}


@override
int get hashCode => Object.hash(runtimeType,startDate,endDate,curriculumId);

@override
String toString() {
  return 'RecentActivityWindow(startDate: $startDate, endDate: $endDate, curriculumId: $curriculumId)';
}


}

/// @nodoc
abstract mixin class $RecentActivityWindowCopyWith<$Res>  {
  factory $RecentActivityWindowCopyWith(RecentActivityWindow value, $Res Function(RecentActivityWindow) _then) = _$RecentActivityWindowCopyWithImpl;
@useResult
$Res call({
 DateTime startDate, DateTime endDate, String? curriculumId
});




}
/// @nodoc
class _$RecentActivityWindowCopyWithImpl<$Res>
    implements $RecentActivityWindowCopyWith<$Res> {
  _$RecentActivityWindowCopyWithImpl(this._self, this._then);

  final RecentActivityWindow _self;
  final $Res Function(RecentActivityWindow) _then;

/// Create a copy of RecentActivityWindow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startDate = null,Object? endDate = null,Object? curriculumId = freezed,}) {
  return _then(_self.copyWith(
startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,endDate: null == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime,curriculumId: freezed == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RecentActivityWindow].
extension RecentActivityWindowPatterns on RecentActivityWindow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecentActivityWindow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecentActivityWindow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecentActivityWindow value)  $default,){
final _that = this;
switch (_that) {
case _RecentActivityWindow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecentActivityWindow value)?  $default,){
final _that = this;
switch (_that) {
case _RecentActivityWindow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime startDate,  DateTime endDate,  String? curriculumId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecentActivityWindow() when $default != null:
return $default(_that.startDate,_that.endDate,_that.curriculumId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime startDate,  DateTime endDate,  String? curriculumId)  $default,) {final _that = this;
switch (_that) {
case _RecentActivityWindow():
return $default(_that.startDate,_that.endDate,_that.curriculumId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime startDate,  DateTime endDate,  String? curriculumId)?  $default,) {final _that = this;
switch (_that) {
case _RecentActivityWindow() when $default != null:
return $default(_that.startDate,_that.endDate,_that.curriculumId);case _:
  return null;

}
}

}

/// @nodoc


class _RecentActivityWindow implements RecentActivityWindow {
  const _RecentActivityWindow({required this.startDate, required this.endDate, this.curriculumId});
  

@override final  DateTime startDate;
@override final  DateTime endDate;
@override final  String? curriculumId;

/// Create a copy of RecentActivityWindow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecentActivityWindowCopyWith<_RecentActivityWindow> get copyWith => __$RecentActivityWindowCopyWithImpl<_RecentActivityWindow>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecentActivityWindow&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.curriculumId, curriculumId) || other.curriculumId == curriculumId));
}


@override
int get hashCode => Object.hash(runtimeType,startDate,endDate,curriculumId);

@override
String toString() {
  return 'RecentActivityWindow(startDate: $startDate, endDate: $endDate, curriculumId: $curriculumId)';
}


}

/// @nodoc
abstract mixin class _$RecentActivityWindowCopyWith<$Res> implements $RecentActivityWindowCopyWith<$Res> {
  factory _$RecentActivityWindowCopyWith(_RecentActivityWindow value, $Res Function(_RecentActivityWindow) _then) = __$RecentActivityWindowCopyWithImpl;
@override @useResult
$Res call({
 DateTime startDate, DateTime endDate, String? curriculumId
});




}
/// @nodoc
class __$RecentActivityWindowCopyWithImpl<$Res>
    implements _$RecentActivityWindowCopyWith<$Res> {
  __$RecentActivityWindowCopyWithImpl(this._self, this._then);

  final _RecentActivityWindow _self;
  final $Res Function(_RecentActivityWindow) _then;

/// Create a copy of RecentActivityWindow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startDate = null,Object? endDate = null,Object? curriculumId = freezed,}) {
  return _then(_RecentActivityWindow(
startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,endDate: null == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime,curriculumId: freezed == curriculumId ? _self.curriculumId : curriculumId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
