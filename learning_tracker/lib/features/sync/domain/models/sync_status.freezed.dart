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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SyncStatusLocalOnly value)?  localOnly,TResult Function( SyncStatusSyncing value)?  syncing,TResult Function( SyncStatusSynced value)?  synced,TResult Function( SyncStatusPending value)?  pending,TResult Function( SyncStatusOffline value)?  offline,TResult Function( SyncStatusError value)?  error,TResult Function( SyncStatusDegraded value)?  degraded,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SyncStatusLocalOnly() when localOnly != null:
return localOnly(_that);case SyncStatusSyncing() when syncing != null:
return syncing(_that);case SyncStatusSynced() when synced != null:
return synced(_that);case SyncStatusPending() when pending != null:
return pending(_that);case SyncStatusOffline() when offline != null:
return offline(_that);case SyncStatusError() when error != null:
return error(_that);case SyncStatusDegraded() when degraded != null:
return degraded(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SyncStatusLocalOnly value)  localOnly,required TResult Function( SyncStatusSyncing value)  syncing,required TResult Function( SyncStatusSynced value)  synced,required TResult Function( SyncStatusPending value)  pending,required TResult Function( SyncStatusOffline value)  offline,required TResult Function( SyncStatusError value)  error,required TResult Function( SyncStatusDegraded value)  degraded,}){
final _that = this;
switch (_that) {
case SyncStatusLocalOnly():
return localOnly(_that);case SyncStatusSyncing():
return syncing(_that);case SyncStatusSynced():
return synced(_that);case SyncStatusPending():
return pending(_that);case SyncStatusOffline():
return offline(_that);case SyncStatusError():
return error(_that);case SyncStatusDegraded():
return degraded(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SyncStatusLocalOnly value)?  localOnly,TResult? Function( SyncStatusSyncing value)?  syncing,TResult? Function( SyncStatusSynced value)?  synced,TResult? Function( SyncStatusPending value)?  pending,TResult? Function( SyncStatusOffline value)?  offline,TResult? Function( SyncStatusError value)?  error,TResult? Function( SyncStatusDegraded value)?  degraded,}){
final _that = this;
switch (_that) {
case SyncStatusLocalOnly() when localOnly != null:
return localOnly(_that);case SyncStatusSyncing() when syncing != null:
return syncing(_that);case SyncStatusSynced() when synced != null:
return synced(_that);case SyncStatusPending() when pending != null:
return pending(_that);case SyncStatusOffline() when offline != null:
return offline(_that);case SyncStatusError() when error != null:
return error(_that);case SyncStatusDegraded() when degraded != null:
return degraded(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  localOnly,TResult Function( DateTime startedAt)?  syncing,TResult Function( DateTime lastSyncedAt)?  synced,TResult Function( int pendingChanges)?  pending,TResult Function( int pendingChanges)?  offline,TResult Function( SyncErrorCode code,  DateTime failedAt,  String? debugDetail)?  error,TResult Function( int pendingChanges,  String reason)?  degraded,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SyncStatusLocalOnly() when localOnly != null:
return localOnly();case SyncStatusSyncing() when syncing != null:
return syncing(_that.startedAt);case SyncStatusSynced() when synced != null:
return synced(_that.lastSyncedAt);case SyncStatusPending() when pending != null:
return pending(_that.pendingChanges);case SyncStatusOffline() when offline != null:
return offline(_that.pendingChanges);case SyncStatusError() when error != null:
return error(_that.code,_that.failedAt,_that.debugDetail);case SyncStatusDegraded() when degraded != null:
return degraded(_that.pendingChanges,_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  localOnly,required TResult Function( DateTime startedAt)  syncing,required TResult Function( DateTime lastSyncedAt)  synced,required TResult Function( int pendingChanges)  pending,required TResult Function( int pendingChanges)  offline,required TResult Function( SyncErrorCode code,  DateTime failedAt,  String? debugDetail)  error,required TResult Function( int pendingChanges,  String reason)  degraded,}) {final _that = this;
switch (_that) {
case SyncStatusLocalOnly():
return localOnly();case SyncStatusSyncing():
return syncing(_that.startedAt);case SyncStatusSynced():
return synced(_that.lastSyncedAt);case SyncStatusPending():
return pending(_that.pendingChanges);case SyncStatusOffline():
return offline(_that.pendingChanges);case SyncStatusError():
return error(_that.code,_that.failedAt,_that.debugDetail);case SyncStatusDegraded():
return degraded(_that.pendingChanges,_that.reason);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  localOnly,TResult? Function( DateTime startedAt)?  syncing,TResult? Function( DateTime lastSyncedAt)?  synced,TResult? Function( int pendingChanges)?  pending,TResult? Function( int pendingChanges)?  offline,TResult? Function( SyncErrorCode code,  DateTime failedAt,  String? debugDetail)?  error,TResult? Function( int pendingChanges,  String reason)?  degraded,}) {final _that = this;
switch (_that) {
case SyncStatusLocalOnly() when localOnly != null:
return localOnly();case SyncStatusSyncing() when syncing != null:
return syncing(_that.startedAt);case SyncStatusSynced() when synced != null:
return synced(_that.lastSyncedAt);case SyncStatusPending() when pending != null:
return pending(_that.pendingChanges);case SyncStatusOffline() when offline != null:
return offline(_that.pendingChanges);case SyncStatusError() when error != null:
return error(_that.code,_that.failedAt,_that.debugDetail);case SyncStatusDegraded() when degraded != null:
return degraded(_that.pendingChanges,_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class SyncStatusLocalOnly implements SyncStatus {
  const SyncStatusLocalOnly();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncStatusLocalOnly);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SyncStatus.localOnly()';
}


}




/// @nodoc


class SyncStatusSyncing implements SyncStatus {
  const SyncStatusSyncing({required this.startedAt});
  

 final  DateTime startedAt;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncStatusSyncingCopyWith<SyncStatusSyncing> get copyWith => _$SyncStatusSyncingCopyWithImpl<SyncStatusSyncing>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncStatusSyncing&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt));
}


@override
int get hashCode => Object.hash(runtimeType,startedAt);

@override
String toString() {
  return 'SyncStatus.syncing(startedAt: $startedAt)';
}


}

/// @nodoc
abstract mixin class $SyncStatusSyncingCopyWith<$Res> implements $SyncStatusCopyWith<$Res> {
  factory $SyncStatusSyncingCopyWith(SyncStatusSyncing value, $Res Function(SyncStatusSyncing) _then) = _$SyncStatusSyncingCopyWithImpl;
@useResult
$Res call({
 DateTime startedAt
});




}
/// @nodoc
class _$SyncStatusSyncingCopyWithImpl<$Res>
    implements $SyncStatusSyncingCopyWith<$Res> {
  _$SyncStatusSyncingCopyWithImpl(this._self, this._then);

  final SyncStatusSyncing _self;
  final $Res Function(SyncStatusSyncing) _then;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? startedAt = null,}) {
  return _then(SyncStatusSyncing(
startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc


class SyncStatusSynced implements SyncStatus {
  const SyncStatusSynced({required this.lastSyncedAt});
  

 final  DateTime lastSyncedAt;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncStatusSyncedCopyWith<SyncStatusSynced> get copyWith => _$SyncStatusSyncedCopyWithImpl<SyncStatusSynced>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncStatusSynced&&(identical(other.lastSyncedAt, lastSyncedAt) || other.lastSyncedAt == lastSyncedAt));
}


@override
int get hashCode => Object.hash(runtimeType,lastSyncedAt);

@override
String toString() {
  return 'SyncStatus.synced(lastSyncedAt: $lastSyncedAt)';
}


}

/// @nodoc
abstract mixin class $SyncStatusSyncedCopyWith<$Res> implements $SyncStatusCopyWith<$Res> {
  factory $SyncStatusSyncedCopyWith(SyncStatusSynced value, $Res Function(SyncStatusSynced) _then) = _$SyncStatusSyncedCopyWithImpl;
@useResult
$Res call({
 DateTime lastSyncedAt
});




}
/// @nodoc
class _$SyncStatusSyncedCopyWithImpl<$Res>
    implements $SyncStatusSyncedCopyWith<$Res> {
  _$SyncStatusSyncedCopyWithImpl(this._self, this._then);

  final SyncStatusSynced _self;
  final $Res Function(SyncStatusSynced) _then;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? lastSyncedAt = null,}) {
  return _then(SyncStatusSynced(
lastSyncedAt: null == lastSyncedAt ? _self.lastSyncedAt : lastSyncedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc


class SyncStatusPending implements SyncStatus {
  const SyncStatusPending({required this.pendingChanges});
  

 final  int pendingChanges;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncStatusPendingCopyWith<SyncStatusPending> get copyWith => _$SyncStatusPendingCopyWithImpl<SyncStatusPending>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncStatusPending&&(identical(other.pendingChanges, pendingChanges) || other.pendingChanges == pendingChanges));
}


@override
int get hashCode => Object.hash(runtimeType,pendingChanges);

@override
String toString() {
  return 'SyncStatus.pending(pendingChanges: $pendingChanges)';
}


}

/// @nodoc
abstract mixin class $SyncStatusPendingCopyWith<$Res> implements $SyncStatusCopyWith<$Res> {
  factory $SyncStatusPendingCopyWith(SyncStatusPending value, $Res Function(SyncStatusPending) _then) = _$SyncStatusPendingCopyWithImpl;
@useResult
$Res call({
 int pendingChanges
});




}
/// @nodoc
class _$SyncStatusPendingCopyWithImpl<$Res>
    implements $SyncStatusPendingCopyWith<$Res> {
  _$SyncStatusPendingCopyWithImpl(this._self, this._then);

  final SyncStatusPending _self;
  final $Res Function(SyncStatusPending) _then;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pendingChanges = null,}) {
  return _then(SyncStatusPending(
pendingChanges: null == pendingChanges ? _self.pendingChanges : pendingChanges // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class SyncStatusOffline implements SyncStatus {
  const SyncStatusOffline({required this.pendingChanges});
  

 final  int pendingChanges;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncStatusOfflineCopyWith<SyncStatusOffline> get copyWith => _$SyncStatusOfflineCopyWithImpl<SyncStatusOffline>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncStatusOffline&&(identical(other.pendingChanges, pendingChanges) || other.pendingChanges == pendingChanges));
}


@override
int get hashCode => Object.hash(runtimeType,pendingChanges);

@override
String toString() {
  return 'SyncStatus.offline(pendingChanges: $pendingChanges)';
}


}

/// @nodoc
abstract mixin class $SyncStatusOfflineCopyWith<$Res> implements $SyncStatusCopyWith<$Res> {
  factory $SyncStatusOfflineCopyWith(SyncStatusOffline value, $Res Function(SyncStatusOffline) _then) = _$SyncStatusOfflineCopyWithImpl;
@useResult
$Res call({
 int pendingChanges
});




}
/// @nodoc
class _$SyncStatusOfflineCopyWithImpl<$Res>
    implements $SyncStatusOfflineCopyWith<$Res> {
  _$SyncStatusOfflineCopyWithImpl(this._self, this._then);

  final SyncStatusOffline _self;
  final $Res Function(SyncStatusOffline) _then;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pendingChanges = null,}) {
  return _then(SyncStatusOffline(
pendingChanges: null == pendingChanges ? _self.pendingChanges : pendingChanges // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class SyncStatusError implements SyncStatus {
  const SyncStatusError({required this.code, required this.failedAt, this.debugDetail});
  

 final  SyncErrorCode code;
 final  DateTime failedAt;
 final  String? debugDetail;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncStatusErrorCopyWith<SyncStatusError> get copyWith => _$SyncStatusErrorCopyWithImpl<SyncStatusError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncStatusError&&(identical(other.code, code) || other.code == code)&&(identical(other.failedAt, failedAt) || other.failedAt == failedAt)&&(identical(other.debugDetail, debugDetail) || other.debugDetail == debugDetail));
}


@override
int get hashCode => Object.hash(runtimeType,code,failedAt,debugDetail);

@override
String toString() {
  return 'SyncStatus.error(code: $code, failedAt: $failedAt, debugDetail: $debugDetail)';
}


}

/// @nodoc
abstract mixin class $SyncStatusErrorCopyWith<$Res> implements $SyncStatusCopyWith<$Res> {
  factory $SyncStatusErrorCopyWith(SyncStatusError value, $Res Function(SyncStatusError) _then) = _$SyncStatusErrorCopyWithImpl;
@useResult
$Res call({
 SyncErrorCode code, DateTime failedAt, String? debugDetail
});




}
/// @nodoc
class _$SyncStatusErrorCopyWithImpl<$Res>
    implements $SyncStatusErrorCopyWith<$Res> {
  _$SyncStatusErrorCopyWithImpl(this._self, this._then);

  final SyncStatusError _self;
  final $Res Function(SyncStatusError) _then;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? code = null,Object? failedAt = null,Object? debugDetail = freezed,}) {
  return _then(SyncStatusError(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as SyncErrorCode,failedAt: null == failedAt ? _self.failedAt : failedAt // ignore: cast_nullable_to_non_nullable
as DateTime,debugDetail: freezed == debugDetail ? _self.debugDetail : debugDetail // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class SyncStatusDegraded implements SyncStatus {
  const SyncStatusDegraded({required this.pendingChanges, required this.reason});
  

 final  int pendingChanges;
 final  String reason;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncStatusDegradedCopyWith<SyncStatusDegraded> get copyWith => _$SyncStatusDegradedCopyWithImpl<SyncStatusDegraded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncStatusDegraded&&(identical(other.pendingChanges, pendingChanges) || other.pendingChanges == pendingChanges)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,pendingChanges,reason);

@override
String toString() {
  return 'SyncStatus.degraded(pendingChanges: $pendingChanges, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $SyncStatusDegradedCopyWith<$Res> implements $SyncStatusCopyWith<$Res> {
  factory $SyncStatusDegradedCopyWith(SyncStatusDegraded value, $Res Function(SyncStatusDegraded) _then) = _$SyncStatusDegradedCopyWithImpl;
@useResult
$Res call({
 int pendingChanges, String reason
});




}
/// @nodoc
class _$SyncStatusDegradedCopyWithImpl<$Res>
    implements $SyncStatusDegradedCopyWith<$Res> {
  _$SyncStatusDegradedCopyWithImpl(this._self, this._then);

  final SyncStatusDegraded _self;
  final $Res Function(SyncStatusDegraded) _then;

/// Create a copy of SyncStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pendingChanges = null,Object? reason = null,}) {
  return _then(SyncStatusDegraded(
pendingChanges: null == pendingChanges ? _self.pendingChanges : pendingChanges // ignore: cast_nullable_to_non_nullable
as int,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
