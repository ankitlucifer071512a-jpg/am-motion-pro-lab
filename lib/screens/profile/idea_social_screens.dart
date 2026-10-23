import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_appearance.dart';
import '../../services/idea_lab_backend.dart';
import '../../services/idea_lab_social_service.dart';
import '../../services/idea_watch_history_service.dart';
import '../../services/idea_device_account_store.dart';
import '../../services/idea_motion_preferences.dart';
import '../../services/idea_video_preferences.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/app_emoji_picker_button.dart';
import '../../widgets/creator_music_list.dart';
import '../../widgets/idea_community_video_preview.dart';
import '../../widgets/idea_post_media_player.dart';
import '../idea_lab/idea_music_library_screen.dart';
import 'support_screen.dart';

String _formatMessageError(Object error) {
  final value = '$error';
  if (value.contains('idea_messages')) {
    return 'Messages database setup is missing. From the project folder run: npx supabase db push (migration 202610160002_idea_social.sql), then reload the app.';
  }
  return value;
}

class IdeaCreatorScreen extends StatefulWidget {
  const IdeaCreatorScreen({super.key, required this.creatorId});
  final String creatorId;

  @override
  State<IdeaCreatorScreen> createState() => _IdeaCreatorScreenState();
}

class _IdeaCreatorScreenState extends State<IdeaCreatorScreen> {
  final _social = IdeaLabSocialService();
  final _posts = IdeaLabPostService();
  IdeaLabCreatorProfile? _profile;
  List<IdeaLabPost> _items = [];
  Map<String, int> _views = {};
  (int, int, int)? _counts;
  bool _following = false;
  bool _followRequested = false;
  bool _blocked = false;
  bool _loading = true;
  bool _postsHaveMore = false;
  bool _loadingMore = false;
  String? _error;
  int _profileTab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Future.wait([
        _social.profile(widget.creatorId),
        _posts.fetchCreatorPosts(widget.creatorId),
        _social.counts(widget.creatorId),
        if (IdeaLabBackend.currentUser?.id != widget.creatorId)
          _social.isFollowing(widget.creatorId),
        if (IdeaLabBackend.currentUser?.id != widget.creatorId)
          _social.hasFollowRequest(widget.creatorId),
        if (IdeaLabBackend.currentUser?.id != widget.creatorId)
          _social.isBlocked(widget.creatorId),
      ]);
      final profile = data[0] as IdeaLabCreatorProfile;
      final items = data[1] as List<IdeaLabPost>;
      final counts = data[2] as (int, int, int);
      final following = data.length > 3 ? data[3] as bool : false;
      final otherProfile = IdeaLabBackend.currentUser?.id != widget.creatorId;
      final requested = otherProfile && data.length > 4
          ? data[4] as bool
          : false;
      final blocked = otherProfile && data.length > 5 ? data[5] as bool : false;
      final views = await _social.postViewCounts(
        items.map((e) => e.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _items = items;
        _postsHaveMore = items.length == IdeaLabPostService.pageSize;
        _counts = counts;
        _following = following;
        _followRequested = requested;
        _blocked = blocked;
        _views = views;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _follow() async {
    try {
      if (_followRequested) {
        await IdeaLabBackend.client
            .from('idea_follow_requests')
            .delete()
            .eq('requester_id', IdeaLabBackend.currentUser!.id)
            .eq('target_id', widget.creatorId);
      } else {
        await _social.toggleFollow(widget.creatorId, following: _following);
      }
      await _load();
    } catch (error) {
      _message('Could not update follow: $error');
    }
  }

  Future<void> _toggleBlock() async {
    try {
      await _social.setBlocked(widget.creatorId, blocked: !_blocked);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _message('Could not update block: $error');
    }
  }

  Future<void> _loadMorePosts() async {
    if (_loadingMore || !_postsHaveMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await _posts.fetchCreatorPosts(
        widget.creatorId,
        offset: _items.length,
      );
      final views = await _social.postViewCounts(
        next.map((post) => post.id).toList(),
      );
      if (mounted) {
        setState(() {
          _items.addAll(next);
          _views.addAll(views);
          _postsHaveMore = next.length == IdeaLabPostService.pageSize;
          _loadingMore = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingMore = false;
          _error = '$error';
        });
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            'Profile setup required. Apply the Idea Lab social migration, then retry.\n${_error ?? ''}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final profile = _profile!;
    final own = IdeaLabBackend.currentUser?.id == profile.id;
    final counts = _counts ?? (0, 0, 0);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          profile.username == null
              ? profile.displayName
              : '@${profile.username}',
        ),
        actions: [
          if (!own)
            PopupMenuButton<String>(
              onSelected: (_) => _toggleBlock(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'block',
                  child: Text(_blocked ? 'Unblock account' : 'Block account'),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundImage: profile.avatarUrl == null
                      ? null
                      : NetworkImage(profile.avatarUrl!),
                  child: profile.avatarUrl == null
                      ? const Icon(Icons.person_outline, size: 40)
                      : null,
                ),
                const SizedBox(height: 10),
                Text(profile.displayName, style: AppText.h2),
                if (profile.username != null)
                  Text('@${profile.username}', style: AppText.caption),
                if (profile.bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    profile.bio,
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat('${counts.$1}', 'posts'),
                    _stat('${counts.$2}', 'followers'),
                    _stat('${counts.$3}', 'following'),
                  ],
                ),
                if (!own) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _follow,
                          child: Text(
                            _following
                                ? 'Following'
                                : _followRequested
                                ? 'Requested'
                                : profile.isPrivate
                                ? 'Request to follow'
                                : 'Follow',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  IdeaConversationScreen(other: profile),
                            ),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Message'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children: [
              for (var index = 0; index < 3; index++)
                ChoiceChip(
                  label: Text(['Posts', 'Videos', 'Your music'][index]),
                  selected: _profileTab == index,
                  onSelected: (_) => setState(() => _profileTab = index),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_profileTab == 0) ...[
            Text('Posts', style: AppText.h2),
            const SizedBox(height: 10),
            if (_items.isEmpty)
              Text('No published posts yet.', style: AppText.caption)
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                ),
                itemBuilder: (context, index) {
                  final post = _items[index];
                  final media = post.media.isEmpty ? null : post.media.first;
                  return InkWell(
                    onTap: () async {
                      if (!own && IdeaLabBackend.currentUser != null) {
                        try {
                          await _social.recordPostView(post.id);
                          final updated = await _social.postViewCounts([
                            post.id,
                          ]);
                          if (mounted) setState(() => _views.addAll(updated));
                        } catch (_) {}
                      }
                      if (!context.mounted) return;
                      showDialog<void>(
                        context: context,
                        builder: (dialogContext) => Dialog(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 700,
                              maxHeight: 760,
                            ),
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                if (media != null &&
                                    media.mimeType.startsWith('image/'))
                                  Image.network(media.url, fit: BoxFit.contain),
                                if (media != null &&
                                    media.mimeType.startsWith('video/'))
                                  AspectRatio(
                                    aspectRatio: media.aspectRatio,
                                    child: IdeaPostMediaPlayer(
                                      media: media,
                                      music: post.music,
                                    ),
                                  ),
                                Text(post.caption, style: AppText.body),
                                Text(
                                  '${_views[post.id] ?? 0} views',
                                  style: AppText.caption,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (media != null &&
                            media.mimeType.startsWith('image/'))
                          Image.network(
                            media.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: AppColors.glassFill),
                          ),
                        if (media != null &&
                            media.mimeType.startsWith('video/'))
                          IdeaCommunityVideoPreview(
                            media: media,
                            viewCount: _views[post.id],
                          )
                        else if (media == null)
                          const _CreatorVideoCoverFallback(),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              child: Text(
                                '${_views[post.id] ?? 0}',
                                style: AppText.caption.copyWith(fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (_postsHaveMore)
              Center(
                child: TextButton.icon(
                  onPressed: _loadingMore ? null : _loadMorePosts,
                  icon: const Icon(Icons.expand_more),
                  label: Text(
                    _loadingMore ? 'Loading posts…' : 'Load more posts',
                  ),
                ),
              ),
          ] else if (_profileTab == 1)
            _creatorVideoGrid(
              _items
                  .where(
                    (post) => post.media.any(
                      (media) =>
                          media.mimeType.toLowerCase().startsWith('video/'),
                    ),
                  )
                  .toList(),
            )
          else
            CreatorMusicList(ownerId: profile.id, isOwner: own),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
    children: [
      Text(value, style: AppText.h2),
      Text(label, style: AppText.caption),
    ],
  );

  Widget _creatorVideoGrid(List<IdeaLabPost> videos) {
    if (videos.isEmpty) {
      return GlassCard(
        child: Column(
          children: [
            const Icon(
              Icons.movie_creation_outlined,
              color: AppColors.sky,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text('No published videos yet', style: AppText.h3),
            Text(
              'Videos shared by this creator will appear here.',
              style: AppText.caption,
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: videos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: .78,
      ),
      itemBuilder: (context, index) {
        final post = videos[index];
        final media = post.media.firstWhere(
          (item) => item.mimeType.toLowerCase().startsWith('video/'),
        );
        return InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (media.thumbnailUrl != null)
                      Image.network(
                        media.thumbnailUrl!,
                        height: 240,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const _CreatorVideoCoverFallback(),
                      )
                    else
                      const _CreatorVideoCoverFallback(),
                    const SizedBox(height: 12),
                    Text(post.caption, style: AppText.body),
                  ],
                ),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (media.thumbnailUrl != null)
                  Image.network(
                    media.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const _CreatorVideoCoverFallback(),
                  )
                else
                  const _CreatorVideoCoverFallback(),
                const Center(
                  child: CircleAvatar(
                    backgroundColor: Color(0x99000000),
                    child: Icon(Icons.play_arrow_rounded, color: Colors.white),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Text(
                    post.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreatorVideoCoverFallback extends StatelessWidget {
  const _CreatorVideoCoverFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xff142444), Color(0xff2c1d4d), Color(0xff101827)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.sky),
          SizedBox(height: 5),
          Text(
            'AM MOTION LAB',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 8,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Settings are limited to preferences the app can currently honor. Unsupported
/// account privacy controls are deliberately shown as unavailable, not simulated.
class IdeaSettingsScreen extends StatefulWidget {
  const IdeaSettingsScreen({super.key});
  @override
  State<IdeaSettingsScreen> createState() => _IdeaSettingsScreenState();
}

class IdeaBlockedAccountsScreen extends StatefulWidget {
  const IdeaBlockedAccountsScreen({super.key});
  @override
  State<IdeaBlockedAccountsScreen> createState() =>
      _IdeaBlockedAccountsScreenState();
}

class IdeaWatchHistoryScreen extends StatefulWidget {
  const IdeaWatchHistoryScreen({super.key});
  @override
  State<IdeaWatchHistoryScreen> createState() => _IdeaWatchHistoryScreenState();
}

class _IdeaWatchHistoryScreenState extends State<IdeaWatchHistoryScreen> {
  final _history = IdeaWatchHistoryService();
  bool? _paused;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _history.history(),
        _history.historyPaused(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<Map<String, dynamic>>;
        _paused = results[1] as bool;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _setPaused(bool value) async {
    final previous = _paused;
    setState(() => _paused = value);
    try {
      await _history.setHistoryPaused(value);
    } catch (error) {
      if (mounted) {
        setState(() {
          _paused = previous;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear watch history?'),
        content: const Text(
          'This removes your saved Reels watch history from this account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _history.clearHistory();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Watch history'),
      actions: [
        IconButton(
          tooltip: 'Clear history',
          onPressed: _items.isEmpty ? null : _clear,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    body: Column(
      children: [
        SwitchListTile(
          secondary: const Icon(
            Icons.pause_circle_outline,
            color: AppColors.sky,
          ),
          title: Text('Pause watch history', style: AppText.body),
          subtitle: Text(
            'New Reels watched while paused will not be saved.',
            style: AppText.caption,
          ),
          value: _paused ?? false,
          onChanged: _paused == null ? null : _setPaused,
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load watch history: $_error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else if (_items.isEmpty)
          Expanded(
            child: Center(
              child: Text('No watched Reels yet.', style: AppText.body),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final row = _items[index];
                final post = row['post'] as Map<String, dynamic>?;
                return ListTile(
                  leading: const Icon(
                    Icons.video_library_outlined,
                    color: AppColors.sky,
                  ),
                  title: Text(
                    post?['caption'] as String? ?? 'Reel no longer available',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Watched ${DateTime.tryParse(row['watched_at'] as String? ?? '')?.toLocal() ?? ''}',
                    style: AppText.caption,
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _IdeaBlockedAccountsScreenState extends State<IdeaBlockedAccountsScreen> {
  final _social = IdeaLabSocialService();
  late Future<List<Map<String, dynamic>>> _items;
  @override
  void initState() {
    super.initState();
    _items = _social.blockedProfiles();
  }

  void _reload() => setState(() => _items = _social.blockedProfiles());
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Blocked accounts')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load blocked accounts: ${snapshot.error}'),
          );
        }
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return Center(
            child: Text(
              'You have not blocked any accounts.',
              style: AppText.body,
            ),
          );
        }
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final name = row['display_name'] as String? ?? 'Creator';
            return ListTile(
              title: Text(name),
              subtitle: row['username'] == null
                  ? null
                  : Text('@${row['username']}'),
              trailing: TextButton(
                onPressed: () async {
                  try {
                    await _social.setBlocked(
                      row['id'] as String,
                      blocked: false,
                    );
                    _reload();
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not unblock account: $error'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Unblock'),
              ),
            );
          },
        );
      },
    ),
  );
}

class IdeaFollowRequestsScreen extends StatefulWidget {
  const IdeaFollowRequestsScreen({super.key});
  @override
  State<IdeaFollowRequestsScreen> createState() =>
      _IdeaFollowRequestsScreenState();
}

class IdeaStorySettingsScreen extends StatefulWidget {
  const IdeaStorySettingsScreen({super.key});
  @override
  State<IdeaStorySettingsScreen> createState() =>
      _IdeaStorySettingsScreenState();
}

class _IdeaStorySettingsScreenState extends State<IdeaStorySettingsScreen> {
  final _social = IdeaLabSocialService();
  String _replies = 'everyone';
  bool _resharing = true;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _social.storyPreferences();
      if (mounted) {
        setState(() {
          _replies = value['replies_access'] as String;
          _resharing = value['allow_resharing'] as bool;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    try {
      await _social.saveStoryPreferences(
        repliesAccess: _replies,
        allowResharing: _resharing,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Story defaults saved.')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Story and location')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Could not load or save settings: $_error',
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ),
              Text('Default story controls', style: AppText.h2),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.reply_outlined,
                        color: AppColors.sky,
                      ),
                      title: Text('Who can reply', style: AppText.body),
                      subtitle: Text(
                        'The choice is saved on each story.',
                        style: AppText.caption,
                      ),
                      trailing: DropdownButton<String>(
                        value: _replies,
                        items: const [
                          DropdownMenuItem(
                            value: 'everyone',
                            child: Text('Everyone'),
                          ),
                          DropdownMenuItem(
                            value: 'followers',
                            child: Text('Followers'),
                          ),
                          DropdownMenuItem(value: 'off', child: Text('Off')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _replies = value);
                        },
                      ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.repeat_rounded,
                        color: AppColors.sky,
                      ),
                      title: Text('Allow resharing', style: AppText.body),
                      subtitle: Text(
                        'Saved as the default for new stories.',
                        style: AppText.caption,
                      ),
                      value: _resharing,
                      onChanged: (value) => setState(() => _resharing = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      color: AppColors.sky,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Location is off by default. Add a location only from the individual story composer; it is not read from device GPS.',
                        style: AppText.body,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Save defaults'),
              ),
            ],
          ),
  );
}

class _IdeaFollowRequestsScreenState extends State<IdeaFollowRequestsScreen> {
  final _social = IdeaLabSocialService();
  late Future<List<Map<String, dynamic>>> _items;
  @override
  void initState() {
    super.initState();
    _items = _social.incomingFollowRequests();
  }

  void _reload() => setState(() => _items = _social.incomingFollowRequests());
  Future<void> _respond(String id, bool approve) async {
    try {
      await _social.respondToFollowRequest(id, approve: approve);
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update follow request: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Follow requests')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load requests: ${snapshot.error}'),
          );
        }
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return Center(
            child: Text('No pending follow requests.', style: AppText.body),
          );
        }
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final profile = row['profile'] as Map<String, dynamic>?;
            return ListTile(
              title: Text(profile?['display_name'] as String? ?? 'Creator'),
              subtitle: profile?['username'] == null
                  ? null
                  : Text('@${profile!['username']}'),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Decline',
                    onPressed: () =>
                        _respond(row['requester_id'] as String, false),
                    icon: const Icon(Icons.close),
                  ),
                  IconButton(
                    tooltip: 'Approve',
                    onPressed: () =>
                        _respond(row['requester_id'] as String, true),
                    icon: const Icon(Icons.check, color: AppColors.sky),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

class _IdeaSettingsScreenState extends State<IdeaSettingsScreen> {
  final _social = IdeaLabSocialService();
  bool _videoAutoplay = true;
  bool _reduceMotion = false;
  bool? _privateAccount;

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
    IdeaMotionPreferences.load().then((_) {
      if (mounted) {
        setState(
          () => _reduceMotion = IdeaMotionPreferences.reduceMotion.value,
        );
      }
    });
    IdeaVideoPreferences.autoplayEnabled().then((enabled) {
      if (mounted) setState(() => _videoAutoplay = enabled);
    });
  }

  Future<void> _loadPrivacy() async {
    try {
      final value = await _social.currentProfileIsPrivate();
      if (mounted) setState(() => _privateAccount = value);
    } catch (_) {
      if (mounted) setState(() => _privateAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings and activity')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        _settingsGroup('Your account', [
          _settingsRow(
            Icons.bookmark_border_rounded,
            'Saved',
            'Your saved music and tracks',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const IdeaMusicLibraryScreen(initialTab: 2),
              ),
            ),
          ),
          _settingsRow(
            Icons.dark_mode_outlined,
            'Brand appearance',
            'Dark theme is on · Midnight, Motion Blue and Electric Purple',
            onTap: () => _showBrandAppearance(context),
          ),
          _settingsRow(
            Icons.report_problem_outlined,
            'Report a problem',
            'Contact AM Motion Lab support',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
            ),
          ),
        ]),
        _settingsGroup('Your activity', [
          _settingsRow(
            Icons.history_rounded,
            'Watch history',
            'Your private Reels watch history',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const IdeaWatchHistoryScreen(),
              ),
            ),
          ),
        ]),
        _settingsGroup('Who can see your content', [
          SwitchListTile(
            secondary: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.sky,
            ),
            title: Text('Private account', style: AppText.body),
            subtitle: Text(
              _privateAccount == null
                  ? 'Loading privacy setting…'
                  : _privateAccount!
                  ? 'Only approved followers can see your posts and stories'
                  : 'Anyone can see your public posts and stories',
              style: AppText.caption,
            ),
            value: _privateAccount ?? false,
            onChanged: _privateAccount == null
                ? null
                : (value) async {
                    final old = _privateAccount!;
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _privateAccount = value);
                    try {
                      await _social.setPrivate(value);
                    } catch (error) {
                      if (!mounted) return;
                      setState(() => _privateAccount = old);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Could not update privacy: $error'),
                        ),
                      );
                    }
                  },
          ),
          _settingsRow(
            Icons.block_outlined,
            'Blocked accounts',
            'Manage accounts you have blocked',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const IdeaBlockedAccountsScreen(),
              ),
            ),
          ),
          _settingsRow(
            Icons.person_add_alt_1_outlined,
            'Follow requests',
            'Approve or decline private-account requests',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const IdeaFollowRequestsScreen(),
              ),
            ),
          ),
          _settingsRow(
            Icons.location_on_outlined,
            'Story and location',
            'Replies, resharing and per-story location',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const IdeaStorySettingsScreen(),
              ),
            ),
          ),
        ]),
        _settingsGroup('App preferences', [
          SwitchListTile(
            secondary: const Icon(
              Icons.play_circle_outline,
              color: AppColors.sky,
            ),
            title: Text('Video autoplay', style: AppText.body),
            subtitle: Text(
              'Play videos when they become visible',
              style: AppText.caption,
            ),
            value: _videoAutoplay,
            onChanged: (value) {
              setState(() => _videoAutoplay = value);
              unawaited(IdeaVideoPreferences.setAutoplayEnabled(value));
            },
          ),
          SwitchListTile(
            secondary: const Icon(
              Icons.motion_photos_off_outlined,
              color: AppColors.sky,
            ),
            title: Text('Reduce motion', style: AppText.body),
            subtitle: Text(
              'Stops automatic carousel movement',
              style: AppText.caption,
            ),
            value: _reduceMotion,
            onChanged: (value) {
              setState(() => _reduceMotion = value);
              unawaited(IdeaMotionPreferences.setReduceMotion(value));
            },
          ),
        ]),
        _settingsGroup('Account', [
          _settingsRow(
            Icons.switch_account_outlined,
            'Switch accounts',
            'Sign out to use another account',
            onTap: _switchAccount,
          ),
          _settingsRow(
            Icons.logout_rounded,
            'Log out',
            'Sign out of this device',
            onTap: _logOut,
          ),
        ]),
        const SizedBox(height: 10),
        Center(child: Text('AM MOTION LAB · Settings', style: AppText.caption)),
      ],
    ),
  );

  Widget _settingsGroup(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Text(title.toUpperCase(), style: AppText.label),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, color: AppColors.glassBorder),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _settingsRow(
    IconData icon,
    String title,
    String subtitle, {
    Widget? trailing,
    VoidCallback? onTap,
  }) => ListTile(
    leading: Icon(icon, color: AppColors.sky),
    title: Text(title, style: AppText.body),
    subtitle: Text(subtitle, style: AppText.caption),
    trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
    onTap: onTap ?? () => _showInfo(context, subtitle),
  );

  void _showInfo(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _showBrandAppearance(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AM Motion Lab appearance'),
        content: ValueListenableBuilder<BrandAccent>(
          valueListenable: BrandAppearance.accent,
          builder: (context, selected, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your dark brand theme is active across the app.'),
              const SizedBox(height: 16),
              for (final choice in BrandAccent.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => BrandAppearance.select(choice),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: choice.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected == choice
                              ? Colors.white
                              : Colors.white30,
                          width: selected == choice ? 3 : 1,
                        ),
                      ),
                      child: selected == choice
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                  title: Text(choice.label),
                  trailing: selected == choice
                      ? const Icon(
                          Icons.radio_button_checked_rounded,
                          color: AppColors.sky,
                        )
                      : const Icon(Icons.radio_button_unchecked_rounded),
                  onTap: () => BrandAppearance.select(choice),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _switchAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const IdeaDeviceAccountsScreen()),
    );
  }

  Future<void> _logOut() async {
    final proceed = await _confirmSignOut('Log out?');
    if (proceed) await _signOut();
  }

  Future<bool> _confirmSignOut(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: const Text(
            'You can sign back in or choose another account afterwards.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _signOut() async {
    try {
      await IdeaLabBackend.client.auth.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) _showInfo(context, 'Could not sign out: $error');
    }
  }
}

class IdeaDeviceAccountsScreen extends StatefulWidget {
  const IdeaDeviceAccountsScreen({super.key});
  @override
  State<IdeaDeviceAccountsScreen> createState() =>
      _IdeaDeviceAccountsScreenState();
}

class _IdeaDeviceAccountsScreenState extends State<IdeaDeviceAccountsScreen> {
  final _store = IdeaDeviceAccountStore.instance;
  late Future<List<IdeaDeviceAccount>> _accounts;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _accounts = _store.accounts();
  }

  void _reload() => setState(() => _accounts = _store.accounts());

  Future<void> _addAccount() async {
    setState(() => _busy = true);
    try {
      await IdeaLabBackend.client.auth.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start account sign-in: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switch(IdeaDeviceAccount account) async {
    setState(() => _busy = true);
    try {
      await _store.switchTo(IdeaLabBackend.client, account);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not switch account. Sign in again to refresh its saved session.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(IdeaDeviceAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove account from this device?'),
        content: const Text(
          'This removes the saved sign-in token on this device. It does not delete the AM Motion Lab account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      if (IdeaLabBackend.currentUser?.id == account.id) {
        await IdeaLabBackend.client.auth.signOut();
      }
      await _store.remove(account.id);
      _reload();
      if (IdeaLabBackend.currentUser == null && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not remove this device account: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Switch accounts')),
    body: !_store.supported
        ? Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Saved account switching is available in the Android app only. Browsers do not receive this refresh-token vault; sign out and sign in to switch accounts on web.',
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
            ),
          )
        : FutureBuilder<List<IdeaDeviceAccount>>(
            future: _accounts,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not read secure device accounts: ${snapshot.error}',
                  ),
                );
              }
              final accounts = snapshot.data ?? const [];
              final activeId = IdeaLabBackend.currentUser?.id;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Accounts on this device', style: AppText.h2),
                  const SizedBox(height: 10),
                  if (accounts.isEmpty)
                    Text(
                      'Sign-ins on this device will be saved here.',
                      style: AppText.caption,
                    ),
                  for (final account in accounts)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: account.avatarUrl == null
                              ? null
                              : NetworkImage(account.avatarUrl!),
                          child: account.avatarUrl == null
                              ? Text(
                                  account.name.isEmpty
                                      ? 'A'
                                      : account.name[0].toUpperCase(),
                                )
                              : null,
                        ),
                        title: Text(account.name),
                        subtitle: Text(
                          account.email.isEmpty ? 'Account' : account.email,
                        ),
                        trailing: PopupMenuButton<String>(
                          enabled: !_busy,
                          onSelected: (value) => value == 'remove'
                              ? _remove(account)
                              : _switch(account),
                          itemBuilder: (_) => [
                            if (activeId != account.id)
                              const PopupMenuItem(
                                value: 'switch',
                                child: Text('Switch'),
                              ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove from device'),
                            ),
                          ],
                          child: activeId == account.id
                              ? const Chip(label: Text('Active'))
                              : const Icon(Icons.more_vert),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _addAccount,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Add account'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Refresh tokens are encrypted with an Android Keystore key and stored on this device. Anyone who can unlock or compromise this device may still access its signed-in accounts. This feature is disabled on web.',
                    style: AppText.caption,
                  ),
                ],
              );
            },
          ),
  );
}

class IdeaCreatorSearchScreen extends StatefulWidget {
  const IdeaCreatorSearchScreen({super.key});
  @override
  State<IdeaCreatorSearchScreen> createState() =>
      _IdeaCreatorSearchScreenState();
}

class _IdeaCreatorSearchScreenState extends State<IdeaCreatorSearchScreen> {
  final _social = IdeaLabSocialService();
  final _controller = TextEditingController();
  List<IdeaLabCreatorProfile> _results = [];
  List<IdeaLabCreatorProfile> _matches = [];
  bool _busy = false;
  bool _googleScopeRequested = false;
  String? _error;
  String? _contactMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await _social.searchCreators(_controller.text);
      if (mounted) setState(() => _results = rows);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmContactMatch(String source) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Match $source contacts?'),
          content: const Text(
            'After you approve, their email addresses and phone numbers are sent over HTTPS to AM Motion Lab’s server for one time matching. The app does not save the contact list. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _syncDeviceContacts() async {
    if (kIsWeb) {
      setState(
        () => _contactMessage =
            'Device address-book matching is available in the Android/iOS app. Use username search on web.',
      );
      return;
    }
    if (!await _confirmContactMatch('phone and email')) return;
    setState(() {
      _busy = true;
      _error = null;
      _contactMessage = null;
    });
    try {
      final permission = await FlutterContacts.permissions.request(
        PermissionType.read,
      );
      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.limited) {
        throw StateError(
          'Contacts permission was not granted. You can still search by username.',
        );
      }
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone, ContactProperty.email},
      );
      final emails = <String>[];
      final phones = <String>[];
      for (final contact in contacts) {
        emails.addAll(contact.emails.map((item) => item.address));
        phones.addAll(
          contact.phones.map((item) => item.normalizedNumber ?? item.number),
        );
        if (emails.length + phones.length >= 5000) break;
      }
      final matches = await _social.matchContacts(
        emails: emails,
        phones: phones,
      );
      if (mounted) {
        setState(() {
          _matches = matches;
          _contactMessage =
              '${matches.length} matching creator${matches.length == 1 ? '' : 's'} found. Contacts were not saved.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncGoogleContacts() async {
    if (!await _confirmContactMatch('Google')) return;
    setState(() {
      _busy = true;
      _error = null;
      _contactMessage = null;
    });
    try {
      final auth = IdeaLabBackend.client.auth;
      if (!_googleScopeRequested) {
        await auth.linkIdentity(
          OAuthProvider.google,
          scopes: 'https://www.googleapis.com/auth/contacts.readonly',
        );
        if (mounted) {
          setState(() {
            _googleScopeRequested = true;
            _contactMessage =
                'Approve Google Contacts access, return here, and tap Sync Google contacts again.';
          });
        }
        return;
      }
      var token = auth.currentSession?.providerToken;
      if (token == null || token.isEmpty) {
        throw StateError(
          'Google did not return an access token. Confirm that Google sign-in and contacts.readonly scope are enabled, then reconnect.',
        );
      }
      final emails = <String>[];
      final phones = <String>[];
      String? pageToken;
      var pages = 0;
      do {
        pages++;
        final uri =
            Uri.https('people.googleapis.com', '/v1/people/me/connections', {
              'personFields': 'emailAddresses,phoneNumbers',
              'pageSize': '1000',
              if (pageToken != null) 'pageToken': pageToken,
            });
        final response = await http.get(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode != 200) {
          throw StateError(
            'Google Contacts request failed (${response.statusCode}). Check Google Contacts API and OAuth consent setup.',
          );
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        for (final person
            in (data['connections'] as List<dynamic>? ?? const [])) {
          final contact = person as Map<String, dynamic>;
          emails.addAll(
            (contact['emailAddresses'] as List<dynamic>? ?? const []).map(
              (v) => (v as Map<String, dynamic>)['value'] as String? ?? '',
            ),
          );
          phones.addAll(
            (contact['phoneNumbers'] as List<dynamic>? ?? const []).map(
              (v) => (v as Map<String, dynamic>)['value'] as String? ?? '',
            ),
          );
        }
        pageToken = data['nextPageToken'] as String?;
      } while (pageToken != null &&
          pages < 5 &&
          emails.length + phones.length < 5000);
      final matches = await _social.matchContacts(
        emails: emails,
        phones: phones,
      );
      if (mounted) {
        setState(() {
          _matches = matches;
          _contactMessage =
              '${matches.length} matching creator${matches.length == 1 ? '' : 's'} found. Google contacts were not saved.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Find creators')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            labelText: 'Search username',
            suffixIcon: IconButton(
              onPressed: _search,
              icon: const Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _syncDeviceContacts,
          icon: const Icon(Icons.contacts_outlined),
          label: const Text('Find phone contacts'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _syncGoogleContacts,
          icon: const Icon(Icons.account_circle_outlined),
          label: Text(
            _googleScopeRequested
                ? 'Sync Google contacts'
                : 'Connect Google contacts',
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_contactMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_contactMessage!, style: AppText.caption),
          ),
        if (_error != null)
          Text(
            'Creator search needs the social migration: $_error',
            style: const TextStyle(color: Colors.orangeAccent),
          ),
        for (final profile in _results)
          ListTile(
            leading: CircleAvatar(
              backgroundImage: profile.avatarUrl == null
                  ? null
                  : NetworkImage(profile.avatarUrl!),
              child: profile.avatarUrl == null
                  ? const Icon(Icons.person_outline)
                  : null,
            ),
            title: Text(profile.displayName),
            subtitle: Text('@${profile.username ?? 'creator'}'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => IdeaCreatorScreen(creatorId: profile.id),
              ),
            ),
          ),
        if (_matches.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('People you may know', style: AppText.h2),
          for (final profile in _matches)
            ListTile(
              leading: CircleAvatar(
                backgroundImage: profile.avatarUrl == null
                    ? null
                    : NetworkImage(profile.avatarUrl!),
                child: profile.avatarUrl == null
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              title: Text(profile.displayName),
              subtitle: Text('@${profile.username ?? 'creator'}'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => IdeaCreatorScreen(creatorId: profile.id),
                ),
              ),
            ),
        ],
      ],
    ),
  );
}

class IdeaMessagesScreen extends StatefulWidget {
  const IdeaMessagesScreen({super.key});
  @override
  State<IdeaMessagesScreen> createState() => _IdeaMessagesScreenState();
}

class _IdeaMessagesScreenState extends State<IdeaMessagesScreen> {
  final _social = IdeaLabSocialService();
  final _search = TextEditingController();
  List<IdeaConversationPreview> _conversations = [];
  IdeaLabCreatorProfile? _selectedPerson;
  bool _loading = true;
  bool _loadingRequest = false;
  bool _unreadOnly = false;
  String? _error;
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadingRequest) return;
    _loadingRequest = true;
    try {
      final result = await _social.conversationPreviews();
      if (mounted) {
        setState(() {
          _conversations = result;
          _error = null;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _formatMessageError(error);
          _loading = false;
        });
      }
    }
    finally {
      _loadingRequest = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _conversations.where((conversation) {
      final profile = conversation.profile;
      final matchesQuery = query.isEmpty ||
          '${profile.displayName} ${profile.username ?? ''} ${conversation.lastMessage}'
              .toLowerCase()
              .contains(query);
      return matchesQuery && (!_unreadOnly || conversation.unreadCount > 0);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'Find creators',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const IdeaCreatorSearchScreen(),
              ),
            ),
            icon: const Icon(Icons.person_search_outlined),
          ),
          IconButton(
            tooltip: 'Refresh conversations',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navyDeep, AppColors.navy, AppColors.navyDeep],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search conversations or creators',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: AppColors.glassFillStrong,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: AppColors.glassBorder),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        _MessageFilterChip(
                          label: 'All',
                          selected: !_unreadOnly,
                          onTap: () => setState(() => _unreadOnly = false),
                        ),
                        const SizedBox(width: 8),
                        _MessageFilterChip(
                          label: 'Unread',
                          selected: _unreadOnly,
                          onTap: () => setState(() => _unreadOnly = true),
                        ),
                        if (constraints.maxWidth > 420) ...[
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const IdeaCreatorSearchScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('New message'),
                          ),
                        ] else ...[
                          const Spacer(),
                          IconButton(
                            tooltip: 'New message',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const IdeaCreatorSearchScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? _MessageEmptyState(
                              icon: Icons.cloud_off_outlined,
                              title: 'Messages could not be loaded',
                              message: _formatMessageError(_error!),
                              action: TextButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try again'),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final split = constraints.maxWidth >= 760;
                                final list = _buildConversationList(
                                  visible,
                                  split: split,
                                );
                                if (!split) return list;
                                return Row(
                                  children: [
                                    SizedBox(width: 330, child: list),
                                    const VerticalDivider(width: 1, color: AppColors.glassBorder),
                                    Expanded(
                                      child: _selectedPerson == null
                                          ? const _MessageEmptyState(
                                              icon: Icons.forum_outlined,
                                              title: 'Choose a conversation',
                                              message: 'Select a creator on the left to view your messages.',
                                            )
                                          : IdeaConversationScreen(
                                              key: ValueKey(_selectedPerson!.id),
                                              other: _selectedPerson!,
                                              embedded: true,
                                            ),
                                    ),
                                  ],
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationList(
    List<IdeaConversationPreview> visible, {
    required bool split,
  }) {
    if (visible.isEmpty) {
      return _MessageEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: _conversations.isEmpty ? 'Start a conversation' : 'No matching conversations',
        message: _conversations.isEmpty
            ? 'Find a creator and send your first message.'
            : 'Try another search or switch to All.',
        action: _conversations.isEmpty
            ? FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const IdeaCreatorSearchScreen()),
                ),
                icon: const Icon(Icons.person_search_outlined),
                label: const Text('Find creators'),
              )
            : null,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final conversation = visible[index];
        final person = conversation.profile;
        final selected = split && _selectedPerson?.id == person.id;
        return Material(
          color: selected
              ? AppColors.blue.withValues(alpha: .24)
              : AppColors.glassFill.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: _MessageAvatar(profile: person, radius: 25),
            title: Text(person.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(conversation.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_timeLabel(conversation.lastMessageAt), style: const TextStyle(fontSize: 11, color: AppColors.inkDim)),
                if (conversation.unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  DecoratedBox(
                    decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Text('${conversation.unreadCount}', style: const TextStyle(fontSize: 10, height: 1, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
            onTap: () {
              if (split) {
                setState(() => _selectedPerson = person);
              } else {
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => IdeaConversationScreen(other: person)))
                    .then((_) => _load());
              }
            },
          ),
        );
      },
    );
  }

  String _timeLabel(DateTime date) {
    final elapsed = DateTime.now().difference(date.toLocal());
    if (elapsed.inDays > 0) return '${elapsed.inDays}d';
    if (elapsed.inHours > 0) return '${elapsed.inHours}h';
    if (elapsed.inMinutes > 0) return '${elapsed.inMinutes}m';
    return 'now';
  }
}

class _MessageFilterChip extends StatelessWidget {
  const _MessageFilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.blue : AppColors.glassFillStrong,
    borderRadius: BorderRadius.circular(99),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.inkDim, fontWeight: FontWeight.w600)),
      ),
    ),
  );
}

class _MessageEmptyState extends StatelessWidget {
  const _MessageEmptyState({required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.sky, size: 38),
        const SizedBox(height: 12),
        Text(title, style: AppText.h3, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(message, style: AppText.caption, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ]),
    ),
  );
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.profile, required this.radius});
  final IdeaLabCreatorProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.violet.withValues(alpha: .45),
    backgroundImage: profile.avatarUrl == null ? null : NetworkImage(profile.avatarUrl!),
    child: profile.avatarUrl == null ? Icon(Icons.person_outline, color: AppColors.sky, size: radius) : null,
  );
}

class IdeaConversationScreen extends StatefulWidget {
  const IdeaConversationScreen({super.key, required this.other, this.embedded = false});
  final IdeaLabCreatorProfile other;
  final bool embedded;
  @override
  State<IdeaConversationScreen> createState() => _IdeaConversationScreenState();
}

class _IdeaConversationScreenState extends State<IdeaConversationScreen> {
  final _social = IdeaLabSocialService();
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _sending = false;
  bool _initialLoading = true;
  bool _loadInProgress = false;
  bool _pendingBottomScroll = false;
  String? _error;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _refresh = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false, bool forceBottom = false}) async {
    if (_loadInProgress) {
      _pendingBottomScroll = _pendingBottomScroll || forceBottom;
      return;
    }
    _loadInProgress = true;
    final wasAtBottom = !_scroll.hasClients ||
        _scroll.position.maxScrollExtent - _scroll.position.pixels < 100;
    try {
      final rows = await _social.thread(widget.other.id);
      if (!mounted) return;
      final unique = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        unique[row['id'] as String] = row;
      }
      final ordered = unique.values.toList()
        ..sort((left, right) {
          final time = DateTime.parse(left['created_at'] as String)
              .compareTo(DateTime.parse(right['created_at'] as String));
          return time != 0 ? time : (left['id'] as String).compareTo(right['id'] as String);
        });
      final previousState = _messages.map((message) => '${message['id']}:${message['read_at']}').join('|');
      final nextState = ordered.map((message) => '${message['id']}:${message['read_at']}').join('|');
      if (previousState != nextState || _initialLoading) {
        setState(() {
          _messages = ordered;
          _error = null;
          _initialLoading = false;
        });
        if (initial || forceBottom || wasAtBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) {
              _scroll.animateTo(
                _scroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              );
            }
          });
        }
      } else if (_initialLoading) {
        setState(() => _initialLoading = false);
      }
      final unread = ordered.where((row) =>
          row['recipient_id'] == _social.currentUserId && row['read_at'] == null).toList();
      for (final row in unread) {
        _social.markRead(row['id'] as String).catchError((_) {});
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _formatMessageError(error);
          _initialLoading = false;
        });
      }
    } finally {
      _loadInProgress = false;
      if (_pendingBottomScroll && mounted) {
        _pendingBottomScroll = false;
        scheduleMicrotask(() => _load(forceBottom: true));
      }
    }
  }

  Future<void> _send() async {
    final value = _text.text.trim();
    if (_sending || value.isEmpty) return;
    setState(() { _sending = true; _error = null; });
    try {
      await _social.sendMessage(widget.other.id, value);
      _text.clear();
      await _load(forceBottom: true);
    } catch (error) {
      if (mounted) setState(() => _error = _formatMessageError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _timeFor(Map<String, dynamic> message) => TimeOfDay.fromDateTime(
    DateTime.parse(message['created_at'] as String).toLocal(),
  ).format(context);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 8,
      leading: widget.embedded ? const SizedBox(width: 8) : null,
      title: Row(children: [
        _MessageAvatar(profile: widget.other, radius: 19),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.other.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
          Text(widget.other.username == null ? 'Idea Lab creator' : '@${widget.other.username}', style: AppText.caption.copyWith(fontSize: 11)),
        ])),
      ]),
      actions: [
        IconButton(tooltip: 'Refresh messages', onPressed: () => _load(), icon: const Icon(Icons.refresh_rounded)),
        PopupMenuButton<String>(
          tooltip: 'Conversation options',
          onSelected: (value) {
            if (value == 'profile') {
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => IdeaCreatorScreen(creatorId: widget.other.id)));
            } else {
              _load();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'profile', child: Text('View profile')),
            PopupMenuItem(value: 'refresh', child: Text('Refresh conversation')),
          ],
        ),
      ],
    ),
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.navyDeep, AppColors.navy])),
      child: Column(children: [
        if (_error != null)
          MaterialBanner(
            content: Text(_error!, maxLines: 3, overflow: TextOverflow.ellipsis),
            actions: [TextButton(onPressed: () => _load(), child: const Text('Retry'))],
          ),
        Expanded(child: _initialLoading
            ? const Center(child: CircularProgressIndicator())
            : _messages.isEmpty
                ? const _MessageEmptyState(icon: Icons.waving_hand_outlined, title: 'Say hello', message: 'Your messages with this creator will appear here.')
                : Center(child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final mine = message['sender_id'] == _social.currentUserId;
                        final read = message['read_at'] != null;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .76),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: mine ? AppColors.brandGradient : null,
                                  color: mine ? null : AppColors.glassFillStrong,
                                  border: Border.all(color: mine ? AppColors.blue.withValues(alpha: .55) : AppColors.glassBorder),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(mine ? 18 : 5),
                                    bottomRight: Radius.circular(mine ? 5 : 18),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 10, 13, 7),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Align(alignment: Alignment.centerLeft, child: SelectableText(message['body'] as String, style: AppText.body.copyWith(height: 1.35))),
                                    const SizedBox(height: 5),
                                    Row(mainAxisSize: MainAxisSize.min, children: [
                                      Text(_timeFor(message), style: AppText.caption.copyWith(fontSize: 10, color: mine ? Colors.white70 : AppColors.inkDim)),
                                      if (mine) ...[
                                        const SizedBox(width: 5),
                                        Text(
                                          read ? 'Read' : 'Sent',
                                          style: AppText.caption.copyWith(
                                            fontSize: 10,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(read ? Icons.done_all_rounded : Icons.check_rounded, size: 14, color: read ? const Color(0xFFB7D6FF) : Colors.white70),
                                      ],
                                    ]),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ))),
        SafeArea(
          top: false,
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(children: [
                AppEmojiPickerButton(controller: _text),
                Expanded(child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 4000,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Write a message…',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.glassFillStrong,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.glassBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.glassBorder)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                )),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
                  child: IconButton(
                    tooltip: 'Send message',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ]),
            ),
          )),
        ),
      ]),
    ),
  );
}
