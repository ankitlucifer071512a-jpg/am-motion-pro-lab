import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/challenge_repository.dart';
import '../../services/course_repository.dart';
import '../../services/idea_lab_backend.dart';
import '../../services/idea_lab_social_service.dart';
import '../../services/learning_progress_store.dart';
import '../../widgets/creator_music_list.dart';
import '../../widgets/glass_card.dart';
import '../idea_lab/idea_post_detail_dialog.dart';
import 'idea_social_screens.dart';
import 'support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _social = IdeaLabSocialService();
  final _postService = IdeaLabPostService();
  int _xp = 0;
  double? _portfolioRating;
  Set<String> _done = {};
  IdeaLabCreatorProfile? _profile;
  List<IdeaLabPost> _posts = [];
  Map<String, int> _views = {};
  (int, int, int)? _counts;
  bool _socialLoading = false;
  bool _postsHaveMore = false;
  String? _socialError;
  int _profileTab = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSocial();
  }

  Future<void> _load() async {
    final store = LearningProgressStore.instance;
    final data = await Future.wait([
      store.xp,
      store.completed,
      store.portfolioPracticeRating,
    ]);
    if (mounted) {
      setState(() {
        _xp = data[0] as int;
        _done = data[1] as Set<String>;
        _portfolioRating = data[2] as double?;
      });
    }
  }

  Future<void> _loadSocial() async {
    final user = IdeaLabBackend.currentUser;
    if (user == null) return;
    setState(() {
      _socialLoading = true;
      _socialError = null;
    });
    try {
      final result = await Future.wait([
        _social.profile(user.id),
        _postService.fetchCreatorPosts(user.id),
        _social.counts(user.id),
      ]);
      final profile = result[0] as IdeaLabCreatorProfile;
      final posts = result[1] as List<IdeaLabPost>;
      final counts = result[2] as (int, int, int);
      final views = await _social.postViewCounts(
        posts.map((post) => post.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _posts = posts;
        _postsHaveMore = posts.length == IdeaLabPostService.pageSize;
        _counts = counts;
        _views = views;
        _socialLoading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _socialLoading = false;
          _socialError = '$error';
        });
      }
    }
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await IdeaLabBackend.client.auth.signOut();
    } catch (_) {
      if (mounted && messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Unable to sign out. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _pickAvatar([Future<XFile?>? selection]) async {
    try {
      final file =
          await (selection ??
              ImagePicker().pickImage(source: ImageSource.gallery));
      if (file == null) return;
      await _social.uploadAvatar(file);
      await _loadSocial();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update profile photo: $error')),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    final initial = _profile;
    if (initial == null) return;
    var name = initial.displayName;
    var username = initial.username ?? '';
    var bio = initial.bio;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.manage_accounts_outlined,
                        color: AppColors.sky,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Edit profile', style: AppText.h2)),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'Make your creator profile yours',
                        style: AppText.body,
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: AppColors.glassFillStrong,
                              backgroundImage: initial.avatarUrl == null
                                  ? null
                                  : NetworkImage(initial.avatarUrl!),
                              child: initial.avatarUrl == null
                                  ? const Icon(
                                      Icons.person_outline,
                                      color: AppColors.sky,
                                      size: 32,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(initial.displayName, style: AppText.h3),
                                  Text(
                                    'Profile photo and public details',
                                    style: AppText.caption,
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                final selection = ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                );
                                Navigator.pop(dialogContext, false);
                                unawaited(_pickAvatar(selection));
                              },
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Change photo'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _profileField(
                        'Name',
                        name,
                        (value) => setDialogState(() => name = value),
                        icon: Icons.badge_outlined,
                        maxLength: 80,
                      ),
                      const SizedBox(height: 12),
                      _profileField(
                        'Username',
                        username,
                        (value) => setDialogState(() => username = value),
                        icon: Icons.alternate_email,
                      ),
                      const SizedBox(height: 12),
                      _profileField(
                        'About you',
                        bio,
                        (value) => setDialogState(() => bio = value),
                        icon: Icons.notes_rounded,
                        maxLines: 5,
                        maxLength: 160,
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              color: AppColors.sky,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your email stays private. Name, username and bio are shown on your creator profile.',
                                style: AppText.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Save profile'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != true) return;
    try {
      await _social.updateProfile(
        displayName: name,
        username: username,
        bio: bio,
      );
      await _loadSocial();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update profile: $error')),
        );
      }
    }
  }

  Widget _profileField(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
  }) => TextFormField(
    initialValue: value,
    maxLines: maxLines,
    maxLength: maxLength,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.glassFill.withValues(alpha: .75),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  Future<void> _deletePost(IdeaLabPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('The post and its uploaded media will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _postService.deletePost(post);
      await _loadSocial();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete post: $error')),
        );
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_socialLoading || !_postsHaveMore || IdeaLabBackend.currentUser == null) {
      return;
    }
    setState(() => _socialLoading = true);
    try {
      final next = await _postService.fetchCreatorPosts(
        IdeaLabBackend.currentUser!.id,
        offset: _posts.length,
      );
      final views = await _social.postViewCounts(
        next.map((post) => post.id).toList(),
      );
      if (mounted) {
        setState(() {
          _posts.addAll(next);
          _views.addAll(views);
          _postsHaveMore = next.length == IdeaLabPostService.pageSize;
          _socialLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _socialLoading = false;
          _socialError = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedInUser = IdeaLabBackend.currentUser;
    final counts = _counts ?? (0, 0, 0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      children: [
        Text('CREATOR PROFILE', style: AppText.label),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: Text('Profile', style: AppText.h1)),
            IconButton(
              tooltip: 'Refresh profile and game rating',
              onPressed: () {
                _load();
                _loadSocial();
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (signedInUser != null) ...[
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _pickAvatar,
                      customBorder: const CircleBorder(),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.glassFillStrong,
                            backgroundImage: _profile?.avatarUrl == null
                                ? null
                                : NetworkImage(_profile!.avatarUrl!),
                            child: _profile?.avatarUrl == null
                                ? const Icon(
                                    Icons.person_outline,
                                    color: AppColors.sky,
                                    size: 38,
                                  )
                                : null,
                          ),
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 13,
                              child: Icon(Icons.add_a_photo_outlined, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile?.displayName ??
                                signedInUser.email ??
                                'Creator',
                            style: AppText.h3,
                          ),
                          if (_profile?.username != null)
                            Text(
                              '@${_profile!.username}',
                              style: AppText.caption,
                            ),
                          if (signedInUser.email != null ||
                              signedInUser.phone != null)
                            Text(
                              signedInUser.email ?? signedInUser.phone!,
                              style: AppText.caption,
                            ),
                          if (_profile?.bio.isNotEmpty == true) ...[
                            const SizedBox(height: 7),
                            Text(_profile!.bio, style: AppText.body),
                          ],
                          if (_profile == null && _socialError == null)
                            const LinearProgressIndicator(minHeight: 2),
                          if (_socialError != null)
                            Text(
                              'Profile setup required. Apply the Idea Lab social migration.\n$_socialError',
                              style: AppText.caption.copyWith(
                                color: Colors.orangeAccent,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _socialStat('${counts.$1}', 'posts'),
                    _socialStat('${counts.$2}', 'followers'),
                    _socialStat('${counts.$3}', 'following'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _profile == null ? null : _editProfile,
                        child: const Text('Edit profile'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const IdeaMessagesScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Messages'),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const IdeaCreatorSearchScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.person_search_outlined),
                        label: const Text('Find creators'),
                      ),
                    ),
                  ],
                ),
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
            Row(
              children: [
                Expanded(child: Text('Posts', style: AppText.h2)),
                if (_socialLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            if (_posts.isEmpty && !_socialLoading)
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Your published posts will appear here.',
                  style: AppText.caption,
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _posts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                ),
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  final media = post.media.isEmpty ? null : post.media.first;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      InkWell(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => IdeaPostDetailDialog(post: post),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (media != null &&
                                media.mimeType.startsWith('image/'))
                              Image.network(
                                media.url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: AppColors.glassFill,
                                ),
                              )
                            else if (media != null &&
                                media.mimeType.startsWith('video/') &&
                                media.thumbnailUrl != null)
                              Image.network(
                                media.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _videoFallback(),
                              )
                            else
                              _videoFallback(),
                            if (media != null &&
                                media.mimeType.startsWith('video/'))
                              Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(7),
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 3,
                        bottom: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .72),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            child: Text(
                              '${_views[post.id] ?? 0} views',
                              style: AppText.caption.copyWith(fontSize: 9),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Material(
                          color: Colors.black.withValues(alpha: .7),
                          child: PopupMenuButton<String>(
                            tooltip: 'Post options',
                            onSelected: (action) {
                              if (action == 'delete') _deletePost(post);
                              if (action == 'share') {
                                SharePlus.instance.share(
                                  ShareParams(
                                    title: 'AM Motion Lab · ${post.creator}',
                                    text: post.media.isEmpty
                                        ? post.caption
                                        : '${post.caption}\n\n${post.media.first.url}',
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'share',
                                child: Text('Share'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete post'),
                              ),
                            ],
                            icon: const Icon(
                              Icons.more_vert,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            if (_postsHaveMore)
              Center(
                child: TextButton.icon(
                  onPressed: _loadMorePosts,
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Load more posts'),
                ),
              ),
          ] else if (_profileTab == 1) ...[
            _profileVideoGrid(
              _posts
                  .where(
                    (post) => post.media.any(
                      (media) =>
                          media.mimeType.toLowerCase().startsWith('video/'),
                    ),
                  )
                  .toList(),
            ),
            if (_postsHaveMore)
              Center(
                child: TextButton.icon(
                  onPressed: _loadMorePosts,
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Load more videos'),
                ),
              ),
          ] else
            CreatorMusicList(ownerId: signedInUser.id, isOwner: true),
        ] else
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(
                    Icons.person_outline,
                    color: AppColors.sky,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Guest learner', style: AppText.h3),
                      Text(
                        'Sign in to edit your creator profile.',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _stat('$_xp', 'Game XP', Icons.bolt_outlined)),
            const SizedBox(width: 10),
            Expanded(
              child: _stat(
                '${_done.length}',
                'Challenges done',
                Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        if (_portfolioRating != null) ...[
          const SizedBox(height: 10),
          _stat(
            '${_portfolioRating!.toStringAsFixed(1)} / 5',
            'Game Lab practice rating',
            Icons.star_outline_rounded,
          ),
        ],
        const SizedBox(height: 20),
        Text('Purchased courses', style: AppText.h2),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No enrollment data is connected. Purchased courses will appear here after account and backend integration.',
            style: AppText.body,
          ),
        ),
        const SizedBox(height: 20),
        Text('Learning progress • Local prototype', style: AppText.h2),
        const SizedBox(height: 8),
        for (final course in CourseRepository.courses)
          Builder(
            builder: (context) {
              final challenges = ChallengeRepository.forCourse(course);
              final complete = challenges
                  .where((c) => _done.contains(c.id))
                  .length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(course.name, style: AppText.body),
                          ),
                          Text(
                            '$complete/${challenges.length}',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: challenges.isEmpty
                              ? 0
                              : complete / challenges.length,
                          minHeight: 5,
                          backgroundColor: AppColors.glassBorder,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.sky,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 12),
        Text('Achievements & certificates', style: AppText.h2),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Text(
            _done.isEmpty
                ? 'Complete practice challenges to earn local XP and achievements.'
                : 'Practice streak • ${_done.length} challenge${_done.length == 1 ? '' : 's'} completed. Certificates are a placeholder until course completion is verified.',
            style: AppText.body,
          ),
        ),
        const SizedBox(height: 20),
        Text('Account', style: AppText.h2),
        const SizedBox(height: 8),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(
                    Icons.support_agent_outlined,
                    color: AppColors.sky,
                  ),
                  title: Text('Support', style: AppText.body),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SupportScreen(),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.glassBorder),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(
                    Icons.settings_outlined,
                    color: AppColors.sky,
                  ),
                  title: Text('Settings', style: AppText.body),
                  subtitle: Text(
                    'Account, content and app preferences',
                    style: AppText.caption,
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const IdeaSettingsScreen(),
                    ),
                  ),
                ),
              ),
              if (signedInUser != null) ...[
                const Divider(height: 1, color: AppColors.glassBorder),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.inkDim),
                    title: Text('Sign out', style: AppText.body),
                    subtitle: Text(
                      'Sign out of this device',
                      style: AppText.caption,
                    ),
                    onTap: _signOut,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _socialStat(String value, String label) => Column(
    children: [
      Text(value, style: AppText.h2),
      Text(label, style: AppText.caption),
    ],
  );

  Widget _profileVideoGrid(List<IdeaLabPost> videos) {
    if (_socialLoading && videos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_socialError != null && videos.isEmpty) {
      return GlassCard(
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.sky,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text('Videos could not be loaded', style: AppText.h3),
            Text(
              _socialError!,
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
            TextButton.icon(
              onPressed: _loadSocial,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (videos.isEmpty) {
      return GlassCard(
        child: Column(
          children: [
            const Icon(
              Icons.movie_creation_outlined,
              color: AppColors.sky,
              size: 34,
            ),
            const SizedBox(height: 8),
            Text('No videos yet', style: AppText.h3),
            Text('Published videos will show up here.', style: AppText.caption),
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
          borderRadius: BorderRadius.circular(14),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => IdeaPostDetailDialog(post: post),
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
                    errorBuilder: (_, __, ___) => _videoFallback(),
                  )
                else
                  _videoFallback(),
                Align(
                  alignment: Alignment.center,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .55),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
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
                    style: AppText.caption.copyWith(
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _videoFallback() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff142444), Color(0xff2c1d4d), Color(0xff101827)],
      ),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.sky, size: 26),
          SizedBox(height: 5),
          Text(
            'AM MOTION LAB',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 8,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _stat(String value, String label, IconData icon) => GlassCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      children: [
        Icon(icon, color: AppColors.sky),
        const SizedBox(height: 6),
        Text(value, style: AppText.h2),
        Text(label, style: AppText.caption),
      ],
    ),
  );
}
