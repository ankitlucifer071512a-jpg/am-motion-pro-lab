import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/idea_lab_backend.dart';
import '../../services/idea_lab_social_service.dart';
import '../../widgets/app_emoji_picker_button.dart';
import '../../widgets/idea_post_media_player.dart';

class IdeaPostDetailDialog extends StatefulWidget {
  const IdeaPostDetailDialog({
    super.key,
    required this.post,
    this.onOpenCreator,
  });

  final IdeaLabPost post;
  final VoidCallback? onOpenCreator;

  @override
  State<IdeaPostDetailDialog> createState() => _IdeaPostDetailDialogState();
}

class _IdeaPostDetailDialogState extends State<IdeaPostDetailDialog> {
  final _social = IdeaLabSocialService();
  final _comment = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  int _likes = 0;
  bool _liked = false;
  bool _loading = true;
  bool _posting = false;
  bool _savingLike = false;
  String? _error;
  String? _replyTo;
  String? _replyName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<Object>([
        _social.postEngagement(widget.post.id),
        _social.postComments(widget.post.id),
      ]);
      final engagement = values[0] as (int, int, bool);
      if (!mounted) return;
      setState(() {
        _likes = engagement.$1;
        _liked = engagement.$3;
        _comments = values[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) {
    final value = error.toString();
    final missingDatabaseObject =
        value.contains('42P01') || // PostgreSQL undefined_table
        value.contains('42883') || // PostgreSQL undefined_function
        value.contains('PGRST202') ||
        value.contains('PGRST204') ||
        value.toLowerCase().contains('schema cache') ||
        value.toLowerCase().contains('does not exist');
    if (missingDatabaseObject &&
        (value.contains('idea_post_likes') ||
            value.contains('idea_post_comments') ||
            value.contains('idea_post_engagement_counts'))) {
      return 'Apply migration 202610170001_idea_post_interactions.sql to enable likes and comments.';
    }
    return value.replaceFirst('Exception: ', '');
  }

  Future<void> _toggleLike() async {
    if (_savingLike) return;
    setState(() => _savingLike = true);
    try {
      await _social.togglePostLike(widget.post.id, liked: _liked);
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _likes += _liked ? 1 : -1;
        });
      }
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _savingLike = false);
    }
  }

  Future<void> _sendComment() async {
    if (_posting || _comment.text.trim().isEmpty) return;
    setState(() => _posting = true);
    try {
      await _social.addPostComment(
        widget.post.id,
        _comment.text,
        parentCommentId: _replyTo,
      );
      _comment.clear();
      setState(() {
        _replyTo = null;
        _replyName = null;
      });
      await _load();
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _share() async {
    final mediaUrl = widget.post.media.isEmpty
        ? ''
        : widget.post.media.first.url;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: [
            widget.post.caption,
            mediaUrl,
          ].where((part) => part.isNotEmpty).join('\n\n'),
          title: 'AM Motion Lab · ${widget.post.creator}',
        ),
      );
    } catch (error) {
      if (mounted) _showMessage('Could not open sharing: $error');
    }
  }

  Future<void> _openMediaForDownload() async {
    if (widget.post.media.isEmpty) return;
    final media = widget.post.media.first;
    try {
      final response = await http.get(Uri.parse(media.url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('The media server returned ${response.statusCode}.');
      }
      final path = Uri.parse(media.url).pathSegments;
      final filename = path.isEmpty ? 'idea-lab-media' : path.last;
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save original media',
        fileName: filename,
        bytes: response.bodyBytes,
        mimeType: media.mimeType,
      );
      if (mounted) {
        _showMessage(saved == null ? 'Download cancelled.' : 'Media saved.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Download failed. Check your connection and try again: $error',
        );
      }
    }
  }

  List<Map<String, dynamic>> get _topLevelComments => _comments
      .where((comment) => comment['parent_comment_id'] == null)
      .toList();

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 720,
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundImage: widget.post.avatarUrl == null
                      ? null
                      : NetworkImage(widget.post.avatarUrl!),
                  child: widget.post.avatarUrl == null
                      ? const Icon(Icons.person_outline, size: 18)
                      : null,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: InkWell(
                    onTap: widget.onOpenCreator,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.post.creator, style: AppText.h3),
                        Text(
                          '${widget.post.category} · ${_dateLabel(widget.post.createdAt)}',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Share post',
                  onPressed: _share,
                  icon: const Icon(Icons.share_outlined),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              children: [
                for (final media in widget.post.media)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: IdeaPostMediaPlayer(
                      media: media,
                      music: widget.post.music,
                    ),
                  ),
                if (widget.post.music != null) ...[
                  Text(
                    'Music: ${widget.post.music!.track.title} · ${widget.post.music!.track.license}',
                    style: AppText.caption,
                  ),
                  if (widget.post.music!.track.attribution.isNotEmpty)
                    Text(
                      widget.post.music!.track.attribution,
                      style: AppText.caption.copyWith(fontSize: 10),
                    ),
                  Text(
                    'Track source: ${widget.post.music!.track.sourceUrl}',
                    style: AppText.caption.copyWith(fontSize: 10),
                  ),
                ],
                Text(widget.post.caption, style: AppText.body),
                if (widget.post.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.post.tags.map((tag) => '#$tag').join(' '),
                    style: AppText.caption.copyWith(color: AppColors.sky),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      tooltip: _liked ? 'Unlike' : 'Like',
                      onPressed: _savingLike ? null : _toggleLike,
                      icon: Icon(
                        _liked ? Icons.favorite : Icons.favorite_border,
                        color: _liked ? Colors.pinkAccent : AppColors.ink,
                      ),
                    ),
                    Text(
                      widget.post.hideLikeCount
                          ? (_liked ? 'Liked' : 'Like')
                          : '$_likes likes',
                      style: AppText.caption,
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.mode_comment_outlined, size: 18),
                    const SizedBox(width: 5),
                    Text(
                      widget.post.commentsAccess == 'off'
                          ? 'Comments off'
                          : '${_comments.length} comments',
                      style: AppText.caption,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Download original media',
                      onPressed: _openMediaForDownload,
                      icon: const Icon(Icons.download_outlined),
                    ),
                  ],
                ),
                const Divider(),
                if (widget.post.commentsAccess == 'off')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Comments are turned off for this post.',
                      style: AppText.caption,
                    ),
                  )
                else if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!, style: AppText.caption),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  )
                else if (_topLevelComments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'No comments yet. Start the conversation.',
                      style: AppText.caption,
                    ),
                  )
                else
                  for (final comment in _topLevelComments) ...[
                    _CommentTile(
                      comment: comment,
                      onReply: () => setState(() {
                        _replyTo = comment['id'] as String;
                        _replyName = _authorName(comment);
                      }),
                    ),
                    for (final reply in _comments.where(
                      (item) => item['parent_comment_id'] == comment['id'],
                    ))
                      Padding(
                        padding: const EdgeInsets.only(left: 34),
                        child: _CommentTile(comment: reply),
                      ),
                  ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(
                children: [
                  if (_replyName != null && widget.post.commentsAccess != 'off')
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Replying to $_replyName',
                            style: AppText.caption,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() {
                            _replyTo = null;
                            _replyName = null;
                          }),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  if (widget.post.commentsAccess != 'off')
                    Row(
                      children: [
                        AppEmojiPickerButton(controller: _comment),
                        Expanded(
                          child: TextField(
                            controller: _comment,
                            minLines: 1,
                            maxLines: 3,
                            maxLength: 2200,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment',
                              counterText: '',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _posting ? null : _sendComment,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: AppColors.sky,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  String _authorName(Map<String, dynamic> comment) {
    final author = comment['author'] as Map<String, dynamic>?;
    return author?['display_name'] as String? ?? 'Creator';
  }

  String _dateLabel(DateTime date) {
    final elapsed = DateTime.now().difference(date.toLocal());
    if (elapsed.inDays > 0) return '${elapsed.inDays}d ago';
    if (elapsed.inHours > 0) return '${elapsed.inHours}h ago';
    if (elapsed.inMinutes > 0) return '${elapsed.inMinutes}m ago';
    return 'now';
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, this.onReply});

  final Map<String, dynamic> comment;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final author = comment['author'] as Map<String, dynamic>?;
    final displayName = author?['display_name'] as String? ?? 'Creator';
    final avatarPath = author?['avatar_path'] as String?;
    final avatarFuture = avatarPath == null
        ? null
        : IdeaLabBackend.signedMediaUrl('idea-avatars', avatarPath);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String?>(
            future: avatarFuture,
            builder: (context, snapshot) => CircleAvatar(
              radius: 14,
              backgroundImage: snapshot.data == null ? null : NetworkImage(snapshot.data!),
              child: snapshot.data == null ? const Icon(Icons.person_outline, size: 16) : null,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppText.caption.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(comment['body'] as String, style: AppText.body),
                if (onReply != null)
                  TextButton(
                    onPressed: onReply,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                    ),
                    child: const Text('Reply'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
