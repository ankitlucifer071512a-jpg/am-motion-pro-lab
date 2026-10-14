import 'package:shared_preferences/shared_preferences.dart';

/// Local prototype store. The interface is intentionally small so a backend
/// progress repository can replace it without changing learning screens.
class LearningProgressStore {
  LearningProgressStore._();
  static final LearningProgressStore instance = LearningProgressStore._();

  static const _xpKey = 'learning_xp_v1';
  static const _completedKey = 'completed_challenges_v1';
  static const _readNotificationsKey = 'read_notifications_v1';
  static const _neonBestKey = 'neon_rush_best_v1';
  static const _neonHistoryKey = 'neon_rush_history_v1';
  static const _neonAchievementsKey = 'neon_rush_achievements_v1';
  static const _neonTrailKey = 'neon_rush_trail_v1';

  Future<int> get xp async =>
      (await SharedPreferences.getInstance()).getInt(_xpKey) ?? 0;
  Future<Set<String>> get completed async =>
      (await SharedPreferences.getInstance())
          .getStringList(_completedKey)
          ?.toSet() ??
      {};

  Future<void> completeChallenge(String id, {int xpAward = 25}) async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getStringList(_completedKey)?.toSet() ?? <String>{};
    if (done.add(id)) {
      await prefs.setStringList(_completedKey, done.toList());
      await prefs.setInt(_xpKey, (prefs.getInt(_xpKey) ?? 0) + xpAward);
    }
  }

  Future<Set<String>> get readNotifications async =>
      (await SharedPreferences.getInstance())
          .getStringList(_readNotificationsKey)
          ?.toSet() ??
      {};

  Future<void> markNotificationRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final read =
        prefs.getStringList(_readNotificationsKey)?.toSet() ?? <String>{};
    read.add(id);
    await prefs.setStringList(_readNotificationsKey, read.toList());
  }

  Future<void> markAllNotificationsRead(Iterable<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final read =
        prefs.getStringList(_readNotificationsKey)?.toSet() ?? <String>{};
    read.addAll(ids);
    await prefs.setStringList(_readNotificationsKey, read.toList());
  }

  Future<int> get neonRushBest async =>
      (await SharedPreferences.getInstance()).getInt(_neonBestKey) ?? 0;

  Future<List<int>> get neonRushHistory async =>
      (await SharedPreferences.getInstance())
          .getStringList(_neonHistoryKey)
          ?.map(int.tryParse)
          .whereType<int>()
          .toList() ??
      [];

  Future<void> recordNeonRushRun(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt(_neonBestKey) ?? 0;
    if (score > best) await prefs.setInt(_neonBestKey, score);
    final history = prefs.getStringList(_neonHistoryKey) ?? <String>[];
    history.insert(0, score.toString());
    await prefs.setStringList(_neonHistoryKey, history.take(10).toList());
  }

  Future<Set<String>> get neonRushAchievements async =>
      (await SharedPreferences.getInstance())
          .getStringList(_neonAchievementsKey)
          ?.toSet() ??
      {};

  Future<bool> unlockNeonRushAchievement(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final achievements =
        prefs.getStringList(_neonAchievementsKey)?.toSet() ?? <String>{};
    final added = achievements.add(id);
    if (added) {
      await prefs.setStringList(_neonAchievementsKey, achievements.toList());
    }
    return added;
  }

  Future<String> get neonRushTrail async =>
      (await SharedPreferences.getInstance()).getString(_neonTrailKey) ??
      'blue';

  Future<void> setNeonRushTrail(String trail) async =>
      (await SharedPreferences.getInstance()).setString(_neonTrailKey, trail);

  Future<bool> getNeonRushOption(String key,
          {bool defaultValue = false}) async =>
      (await SharedPreferences.getInstance()).getBool('neon_rush_$key') ??
      defaultValue;

  Future<void> setNeonRushOption(String key, bool value) async =>
      (await SharedPreferences.getInstance()).setBool('neon_rush_$key', value);
}
