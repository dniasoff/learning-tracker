// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sacred_location.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SacredLocation {

 double get latitude; double get longitude; SacredLocationSource get source; DateTime get fixedAt; String? get countryCode; String? get cityLabel;
/// Create a copy of SacredLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SacredLocationCopyWith<SacredLocation> get copyWith => _$SacredLocationCopyWithImpl<SacredLocation>(this as SacredLocation, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SacredLocation&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.source, source) || other.source == source)&&(identical(other.fixedAt, fixedAt) || other.fixedAt == fixedAt)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.cityLabel, cityLabel) || other.cityLabel == cityLabel));
}


@override
int get hashCode => Object.hash(runtimeType,latitude,longitude,source,fixedAt,countryCode,cityLabel);

@override
String toString() {
  return 'SacredLocation(latitude: $latitude, longitude: $longitude, source: $source, fixedAt: $fixedAt, countryCode: $countryCode, cityLabel: $cityLabel)';
}


}

/// @nodoc
abstract mixin class $SacredLocationCopyWith<$Res>  {
  factory $SacredLocationCopyWith(SacredLocation value, $Res Function(SacredLocation) _then) = _$SacredLocationCopyWithImpl;
@useResult
$Res call({
 double latitude, double longitude, SacredLocationSource source, DateTime fixedAt, String? countryCode, String? cityLabel
});




}
/// @nodoc
class _$SacredLocationCopyWithImpl<$Res>
    implements $SacredLocationCopyWith<$Res> {
  _$SacredLocationCopyWithImpl(this._self, this._then);

  final SacredLocation _self;
  final $Res Function(SacredLocation) _then;

/// Create a copy of SacredLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? latitude = null,Object? longitude = null,Object? source = null,Object? fixedAt = null,Object? countryCode = freezed,Object? cityLabel = freezed,}) {
  return _then(_self.copyWith(
latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as SacredLocationSource,fixedAt: null == fixedAt ? _self.fixedAt : fixedAt // ignore: cast_nullable_to_non_nullable
as DateTime,countryCode: freezed == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String?,cityLabel: freezed == cityLabel ? _self.cityLabel : cityLabel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SacredLocation].
extension SacredLocationPatterns on SacredLocation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SacredLocation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SacredLocation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SacredLocation value)  $default,){
final _that = this;
switch (_that) {
case _SacredLocation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SacredLocation value)?  $default,){
final _that = this;
switch (_that) {
case _SacredLocation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double latitude,  double longitude,  SacredLocationSource source,  DateTime fixedAt,  String? countryCode,  String? cityLabel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SacredLocation() when $default != null:
return $default(_that.latitude,_that.longitude,_that.source,_that.fixedAt,_that.countryCode,_that.cityLabel);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double latitude,  double longitude,  SacredLocationSource source,  DateTime fixedAt,  String? countryCode,  String? cityLabel)  $default,) {final _that = this;
switch (_that) {
case _SacredLocation():
return $default(_that.latitude,_that.longitude,_that.source,_that.fixedAt,_that.countryCode,_that.cityLabel);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double latitude,  double longitude,  SacredLocationSource source,  DateTime fixedAt,  String? countryCode,  String? cityLabel)?  $default,) {final _that = this;
switch (_that) {
case _SacredLocation() when $default != null:
return $default(_that.latitude,_that.longitude,_that.source,_that.fixedAt,_that.countryCode,_that.cityLabel);case _:
  return null;

}
}

}

/// @nodoc


class _SacredLocation implements SacredLocation {
  const _SacredLocation({required this.latitude, required this.longitude, required this.source, required this.fixedAt, this.countryCode, this.cityLabel});
  

@override final  double latitude;
@override final  double longitude;
@override final  SacredLocationSource source;
@override final  DateTime fixedAt;
@override final  String? countryCode;
@override final  String? cityLabel;

/// Create a copy of SacredLocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SacredLocationCopyWith<_SacredLocation> get copyWith => __$SacredLocationCopyWithImpl<_SacredLocation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SacredLocation&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.source, source) || other.source == source)&&(identical(other.fixedAt, fixedAt) || other.fixedAt == fixedAt)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.cityLabel, cityLabel) || other.cityLabel == cityLabel));
}


@override
int get hashCode => Object.hash(runtimeType,latitude,longitude,source,fixedAt,countryCode,cityLabel);

@override
String toString() {
  return 'SacredLocation(latitude: $latitude, longitude: $longitude, source: $source, fixedAt: $fixedAt, countryCode: $countryCode, cityLabel: $cityLabel)';
}


}

/// @nodoc
abstract mixin class _$SacredLocationCopyWith<$Res> implements $SacredLocationCopyWith<$Res> {
  factory _$SacredLocationCopyWith(_SacredLocation value, $Res Function(_SacredLocation) _then) = __$SacredLocationCopyWithImpl;
@override @useResult
$Res call({
 double latitude, double longitude, SacredLocationSource source, DateTime fixedAt, String? countryCode, String? cityLabel
});




}
/// @nodoc
class __$SacredLocationCopyWithImpl<$Res>
    implements _$SacredLocationCopyWith<$Res> {
  __$SacredLocationCopyWithImpl(this._self, this._then);

  final _SacredLocation _self;
  final $Res Function(_SacredLocation) _then;

/// Create a copy of SacredLocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? latitude = null,Object? longitude = null,Object? source = null,Object? fixedAt = null,Object? countryCode = freezed,Object? cityLabel = freezed,}) {
  return _then(_SacredLocation(
latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as SacredLocationSource,fixedAt: null == fixedAt ? _self.fixedAt : fixedAt // ignore: cast_nullable_to_non_nullable
as DateTime,countryCode: freezed == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String?,cityLabel: freezed == cityLabel ? _self.cityLabel : cityLabel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
