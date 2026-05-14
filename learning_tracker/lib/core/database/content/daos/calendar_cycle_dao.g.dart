// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_cycle_dao.dart';

// ignore_for_file: type=lint
mixin _$CalendarCycleDaoMixin on DatabaseAccessor<ContentDatabase> {
  $CalendarCyclesTable get calendarCycles => attachedDatabase.calendarCycles;
  CalendarCycleDaoManager get managers => CalendarCycleDaoManager(this);
}

class CalendarCycleDaoManager {
  final _$CalendarCycleDaoMixin _db;
  CalendarCycleDaoManager(this._db);
  $$CalendarCyclesTableTableManager get calendarCycles =>
      $$CalendarCyclesTableTableManager(
        _db.attachedDatabase,
        _db.calendarCycles,
      );
}
