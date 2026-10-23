import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared Reduce motion preference used by animated Idea Lab components.
class IdeaMotionPreferences {
  IdeaMotionPreferences._();

  static final ValueNotifier<bool> reduceMotion = ValueNotifier<bool>(false);
  static const _key = 'idea_reduce_motion';

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    reduceMotion.value = preferences.getBool(_key) ?? false;
  }

  static Future<void> setReduceMotion(bool value) async {
    reduceMotion.value = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key, value);
  }
}
