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
  static const _motionDashBestKey = 'motion_dash_best_v1';
  static const _motionDashUnlockedKey = 'motion_dash_unlocked_stage_v1';
  static const _motionDashUnlockedRoundKey = 'motion_dash_unlocked_round_v1';
  static const _motionDashCompletedRoundsKey =
      'motion_dash_completed_rounds_v1';
  static const _courseLessonsKey = 'course_lessons_completed_demo_v1';
  static const _portfolioRatingKey = 'portfolio_practice_rating_v1';

  Future<double?> get portfolioPracticeRating async =>
      (await SharedPreferences.getInstance()).getDouble(_portfolioRatingKey);

  Future<void> recordPortfolioPracticeRating(double rating) async =>
      (await SharedPreferences.getInstance()).setDouble(
        _portfolioRatingKey,
        rating.clamp(1, 5),
      );

  Future<Set<String>> get completedCourseLessons async =>
      (await SharedPreferences.getInstance())
          .getStringList(_courseLessonsKey)
          ?.toSet() ??
      {};

  Future<void> completeCourseLesson(String courseId, String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    final completed =
        prefs.getStringList(_courseLessonsKey)?.toSet() ?? <String>{};
    completed.add('$courseId:$lessonId');
    await prefs.setStringList(_courseLessonsKey, completed.toList());
  }

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

  Future<int> get motionDashBest async =>
      (await SharedPreferences.getInstance()).getInt(_motionDashBestKey) ?? 0;

  Future<int> get motionDashUnlockedStage async =>
      (await SharedPreferences.getInstance()).getInt(_motionDashUnlockedKey) ??
      1;

  Future<int> get motionDashUnlockedRound async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_motionDashUnlockedRoundKey) ??
        prefs.getInt(_motionDashUnlockedKey) ??
        1;
  }

  Future<int> get motionDashCompletedRounds async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_motionDashCompletedRoundsKey) ?? 0;
  }

  Future<void> recordMotionDashRun(int score, int reachedStage) async {
    final prefs = await SharedPreferences.getInstance();
    if (score > (prefs.getInt(_motionDashBestKey) ?? 0)) {
      await prefs.setInt(_motionDashBestKey, score);
    }
    final unlocked = prefs.getInt(_motionDashUnlockedKey) ?? 1;
    if (reachedStage > unlocked) {
      await prefs.setInt(_motionDashUnlockedKey, reachedStage);
    }
  }

  Future<void> recordMotionDashRoundCompleted(int score, int round) async {
    final prefs = await SharedPreferences.getInstance();
    if (score > (prefs.getInt(_motionDashBestKey) ?? 0)) {
      await prefs.setInt(_motionDashBestKey, score);
    }
    final unlocked = prefs.getInt(_motionDashUnlockedRoundKey) ??
        prefs.getInt(_motionDashUnlockedKey) ??
        1;
    if (round + 1 > unlocked) {
      await prefs.setInt(_motionDashUnlockedRoundKey, round + 1);
    }
    final completed = prefs.getInt(_motionDashCompletedRoundsKey) ?? 0;
    if (round > completed) {
      await prefs.setInt(_motionDashCompletedRoundsKey, round);
    }
  }

  Future<void> recordMotionDashBestScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    if (score > (prefs.getInt(_motionDashBestKey) ?? 0)) {
      await prefs.setInt(_motionDashBestKey, score);
    }
  }
}
