// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lifetime_knowledge.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LifetimeLeafProvenance {

/// Where the leaf's lifetime credit comes from.
 LifetimeLeafSource get source;/// Number of completion events recorded for this leaf — `limudim +
/// chazaros`, i.e. every distinct stage event ever logged.
///
/// For [LifetimeLeafSource.lifetimeImported] entries that originated from
/// the ledger rather than the completion_events table this is `0` (no
/// event rows exist for ledger-only marks). For
/// [LifetimeLeafSource.bulkMarked] it counts the bulk-import event rows
/// (typically 1). For [LifetimeLeafSource.live] it counts all completion
/// events including the upgrades from prior bulk imports.
 int get chazarosCount;
/// Create a copy of LifetimeLeafProvenance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LifetimeLeafProvenanceCopyWith<LifetimeLeafProvenance> get copyWith => _$LifetimeLeafProvenanceCopyWithImpl<LifetimeLeafProvenance>(this as LifetimeLeafProvenance, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LifetimeLeafProvenance&&(identical(other.source, source) || other.source == source)&&(identical(other.chazarosCount, chazarosCount) || other.chazarosCount == chazarosCount));
}


@override
int get hashCode => Object.hash(runtimeType,source,chazarosCount);



}

/// @nodoc
abstract mixin class $LifetimeLeafProvenanceCopyWith<$Res>  {
  factory $LifetimeLeafProvenanceCopyWith(LifetimeLeafProvenance value, $Res Function(LifetimeLeafProvenance) _then) = _$LifetimeLeafProvenanceCopyWithImpl;
@useResult
$Res call({
 LifetimeLeafSource source, int chazarosCount
});




}
/// @nodoc
class _$LifetimeLeafProvenanceCopyWithImpl<$Res>
    implements $LifetimeLeafProvenanceCopyWith<$Res> {
  _$LifetimeLeafProvenanceCopyWithImpl(this._self, this._then);

  final LifetimeLeafProvenance _self;
  final $Res Function(LifetimeLeafProvenance) _then;

/// Create a copy of LifetimeLeafProvenance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? source = null,Object? chazarosCount = null,}) {
  return _then(_self.copyWith(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as LifetimeLeafSource,chazarosCount: null == chazarosCount ? _self.chazarosCount : chazarosCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LifetimeLeafProvenance].
extension LifetimeLeafProvenancePatterns on LifetimeLeafProvenance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LifetimeLeafProvenance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LifetimeLeafProvenance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LifetimeLeafProvenance value)  $default,){
final _that = this;
switch (_that) {
case _LifetimeLeafProvenance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LifetimeLeafProvenance value)?  $default,){
final _that = this;
switch (_that) {
case _LifetimeLeafProvenance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LifetimeLeafSource source,  int chazarosCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LifetimeLeafProvenance() when $default != null:
return $default(_that.source,_that.chazarosCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LifetimeLeafSource source,  int chazarosCount)  $default,) {final _that = this;
switch (_that) {
case _LifetimeLeafProvenance():
return $default(_that.source,_that.chazarosCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LifetimeLeafSource source,  int chazarosCount)?  $default,) {final _that = this;
switch (_that) {
case _LifetimeLeafProvenance() when $default != null:
return $default(_that.source,_that.chazarosCount);case _:
  return null;

}
}

}

/// @nodoc


class _LifetimeLeafProvenance extends LifetimeLeafProvenance {
  const _LifetimeLeafProvenance({required this.source, required this.chazarosCount}): super._();
  

/// Where the leaf's lifetime credit comes from.
@override final  LifetimeLeafSource source;
/// Number of completion events recorded for this leaf — `limudim +
/// chazaros`, i.e. every distinct stage event ever logged.
///
/// For [LifetimeLeafSource.lifetimeImported] entries that originated from
/// the ledger rather than the completion_events table this is `0` (no
/// event rows exist for ledger-only marks). For
/// [LifetimeLeafSource.bulkMarked] it counts the bulk-import event rows
/// (typically 1). For [LifetimeLeafSource.live] it counts all completion
/// events including the upgrades from prior bulk imports.
@override final  int chazarosCount;

/// Create a copy of LifetimeLeafProvenance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LifetimeLeafProvenanceCopyWith<_LifetimeLeafProvenance> get copyWith => __$LifetimeLeafProvenanceCopyWithImpl<_LifetimeLeafProvenance>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LifetimeLeafProvenance&&(identical(other.source, source) || other.source == source)&&(identical(other.chazarosCount, chazarosCount) || other.chazarosCount == chazarosCount));
}


@override
int get hashCode => Object.hash(runtimeType,source,chazarosCount);



}

/// @nodoc
abstract mixin class _$LifetimeLeafProvenanceCopyWith<$Res> implements $LifetimeLeafProvenanceCopyWith<$Res> {
  factory _$LifetimeLeafProvenanceCopyWith(_LifetimeLeafProvenance value, $Res Function(_LifetimeLeafProvenance) _then) = __$LifetimeLeafProvenanceCopyWithImpl;
@override @useResult
$Res call({
 LifetimeLeafSource source, int chazarosCount
});




}
/// @nodoc
class __$LifetimeLeafProvenanceCopyWithImpl<$Res>
    implements _$LifetimeLeafProvenanceCopyWith<$Res> {
  __$LifetimeLeafProvenanceCopyWithImpl(this._self, this._then);

  final _LifetimeLeafProvenance _self;
  final $Res Function(_LifetimeLeafProvenance) _then;

/// Create a copy of LifetimeLeafProvenance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? source = null,Object? chazarosCount = null,}) {
  return _then(_LifetimeLeafProvenance(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as LifetimeLeafSource,chazarosCount: null == chazarosCount ? _self.chazarosCount : chazarosCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
