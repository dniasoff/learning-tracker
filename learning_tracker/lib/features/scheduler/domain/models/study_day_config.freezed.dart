// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'study_day_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StudyDayConfigEntry {

 int get dayOfWeek;// 1=Mon..7=Sun (ISO 8601)
 DayType get dayType;
/// Create a copy of StudyDayConfigEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudyDayConfigEntryCopyWith<StudyDayConfigEntry> get copyWith => _$StudyDayConfigEntryCopyWithImpl<StudyDayConfigEntry>(this as StudyDayConfigEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudyDayConfigEntry&&(identical(other.dayOfWeek, dayOfWeek) || other.dayOfWeek == dayOfWeek)&&(identical(other.dayType, dayType) || other.dayType == dayType));
}


@override
int get hashCode => Object.hash(runtimeType,dayOfWeek,dayType);

@override
String toString() {
  return 'StudyDayConfigEntry(dayOfWeek: $dayOfWeek, dayType: $dayType)';
}


}

/// @nodoc
abstract mixin class $StudyDayConfigEntryCopyWith<$Res>  {
  factory $StudyDayConfigEntryCopyWith(StudyDayConfigEntry value, $Res Function(StudyDayConfigEntry) _then) = _$StudyDayConfigEntryCopyWithImpl;
@useResult
$Res call({
 int dayOfWeek, DayType dayType
});




}
/// @nodoc
class _$StudyDayConfigEntryCopyWithImpl<$Res>
    implements $StudyDayConfigEntryCopyWith<$Res> {
  _$StudyDayConfigEntryCopyWithImpl(this._self, this._then);

  final StudyDayConfigEntry _self;
  final $Res Function(StudyDayConfigEntry) _then;

/// Create a copy of StudyDayConfigEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? dayOfWeek = null,Object? dayType = null,}) {
  return _then(_self.copyWith(
dayOfWeek: null == dayOfWeek ? _self.dayOfWeek : dayOfWeek // ignore: cast_nullable_to_non_nullable
as int,dayType: null == dayType ? _self.dayType : dayType // ignore: cast_nullable_to_non_nullable
as DayType,
  ));
}

}


/// Adds pattern-matching-related methods to [StudyDayConfigEntry].
extension StudyDayConfigEntryPatterns on StudyDayConfigEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudyDayConfigEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudyDayConfigEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudyDayConfigEntry value)  $default,){
final _that = this;
switch (_that) {
case _StudyDayConfigEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudyDayConfigEntry value)?  $default,){
final _that = this;
switch (_that) {
case _StudyDayConfigEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int dayOfWeek,  DayType dayType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudyDayConfigEntry() when $default != null:
return $default(_that.dayOfWeek,_that.dayType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int dayOfWeek,  DayType dayType)  $default,) {final _that = this;
switch (_that) {
case _StudyDayConfigEntry():
return $default(_that.dayOfWeek,_that.dayType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int dayOfWeek,  DayType dayType)?  $default,) {final _that = this;
switch (_that) {
case _StudyDayConfigEntry() when $default != null:
return $default(_that.dayOfWeek,_that.dayType);case _:
  return null;

}
}

}

/// @nodoc


class _StudyDayConfigEntry implements StudyDayConfigEntry {
  const _StudyDayConfigEntry({required this.dayOfWeek, required this.dayType});
  

@override final  int dayOfWeek;
// 1=Mon..7=Sun (ISO 8601)
@override final  DayType dayType;

/// Create a copy of StudyDayConfigEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudyDayConfigEntryCopyWith<_StudyDayConfigEntry> get copyWith => __$StudyDayConfigEntryCopyWithImpl<_StudyDayConfigEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudyDayConfigEntry&&(identical(other.dayOfWeek, dayOfWeek) || other.dayOfWeek == dayOfWeek)&&(identical(other.dayType, dayType) || other.dayType == dayType));
}


@override
int get hashCode => Object.hash(runtimeType,dayOfWeek,dayType);

@override
String toString() {
  return 'StudyDayConfigEntry(dayOfWeek: $dayOfWeek, dayType: $dayType)';
}


}

/// @nodoc
abstract mixin class _$StudyDayConfigEntryCopyWith<$Res> implements $StudyDayConfigEntryCopyWith<$Res> {
  factory _$StudyDayConfigEntryCopyWith(_StudyDayConfigEntry value, $Res Function(_StudyDayConfigEntry) _then) = __$StudyDayConfigEntryCopyWithImpl;
@override @useResult
$Res call({
 int dayOfWeek, DayType dayType
});




}
/// @nodoc
class __$StudyDayConfigEntryCopyWithImpl<$Res>
    implements _$StudyDayConfigEntryCopyWith<$Res> {
  __$StudyDayConfigEntryCopyWithImpl(this._self, this._then);

  final _StudyDayConfigEntry _self;
  final $Res Function(_StudyDayConfigEntry) _then;

/// Create a copy of StudyDayConfigEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? dayOfWeek = null,Object? dayType = null,}) {
  return _then(_StudyDayConfigEntry(
dayOfWeek: null == dayOfWeek ? _self.dayOfWeek : dayOfWeek // ignore: cast_nullable_to_non_nullable
as int,dayType: null == dayType ? _self.dayType : dayType // ignore: cast_nullable_to_non_nullable
as DayType,
  ));
}


}

// dart format on
