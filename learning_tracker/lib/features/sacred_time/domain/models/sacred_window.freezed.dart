// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sacred_window.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SacredWindow {

 DateTime get startUtc; DateTime get endUtc; SacredWindowKind get kind;
/// Create a copy of SacredWindow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SacredWindowCopyWith<SacredWindow> get copyWith => _$SacredWindowCopyWithImpl<SacredWindow>(this as SacredWindow, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SacredWindow&&(identical(other.startUtc, startUtc) || other.startUtc == startUtc)&&(identical(other.endUtc, endUtc) || other.endUtc == endUtc)&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode => Object.hash(runtimeType,startUtc,endUtc,kind);

@override
String toString() {
  return 'SacredWindow(startUtc: $startUtc, endUtc: $endUtc, kind: $kind)';
}


}

/// @nodoc
abstract mixin class $SacredWindowCopyWith<$Res>  {
  factory $SacredWindowCopyWith(SacredWindow value, $Res Function(SacredWindow) _then) = _$SacredWindowCopyWithImpl;
@useResult
$Res call({
 DateTime startUtc, DateTime endUtc, SacredWindowKind kind
});




}
/// @nodoc
class _$SacredWindowCopyWithImpl<$Res>
    implements $SacredWindowCopyWith<$Res> {
  _$SacredWindowCopyWithImpl(this._self, this._then);

  final SacredWindow _self;
  final $Res Function(SacredWindow) _then;

/// Create a copy of SacredWindow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startUtc = null,Object? endUtc = null,Object? kind = null,}) {
  return _then(_self.copyWith(
startUtc: null == startUtc ? _self.startUtc : startUtc // ignore: cast_nullable_to_non_nullable
as DateTime,endUtc: null == endUtc ? _self.endUtc : endUtc // ignore: cast_nullable_to_non_nullable
as DateTime,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as SacredWindowKind,
  ));
}

}


/// Adds pattern-matching-related methods to [SacredWindow].
extension SacredWindowPatterns on SacredWindow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SacredWindow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SacredWindow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SacredWindow value)  $default,){
final _that = this;
switch (_that) {
case _SacredWindow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SacredWindow value)?  $default,){
final _that = this;
switch (_that) {
case _SacredWindow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime startUtc,  DateTime endUtc,  SacredWindowKind kind)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SacredWindow() when $default != null:
return $default(_that.startUtc,_that.endUtc,_that.kind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime startUtc,  DateTime endUtc,  SacredWindowKind kind)  $default,) {final _that = this;
switch (_that) {
case _SacredWindow():
return $default(_that.startUtc,_that.endUtc,_that.kind);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime startUtc,  DateTime endUtc,  SacredWindowKind kind)?  $default,) {final _that = this;
switch (_that) {
case _SacredWindow() when $default != null:
return $default(_that.startUtc,_that.endUtc,_that.kind);case _:
  return null;

}
}

}

/// @nodoc


class _SacredWindow implements SacredWindow {
  const _SacredWindow({required this.startUtc, required this.endUtc, required this.kind});
  

@override final  DateTime startUtc;
@override final  DateTime endUtc;
@override final  SacredWindowKind kind;

/// Create a copy of SacredWindow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SacredWindowCopyWith<_SacredWindow> get copyWith => __$SacredWindowCopyWithImpl<_SacredWindow>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SacredWindow&&(identical(other.startUtc, startUtc) || other.startUtc == startUtc)&&(identical(other.endUtc, endUtc) || other.endUtc == endUtc)&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode => Object.hash(runtimeType,startUtc,endUtc,kind);

@override
String toString() {
  return 'SacredWindow(startUtc: $startUtc, endUtc: $endUtc, kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$SacredWindowCopyWith<$Res> implements $SacredWindowCopyWith<$Res> {
  factory _$SacredWindowCopyWith(_SacredWindow value, $Res Function(_SacredWindow) _then) = __$SacredWindowCopyWithImpl;
@override @useResult
$Res call({
 DateTime startUtc, DateTime endUtc, SacredWindowKind kind
});




}
/// @nodoc
class __$SacredWindowCopyWithImpl<$Res>
    implements _$SacredWindowCopyWith<$Res> {
  __$SacredWindowCopyWithImpl(this._self, this._then);

  final _SacredWindow _self;
  final $Res Function(_SacredWindow) _then;

/// Create a copy of SacredWindow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startUtc = null,Object? endUtc = null,Object? kind = null,}) {
  return _then(_SacredWindow(
startUtc: null == startUtc ? _self.startUtc : startUtc // ignore: cast_nullable_to_non_nullable
as DateTime,endUtc: null == endUtc ? _self.endUtc : endUtc // ignore: cast_nullable_to_non_nullable
as DateTime,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as SacredWindowKind,
  ));
}


}

// dart format on
