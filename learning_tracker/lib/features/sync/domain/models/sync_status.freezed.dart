// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SyncStatus {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SyncStatus()';
}


}

/// @nodoc
class $SyncStatusCopyWith<$Res>  {
$SyncStatusCopyWith(SyncStatus _, $Res Function(SyncStatus) __);
}


/// Adds pattern-matching-related methods to [SyncStatus].
extension SyncStatusPatterns on SyncStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Syncing value)?  syncing,TResult Function( _Synced value)?  synced,TResult Function( _Offline value)?  offline,TResult Function( _Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Syncing() when syncing != null:
return syncing(_that);case _Synced() when synced != null:
return synced(_that);case _Offline() when offline != null:
return offline(_that);case _Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Syncing value)  syncing,required TResult Function( _Synced value)  synced,required TResult Function( _Offline value)  offline,required TResult Function( _Error value)  error,}){
final _that = this;
switch (_that) {
case _Syncing():
return syncing(_that);case _Synced():
return synced(_that);case _Offline():
return offline(_that);case _Error():
return error(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Syncing value)?  syncing,TResult? Function( _Synced value)?  synced,TResult? Function( _Offline value)?  offline,TResult? Function( _Error value)?  error,}){
final _that = this;
switch (_that) {
case _Syncing() when syncing != null:
return syncing(_that);case _Synced() when synced != null:
return synced(_that);case _Offline() when offline != null:
return offline(_that);case _Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( DateTime startedAt)?  syncing,TResult Function( DateTime lastSyncedAt)?  synced,TResult Function( int pendingChanges)?  offline,TResult Function( String message,  DateTime failedAt)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Syncing() when syncing != null:
return syncing(_that.startedAt);case _Synced() when synced != null:
return synced(_that.lastSyncedAt);case _Offline() when offline != null:
return offline(_that.pendingChanges);case _Error() when error != null:
return error(_that.message,_that.failedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( DateTime startedAt)  syncing,required TResult Function( DateTime lastSyncedAt)  synced,required TResult Function( int pendingChanges)  offline,required TResult Function( String message,  DateTime failedAt)  error,}) {final _that = this;
switch (_that) {
case _Syncing():
return syncing(_that.startedAt);case _Synced():
return synced(_that.lastSyncedAt);case _Offline():
return offline(_that.pendingChanges);case _Error():
return error(_that.message,_that.failedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( DateTime startedAt)?  syncing,TResult? Function( DateTime lastSyncedAt)?  synced,TResult? Function( int pendingChanges)?  offline,TResult? Function( String message,  DateTime failedAt)?  error,}) {final _that = this;
switch (_that) {
case _Syncing() when syncing != null:
return syncing(_that.startedAt);case _Synced() when synced != null:
return synced(_that.lastSyncedAt);case _Offline() when offline != null:
return offline(_that.pendingChanges);case _Error() when error != null:
return error(_that.message,_that.failedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Syncing implements SyncStatus {
  const _Syncing({required this.startedAt});
  

 final  DateTime startedAt;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncingCopyWith<_Syncing> get copyWith => __$SyncingCopyWithImpl<_Syncing>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Syncing&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt));
}


@override
int get hashCode => Object.hash(runtimeType,startedAt);

@override
String toString() {
  return 'SyncStatus.syncing(startedAt: $startedAt)';
}


}

/// @nodoc
abstract mixin class _$SyncingCopyWith<$Res> implements $SyncStatusCopyWith<$Res> {
  factory _$SyncingCopyWith(_Syncing value, $Res Function(_Syncing) _then) = __$SyncingCopyWithImpl;
@useResult
$Res call({
 DateTime startedAt
});




}
/// @nodoc
class __$SyncingCopyWithImpl<$Res>
    implements _$SyncingCopyWith<$Res> {
  __$SyncingCopyWithImpl(this._self, this._then);

  final _Syncing _self;
  final $Res Function(_Syncing) _then;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? startedAt = null,}) {
  return _then(_Syncing(
startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc


class _Synced implements SyncStatus {
  const _Synced({required this.lastSyncedAt});
  

 final  DateTime lastSyncedAt;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncedCopyWith<_Synced> get copyWith => __$SyncedCopyWithImpl<_Synced>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Synced&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt));
}


@override
int get hashCode => Object.hash(runtimeType,lastSyncedAt);

@override
String toString() {
  return 'SyncStatus.synced(lastSyncedAt: $lastSyncedAt)';
}


}

/// @nodoc
abstract mixin class _$SyncedCopyWith<$Res> implements $SyncStatusCopyWith<$Res> {
  factory _$SyncedCopyWith(_Synced value, $Res Function(_Synced) _then) = __$SyncedCopyWithImpl;
@useResult
$Res call({
 DateTime lastSyncedAt
});




}
/// @nodoc
class __$SyncedCopyWithImpl<$Res>
    implements _$SyncedCopyWith<$Res> {
  __$SyncedCopyWithImpl(this._self, this._then);

  final _Synced _self;
  final $Res Function(_Synced) _then;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? lastSyncedAt = null,}) {
  return _then(_Synced(
lastSyncedAt: null == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc


class _Offline implements SyncStatus {
  const _Offline({required this.pendingChanges});
  

 final  int pendingChanges;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OfflineCopyWith<_Offline> get copyWith => __$OfflineCopyWithImpl<_Offline>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Offline&&(identical(other.pendingChanges, pendingChanges) || other.pendingChanges == pendingChanges));
}


@override
int get hashCode => Object.hash(runtimeType,pendingChanges);

@override
String toString() {
  return 'SyncStatus.offline(pendingChanges: $pendingChanges)';
}


}

/// @nodoc
abstract mixin class _$OfflineCopyWith<$Res> implements $SyncStatusCopyWith<$Res> {
  factory _$OfflineCopyWith(_Offline value, $Res Function(_Offline) _then) = __$OfflineCopyWithImpl;
@useResult
$Res call({
 int pendingChanges
});




}
/// @nodoc
class __$OfflineCopyWithImpl<$Res>
    implements _$OfflineCopyWith<$Res> {
  __$OfflineCopyWithImpl(this._self, this._then);

  final _Offline _self;
  final $Res Function(_Offline) _then;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pendingChanges = null,}) {
  return _then(_Offline(
pendingChanges: null == pendingChanges ? _self.pendingChanges : pendingChanges // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _Error implements SyncStatus {
  const _Error({required this.message, required this.failedAt});
  

 final  String message;
 final  DateTime failedAt;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ErrorCopyWith<_Error> get copyWith => __$ErrorCopyWithImpl<_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Error&&(identical(other.message, message) || other.message == message)&&(identical(other.failedAt, failedAt) || other.failedAt == failedAt));
}


@override
int get hashCode => Object.hash(runtimeType,message,failedAt);

@override
String toString() {
  return 'SyncStatus.error(message: $message, failedAt: $failedAt)';
}


}

/// @nodoc
abstract mixin class _$ErrorCopyWith<$Res> implements $SyncStatusCopyWith<$Res> {
  factory _$ErrorCopyWith(_Error value, $Res Function(_Error) _then) = __$ErrorCopyWithImpl;
@useResult
$Res call({
 String message, DateTime failedAt
});




}
/// @nodoc
class __$ErrorCopyWithImpl<$Res>
    implements _$ErrorCopyWith<$Res> {
  __$ErrorCopyWithImpl(this._self, this._then);

  final _Error _self;
  final $Res Function(_Error) _then;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,Object? failedAt = null,}) {
  return _then(_Error(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,failedAt: null == failedAt ? _self.failedAt : failedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
