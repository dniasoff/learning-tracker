import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences wrapper for learning order permission setting.
class LearningOrderPreferences {
  LearningOrderPreferences._();

  static final LearningOrderPreferences instance = LearningOrderPreferences._();

  static const _parentControlsOrderingKey = 'learning_order_parent_controls';

  bool _parentControlsOrdering = false;
  bool _initialized = false;

  bool get parentControlsOrdering => _parentControlsOrdering;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _parentControlsOrdering =
        prefs.getBool(_parentControlsOrderingKey) ?? false;
    _initialized = true;
  }

  Future<void> setParentControlsOrdering(bool value) async {
    _parentControlsOrdering = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_parentControlsOrderingKey, value);
  }

  void reset() {
    _parentControlsOrdering = false;
    _initialized = false;
  }
}
