// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reminder_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReminderPreferences {

 bool get reminderEnabled; int get reminderHour; int get reminderMinute; bool get streakAlertEnabled; int get streakAlertHour; int get streakAlertMinute; bool get rewardNotificationEnabled;
/// Create a copy of ReminderPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReminderPreferencesCopyWith<ReminderPreferences> get copyWith => _$ReminderPreferencesCopyWithImpl<ReminderPreferences>(this as ReminderPreferences, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReminderPreferences&&(identical(other.reminderEnabled, reminderEnabled) || other.reminderEnabled == reminderEnabled)&&(identical(other.reminderHour, reminderHour) || other.reminderHour == reminderHour)&&(identical(other.reminderMinute, reminderMinute) || other.reminderMinute == reminderMinute)&&(identical(other.streakAlertEnabled, streakAlertEnabled) || other.streakAlertEnabled == streakAlertEnabled)&&(identical(other.streakAlertHour, streakAlertHour) || other.streakAlertHour == streakAlertHour)&&(identical(other.streakAlertMinute, streakAlertMinute) || other.streakAlertMinute == streakAlertMinute)&&(identical(other.rewardNotificationEnabled, rewardNotificationEnabled) || other.rewardNotificationEnabled == rewardNotificationEnabled));
}


@override
int get hashCode => Object.hash(runtimeType,reminderEnabled,reminderHour,reminderMinute,streakAlertEnabled,streakAlertHour,streakAlertMinute,rewardNotificationEnabled);

@override
String toString() {
  return 'ReminderPreferences(reminderEnabled: $reminderEnabled, reminderHour: $reminderHour, reminderMinute: $reminderMinute, streakAlertEnabled: $streakAlertEnabled, streakAlertHour: $streakAlertHour, streakAlertMinute: $streakAlertMinute, rewardNotificationEnabled: $rewardNotificationEnabled)';
}


}

/// @nodoc
abstract mixin class $ReminderPreferencesCopyWith<$Res>  {
  factory $ReminderPreferencesCopyWith(ReminderPreferences value, $Res Function(ReminderPreferences) _then) = _$ReminderPreferencesCopyWithImpl;
@useResult
$Res call({
 bool reminderEnabled, int reminderHour, int reminderMinute, bool streakAlertEnabled, int streakAlertHour, int streakAlertMinute, bool rewardNotificationEnabled
});




}
/// @nodoc
class _$ReminderPreferencesCopyWithImpl<$Res>
    implements $ReminderPreferencesCopyWith<$Res> {
  _$ReminderPreferencesCopyWithImpl(this._self, this._then);

  final ReminderPreferences _self;
  final $Res Function(ReminderPreferences) _then;

/// Create a copy of ReminderPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reminderEnabled = null,Object? reminderHour = null,Object? reminderMinute = null,Object? streakAlertEnabled = null,Object? streakAlertHour = null,Object? streakAlertMinute = null,Object? rewardNotificationEnabled = null,}) {
  return _then(_self.copyWith(
reminderEnabled: null == reminderEnabled ? _self.reminderEnabled : reminderEnabled // ignore: cast_nullable_to_non_nullable
as bool,reminderHour: null == reminderHour ? _self.reminderHour : reminderHour // ignore: cast_nullable_to_non_nullable
as int,reminderMinute: null == reminderMinute ? _self.reminderMinute : reminderMinute // ignore: cast_nullable_to_non_nullable
as int,streakAlertEnabled: null == streakAlertEnabled ? _self.streakAlertEnabled : streakAlertEnabled // ignore: cast_nullable_to_non_nullable
as bool,streakAlertHour: null == streakAlertHour ? _self.streakAlertHour : streakAlertHour // ignore: cast_nullable_to_non_nullable
as int,streakAlertMinute: null == streakAlertMinute ? _self.streakAlertMinute : streakAlertMinute // ignore: cast_nullable_to_non_nullable
as int,rewardNotificationEnabled: null == rewardNotificationEnabled ? _self.rewardNotificationEnabled : rewardNotificationEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ReminderPreferences].
extension ReminderPreferencesPatterns on ReminderPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReminderPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReminderPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReminderPreferences value)  $default,){
final _that = this;
switch (_that) {
case _ReminderPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReminderPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _ReminderPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool reminderEnabled,  int reminderHour,  int reminderMinute,  bool streakAlertEnabled,  int streakAlertHour,  int streakAlertMinute,  bool rewardNotificationEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReminderPreferences() when $default != null:
return $default(_that.reminderEnabled,_that.reminderHour,_that.reminderMinute,_that.streakAlertEnabled,_that.streakAlertHour,_that.streakAlertMinute,_that.rewardNotificationEnabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool reminderEnabled,  int reminderHour,  int reminderMinute,  bool streakAlertEnabled,  int streakAlertHour,  int streakAlertMinute,  bool rewardNotificationEnabled)  $default,) {final _that = this;
switch (_that) {
case _ReminderPreferences():
return $default(_that.reminderEnabled,_that.reminderHour,_that.reminderMinute,_that.streakAlertEnabled,_that.streakAlertHour,_that.streakAlertMinute,_that.rewardNotificationEnabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool reminderEnabled,  int reminderHour,  int reminderMinute,  bool streakAlertEnabled,  int streakAlertHour,  int streakAlertMinute,  bool rewardNotificationEnabled)?  $default,) {final _that = this;
switch (_that) {
case _ReminderPreferences() when $default != null:
return $default(_that.reminderEnabled,_that.reminderHour,_that.reminderMinute,_that.streakAlertEnabled,_that.streakAlertHour,_that.streakAlertMinute,_that.rewardNotificationEnabled);case _:
  return null;

}
}

}

/// @nodoc


class _ReminderPreferences extends ReminderPreferences {
  const _ReminderPreferences({required this.reminderEnabled, required this.reminderHour, required this.reminderMinute, required this.streakAlertEnabled, required this.streakAlertHour, required this.streakAlertMinute, required this.rewardNotificationEnabled}): super._();
  

@override final  bool reminderEnabled;
@override final  int reminderHour;
@override final  int reminderMinute;
@override final  bool streakAlertEnabled;
@override final  int streakAlertHour;
@override final  int streakAlertMinute;
@override final  bool rewardNotificationEnabled;

/// Create a copy of ReminderPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReminderPreferencesCopyWith<_ReminderPreferences> get copyWith => __$ReminderPreferencesCopyWithImpl<_ReminderPreferences>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReminderPreferences&&(identical(other.reminderEnabled, reminderEnabled) || other.reminderEnabled == reminderEnabled)&&(identical(other.reminderHour, reminderHour) || other.reminderHour == reminderHour)&&(identical(other.reminderMinute, reminderMinute) || other.reminderMinute == reminderMinute)&&(identical(other.streakAlertEnabled, streakAlertEnabled) || other.streakAlertEnabled == streakAlertEnabled)&&(identical(other.streakAlertHour, streakAlertHour) || other.streakAlertHour == streakAlertHour)&&(identical(other.streakAlertMinute, streakAlertMinute) || other.streakAlertMinute == streakAlertMinute)&&(identical(other.rewardNotificationEnabled, rewardNotificationEnabled) || other.rewardNotificationEnabled == rewardNotificationEnabled));
}


@override
int get hashCode => Object.hash(runtimeType,reminderEnabled,reminderHour,reminderMinute,streakAlertEnabled,streakAlertHour,streakAlertMinute,rewardNotificationEnabled);

@override
String toString() {
  return 'ReminderPreferences(reminderEnabled: $reminderEnabled, reminderHour: $reminderHour, reminderMinute: $reminderMinute, streakAlertEnabled: $streakAlertEnabled, streakAlertHour: $streakAlertHour, streakAlertMinute: $streakAlertMinute, rewardNotificationEnabled: $rewardNotificationEnabled)';
}


}

/// @nodoc
abstract mixin class _$ReminderPreferencesCopyWith<$Res> implements $ReminderPreferencesCopyWith<$Res> {
  factory _$ReminderPreferencesCopyWith(_ReminderPreferences value, $Res Function(_ReminderPreferences) _then) = __$ReminderPreferencesCopyWithImpl;
@override @useResult
$Res call({
 bool reminderEnabled, int reminderHour, int reminderMinute, bool streakAlertEnabled, int streakAlertHour, int streakAlertMinute, bool rewardNotificationEnabled
});




}
/// @nodoc
class __$ReminderPreferencesCopyWithImpl<$Res>
    implements _$ReminderPreferencesCopyWith<$Res> {
  __$ReminderPreferencesCopyWithImpl(this._self, this._then);

  final _ReminderPreferences _self;
  final $Res Function(_ReminderPreferences) _then;

/// Create a copy of ReminderPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reminderEnabled = null,Object? reminderHour = null,Object? reminderMinute = null,Object? streakAlertEnabled = null,Object? streakAlertHour = null,Object? streakAlertMinute = null,Object? rewardNotificationEnabled = null,}) {
  return _then(_ReminderPreferences(
reminderEnabled: null == reminderEnabled ? _self.reminderEnabled : reminderEnabled // ignore: cast_nullable_to_non_nullable
as bool,reminderHour: null == reminderHour ? _self.reminderHour : reminderHour // ignore: cast_nullable_to_non_nullable
as int,reminderMinute: null == reminderMinute ? _self.reminderMinute : reminderMinute // ignore: cast_nullable_to_non_nullable
as int,streakAlertEnabled: null == streakAlertEnabled ? _self.streakAlertEnabled : streakAlertEnabled // ignore: cast_nullable_to_non_nullable
as bool,streakAlertHour: null == streakAlertHour ? _self.streakAlertHour : streakAlertHour // ignore: cast_nullable_to_non_nullable
as int,streakAlertMinute: null == streakAlertMinute ? _self.streakAlertMinute : streakAlertMinute // ignore: cast_nullable_to_non_nullable
as int,rewardNotificationEnabled: null == rewardNotificationEnabled ? _self.rewardNotificationEnabled : rewardNotificationEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
