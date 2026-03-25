enum DayType {
  study,
  review;

  String get storageKey => name;

  static DayType fromStorageKey(String key) =>
      DayType.values.firstWhere((e) => e.storageKey == key);
}
