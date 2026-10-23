import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'edge_function_errors.dart';
import 'idea_lab_backend.dart';
import 'user_input_sanitizer.dart';

class IdeaLabCreatorProfile {
  const IdeaLabCreatorProfile({
    required this.id,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.avatarUrl,
    this.isPrivate = false,
  });

  final String id;
  final String displayName;
  final String? username;
  final String bio;
  final String? avatarUrl;
  final bool isPrivate;

  static Future<IdeaLabCreatorProfile> fromJson(Map<String, dynamic> row) async {
    final path = row['avatar_path'] as String?;
    return IdeaLabCreatorProfile(
      id: row['id'] as String,
      displayName: row['display_name'] as String? ?? 'Creator',
      username: row['username'] as String?,
      bio: row['bio'] as String? ?? '',
      avatarUrl: path == null ? null : await IdeaLabBackend.signedMediaUrl('idea-avatars', path),
      isPrivate: row['is_private'] == true,
    );
  }
}

class IdeaConversationPreview {
  const IdeaConversationPreview({
    required this.profile,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final IdeaLabCreatorProfile profile;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
}

class IdeaLabSocialService {
  static final ValueNotifier<(String, String?)?> currentUserAvatar =
      ValueNotifier(null);

  SupabaseClient get _client => IdeaLabBackend.client;

  String get currentUserId => _client.auth.currentUser!.id;

  Future<IdeaLabCreatorProfile> profile(String id) async {
    final row = await _client
        .from('idea_profiles')
        .select('id,display_name,username,bio,avatar_path,is_private')
        .eq('id', id)
        .single();
    final profile =
        await IdeaLabCreatorProfile.fromJson(Map<String, dynamic>.from(row));
    if (_client.auth.currentUser?.id == id) {
      currentUserAvatar.value = (id, profile.avatarUrl);
    }
    return profile;
  }

  Future<(int posts, int followers, int following)> counts(String id) async {
    final rows = await _client.rpc('idea_profile_counts', params: {
      'target_profile': id,
    });
    if ((rows as List).isEmpty) return (0, 0, 0);
    final row = rows.first as Map;
    return (
      (row['post_count'] as num).toInt(),
      (row['follower_count'] as num).toInt(),
      (row['following_count'] as num).toInt(),
    );
  }

  Future<bool> isFollowing(String id) async {
    final rows = await _client
        .from('idea_follows')
        .select('follower_id')
        .eq('follower_id', currentUserId)
        .eq('followed_id', id)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> toggleFollow(String id, {required bool following}) async {
    if (following) {
      await _client
          .from('idea_follows')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('followed_id', id);
    } else {
      await _client.rpc('request_idea_follow', params: {'target_profile': id});
    }
  }

  Future<bool> hasFollowRequest(String id) async {
    final rows = await _client.from('idea_follow_requests').select('requester_id')
        .eq('requester_id', currentUserId).eq('target_id', id).limit(1);
    return rows.isNotEmpty;
  }

  Future<bool> isBlocked(String id) async {
    final rows = await _client.from('idea_blocks').select('blocked_id')
        .eq('blocker_id', currentUserId).eq('blocked_id', id).limit(1);
    return rows.isNotEmpty;
  }

  Future<void> setBlocked(String id, {required bool blocked}) async {
    if (blocked) {
      await _client.from('idea_blocks').insert({'blocker_id': currentUserId, 'blocked_id': id});
    } else {
      await _client.from('idea_blocks').delete().eq('blocker_id', currentUserId).eq('blocked_id', id);
    }
  }

  Future<void> setPrivate(bool value) async {
    await _client.from('idea_profiles').update({'is_private': value}).eq('id', currentUserId);
  }

  Future<bool> currentProfileIsPrivate() async {
    final row = await _client.from('idea_profiles').select('is_private')
        .eq('id', currentUserId).single();
    return row['is_private'] == true;
  }

  Future<Map<String, dynamic>> storyPreferences() async {
    final row = await _client.from('idea_story_preferences')
        .select('replies_access,allow_resharing').eq('user_id', currentUserId).maybeSingle();
    return row == null
        ? {'replies_access': 'everyone', 'allow_resharing': true}
        : Map<String, dynamic>.from(row);
  }

  Future<void> saveStoryPreferences({required String repliesAccess, required bool allowResharing}) async {
    await _client.from('idea_story_preferences').upsert({
      'user_id': currentUserId,
      'replies_access': repliesAccess,
      'allow_resharing': allowResharing,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<IdeaLabCreatorProfile>> storyHideCandidates() async {
    final rows = await _client.rpc('list_idea_story_hide_candidates');
    return Future.wait((rows as List).map((row) => IdeaLabCreatorProfile.fromJson(
      Map<String, dynamic>.from(row as Map),
    )));
  }

  Future<List<Map<String, dynamic>>> incomingFollowRequests() async {
    final rows = await _client.from('idea_follow_requests')
        .select('requester_id,target_id,created_at,profile:idea_profiles!idea_follow_requests_requester_id_fkey(id,display_name,username,bio,avatar_path,is_private)')
        .eq('target_id', currentUserId).order('created_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> respondToFollowRequest(String requesterId, {required bool approve}) async {
    await _client.rpc('respond_idea_follow_request', params: {
      'requester': requesterId, 'approve': approve,
    });
  }

  Future<List<Map<String, dynamic>>> blockedProfiles() async {
    final rows = await _client.rpc('list_idea_blocked_profiles');
    return (rows as List).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<IdeaLabCreatorProfile>> followList(String profileId,
      {required bool followers}) async {
    final rows = await _client
        .from('idea_follows')
        .select(followers ? 'follower_id' : 'followed_id')
        .eq(followers ? 'followed_id' : 'follower_id', profileId)
        .limit(100);
    final ids = rows
        .map((row) => row[followers ? 'follower_id' : 'followed_id'] as String)
        .toList();
    if (ids.isEmpty) return const [];
    final profiles = await _client
        .from('idea_profiles')
        .select('id,display_name,username,bio,avatar_path,is_private')
        .inFilter('id', ids);
    return Future.wait(profiles.map((row) => IdeaLabCreatorProfile.fromJson(Map<String, dynamic>.from(row))));
  }

  Future<void> recordPostView(String postId) async {
    await _client.rpc('record_idea_post_view', params: {'target_post': postId});
  }

  Future<Map<String, int>> postViewCounts(List<String> postIds) async {
    if (postIds.isEmpty) return const {};
    final rows = await _client.rpc('idea_post_view_counts', params: {
      'target_posts': postIds,
    });
    return {
      for (final row in rows as List)
        row['post_id'] as String: (row['view_count'] as num).toInt(),
    };
  }

  Future<void> updateProfile({
    required String displayName,
    required String username,
    required String bio,
  }) async {
    final safeDisplayName = UserInputSanitizer.profileText(displayName);
    final safeBio = UserInputSanitizer.profileText(bio);
    if (safeDisplayName.isEmpty || safeDisplayName.length > 80) {
      throw ArgumentError('Name must be between 1 and 80 characters.');
    }
    if (safeBio.length > 160) {
      throw ArgumentError('About you must be 160 characters or fewer.');
    }
    final normalizedUsername = username.trim().replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[a-zA-Z0-9_.]{3,30}$').hasMatch(normalizedUsername)) {
      throw ArgumentError('Username must be 3–30 letters, numbers, dots, or underscores.');
    }
    await _client.from('idea_profiles').update({
      'display_name': safeDisplayName,
      'username': normalizedUsername.toLowerCase(),
      'bio': safeBio,
    }).eq('id', currentUserId);
  }

  Future<void> uploadAvatar(XFile file) async {
    final extension = file.name.split('.').last.toLowerCase();
    final mime = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw ArgumentError('Choose a JPG, PNG, or WebP profile photo.'),
    };
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw ArgumentError('Profile photos must be under 5 MiB.');
    }
    final path = '$currentUserId/avatar.$extension';
    await _client.storage.from('idea-avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: true),
        );
    await _client
        .from('idea_profiles')
        .update({'avatar_path': path})
        .eq('id', currentUserId);
  }

  Future<List<IdeaLabCreatorProfile>> searchCreators(String query) async {
    final value = query.trim().replaceFirst(RegExp(r'^@'), '');
    if (value.length < 2) return const [];
    final rows = await _client
        .from('idea_profiles')
        .select('id,display_name,username,bio,avatar_path,is_private')
        .ilike('username', '%$value%')
        .neq('id', currentUserId)
        .limit(20);
    return Future.wait(rows.map((row) => IdeaLabCreatorProfile.fromJson(Map<String, dynamic>.from(row))));
  }

  Future<List<IdeaLabCreatorProfile>> matchContacts({
    required List<String> emails,
    required List<String> phones,
  }) async {
    late final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'match-idea-contacts',
        body: {'emails': emails, 'phones': phones},
      );
    } on FunctionException catch (error) {
      throw StateError(
        EdgeFunctionErrors.friendlyMessage(
          error.details,
          fallback: 'Contact matching is temporarily unavailable.',
          status: error.status,
        ),
      );
    }
    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        EdgeFunctionErrors.friendlyMessage(
          response.data,
          fallback: 'Contact matching is temporarily unavailable.',
          status: response.status,
        ),
      );
    }
    final rows = (response.data['matches'] as List<dynamic>? ?? const []);
    return Future.wait(rows.map((row) => IdeaLabCreatorProfile.fromJson(Map<String, dynamic>.from(row as Map))));
  }

  Future<List<Map<String, dynamic>>> thread(String otherUserId) async {
    final me = currentUserId;
    return _messagesBetween(
      me,
      otherUserId,
      columns: 'id,sender_id,recipient_id,body,created_at,read_at',
    );
  }

  Future<void> sendMessage(String recipientId, String text) async {
    if (recipientId == currentUserId) {
      throw ArgumentError('You cannot send a message to yourself.');
    }
    final body = text.trim();
    if (body.isEmpty || body.length > 4000) {
      throw ArgumentError('A message must be between 1 and 4000 characters.');
    }
    await _client.from('idea_messages').insert({
      'sender_id': currentUserId,
      'recipient_id': recipientId,
      'body': body,
    });
  }

  Future<void> markRead(String messageId) async {
    await _client
        .from('idea_messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', messageId)
        .eq('recipient_id', currentUserId);
  }

  Future<(int likes, int comments, bool liked)> postEngagement(
    String postId,
  ) async {
    final rows = await _client.rpc('idea_post_engagement_counts', params: {
      'target_post': postId,
    });
    final row = (rows as List).first as Map;
    final likedRows = await _client
        .from('idea_post_likes')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', currentUserId)
        .limit(1);
    return (
      (row['like_count'] as num).toInt(),
      (row['comment_count'] as num).toInt(),
      likedRows.isNotEmpty,
    );
  }

  Future<void> togglePostLike(String postId, {required bool liked}) async {
    if (liked) {
      await _client
          .from('idea_post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', currentUserId);
    } else {
      await _client.from('idea_post_likes').insert({
        'post_id': postId,
        'user_id': currentUserId,
      });
    }
  }

  Future<List<Map<String, dynamic>>> postComments(String postId) async {
    final rows = await _client
        .from('idea_post_comments')
        .select('id,post_id,author_id,parent_comment_id,body,created_at,author:idea_profiles!idea_post_comments_author_id_fkey(display_name,avatar_path)')
        .eq('post_id', postId)
        .order('created_at');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> addPostComment(
    String postId,
    String body, {
    String? parentCommentId,
  }) async {
    final text = body.trim();
    if (text.isEmpty || text.length > 2200) {
      throw ArgumentError('Comments must contain 1 to 2200 characters.');
    }
    await _client.from('idea_post_comments').insert({
      'post_id': postId,
      'author_id': currentUserId,
      'parent_comment_id': parentCommentId,
      'body': text,
    });
  }

  Future<(int likes, bool liked, int comments)> storyEngagement(String storyId) async {
    final likes = await _client.from('idea_story_likes').select('user_id').eq('story_id', storyId);
    final comments = await _client.from('idea_story_comments').select('id').eq('story_id', storyId);
    return (
      likes.length,
      likes.any((row) => row['user_id'] == currentUserId),
      comments.length,
    );
  }

  Future<void> toggleStoryLike(String storyId, {required bool liked}) async {
    if (liked) {
      await _client.from('idea_story_likes').delete().eq('story_id', storyId).eq('user_id', currentUserId);
    } else {
      await _client.from('idea_story_likes').insert({'story_id': storyId, 'user_id': currentUserId});
    }
  }

  Future<List<Map<String, dynamic>>> storyComments(String storyId) async {
    final rows = await _client
        .from('idea_story_comments')
        .select('id,body,created_at,author:idea_profiles!idea_story_comments_author_id_fkey(display_name,avatar_path)')
        .eq('story_id', storyId)
        .order('created_at');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> addStoryComment(String storyId, String body) async {
    final text = body.trim();
    if (text.isEmpty || text.length > 1000) {
      throw ArgumentError('Story comments must contain 1 to 1000 characters.');
    }
    await _client.from('idea_story_comments').insert({
      'story_id': storyId,
      'author_id': currentUserId,
      'body': text,
    });
  }

  Future<void> reportPost(String postId, String reason, String details) async {
    await _client.from('idea_post_reports').insert({
      'post_id': postId,
      'reporter_id': currentUserId,
      'reason': reason,
      'details': details.trim(),
    });
  }

  Future<List<IdeaLabCreatorProfile>> conversationPartners() async {
    final rows = (await _messagesForUser(
      currentUserId,
      columns: 'id,sender_id,recipient_id,created_at',
      descending: true,
    )).take(100);
    final ids = <String>{};
    for (final row in rows) {
      final other = row['sender_id'] == currentUserId
          ? row['recipient_id'] as String
          : row['sender_id'] as String;
      ids.add(other);
    }
    if (ids.isEmpty) return const [];
    final profiles = await _client
        .from('idea_profiles')
        .select('id,display_name,username,bio,avatar_path,is_private')
        .inFilter('id', ids.toList());
    return Future.wait(profiles.map((row) => IdeaLabCreatorProfile.fromJson(Map<String, dynamic>.from(row))));
  }

  Future<List<IdeaConversationPreview>> conversationPreviews() async {
    final rows = (await _messagesForUser(
      currentUserId,
      columns: 'id,sender_id,recipient_id,body,created_at,read_at',
      descending: true,
    )).take(300);
    final latestByPerson = <String, Map<String, dynamic>>{};
    final unreadByPerson = <String, int>{};
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final otherId = row['sender_id'] == currentUserId
          ? row['recipient_id'] as String
          : row['sender_id'] as String;
      latestByPerson.putIfAbsent(otherId, () => row);
      if (row['recipient_id'] == currentUserId && row['read_at'] == null) {
        unreadByPerson.update(otherId, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    if (latestByPerson.isEmpty) return const [];
    final profileRows = await _client
        .from('idea_profiles')
        .select('id,display_name,username,bio,avatar_path')
        .inFilter('id', latestByPerson.keys.toList());
    final parsedProfiles = await Future.wait(profileRows.map((row) => IdeaLabCreatorProfile.fromJson(Map<String, dynamic>.from(row))));
    final profiles = {for (final profile in parsedProfiles) profile.id: profile};
    return [
      for (final entry in latestByPerson.entries)
        if (profiles[entry.key] case final profile?)
          IdeaConversationPreview(
            profile: profile,
            lastMessage: entry.value['body'] as String,
            lastMessageAt: DateTime.parse(entry.value['created_at'] as String),
            unreadCount: unreadByPerson[entry.key] ?? 0,
          ),
    ];
  }

  int _compareMessagesAscending(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final byTime = DateTime.parse(
      left['created_at'] as String,
    ).compareTo(DateTime.parse(right['created_at'] as String));
    if (byTime != 0) return byTime;
    return (left['id'] as String).compareTo(right['id'] as String);
  }

  /// Fetches a conversation using equality filters, which PostgREST encodes as
  /// query parameters. Avoid raw `.or()` filter strings: interpolating IDs into
  /// that grammar can change the filter expression.
  Future<List<Map<String, dynamic>>> _messagesBetween(
    String firstUserId,
    String secondUserId, {
    required String columns,
    bool descending = false,
  }) async {
    final responses = await Future.wait([
      _client
          .from('idea_messages')
          .select(columns)
          .eq('sender_id', firstUserId)
          .eq('recipient_id', secondUserId),
      _client
          .from('idea_messages')
          .select(columns)
          .eq('sender_id', secondUserId)
          .eq('recipient_id', firstUserId),
    ]);
    return _mergeMessageResponses(responses, descending: descending);
  }

  Future<List<Map<String, dynamic>>> _messagesForUser(
    String userId, {
    required String columns,
    bool descending = false,
  }) async {
    final responses = await Future.wait([
      _client.from('idea_messages').select(columns).eq('sender_id', userId),
      _client.from('idea_messages').select(columns).eq('recipient_id', userId),
    ]);
    return _mergeMessageResponses(responses, descending: descending);
  }

  List<Map<String, dynamic>> _mergeMessageResponses(
    List<dynamic> responses, {
    required bool descending,
  }) {
    final rowsById = <String, Map<String, dynamic>>{};
    for (final row in responses.expand((response) => response)) {
      final message = Map<String, dynamic>.from(row);
      rowsById[message['id'] as String] = message;
    }
    final messages = rowsById.values.toList();
    messages.sort(descending
        ? (left, right) => _compareMessagesAscending(right, left)
        : _compareMessagesAscending);
    return messages;
  }
}
