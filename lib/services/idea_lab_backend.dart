import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/idea_music_track.dart';
import 'idea_device_account_store.dart';
import 'edge_function_errors.dart';

class IdeaLabBackend {
  IdeaLabBackend._();

  static const projectUrl = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static final hasValidProjectUrl = _validProjectUrl(projectUrl);
  static final hasPublishableKey =
      publishableKey.isNotEmpty &&
      !publishableKey.contains('REPLACE_WITH') &&
      !publishableKey.contains('YOUR_');
  static final isConfigured = hasValidProjectUrl && hasPublishableKey;
  static bool _initialized = false;
  static String? initializationError;
  static bool get isReady => isConfigured && _initialized;

  static bool _validProjectUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        !uri.host.contains('YOUR_PROJECT_REF');
  }

  static String get configurationMessage {
    if (!hasValidProjectUrl) {
      return 'Supabase Project URL is missing or invalid. Use the full HTTPS Project URL from Supabase Project Settings → API in supabase-credentials.json, then launch with the AM Motion Lab (Supabase) configuration.';
    }
    if (!hasPublishableKey) {
      return 'Supabase publishable key is missing or still an example value. Configure supabase-credentials.json and launch with the AM Motion Lab (Supabase) configuration.';
    }
    return 'Supabase is configured, but its Idea Lab database, buckets, or media validator may still need setup.';
  }

  static Future<void> initialize() async {
    if (!isConfigured) return;
    try {
      await Supabase.initialize(
        url: projectUrl,
        publishableKey: publishableKey,
      );
      IdeaDeviceAccountStore.instance.attach(Supabase.instance.client);
      _initialized = true;
      initializationError = null;
    } catch (_) {
      initializationError =
          'Supabase could not initialize. Check the Project URL and publishable key in the local configuration.';
    }
  }

  static SupabaseClient get client {
    if (!isReady) throw StateError('Supabase is not initialized.');
    return Supabase.instance.client;
  }

  static User? get currentUser => isReady ? client.auth.currentUser : null;

  static Future<String> signedMediaUrl(String bucket, String path) =>
      client.storage.from(bucket).createSignedUrl(path, 10 * 60);
}

class IdeaLabPostMedia {
  const IdeaLabPostMedia({
    required this.id,
    required this.url,
    required this.mimeType,
    required this.position,
    this.thumbnailUrl,
    this.thumbnailStoragePath,
    this.duration,
    this.width,
    this.height,
  });

  final String id;
  final String url;
  final String mimeType;
  final int position;
  final String? thumbnailUrl;
  final String? thumbnailStoragePath;
  final Duration? duration;
  final int? width;
  final int? height;

  double get aspectRatio =>
      width != null && height != null && width! > 0 && height! > 0
      ? width! / height!
      : 16 / 9;

  static Future<IdeaLabPostMedia> fromJson(Map<String, dynamic> json) async {
    final path = json['storage_path'] as String;
    final url = await IdeaLabBackend.signedMediaUrl('idea-media', path);
    final thumbnailPath = json['thumbnail_url'] as String?;
    return IdeaLabPostMedia(
      id: json['id'] as String,
      url: url,
      mimeType: json['mime_type'] as String,
      position: json['position'] as int,
      thumbnailStoragePath: thumbnailPath,
      thumbnailUrl: thumbnailPath == null
          ? null
          : await IdeaLabBackend.signedMediaUrl('idea-media', thumbnailPath),
      duration: json['duration_seconds'] is num
          ? Duration(seconds: (json['duration_seconds'] as num).toInt())
          : null,
      width: json['width'] is num ? (json['width'] as num).toInt() : null,
      height: json['height'] is num ? (json['height'] as num).toInt() : null,
    );
  }
}

class IdeaLabPost {
  const IdeaLabPost({
    required this.id,
    required this.creatorId,
    required this.caption,
    required this.category,
    required this.tags,
    required this.creator,
    required this.avatarUrl,
    required this.createdAt,
    required this.media,
    this.music,
    this.audioId,
    this.audience = 'public',
    this.commentsAccess = 'everyone',
    this.hideLikeCount = false,
    this.allowAudioUse = true,
    this.allowSaving = true,
    this.altText,
    this.locationLabel,
  });

  final String id;
  final String creatorId;
  final String caption;
  final String category;
  final List<String> tags;
  final String creator;
  final String? avatarUrl;
  final DateTime createdAt;
  final List<IdeaLabPostMedia> media;
  final IdeaMusicSelection? music;
  final String? audioId;
  final String audience;
  final String commentsAccess;
  final bool hideLikeCount;
  final bool allowAudioUse;
  final bool allowSaving;
  final String? altText;
  final String? locationLabel;

  static Future<IdeaLabPost> fromJson(Map<String, dynamic> json) async {
    final category = json['idea_categories'] as Map<String, dynamic>?;
    final profile = json['idea_profiles'] as Map<String, dynamic>?;
    final avatarPath = profile?['avatar_path'] as String?;
    final mediaRows = (json['idea_post_media'] as List<dynamic>? ?? const []);
    final tagRows = (json['idea_post_tags'] as List<dynamic>? ?? const []);
    return IdeaLabPost(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      caption: json['caption'] as String,
      category: category?['name'] as String? ?? 'Uncategorized',
      tags: tagRows
          .map((row) => (row as Map<String, dynamic>)['tag'] as String)
          .toList(),
      creator: profile?['display_name'] as String? ?? 'Creator',
      avatarUrl: avatarPath == null
          ? null
          : await IdeaLabBackend.signedMediaUrl('idea-avatars', avatarPath),
      createdAt: DateTime.parse(json['created_at'] as String),
      media: (await Future.wait(mediaRows.map((row) => IdeaLabPostMedia.fromJson(
        Map<String, dynamic>.from(row as Map),
      ))))..sort((a, b) => a.position.compareTo(b.position)),
      music: json['music_metadata'] is Map
          ? IdeaMusicSelection.fromJson(
              Map<String, dynamic>.from(json['music_metadata'] as Map),
            )
          : null,
      audioId: json['audio_id'] as String?,
      audience: json['audience'] as String? ?? 'public',
      commentsAccess: json['comments_access'] as String? ?? 'everyone',
      hideLikeCount: json['hide_like_count'] == true,
      allowAudioUse: json['allow_audio_use'] != false,
      allowSaving: json['allow_saving'] != false,
      altText: json['alt_text'] as String?,
      locationLabel: json['location_label'] as String?,
    );
  }
}

class IdeaLabPostService {
  static const pageSize = 24;
  static const maxImageBytes = 20000000;
  static const maxVideoBytes = 50000000;
  static const maxPostBytes = 100000000;
  static const maxPostMediaItems = 5;
  static const maxCreatorMediaBytes = 500000000;
  static const _tusRecommendedThreshold = 6 * 1024 * 1024;
  static const _standardVideoFallbackLimit = 50 * 1024 * 1024;
  static const _tusChunkBytes = 6 * 1024 * 1024;
  static const _selection =
      'id,creator_id,caption,created_at,idea_categories(name),idea_profiles(display_name,avatar_path),'
      'idea_post_media(id,storage_path,mime_type,position,thumbnail_url,duration_seconds,width,height),idea_post_tags(tag),music_metadata,'
      'audience,comments_access,hide_like_count,allow_audio_use,allow_saving,alt_text,location_label,audio_id';

  void _trace(String message) {
    if (!kDebugMode) return;
    final parts = message.trim().split(RegExp(r'\s+'));
    final event = parts.isEmpty ? '' : parts.first;
    if (!RegExp(r'^[a-z][a-z0-9_.-]*$').hasMatch(event)) {
      debugPrint('[UPLOAD] event');
      return;
    }
    // Log only the static event label. Values may contain user IDs, filenames,
    // object paths, server response bodies, or exception details.
    debugPrint('[UPLOAD] $event');
  }

  Future<dynamic> _invokeMediaValidator(Map<String, dynamic> body) async {
    try {
      return await IdeaLabBackend.client.functions.invoke(
        'validate-idea-media',
        body: body,
      );
    } on FunctionException catch (error) {
      throw StateError(
        EdgeFunctionErrors.friendlyMessage(
          error.details,
          fallback: 'The media verifier is temporarily unavailable.',
          status: error.status,
        ),
      );
    }
  }

  /// Checks server-side setup before enabling creator publishing. This verifies
  /// the migration, both buckets, and the deployed validator using the signed-in
  /// user's session; it never exposes or accepts a service-role key in Flutter.
  Future<void> checkPublishingReady() async {
    _trace(
      'setup.check.start configured=${IdeaLabBackend.isConfigured} signedIn=${IdeaLabBackend.currentUser != null}',
    );
    if (!IdeaLabBackend.isConfigured) {
      throw StateError(IdeaLabBackend.configurationMessage);
    }
    if (IdeaLabBackend.currentUser == null) {
      throw StateError('Sign in to check Idea Lab publishing setup.');
    }
    final response = await _invokeMediaValidator({'action': 'health'});
    _trace(
      'setup.check.response status=${response.status} body=${response.data}',
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        EdgeFunctionErrors.friendlyMessage(
          response.data,
          fallback: 'Idea Lab server setup is incomplete.',
          status: response.status,
        ),
      );
    }
    if (response.data is Map && response.data['ready'] != true) {
      throw StateError('Idea Lab server setup is incomplete.');
    }
  }

  Future<List<IdeaLabPost>> fetchPage({required int offset}) async {
    final rows = await IdeaLabBackend.client
        .from('idea_posts')
        .select(_selection)
        .not('published_at', 'is', null)
        .order('created_at', ascending: false)
        .range(offset, offset + pageSize - 1);
    return Future.wait(rows.map((row) => IdeaLabPost.fromJson(Map<String, dynamic>.from(row))));
  }

  Future<List<IdeaLabPost>> fetchCreatorPosts(
    String creatorId, {
    int offset = 0,
  }) async {
    final rows = await IdeaLabBackend.client
        .from('idea_posts')
        .select(_selection)
        .eq('creator_id', creatorId)
        .not('published_at', 'is', null)
        .order('created_at', ascending: false)
        .range(offset, offset + pageSize - 1);
    return Future.wait(rows.map((row) => IdeaLabPost.fromJson(Map<String, dynamic>.from(row))));
  }

  Future<List<IdeaLabPost>> fetchAudioPosts(String audioId, {int offset = 0}) async {
    final rows = await IdeaLabBackend.client
        .from('idea_posts')
        .select(_selection)
        .eq('audio_id', audioId)
        .not('published_at', 'is', null)
        .order('created_at', ascending: false)
        .range(offset, offset + pageSize - 1);
    final posts = await Future.wait(rows.map((row) => IdeaLabPost.fromJson(Map<String, dynamic>.from(row))));
    return posts.where((post) => post.media.any((media) => media.mimeType == 'video/mp4')).toList();
  }

  Future<void> deletePost(IdeaLabPost post) async {
    final client = IdeaLabBackend.client;
    final user = client.auth.currentUser;
    if (user == null || user.id != post.creatorId) {
      throw StateError('Only the creator can delete this post.');
    }
    final rows = await client
        .from('idea_post_media')
        .select('storage_path,thumbnail_url')
        .eq('post_id', post.id);
    final paths = rows
        .expand((row) => [row['storage_path'], row['thumbnail_url']])
        .whereType<String>()
        .toList();
    if (paths.isNotEmpty) {
      await client.storage.from('idea-media').remove(paths);
    }
    await client.from('idea_posts').delete().eq('id', post.id);
  }

  Future<void> updatePostOwnerFields({
    required String postId,
    required String caption,
    required String category,
    required List<String> tags,
    required bool hideLikeCount,
    required String commentsAccess,
  }) async {
    final user = IdeaLabBackend.client.auth.currentUser;
    if (user == null) throw StateError('Sign in to edit this post.');
    await IdeaLabBackend.client.rpc(
      'update_idea_post_owner_fields',
      params: {
        'target_post': postId,
        'next_caption': caption,
        'next_category': category,
        'next_tags': tags,
        'next_hide_like_count': hideLikeCount,
        'next_comments_access': commentsAccess,
      },
    );
  }

  Future<void> replaceVideoThumbnail({
    required IdeaLabPost post,
    required IdeaLabPostMedia media,
    required XFile cover,
    required Uint8List bytes,
  }) async {
    final client = IdeaLabBackend.client;
    final user = client.auth.currentUser;
    if (user == null ||
        user.id != post.creatorId ||
        !media.mimeType.startsWith('video/')) {
      throw StateError('Only the video creator can replace this cover.');
    }
    if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
      throw ArgumentError('Video covers must be no larger than 2 MiB.');
    }
    final extension = cover.name.split('.').last.toLowerCase();
    final mime = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw ArgumentError('Choose a JPG, PNG, or WebP video cover.'),
    };
    final path = '${user.id}/${post.id}/${_newUuid()}.$extension';
    try {
      await client.storage
          .from('idea-media')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: mime,
              cacheControl: '3600',
              upsert: false,
            ),
          );
    } on StorageException catch (error) {
      if (error.statusCode == '403' ||
          error.message.toLowerCase().contains('row-level security')) {
        throw StateError(
          'Storage denied the cover upload (HTTP ${error.statusCode ?? '403'}): ${error.message}${error.error == null ? '' : ' (${error.error})'}. The original cover is unchanged. Apply migration 202610170014_idea_media_upload_rls_fix.sql, then retry.',
        );
      }
      throw StateError('Cover upload failed: ${error.message}');
    }
    try {
      final validation = await _invokeMediaValidator({
          'action': 'thumbnail',
          'post_id': post.id,
          'bucket': 'idea-media',
          'path': path,
        });
      if (validation.status < 200 || validation.status >= 300) {
        throw StateError(
          EdgeFunctionErrors.friendlyMessage(
            validation.data,
            fallback: 'Cover validation failed.',
            status: validation.status,
          ),
        );
      }
      await client
          .from('idea_post_media')
          .update({'thumbnail_url': path})
          .eq('id', media.id)
          .eq('post_id', post.id)
          .select('id')
          .single();
      final oldPath = media.thumbnailStoragePath;
      if (oldPath != null && oldPath != path) {
        // The database now points at the new cover. A cleanup denial must not
        // turn a successful replacement into a reported failure.
        try {
          await client.storage.from('idea-media').remove([oldPath]);
        } catch (_) {}
      }
    } catch (error) {
      try {
        await client.storage.from('idea-media').remove([path]);
      } catch (_) {}
      if (error is PostgrestException && error.code == '42501') {
        throw StateError(
          'Cover uploaded, but the video thumbnail database policy denied the update. Apply migration 202610170009_idea_video_thumbnails.sql.',
        );
      }
      rethrow;
    }
  }

  Future<Set<String>> fetchSavedIds() async {
    final user = IdeaLabBackend.client.auth.currentUser;
    if (user == null) return {};
    final rows = await IdeaLabBackend.client
        .from('idea_saved_posts')
        .select('post_id')
        .eq('user_id', user.id);
    return rows.map((row) => row['post_id'] as String).toSet();
  }

  Future<Set<String>> toggleSaved(String postId, Set<String> current) async {
    final client = IdeaLabBackend.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in to save community posts.');
    if (current.contains(postId)) {
      await client
          .from('idea_saved_posts')
          .delete()
          .eq('user_id', user.id)
          .eq('post_id', postId);
      return {...current}..remove(postId);
    }
    await client.from('idea_saved_posts').insert({
      'user_id': user.id,
      'post_id': postId,
    });
    return {...current, postId};
  }

  Future<void> publishImages({
    required List<XFile> files,
    required Map<XFile, Uint8List> bytes,
    required Map<XFile, XFile> videoCovers,
    required String caption,
    required String category,
    required List<String> tags,
    required void Function(int completed, int total) onProgress,
    void Function(String filename, int sentBytes, int totalBytes)?
    onVideoProgress,
    required bool Function() isCancelled,
    int maxVideoDurationSeconds = 60,
    int? videoDurationSeconds,
    IdeaMusicSelection? music,
    Map<String, dynamic> postSettings = const {},
  }) async {
    _trace(
      'publish.selection mediaCount=${files.length} videoCount=${files.where((file) => file.name.toLowerCase().endsWith('.mp4')).length} videoDurationSeconds=${videoDurationSeconds ?? 0}',
    );
    final user = IdeaLabBackend.client.auth.currentUser;
    if (user == null) {
      _trace('publish.reject reason=not_signed_in');
      throw StateError('Sign in to publish a post.');
    }
    if (files.isEmpty) {
      _trace('publish.reject reason=no_files');
      throw ArgumentError('Select at least one graphic or video.');
    }
    final videos = files
        .where((file) => file.name.toLowerCase().endsWith('.mp4'))
        .toList(growable: false);
    if (videos.length > 1 || (videos.isNotEmpty && files.length != 1)) {
      throw ArgumentError(
        'Publish one MP4 video or multiple graphics in separate posts.',
      );
    }
    if (caption.trim().isEmpty) {
      _trace('publish.reject reason=empty_caption');
      throw ArgumentError('Add a caption.');
    }
    if (files.length > maxPostMediaItems) {
      throw ArgumentError('Choose up to $maxPostMediaItems photos for a post.');
    }
    var aggregateBytes = 0;
    for (final file in files) {
      final size = bytes[file]?.length ?? await file.length();
      aggregateBytes += size;
      final isVideo = file.name.toLowerCase().endsWith('.mp4');
      _trace(
        'preflight.file name=${file.name} size=$size extension=${file.name.split('.').last.toLowerCase()} reportedMime=${file.mimeType ?? 'unknown'} bytesAlreadyRead=${bytes.containsKey(file)}',
      );
      final limit = isVideo ? maxVideoBytes : maxImageBytes;
      if (size <= 0 || size > limit) {
        _trace(
          'preflight.reject name=${file.name} reason=${size <= 0 ? 'empty' : 'over_limit'} limit=$limit',
        );
        final actualMb = (size / 1000000).toStringAsFixed(1);
        final limitMb = (limit / (1024 * 1024)).round();
        throw ArgumentError(isVideo
            ? 'This video is $actualMb MB. The maximum is $limitMb MB. Please trim or compress it.'
            : 'This image is $actualMb MB. The maximum is $limitMb MB. Please resize or compress it.');
      }
    }
    for (final video in videos) {
      final cover = videoCovers[video];
      if (cover == null) {
        throw ArgumentError('Choose a cover image for ${video.name}.');
      }
      final coverData = bytes[cover] ?? await cover.readAsBytes();
      if (coverData.isEmpty || coverData.length > 2 * 1024 * 1024) {
        throw ArgumentError('Video covers must be no larger than 2 MiB.');
      }
      aggregateBytes += coverData.length;
    }
    if (aggregateBytes > maxPostBytes) {
      throw ArgumentError('The selected media total ${(aggregateBytes / 1000000).toStringAsFixed(1)} MB. The maximum is 100 MB. Remove or compress some files.');
    }

    final db = IdeaLabBackend.client;
    final uploadCount =
        files.length +
        files.where((file) => file.name.toLowerCase().endsWith('.mp4')).length;
    var completedUploads = 0;
    // IDs and paths are allocated before any object is uploaded for safe cleanup.
    final id = _newUuid();
    final uploaded = <String>[];
    final thumbnailUploads = <String>{};
    var metadataCreated = false;
    try {
      final categoryRow = await db
          .from('idea_categories')
          .select('id')
          .eq('name', category)
          .single();
      _trace('database.category_found id=${categoryRow['id']}');
      final mediaRows = <Map<String, dynamic>>[];
      for (var index = 0; index < files.length; index++) {
        if (isCancelled()) throw const IdeaLabUploadCancelled();
        final file = files[index];
        final extension = file.name.split('.').last.toLowerCase();
        final mime = switch (extension) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'webp' => 'image/webp',
          'mp4' => 'video/mp4',
          _ => throw ArgumentError('Unsupported media type: ${file.name}'),
        };
        _trace(
          'file.inspect index=$index name=${file.name} extension=$extension detectedMime=$mime platformMime=${file.mimeType ?? 'unknown'}',
        );
        final size = bytes[file]?.length ?? await file.length();
        final isVideo = mime == 'video/mp4';
        final limit = isVideo ? maxVideoBytes : maxImageBytes;
        if (size <= 0 || size > limit) {
          _trace(
            'file.reject name=${file.name} reason=${size <= 0 ? 'empty' : 'over_limit'} limit=$limit',
          );
          final actualMb = (size / 1000000).toStringAsFixed(1);
          final limitMb = (limit / (1024 * 1024)).round();
          throw ArgumentError(isVideo
              ? 'This video is $actualMb MB. The maximum is $limitMb MB. Please trim or compress it.'
              : 'This image is $actualMb MB. The maximum is $limitMb MB. Please resize or compress it.');
        }
        final path = '${user.id}/$id/${_newUuid()}.$extension';
        uploaded.add(path);
        _trace(
          'storage.video.start name=${file.name} size=$size transport=${isVideo && size > _tusRecommendedThreshold ? 'tus' : 'sdk'} path=$path',
        );
        if (isVideo && size > _tusRecommendedThreshold) {
          try {
            await _uploadVideoResumable(
              file: file,
              path: path,
              mimeType: mime,
              totalBytes: size,
              onProgress: (sent, total) =>
                  onVideoProgress?.call(file.name, sent, total),
              isCancelled: isCancelled,
            );
          } catch (resumableError) {
            _trace('storage.tus.error name=${file.name} error=$resumableError');
            if (resumableError is IdeaLabUploadCancelled) rethrow;
            final isStorageLimitOrPolicy =
                '$resumableError'.contains('(413)') ||
                '$resumableError'.contains('(403)');
            if (size > _standardVideoFallbackLimit || isStorageLimitOrPolicy) {
              rethrow;
            }
            try {
              // Browser/network stacks can reject the custom TUS transport.
              // For files within the safe memory bound, retry via the SDK's
              // standard Storage upload; preserve TUS for larger media.
              await db.storage
                  .from('idea-media')
                  .uploadBinary(
                    path,
                    bytes[file] ?? await file.readAsBytes(),
                    fileOptions: FileOptions(
                      contentType: mime,
                      cacheControl: '3600',
                      upsert: false,
                    ),
                    retryAttempts: 2,
                  );
              _trace('storage.sdk_fallback.done name=${file.name}');
            } catch (fallbackError) {
              _trace(
                'storage.sdk_fallback.error name=${file.name} error=$fallbackError',
              );
              throw StateError(
                'Resumable video upload failed: $resumableError. Standard upload retry also failed: $fallbackError',
              );
            }
          }
        } else {
          // Small videos use the same Storage SDK upload path as graphics.
          // TUS is reserved for larger videos, where chunked transfer matters.
          final data = bytes[file] ?? await file.readAsBytes();
          await db.storage
              .from('idea-media')
              .uploadBinary(
                path,
                data,
                fileOptions: FileOptions(
                  contentType: mime,
                  cacheControl: '3600',
                  upsert: false,
                ),
                retryAttempts: 2,
              );
        }
        _trace('storage.video_or_image.done name=${file.name}');
        completedUploads++;
        onProgress(completedUploads, uploadCount);
        String? thumbnailPath;
        if (mime == 'video/mp4') {
          final cover = videoCovers[file];
          if (cover == null) {
            throw ArgumentError('Choose a cover image for ${file.name}.');
          }
          final coverData = bytes[cover] ?? await cover.readAsBytes();
          _trace(
            'cover.read name=${cover.name} bytes=${coverData.length} mime=${cover.mimeType ?? 'unknown'}',
          );
          final coverExtension = cover.name.split('.').last.toLowerCase();
          final coverMime = switch (coverExtension) {
            'jpg' || 'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => throw ArgumentError('Choose a JPG, PNG, or WebP video cover.'),
          };
          if (coverData.isEmpty || coverData.length > 2 * 1024 * 1024) {
            throw ArgumentError('Video covers must be no larger than 2 MiB.');
          }
          thumbnailPath = '${user.id}/$id/${_newUuid()}.$coverExtension';
          await db.storage
              .from('idea-media')
              .uploadBinary(
                thumbnailPath,
                coverData,
                fileOptions: FileOptions(
                  contentType: coverMime,
                  cacheControl: '3600',
                  upsert: false,
                ),
                retryAttempts: 2,
              );
          _trace('cover.upload.done path=$thumbnailPath');
          uploaded.add(thumbnailPath);
          thumbnailUploads.add(thumbnailPath);
          completedUploads++;
          onProgress(completedUploads, uploadCount);
        }
        mediaRows.add({
          'post_id': id,
          'storage_path': path,
          'mime_type': mime,
          'position': index,
          if (thumbnailPath != null) 'thumbnail_url': thumbnailPath,
        });
      }
      if (isCancelled()) throw const IdeaLabUploadCancelled();
      await db.from('idea_posts').insert({
        'id': id,
        'creator_id': user.id,
        'caption': caption.trim(),
        'category_id': categoryRow['id'],
        'music_metadata': music?.toJson(),
        ...postSettings,
      });
      metadataCreated = true;
      _trace('database.draft_insert.done postId=$id');
      await db.from('idea_post_media').insert(mediaRows);
      _trace('database.media_insert.done count=${mediaRows.length}');
      for (final path in uploaded) {
        _trace(
          'validation.invoke.start path=$path action=${thumbnailUploads.contains(path) ? 'thumbnail' : 'media'}',
        );
        final validation = await _invokeMediaValidator(
          thumbnailUploads.contains(path)
              ? {
                  'action': 'thumbnail',
                  'post_id': id,
                  'bucket': 'idea-media',
                  'path': path,
                }
              : {
                  'bucket': 'idea-media',
                  'path': path,
                  if (path.toLowerCase().endsWith('.mp4'))
                    'max_duration_seconds': maxVideoDurationSeconds,
                },
        );
        _trace(
          'validation.invoke.response path=$path status=${validation.status} body=${validation.data}',
        );
        if (validation.status < 200 || validation.status >= 300) {
          throw StateError(
            EdgeFunctionErrors.friendlyMessage(
              validation.data,
              fallback: 'The uploaded file could not be verified.',
              status: validation.status,
            ),
          );
        }
      }
      if (videos.isNotEmpty) {
        final verifiedRows = await db
            .from('idea_post_media')
            .select(
              'storage_path,mime_type,video_validated,width,height,thumbnail_url',
            )
            .eq('post_id', id);
        final videoRows = (verifiedRows as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .where((row) => row['mime_type'] == 'video/mp4')
            .toList();
        if (videoRows.isEmpty) {
          throw StateError(
            'The video was uploaded, but its staged media record could not be read back. Retry the upload.',
          );
        }
        final videoRow = videoRows.first;
        if (videoRow['storage_path'] != mediaRows.first['storage_path'] ||
            videoRow['video_validated'] != true) {
          throw StateError(
            'The server validator did not mark the uploaded video as verified. The post was not published; check the deployed validate-idea-media function.',
          );
        }
        final width = (videoRow['width'] as num?)?.toDouble();
        final height = (videoRow['height'] as num?)?.toDouble();
        final ratio = width != null && height != null && height > 0
            ? width / height
            : null;
        if (ratio == null || ratio < 0.5 || ratio > 2.4) {
          throw StateError(
            'The server validator did not save valid video dimensions. Re-export the video as a standard MP4 and retry.',
          );
        }
      }
      final normalizedTags = tags
          .map((tag) => tag.trim().toLowerCase())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .take(10)
          .toList();
      if (normalizedTags.isNotEmpty) {
        await db.from('idea_post_tags').insert([
          for (final tag in normalizedTags) {'post_id': id, 'tag': tag},
        ]);
      }
      await db
          .from('idea_posts')
          .update({'published_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
      _trace('database.publish.done postId=$id');
    } catch (error, stack) {
      _trace(
        'publish.error error=$error stack=$stack uploadedCount=${uploaded.length} metadataCreated=$metadataCreated',
      );
      if (uploaded.isNotEmpty) {
        try {
          await db.storage.from('idea-media').remove(uploaded);
          _trace('cleanup.storage.done count=${uploaded.length}');
        } catch (cleanupError) {
          _trace('cleanup.storage.error error=$cleanupError');
        }
      }
      if (metadataCreated) {
        try {
          await db.from('idea_posts').delete().eq('id', id);
          _trace('cleanup.database.done postId=$id');
        } catch (cleanupError) {
          _trace('cleanup.database.error error=$cleanupError');
        }
      }
      rethrow;
    }
  }

  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _uploadVideoResumable({
    required XFile file,
    required String path,
    required String mimeType,
    required int totalBytes,
    required void Function(int sentBytes, int totalBytes)? onProgress,
    required bool Function() isCancelled,
  }) async {
    _trace('tus.start name=${file.name} size=$totalBytes mime=$mimeType');
    final client = http.Client();
    try {
      final session = IdeaLabBackend.client.auth.currentSession;
      if (session == null) {
        throw StateError('Your session expired. Sign in and try again.');
      }
      final projectUri = Uri.parse(IdeaLabBackend.projectUrl);
      final projectRef = projectUri.host.split('.').first;
      final tusUri = Uri.https(
        '$projectRef.storage.supabase.co',
        '/storage/v1/upload/resumable',
      );
      String metadata(String value) => base64.encode(utf8.encode(value));
      final create = http.Request('POST', tusUri)
        ..headers.addAll({
          'apikey': IdeaLabBackend.publishableKey,
          'Authorization': 'Bearer ${session.accessToken}',
          'Tus-Resumable': '1.0.0',
          'Upload-Length': '$totalBytes',
          'Upload-Metadata':
              'bucketName ${metadata('idea-media')},objectName ${metadata(path)},contentType ${metadata(mimeType)},cacheControl ${metadata('3600')}',
          'x-upsert': 'false',
        });
      final created = await client.send(create);
      final createBody = await created.stream.bytesToString();
      _trace(
        'tus.create.response status=${created.statusCode} body=$createBody locationPresent=${created.headers['location']?.isNotEmpty == true}',
      );
      if (created.statusCode < 200 || created.statusCode >= 300) {
        throw StateError(
          _videoStorageFailure(
            'Could not start resumable upload',
            created.statusCode,
            createBody,
          ),
        );
      }
      final location = created.headers['location'];
      if (location == null || location.isEmpty) {
        throw StateError('Storage did not return a resumable upload URL.');
      }
      final uploadUri = tusUri.resolve(location);
      var offset = 0;
      while (offset < totalBytes) {
        if (isCancelled()) throw const IdeaLabUploadCancelled();
        final end = (offset + _tusChunkBytes).clamp(0, totalBytes);
        final builder = BytesBuilder(copy: false);
        await for (final chunk in file.openRead(offset, end)) {
          builder.add(chunk);
        }
        final chunkBytes = builder.takeBytes();
        _trace(
          'tus.chunk.read start=$offset end=$end bytes=${chunkBytes.length}',
        );
        if (chunkBytes.isEmpty || chunkBytes.length != end - offset) {
          throw StateError(
            'Could not read video bytes ${offset + 1}–$end of ${file.name}.',
          );
        }
        var uploaded = false;
        Object? lastError;
        for (var attempt = 0; attempt < 3 && !uploaded; attempt++) {
          if (isCancelled()) throw const IdeaLabUploadCancelled();
          try {
            final patch = http.Request('PATCH', uploadUri)
              ..headers.addAll({
                'apikey': IdeaLabBackend.publishableKey,
                'Authorization': 'Bearer ${session.accessToken}',
                'Tus-Resumable': '1.0.0',
                'Upload-Offset': '$offset',
                'Content-Type': 'application/offset+octet-stream',
              })
              ..bodyBytes = chunkBytes;
            final response = await client.send(patch);
            final body = await response.stream.bytesToString();
            _trace(
              'tus.chunk.response status=${response.statusCode} offset=$offset end=$end body=$body',
            );
            if (response.statusCode == 204) {
              offset =
                  int.tryParse(response.headers['upload-offset'] ?? '') ?? end;
              uploaded = true;
            } else if (response.statusCode == 409) {
              final head = http.Request('HEAD', uploadUri)
                ..headers.addAll({
                  'apikey': IdeaLabBackend.publishableKey,
                  'Authorization': 'Bearer ${session.accessToken}',
                  'Tus-Resumable': '1.0.0',
                });
              final headResponse = await client.send(head);
              await headResponse.stream.drain<void>();
              final serverOffset = int.tryParse(
                headResponse.headers['upload-offset'] ?? '',
              );
              if (serverOffset == null ||
                  (serverOffset != offset && serverOffset != end)) {
                throw StateError(
                  'Storage upload position could not be recovered.',
                );
              }
              if (serverOffset == end) {
                offset = end;
                uploaded = true;
              }
            } else {
              throw StateError(
                _videoStorageFailure(
                  'Video chunk upload failed',
                  response.statusCode,
                  body,
                ),
              );
            }
          } catch (error) {
            lastError = error;
            if ('$error'.contains('(413)') || '$error'.contains('(403)')) {
              rethrow;
            }
            if (attempt < 2) {
              await Future<void>.delayed(
                Duration(milliseconds: 500 * (attempt + 1)),
              );
            }
          }
        }
        onProgress?.call(offset, totalBytes);
        _trace('tus.progress sent=$offset total=$totalBytes');
        if (!uploaded) {
          throw StateError(
            'Video upload stopped at ${(offset / (1024 * 1024)).toStringAsFixed(1)} MiB. ${lastError ?? 'Retry the upload.'}',
          );
        }
      }
      _trace('tus.done name=${file.name} total=$totalBytes');
    } catch (error, stack) {
      _trace('tus.error name=${file.name} error=$error stack=$stack');
      rethrow;
    } finally {
      client.close();
    }
  }

  String _responseDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return '${decoded['message'] ?? decoded['error'] ?? body}';
      }
    } catch (_) {}
    return body.trim().isEmpty
        ? 'No additional details were returned.'
        : body.trim();
  }

  String _videoStorageFailure(String action, int statusCode, String body) {
    final detail = _responseDetail(body);
    if (statusCode == 413) {
      return '$action (413): Supabase Storage rejected this file because it exceeds the Free-plan 50 MB upload ceiling. Trim or compress the video, then retry.';
    }
    if (statusCode == 403) {
      return '$action (403): Storage denied this upload. Confirm migration 202610170014_idea_media_upload_rls_fix.sql is applied and that you are signed in. $detail';
    }
    return '$action ($statusCode): $detail';
  }
}

class IdeaLabStory {
  const IdeaLabStory({
    required this.id,
    required this.creatorId,
    required this.creator,
    required this.avatarUrl,
    required this.createdAt,
    required this.url,
    required this.storagePath,
    required this.mimeType,
    required this.expiresAt,
    required this.seen,
    this.repliesAccess = 'everyone',
    this.allowResharing = true,
    this.locationLabel,
    this.music,
  });

  final String id;
  final String creatorId;
  final String creator;
  final String? avatarUrl;
  final DateTime createdAt;
  final String url;
  final String storagePath;
  final String mimeType;
  final DateTime expiresAt;
  final bool seen;
  final String repliesAccess;
  final bool allowResharing;
  final String? locationLabel;
  final IdeaMusicSelection? music;

  static Future<IdeaLabStory> fromJson(
    Map<String, dynamic> json, {
    required String url,
  }) async {
    final profile = json['idea_profiles'] as Map<String, dynamic>?;
    final avatarPath = profile?['avatar_path'] as String?;
    final views = json['idea_story_views'] as List<dynamic>? ?? const [];
    return IdeaLabStory(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      creator: profile?['display_name'] as String? ?? 'Creator',
      avatarUrl: avatarPath == null
          ? null
          : await IdeaLabBackend.signedMediaUrl('idea-avatars', avatarPath),
      createdAt: DateTime.parse(json['created_at'] as String),
      url: url,
      storagePath: json['storage_path'] as String,
      mimeType: json['mime_type'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      seen: views.isNotEmpty,
      repliesAccess: json['replies_access'] as String? ?? 'everyone',
      allowResharing: json['allow_resharing'] != false,
      locationLabel: json['location_label'] as String?,
      music: json['music_metadata'] is Map
          ? IdeaMusicSelection.fromJson(
              Map<String, dynamic>.from(json['music_metadata'] as Map),
            )
          : null,
    );
  }
}

class IdeaLabStoryService {
  static const maxStoryBytes = 50 * 1024 * 1024;

  Future<dynamic> _invokeMediaValidator(Map<String, dynamic> body) async {
    try {
      return await IdeaLabBackend.client.functions.invoke(
        'validate-idea-media',
        body: body,
      );
    } on FunctionException catch (error) {
      throw StateError(
        EdgeFunctionErrors.friendlyMessage(
          error.details,
          fallback: 'The media verifier is temporarily unavailable.',
          status: error.status,
        ),
      );
    }
  }

  Future<List<IdeaLabStory>> fetchActive() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final viewsSelection = IdeaLabBackend.currentUser == null
        ? ''
        : ',idea_story_views(viewer_id)';
    final rows = await IdeaLabBackend.client
        .from('idea_stories')
        .select(
          'id,creator_id,storage_path,mime_type,created_at,expires_at,music_metadata,replies_access,allow_resharing,location_label,idea_profiles(display_name,avatar_path)$viewsSelection',
        )
        .gt('expires_at', now)
        .eq('media_validated', true)
        .order('created_at', ascending: true);
    final stories = <IdeaLabStory>[];
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final expiresAt = DateTime.parse(row['expires_at'] as String);
      final remaining = expiresAt.difference(DateTime.now().toUtc()).inSeconds;
      if (remaining <= 0) continue;
      final signed = await IdeaLabBackend.client.storage
          .from('idea-stories')
          .createSignedUrl(
            row['storage_path'] as String,
            remaining < 60 ? remaining : 60,
          );
      stories.add(await IdeaLabStory.fromJson(row, url: signed));
    }
    return stories;
  }

  Future<String> signedUrl(IdeaLabStory story) async {
    final remaining = story.expiresAt
        .difference(DateTime.now().toUtc())
        .inSeconds;
    if (remaining <= 0) throw StateError('This story has expired.');
    return IdeaLabBackend.client.storage
        .from('idea-stories')
        .createSignedUrl(story.storagePath, remaining < 60 ? remaining : 60);
  }

  Future<void> publish(
    XFile file, {
    IdeaMusicSelection? music,
    String repliesAccess = 'everyone',
    bool allowResharing = true,
    String? locationLabel,
    List<String> hiddenUserIds = const [],
  }) async {
    final user = IdeaLabBackend.client.auth.currentUser;
    if (user == null) throw StateError('Sign in to publish a story.');
    final extension = file.name.split('.').last.toLowerCase();
    final mime = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      _ => throw ArgumentError('Stories support JPG, PNG, WebP, or MP4.'),
    };
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxStoryBytes) {
      throw ArgumentError('The story must be smaller than 50 MiB.');
    }
    final client = IdeaLabBackend.client;
    final id = _uuid();
    final path = '${user.id}/$id/${_uuid()}.$extension';
    var objectUploaded = false;
    var rowInserted = false;
    try {
      await client.storage
          .from('idea-stories')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: false),
            retryAttempts: 2,
          );
      objectUploaded = true;
      await client.from('idea_stories').insert({
        'id': id,
        'creator_id': user.id,
        'storage_path': path,
        'mime_type': mime,
        'music_metadata': music?.toJson(),
        'replies_access': repliesAccess,
        'allow_resharing': allowResharing,
        'location_label': locationLabel?.trim().isEmpty == true ? null : locationLabel?.trim(),
      });
      rowInserted = true;
      if (hiddenUserIds.isNotEmpty) {
        await client.from('idea_story_hidden_users').insert([
          for (final hiddenUserId in hiddenUserIds)
            {'story_id': id, 'owner_id': user.id, 'hidden_user_id': hiddenUserId},
        ]);
      }
      final validation = await _invokeMediaValidator(
        {'bucket': 'idea-stories', 'path': path},
      );
      if (validation.status < 200 || validation.status >= 300) {
        throw StateError(
          EdgeFunctionErrors.friendlyMessage(
            validation.data,
            fallback: 'The server rejected this story media.',
            status: validation.status,
          ),
        );
      }
    } catch (_) {
      if (rowInserted) {
        try {
          await client.from('idea_stories').delete().eq('id', id);
        } catch (_) {}
      }
      if (objectUploaded) {
        try {
          await client.storage.from('idea-stories').remove([path]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> markViewed(String storyId) async {
    final user = IdeaLabBackend.client.auth.currentUser;
    if (user == null) return;
    await IdeaLabBackend.client.from('idea_story_views').upsert({
      'story_id': storyId,
      'viewer_id': user.id,
    }, onConflict: 'story_id,viewer_id');
  }

  Future<void> delete(IdeaLabStory story) async {
    final client = IdeaLabBackend.client;
    await client.storage.from('idea-stories').remove([story.storagePath]);
    await client.from('idea_stories').delete().eq('id', story.id);
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class IdeaLabUploadCancelled implements Exception {
  const IdeaLabUploadCancelled();
}
