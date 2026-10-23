import 'package:shared_preferences/shared_preferences.dart';

class IdeaVideoPreferences {
  static const _autoplayKey = 'idea_video_autoplay_v1';

  static Future<bool> autoplayEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_autoplayKey) ?? true;
  }

  static Future<void> setAutoplayEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoplayKey, enabled);
  }
}
