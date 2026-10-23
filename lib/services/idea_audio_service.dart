import 'package:supabase_flutter/supabase_flutter.dart';

import 'idea_lab_backend.dart';

class IdeaAudio {
  const IdeaAudio({
    required this.id,
    required this.kind,
    required this.ownerId,
    required this.title,
    required this.artist,
    required this.audioPath,
    required this.playableUrl,
    required this.durationSeconds,
    required this.allowUse,
    required this.status,
    required this.usesCount,
    this.coverPath,
    this.artworkUrl,
    this.license,
    this.attribution,
    this.sourceUrl,
  });

  final String id;
  final String kind;
  final String ownerId;
  final String title;
  final String artist;
  final String audioPath;
  final String playableUrl;
  final String? coverPath;
  final String? artworkUrl;
  final int durationSeconds;
  final bool allowUse;
  final String status;
  final int usesCount;
  final String? license;
  final String? attribution;
  final String? sourceUrl;

  static Future<IdeaAudio> fromRow(Map<String, dynamic> row) async {
    final kind = row['kind'] as String;
    var audioPath = row['audio_url'] as String;
    final coverPath = row['cover_url'] as String?;
    final audioBucket = kind == 'original' ? 'idea-media' : 'music-audio';
    final coverBucket = kind == 'original' ? 'idea-media' : 'music-covers';

    // Original audio is the video's own soundtrack. Resolve its object path
    // from the post media row, which is the canonical storage reference, rather
    // than relying only on the denormalized audios.audio_url value.
    final sourcePostId = row['source_post_id'] as String?;
    if (kind == 'original' && sourcePostId != null) {
      final media = await IdeaLabBackend.client
          .from('idea_post_media')
          .select('storage_path')
          .eq('post_id', sourcePostId)
          .eq('mime_type', 'video/mp4')
          .order('position')
          .limit(1)
          .maybeSingle();
      final canonicalPath = media?['storage_path'] as String?;
      if (canonicalPath != null && canonicalPath.isNotEmpty) {
        audioPath = canonicalPath;
      }
    }
    final playableUrl = kind == 'library' ? audioPath : await IdeaLabBackend.signedMediaUrl(audioBucket, audioPath);
    String? artworkUrl;
    if (coverPath != null) {
      try {
        artworkUrl = kind == 'library'
            ? coverPath
            : await IdeaLabBackend.signedMediaUrl(coverBucket, coverPath);
      } on StorageException {
        // Covers are optional. A missing cover should use the branded artwork
        // fallback and must not prevent the actual audio from loading.
        artworkUrl = null;
      }
    }
    return IdeaAudio(
    id: row['id'] as String,
    kind: kind,
    ownerId: row['owner_id'] as String,
    title: row['title'] as String,
    artist: (row['artist_name'] as String? ?? '').trim().isEmpty
        ? 'Creator'
        : row['artist_name'] as String,
    audioPath: audioPath,
    playableUrl: playableUrl,
    coverPath: coverPath,
    artworkUrl: artworkUrl,
    durationSeconds: (row['duration_seconds'] as num?)?.toInt() ?? 0,
    allowUse: row['allow_use_in_videos'] == true,
    status: row['status'] as String? ?? 'pending',
    usesCount: (row['uses_count'] as num?)?.toInt() ?? 0,
    license: row['license'] as String?,
    attribution: row['attribution'] as String?,
    sourceUrl: row['source_url'] as String?,
  );
  }
}

class IdeaAudioService {
  static const fields =
      'id,kind,owner_id,title,artist_name,audio_url,cover_url,duration_seconds,'
      'allow_use_in_videos,status,uses_count,license,attribution,source_url,'
      'source_post_id';

  SupabaseClient get _db => IdeaLabBackend.client;

  Future<IdeaAudio> get(String id) async {
    final row = await _db.from('audios').select(fields).eq('id', id).single();
    return IdeaAudio.fromRow(Map<String, dynamic>.from(row));
  }

  Future<List<IdeaAudio>> originals({int offset = 0, int limit = 24}) async {
    final rows = await _db.from('audios').select(fields)
        .eq('kind', 'original').eq('status', 'approved')
        .order('uses_count', ascending: false).order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return Future.wait(rows.map((row) => IdeaAudio.fromRow(Map<String, dynamic>.from(row))));
  }

  Future<bool> isSaved(String audioId) async {
    final user = _db.auth.currentUser;
    if (user == null) return false;
    final row = await _db.from('audio_saves').select('audio_id')
        .eq('audio_id', audioId).eq('user_id', user.id).maybeSingle();
    return row != null;
  }

  Future<void> toggleSave(String audioId, {required bool saved}) async {
    final user = _db.auth.currentUser;
    if (user == null) throw StateError('Sign in to save audio.');
    if (saved) {
      await _db.from('audio_saves').delete()
          .eq('audio_id', audioId).eq('user_id', user.id);
    } else {
      await _db.from('audio_saves').insert({'audio_id': audioId, 'user_id': user.id});
    }
  }

  Future<void> report(String audioId, String reason) async {
    final user = _db.auth.currentUser;
    if (user == null) throw StateError('Sign in to report audio.');
    await _db.from('audio_reports').insert({
      'audio_id': audioId, 'reporter_id': user.id, 'reason': reason,
    });
  }

  Future<bool> isAdmin() async {
    final user = _db.auth.currentUser;
    if (user == null) return false;
    return await _db.from('audio_admins').select('user_id')
        .eq('user_id', user.id).maybeSingle() != null;
  }

  Future<void> moderate(String audioId, String status) async {
    await _db.rpc('moderate_audio', params: {
      'target_audio': audioId,
      'next_status': status,
      'review_note': 'Hidden by audio administrator.',
    });
  }
}
