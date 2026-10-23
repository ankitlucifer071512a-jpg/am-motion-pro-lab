import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/creator_audio.dart';
import 'idea_lab_backend.dart';
import 'creator_music_uploader.dart';

typedef UploadProgress = void Function(int sentBytes, int totalBytes);

class CreatorMusicService {
  static const audioBucket = 'music-audio';
  static const coverBucket = 'music-covers';
  static const readableColumns =
      'id,kind,owner_id,title,description,genre,audio_url,cover_url,'
      'duration_seconds,allow_use_in_videos,rights_declared,status,'
      'plays_count,likes_count,source_post_id,license,attribution,created_at';

  SupabaseClient get _client => IdeaLabBackend.client;

  Future<List<CreatorAudio>> forProfile(String ownerId) async {
    // RLS returns all statuses to the owner and approved rows to other viewers.
    // Do not change this to select('*'): private moderation columns are revoked.
    final rows = await _client
        .from('audios')
        .select(readableColumns)
        .eq('owner_id', ownerId)
        .eq('kind', 'upload')
        .order('created_at', ascending: false);
    return Future.wait(rows.map((row) async {
      final audio = CreatorAudio.fromRow(Map<String, dynamic>.from(row));
      String? signedAudio;
      String? signedCover;
      try {
        signedAudio = await _client.storage
            .from(audioBucket)
            .createSignedUrl(audio.audioPath, 3600);
      } catch (_) {
        // Keep the metadata visible if a signed media URL cannot be created.
      }
      if (audio.coverPath != null) {
        try {
          signedCover = await _client.storage
              .from(coverBucket)
              .createSignedUrl(audio.coverPath!, 3600);
        } catch (_) {
          // The UI displays its branded cover fallback.
        }
      }
      return audio.withSignedUrls(audio: signedAudio, cover: signedCover);
    }));
  }

  Future<String?> ownModerationNote(String audioId) async {
    final value = await _client.rpc(
      'get_own_audio_moderation_note',
      params: {'target_audio': audioId},
    );
    return value as String?;
  }

  Future<String> upload({
    required Uint8List audioBytes,
    required String audioFilename,
    Uint8List? coverBytes,
    String? coverFilename,
    required String title,
    required String genre,
    required String description,
    required bool allowUseInVideos,
    required UploadProgress onProgress,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in before uploading music.');
    _validateAudio(audioFilename, audioBytes.length);
    if ((coverBytes == null) != (coverFilename == null)) {
      throw ArgumentError('Choose a valid cover image or remove the selection.');
    }
    if (coverBytes != null) _validateCover(coverFilename!, coverBytes.length);
    if (title.trim().isEmpty) throw ArgumentError('Enter a title for this audio.');
    if (title.trim().length > 160) throw ArgumentError('Title must be 160 characters or fewer.');

    final id = _newUuid(); // Generate before either storage upload.
    final safeAudioName = _safeFilename(audioFilename);
    final audioPath = '${user.id}/$id/$safeAudioName';
    final coverPath = coverFilename == null
        ? null
        : '${user.id}/$id/${_safeFilename(coverFilename)}';
    final uploaded = <(String bucket, String path)>[];
    try {
      // Track attempted paths too: the server may have committed an object even
      // if the response was lost before the client received it.
      uploaded.add((audioBucket, audioPath));
      await _uploadBytes(
        bucket: audioBucket,
        path: audioPath,
        bytes: audioBytes,
        contentType: audioContentType(audioFilename),
        onProgress: onProgress,
      );
      if (coverPath != null && coverBytes != null) {
        uploaded.add((coverBucket, coverPath));
        await _uploadBytes(
          bucket: coverBucket,
          path: coverPath,
          bytes: coverBytes,
          contentType: coverContentType(coverFilename!),
          onProgress: onProgress,
        );
      }

      // The database row is written only after all selected objects uploaded.
      await _client.from('audios').insert({
        'id': id,
        'kind': 'upload',
        'owner_id': user.id,
        'title': title.trim(),
        'genre': genre.trim(),
        'description': description.trim(),
        'audio_url': audioPath,
        'cover_url': coverPath,
        'duration_seconds': 0,
        'allow_use_in_videos': allowUseInVideos,
        'rights_declared': true,
      });
      return id;
    } catch (error) {
      try {
        await _removeUploaded(uploaded);
      } catch (cleanupError) {
        throw StateError('$error. Automatic file cleanup also failed: $cleanupError');
      }
      rethrow;
    }
  }

  Future<void> updateTrack({
    required CreatorAudio track,
    required String title,
    required String genre,
    required String description,
    Uint8List? coverBytes,
    String? coverFilename,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Enter a title for this audio.');
    if (title.trim().length > 160) throw ArgumentError('Title must be 160 characters or fewer.');
    String? newCoverPath;
    try {
      if (coverBytes != null || coverFilename != null) {
        if (coverBytes == null || coverFilename == null) {
          throw ArgumentError('Choose a valid cover image.');
        }
        _validateCover(coverFilename, coverBytes.length);
        final uid = _client.auth.currentUser!.id;
        newCoverPath = '$uid/${track.id}/${_safeFilename(coverFilename)}';
        await _uploadBytes(
          bucket: coverBucket,
          path: newCoverPath,
          bytes: coverBytes,
          contentType: coverContentType(coverFilename),
          onProgress: (_, __) {},
        );
      }
      await _client.from('audios').update({
        'title': title.trim(),
        'genre': genre.trim(),
        'description': description.trim(),
        if (newCoverPath != null) 'cover_url': newCoverPath,
      }).eq('id', track.id).eq('owner_id', _client.auth.currentUser!.id);
    } catch (_) {
      if (newCoverPath != null) {
        try {
          await _removeUploaded([(coverBucket, newCoverPath)]);
        } catch (cleanupError) {
          throw StateError('Audio details could not be saved and the new cover could not be removed: $cleanupError');
        }
      }
      rethrow;
    }
    if (newCoverPath != null && track.coverPath != null) {
      await _removeUploaded([(coverBucket, track.coverPath!)]);
    }
  }

  Future<void> deleteTrack(CreatorAudio track) async {
    await _client
        .from('audios')
        .delete()
        .eq('id', track.id)
        .eq('owner_id', _client.auth.currentUser!.id);
    // Delete the row first so Storage's rule no longer treats approved media as
    // referenced. A cleanup failure is surfaced; it does not restore the row.
    final files = <(String, String)>[(audioBucket, track.audioPath)];
    if (track.coverPath != null) files.add((coverBucket, track.coverPath!));
    await _removeUploaded(files);
  }

  static String audioContentType(String filename) =>
      filename.toLowerCase().endsWith('.mp3') ? 'audio/mpeg' : 'audio/mp4';

  static String coverContentType(String filename) {
    final name = filename.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    return 'image/webp';
  }

  void _validateAudio(String filename, int size) {
    final name = filename.toLowerCase();
    if (!name.endsWith('.mp3') && !name.endsWith('.m4a')) {
      throw ArgumentError('Choose an MP3 or M4A audio file.');
    }
    if (size <= 0 || size > 10 * 1024 * 1024) {
      throw ArgumentError('Audio must be larger than 0 bytes and no more than 10 MB.');
    }
  }

  void _validateCover(String filename, int size) {
    final name = filename.toLowerCase();
    if (!name.endsWith('.jpg') && !name.endsWith('.jpeg') &&
        !name.endsWith('.png') && !name.endsWith('.webp')) {
      throw ArgumentError('Cover must be JPG, PNG, or WebP.');
    }
    if (size <= 0 || size > 2 * 1024 * 1024) {
      throw ArgumentError('Cover must be larger than 0 bytes and no more than 2 MB.');
    }
  }

  Future<void> _uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
    required UploadProgress onProgress,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Your session expired. Sign in and try again.');
    final accessToken = _client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Your session expired. Sign in and try again.');
    }
    final encodedPath = path.split('/').map(Uri.encodeComponent).join('/');
    final uri = Uri.parse('${IdeaLabBackend.projectUrl}/storage/v1/object/$bucket/$encodedPath');
    final response = await sendMusicUpload(
      uri: uri,
      bytes: bytes,
      headers: {
        'apikey': IdeaLabBackend.publishableKey,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': contentType,
        'cache-control': '3600',
        'x-upsert': 'false',
      },
      onProgress: onProgress,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _storageError(response.body);
      throw StateError('Upload failed (${response.statusCode}): $detail');
    }
  }

  String _storageError(String body) {
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(body) as Map);
      return decoded['message']?.toString() ?? body;
    } catch (_) {
      return body.isEmpty ? 'Storage rejected the file.' : body;
    }
  }

  Future<void> _removeUploaded(List<(String bucket, String path)> objects) async {
    final errors = <Object>[];
    for (final object in objects.reversed) {
      try {
        await _client.storage.from(object.$1).remove([object.$2]);
      } catch (error) {
        errors.add(error);
      }
    }
    if (errors.isNotEmpty) {
      throw StateError('Could not remove ${errors.length} uploaded file(s): ${errors.first}');
    }
  }

  String _safeFilename(String filename) {
    final leaf = filename.split(RegExp(r'[/\\]')).last;
    final cleaned = leaf.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'upload.bin' : cleaned;
  }

  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
