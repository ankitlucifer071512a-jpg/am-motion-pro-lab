import 'package:supabase_flutter/supabase_flutter.dart';

import 'idea_lab_backend.dart';

class IdeaWatchHistoryService {
  SupabaseClient get _db => IdeaLabBackend.client;
  String get _userId => _db.auth.currentUser!.id;

  Future<void> recordReelWatch(String postId) async {
    if (_db.auth.currentUser == null) return;
    await _db.rpc('record_idea_reel_watch', params: {'target_post': postId});
  }

  Future<bool> historyPaused() async {
    if (_db.auth.currentUser == null) return false;
    final row = await _db.from('idea_watch_history_preferences')
        .select('paused').eq('user_id', _userId).maybeSingle();
    return row?['paused'] == true;
  }

  Future<void> setHistoryPaused(bool paused) async {
    if (_db.auth.currentUser == null) throw StateError('Sign in to update this setting.');
    await _db.from('idea_watch_history_preferences').upsert({
      'user_id': _userId, 'paused': paused,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> history() async {
    if (_db.auth.currentUser == null) return const [];
    final rows = await _db.from('idea_reel_watch_history')
        .select('post_id,watched_at,post:idea_posts!inner(id,caption,created_at)')
        .eq('user_id', _userId).order('watched_at', ascending: false).limit(200);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> clearHistory() async {
    if (_db.auth.currentUser == null) throw StateError('Sign in to clear history.');
    await _db.from('idea_reel_watch_history').delete().eq('user_id', _userId);
  }
}
