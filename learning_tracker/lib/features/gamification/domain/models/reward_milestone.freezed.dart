// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reward_milestone.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RewardMilestone {

 String get id; int get profileId; int get trackId; String get title;/// Cost in points for the child to redeem this reward (WS7.reward-price).
///
/// Stored under the `threshold_points` JSON key for backward
/// compatibility with existing cloud payloads. In the spend-economy
/// (DEC-32), this is the price the child pays to redeem — not a
/// cumulative auto-unlock threshold.
 int get thresholdPoints; bool get isEnabled; DateTime get createdAt; DateTime get updatedAt;/// Parent-selected reward icon; index into [RewardMilestoneIcons.choices].
/// Synced in `reward_settings`.
 int get iconIndex;
/// Create a copy of RewardMilestone
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RewardMilestoneCopyWith<RewardMilestone> get copyWith => _$RewardMilestoneCopyWithImpl<RewardMilestone>(this as RewardMilestone, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RewardMilestone&&(identical(other.id, id) || other.id == id)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.title, title) || other.title == title)&&(identical(other.thresholdPoints, thresholdPoints) || other.thresholdPoints == thresholdPoints)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.iconIndex, iconIndex) || other.iconIndex == iconIndex));
}


@override
int get hashCode => Object.hash(runtimeType,id,profileId,trackId,title,thresholdPoints,isEnabled,createdAt,updatedAt,iconIndex);

@override
String toString() {
  return 'RewardMilestone(id: $id, profileId: $profileId, trackId: $trackId, title: $title, thresholdPoints: $thresholdPoints, isEnabled: $isEnabled, createdAt: $createdAt, updatedAt: $updatedAt, iconIndex: $iconIndex)';
}


}

/// @nodoc
abstract mixin class $RewardMilestoneCopyWith<$Res>  {
  factory $RewardMilestoneCopyWith(RewardMilestone value, $Res Function(RewardMilestone) _then) = _$RewardMilestoneCopyWithImpl;
@useResult
$Res call({
 String id, int profileId, int trackId, String title, int thresholdPoints, bool isEnabled, DateTime createdAt, DateTime updatedAt, int iconIndex
});




}
/// @nodoc
class _$RewardMilestoneCopyWithImpl<$Res>
    implements $RewardMilestoneCopyWith<$Res> {
  _$RewardMilestoneCopyWithImpl(this._self, this._then);

  final RewardMilestone _self;
  final $Res Function(RewardMilestone) _then;

/// Create a copy of RewardMilestone
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? profileId = null,Object? trackId = null,Object? title = null,Object? thresholdPoints = null,Object? isEnabled = null,Object? createdAt = null,Object? updatedAt = null,Object? iconIndex = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,thresholdPoints: null == thresholdPoints ? _self.thresholdPoints : thresholdPoints // ignore: cast_nullable_to_non_nullable
as int,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,iconIndex: null == iconIndex ? _self.iconIndex : iconIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RewardMilestone].
extension RewardMilestonePatterns on RewardMilestone {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RewardMilestone value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RewardMilestone() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RewardMilestone value)  $default,){
final _that = this;
switch (_that) {
case _RewardMilestone():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RewardMilestone value)?  $default,){
final _that = this;
switch (_that) {
case _RewardMilestone() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int profileId,  int trackId,  String title,  int thresholdPoints,  bool isEnabled,  DateTime createdAt,  DateTime updatedAt,  int iconIndex)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RewardMilestone() when $default != null:
return $default(_that.id,_that.profileId,_that.trackId,_that.title,_that.thresholdPoints,_that.isEnabled,_that.createdAt,_that.updatedAt,_that.iconIndex);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int profileId,  int trackId,  String title,  int thresholdPoints,  bool isEnabled,  DateTime createdAt,  DateTime updatedAt,  int iconIndex)  $default,) {final _that = this;
switch (_that) {
case _RewardMilestone():
return $default(_that.id,_that.profileId,_that.trackId,_that.title,_that.thresholdPoints,_that.isEnabled,_that.createdAt,_that.updatedAt,_that.iconIndex);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int profileId,  int trackId,  String title,  int thresholdPoints,  bool isEnabled,  DateTime createdAt,  DateTime updatedAt,  int iconIndex)?  $default,) {final _that = this;
switch (_that) {
case _RewardMilestone() when $default != null:
return $default(_that.id,_that.profileId,_that.trackId,_that.title,_that.thresholdPoints,_that.isEnabled,_that.createdAt,_that.updatedAt,_that.iconIndex);case _:
  return null;

}
}

}

/// @nodoc


class _RewardMilestone extends RewardMilestone {
  const _RewardMilestone({required this.id, required this.profileId, required this.trackId, required this.title, required this.thresholdPoints, required this.isEnabled, required this.createdAt, required this.updatedAt, this.iconIndex = 0}): super._();
  

@override final  String id;
@override final  int profileId;
@override final  int trackId;
@override final  String title;
/// Cost in points for the child to redeem this reward (WS7.reward-price).
///
/// Stored under the `threshold_points` JSON key for backward
/// compatibility with existing cloud payloads. In the spend-economy
/// (DEC-32), this is the price the child pays to redeem — not a
/// cumulative auto-unlock threshold.
@override final  int thresholdPoints;
@override final  bool isEnabled;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
/// Parent-selected reward icon; index into [RewardMilestoneIcons.choices].
/// Synced in `reward_settings`.
@override@JsonKey() final  int iconIndex;

/// Create a copy of RewardMilestone
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RewardMilestoneCopyWith<_RewardMilestone> get copyWith => __$RewardMilestoneCopyWithImpl<_RewardMilestone>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RewardMilestone&&(identical(other.id, id) || other.id == id)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.title, title) || other.title == title)&&(identical(other.thresholdPoints, thresholdPoints) || other.thresholdPoints == thresholdPoints)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.iconIndex, iconIndex) || other.iconIndex == iconIndex));
}


@override
int get hashCode => Object.hash(runtimeType,id,profileId,trackId,title,thresholdPoints,isEnabled,createdAt,updatedAt,iconIndex);

@override
String toString() {
  return 'RewardMilestone(id: $id, profileId: $profileId, trackId: $trackId, title: $title, thresholdPoints: $thresholdPoints, isEnabled: $isEnabled, createdAt: $createdAt, updatedAt: $updatedAt, iconIndex: $iconIndex)';
}


}

/// @nodoc
abstract mixin class _$RewardMilestoneCopyWith<$Res> implements $RewardMilestoneCopyWith<$Res> {
  factory _$RewardMilestoneCopyWith(_RewardMilestone value, $Res Function(_RewardMilestone) _then) = __$RewardMilestoneCopyWithImpl;
@override @useResult
$Res call({
 String id, int profileId, int trackId, String title, int thresholdPoints, bool isEnabled, DateTime createdAt, DateTime updatedAt, int iconIndex
});




}
/// @nodoc
class __$RewardMilestoneCopyWithImpl<$Res>
    implements _$RewardMilestoneCopyWith<$Res> {
  __$RewardMilestoneCopyWithImpl(this._self, this._then);

  final _RewardMilestone _self;
  final $Res Function(_RewardMilestone) _then;

/// Create a copy of RewardMilestone
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? profileId = null,Object? trackId = null,Object? title = null,Object? thresholdPoints = null,Object? isEnabled = null,Object? createdAt = null,Object? updatedAt = null,Object? iconIndex = null,}) {
  return _then(_RewardMilestone(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,thresholdPoints: null == thresholdPoints ? _self.thresholdPoints : thresholdPoints // ignore: cast_nullable_to_non_nullable
as int,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,iconIndex: null == iconIndex ? _self.iconIndex : iconIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$RewardUnlockRecord {

 String get milestoneId; int get profileId; int get trackId; String get title; int get thresholdPoints; int get pointsAtUnlock; DateTime get unlockedAt;
/// Create a copy of RewardUnlockRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RewardUnlockRecordCopyWith<RewardUnlockRecord> get copyWith => _$RewardUnlockRecordCopyWithImpl<RewardUnlockRecord>(this as RewardUnlockRecord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RewardUnlockRecord&&(identical(other.milestoneId, milestoneId) || other.milestoneId == milestoneId)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.title, title) || other.title == title)&&(identical(other.thresholdPoints, thresholdPoints) || other.thresholdPoints == thresholdPoints)&&(identical(other.pointsAtUnlock, pointsAtUnlock) || other.pointsAtUnlock == pointsAtUnlock)&&(identical(other.unlockedAt, unlockedAt) || other.unlockedAt == unlockedAt));
}


@override
int get hashCode => Object.hash(runtimeType,milestoneId,profileId,trackId,title,thresholdPoints,pointsAtUnlock,unlockedAt);

@override
String toString() {
  return 'RewardUnlockRecord(milestoneId: $milestoneId, profileId: $profileId, trackId: $trackId, title: $title, thresholdPoints: $thresholdPoints, pointsAtUnlock: $pointsAtUnlock, unlockedAt: $unlockedAt)';
}


}

/// @nodoc
abstract mixin class $RewardUnlockRecordCopyWith<$Res>  {
  factory $RewardUnlockRecordCopyWith(RewardUnlockRecord value, $Res Function(RewardUnlockRecord) _then) = _$RewardUnlockRecordCopyWithImpl;
@useResult
$Res call({
 String milestoneId, int profileId, int trackId, String title, int thresholdPoints, int pointsAtUnlock, DateTime unlockedAt
});




}
/// @nodoc
class _$RewardUnlockRecordCopyWithImpl<$Res>
    implements $RewardUnlockRecordCopyWith<$Res> {
  _$RewardUnlockRecordCopyWithImpl(this._self, this._then);

  final RewardUnlockRecord _self;
  final $Res Function(RewardUnlockRecord) _then;

/// Create a copy of RewardUnlockRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? milestoneId = null,Object? profileId = null,Object? trackId = null,Object? title = null,Object? thresholdPoints = null,Object? pointsAtUnlock = null,Object? unlockedAt = null,}) {
  return _then(_self.copyWith(
milestoneId: null == milestoneId ? _self.milestoneId : milestoneId // ignore: cast_nullable_to_non_nullable
as String,profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,thresholdPoints: null == thresholdPoints ? _self.thresholdPoints : thresholdPoints // ignore: cast_nullable_to_non_nullable
as int,pointsAtUnlock: null == pointsAtUnlock ? _self.pointsAtUnlock : pointsAtUnlock // ignore: cast_nullable_to_non_nullable
as int,unlockedAt: null == unlockedAt ? _self.unlockedAt : unlockedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [RewardUnlockRecord].
extension RewardUnlockRecordPatterns on RewardUnlockRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RewardUnlockRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RewardUnlockRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RewardUnlockRecord value)  $default,){
final _that = this;
switch (_that) {
case _RewardUnlockRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RewardUnlockRecord value)?  $default,){
final _that = this;
switch (_that) {
case _RewardUnlockRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String milestoneId,  int profileId,  int trackId,  String title,  int thresholdPoints,  int pointsAtUnlock,  DateTime unlockedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RewardUnlockRecord() when $default != null:
return $default(_that.milestoneId,_that.profileId,_that.trackId,_that.title,_that.thresholdPoints,_that.pointsAtUnlock,_that.unlockedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String milestoneId,  int profileId,  int trackId,  String title,  int thresholdPoints,  int pointsAtUnlock,  DateTime unlockedAt)  $default,) {final _that = this;
switch (_that) {
case _RewardUnlockRecord():
return $default(_that.milestoneId,_that.profileId,_that.trackId,_that.title,_that.thresholdPoints,_that.pointsAtUnlock,_that.unlockedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String milestoneId,  int profileId,  int trackId,  String title,  int thresholdPoints,  int pointsAtUnlock,  DateTime unlockedAt)?  $default,) {final _that = this;
switch (_that) {
case _RewardUnlockRecord() when $default != null:
return $default(_that.milestoneId,_that.profileId,_that.trackId,_that.title,_that.thresholdPoints,_that.pointsAtUnlock,_that.unlockedAt);case _:
  return null;

}
}

}

/// @nodoc


class _RewardUnlockRecord extends RewardUnlockRecord {
  const _RewardUnlockRecord({required this.milestoneId, required this.profileId, required this.trackId, required this.title, required this.thresholdPoints, required this.pointsAtUnlock, required this.unlockedAt}): super._();
  

@override final  String milestoneId;
@override final  int profileId;
@override final  int trackId;
@override final  String title;
@override final  int thresholdPoints;
@override final  int pointsAtUnlock;
@override final  DateTime unlockedAt;

/// Create a copy of RewardUnlockRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RewardUnlockRecordCopyWith<_RewardUnlockRecord> get copyWith => __$RewardUnlockRecordCopyWithImpl<_RewardUnlockRecord>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RewardUnlockRecord&&(identical(other.milestoneId, milestoneId) || other.milestoneId == milestoneId)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.title, title) || other.title == title)&&(identical(other.thresholdPoints, thresholdPoints) || other.thresholdPoints == thresholdPoints)&&(identical(other.pointsAtUnlock, pointsAtUnlock) || other.pointsAtUnlock == pointsAtUnlock)&&(identical(other.unlockedAt, unlockedAt) || other.unlockedAt == unlockedAt));
}


@override
int get hashCode => Object.hash(runtimeType,milestoneId,profileId,trackId,title,thresholdPoints,pointsAtUnlock,unlockedAt);

@override
String toString() {
  return 'RewardUnlockRecord(milestoneId: $milestoneId, profileId: $profileId, trackId: $trackId, title: $title, thresholdPoints: $thresholdPoints, pointsAtUnlock: $pointsAtUnlock, unlockedAt: $unlockedAt)';
}


}

/// @nodoc
abstract mixin class _$RewardUnlockRecordCopyWith<$Res> implements $RewardUnlockRecordCopyWith<$Res> {
  factory _$RewardUnlockRecordCopyWith(_RewardUnlockRecord value, $Res Function(_RewardUnlockRecord) _then) = __$RewardUnlockRecordCopyWithImpl;
@override @useResult
$Res call({
 String milestoneId, int profileId, int trackId, String title, int thresholdPoints, int pointsAtUnlock, DateTime unlockedAt
});




}
/// @nodoc
class __$RewardUnlockRecordCopyWithImpl<$Res>
    implements _$RewardUnlockRecordCopyWith<$Res> {
  __$RewardUnlockRecordCopyWithImpl(this._self, this._then);

  final _RewardUnlockRecord _self;
  final $Res Function(_RewardUnlockRecord) _then;

/// Create a copy of RewardUnlockRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? milestoneId = null,Object? profileId = null,Object? trackId = null,Object? title = null,Object? thresholdPoints = null,Object? pointsAtUnlock = null,Object? unlockedAt = null,}) {
  return _then(_RewardUnlockRecord(
milestoneId: null == milestoneId ? _self.milestoneId : milestoneId // ignore: cast_nullable_to_non_nullable
as String,profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,thresholdPoints: null == thresholdPoints ? _self.thresholdPoints : thresholdPoints // ignore: cast_nullable_to_non_nullable
as int,pointsAtUnlock: null == pointsAtUnlock ? _self.pointsAtUnlock : pointsAtUnlock // ignore: cast_nullable_to_non_nullable
as int,unlockedAt: null == unlockedAt ? _self.unlockedAt : unlockedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
