import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../services/idea_lab_backend.dart';
import '../../services/idea_lab_social_service.dart';

class IdeaStoryViewer extends StatefulWidget {
  const IdeaStoryViewer({
    super.key,
    required this.stories,
    required this.initialIndex,
    required this.onViewed,
    required this.resolveUrl,
    required this.onDelete,
  });

  final List<IdeaLabStory> stories;
  final int initialIndex;
  final ValueChanged<IdeaLabStory> onViewed;
  final Future<String> Function(IdeaLabStory story) resolveUrl;
  final ValueChanged<IdeaLabStory> onDelete;

  @override
  State<IdeaStoryViewer> createState() => _IdeaStoryViewerState();
}

class _IdeaStoryViewerState extends State<IdeaStoryViewer>
    with WidgetsBindingObserver {
  static const _imageDuration = Duration(seconds: 5);
  late int _index;
  VideoPlayerController? _video;
  VideoPlayerController? _music;
  Timer? _timer;
  Duration _imageElapsed = Duration.zero;
  bool _paused = false;
  bool _pausedBeforeBackground = false;
  bool _loading = true;
  bool _transitioning = false;
  bool _mediaFailed = false;
  bool _musicFailed = false;
  bool _storyMarkedViewed = false;
  String? _currentUrl;
  final _social = IdeaLabSocialService();
  int _storyLikes = 0;
  int _storyCommentCount = 0;
  bool _storyLiked = false;
  bool _storyInteractionBusy = false;

  bool get _hasStories => widget.stories.isNotEmpty;
  IdeaLabStory get _story => widget.stories[_index];
  bool get _isVideo => _story.mimeType.startsWith('video/');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _index = widget.stories.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.stories.length - 1);
    if (_hasStories) {
      _showCurrent();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  void _markViewed() {
    if (_hasStories && !_storyMarkedViewed) {
      _storyMarkedViewed = true;
      widget.onViewed(_story);
    }
  }

  void _startImageClock() {
    if (_timer != null) return;
    _markViewed();
    _startMusic();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _paused) return;
      _imageElapsed += const Duration(milliseconds: 100);
      if (_imageElapsed >= _imageDuration) {
        _next();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _showCurrent() async {
    _timer?.cancel();
    _timer = null;
    final old = _video;
    final oldMusic = _music;
    _video = null;
    _music = null;
    if (old != null) {
      old.removeListener(_videoTick);
      await old.dispose();
    }
    if (oldMusic != null) {
      oldMusic.removeListener(_musicTick);
      await oldMusic.dispose();
    }
    if (!mounted || !_hasStories) return;
    setState(() {
      _loading = true;
      _mediaFailed = false;
      _musicFailed = false;
      _storyMarkedViewed = false;
      _imageElapsed = Duration.zero;
      _paused = false;
      _transitioning = false;
      _currentUrl = null;
    });
    if (_story.expiresAt.isBefore(DateTime.now().toUtc())) {
      _next();
      return;
    }
    _loadStoryEngagement();

    try {
      final url = await widget.resolveUrl(_story);
      if (!mounted) return;
      _currentUrl = url;
      if (_isVideo) {
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        _video = controller;
        await controller.initialize();
        if (!mounted || controller != _video) return;
        controller.setLooping(false);
        controller.addListener(_videoTick);
        await controller.setVolume(.55);
        if (!_paused) {
          await controller.play();
          await _startMusic();
        }
        if (!mounted) return;
        setState(() => _loading = false);
        _markViewed();
      } else {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _mediaFailed = true;
        });
      }
    }
  }

  Future<void> _loadStoryEngagement() async {
    try {
      final counts = await _social.storyEngagement(_story.id);
      if (mounted) {
        setState(() {
          _storyLikes = counts.$1;
          _storyLiked = counts.$2;
          _storyCommentCount = counts.$3;
        });
      }
    } catch (_) {
      // The actions still report a clear setup error if the interaction migration is missing.
    }
  }

  Future<void> _toggleStoryLike() async {
    if (_storyInteractionBusy) return;
    setState(() => _storyInteractionBusy = true);
    try {
      await _social.toggleStoryLike(_story.id, liked: _storyLiked);
      if (mounted) {
        setState(() {
          _storyLiked = !_storyLiked;
          _storyLikes += _storyLiked ? 1 : -1;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Story likes need migration 202610170002: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _storyInteractionBusy = false);
    }
  }

  Future<void> _openStoryComments() async {
    final controller = TextEditingController();
    var comments = <Map<String, dynamic>>[];
    var loading = true;
    var sending = false;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          if (loading && error == null) {
            loading = false;
            _social
                .storyComments(_story.id)
                .then((value) {
                  if (sheetContext.mounted) {
                    setSheetState(() => comments = value);
                  }
                })
                .catchError((Object value) {
                  if (sheetContext.mounted) {
                    setSheetState(() => error = '$value');
                  }
                });
          }
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                18,
                16,
                MediaQuery.viewInsetsOf(context).bottom + 12,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .55,
                child: Column(
                  children: [
                    Text(
                      'Story comments',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: error != null
                          ? Center(
                              child: Text(
                                'Comments need migration 202610170002.\n$error',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : comments.isEmpty
                          ? const Center(child: Text('No comments yet.'))
                          : ListView(
                              children: [
                                for (final item in comments)
                                  ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.person_outline),
                                    ),
                                    title: Text(
                                      (item['author'] as Map?)?['display_name']
                                              as String? ??
                                          'Creator',
                                    ),
                                    subtitle: Text(item['body'] as String),
                                  ),
                              ],
                            ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment',
                              counterText: '',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: sending
                              ? null
                              : () async {
                                  setSheetState(() => sending = true);
                                  try {
                                    await _social.addStoryComment(
                                      _story.id,
                                      controller.text,
                                    );
                                    controller.clear();
                                    final result = await _social.storyComments(
                                      _story.id,
                                    );
                                    if (sheetContext.mounted) {
                                      setSheetState(() {
                                        comments = result;
                                        error = null;
                                      });
                                    }
                                    if (mounted) {
                                      setState(
                                        () => _storyCommentCount =
                                            comments.length,
                                      );
                                    }
                                  } catch (value) {
                                    if (sheetContext.mounted) {
                                      setSheetState(() => error = '$value');
                                    }
                                  } finally {
                                    if (sheetContext.mounted) {
                                      setSheetState(() => sending = false);
                                    }
                                  }
                                },
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
  }

  void _videoTick() {
    final video = _video;
    if (!mounted || video == null || !video.value.isInitialized) return;
    if (video.value.hasError) {
      setState(() {
        _loading = false;
        _mediaFailed = true;
      });
    } else if (video.value.position >= video.value.duration &&
        !_transitioning) {
      _next();
    } else {
      setState(() {});
    }
  }

  Future<void> _startMusic() async {
    final selection = _story.music;
    if (selection == null || _music != null || _paused) return;
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(selection.track.audioUrl),
      );
      _music = controller;
      await controller.initialize();
      if (!mounted || controller != _music) return;
      controller.addListener(_musicTick);
      await controller.seekTo(selection.start);
      await controller.setVolume(selection.volume);
      await controller.play();
    } catch (_) {
      if (mounted) setState(() => _musicFailed = true);
    }
  }

  void _musicTick() {
    final music = _music;
    final selection = _story.music;
    if (music == null || selection == null || !music.value.isInitialized) {
      return;
    }
    if (music.value.hasError) {
      setState(() => _musicFailed = true);
    } else if (music.value.position >= selection.end) {
      music.pause();
    }
  }

  void _next() {
    if (_transitioning || !_hasStories) return;
    if (_index >= widget.stories.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }
    _transitioning = true;
    setState(() => _index++);
    _showCurrent();
  }

  void _previous() {
    if (!_hasStories || _transitioning) return;
    if (_index == 0) {
      if (_isVideo) {
        _video?.seekTo(Duration.zero);
      }
      _imageElapsed = Duration.zero;
      setState(() {});
      return;
    }
    setState(() => _index--);
    _showCurrent();
  }

  Future<void> _togglePause() async {
    if (!_hasStories) return;
    setState(() => _paused = !_paused);
    final video = _video;
    if (video != null && video.value.isInitialized) {
      if (_paused) {
        await video.pause();
      } else {
        await video.play();
      }
    }
    final music = _music;
    if (music != null && music.value.isInitialized) {
      if (_paused) {
        await music.pause();
      } else {
        await music.play();
      }
    } else if (!_paused &&
        _story.music != null &&
        (!_isVideo || (video?.value.isInitialized ?? false))) {
      await _startMusic();
    }
  }

  Future<void> _toggleMute() async {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    await video.setVolume(video.value.volume == 0 ? .55 : 0);
    if (mounted) setState(() {});
  }

  Future<void> _toggleMusicMute() async {
    final music = _music;
    if (music == null || !music.value.isInitialized) return;
    await music.setVolume(
      music.value.volume == 0 ? (_story.music?.volume ?? .25) : 0,
    );
    if (mounted) setState(() {});
  }

  void _deleteStory() {
    if (!_hasStories) return;
    widget.onDelete(_story);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      if (!_paused && !_pausedBeforeBackground) {
        _pausedBeforeBackground = true;
        _togglePause();
      }
    } else if (_pausedBeforeBackground && mounted) {
      _pausedBeforeBackground = false;
      _togglePause();
    }
  }

  double get _progress {
    final video = _video;
    if (video != null &&
        video.value.isInitialized &&
        video.value.duration.inMilliseconds > 0) {
      return (video.value.position.inMilliseconds /
              video.value.duration.inMilliseconds)
          .clamp(0.0, 1.0);
    }
    return (_imageElapsed.inMilliseconds / _imageDuration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  String _timeLabel(DateTime date) {
    final elapsed = DateTime.now().difference(date.toLocal());
    if (elapsed.inMinutes < 1) return 'now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
    if (elapsed.inDays < 1) return '${elapsed.inHours}h';
    return '${elapsed.inDays}d';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _video?.removeListener(_videoTick);
    _video?.dispose();
    _music?.removeListener(_musicTick);
    _music?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasStories) return const Scaffold(backgroundColor: Colors.black);
    final video = _video;
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_mediaFailed)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 54,
                    color: Colors.white70,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This story could not be played.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else if (video != null &&
              video.value.isInitialized &&
              video.value.size.width > 0 &&
              video.value.size.height > 0)
            Center(
              child: AspectRatio(
                aspectRatio: video.value.aspectRatio,
                child: VideoPlayer(video),
              ),
            )
          else if (_isVideo && video?.value.isInitialized == true)
            const Center(child: CircularProgressIndicator())
          else if (!_isVideo && _currentUrl != null)
            Center(
              child: Image.network(
                _currentUrl!,
                fit: BoxFit.contain,
                frameBuilder: (context, child, frame, synchronous) {
                  if (frame != null && _loading && mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _loading) {
                        setState(() => _loading = false);
                        _startImageClock();
                      }
                    });
                  }
                  return child;
                },
                errorBuilder: (_, __, ___) {
                  if (!_mediaFailed && mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _loading = false;
                          _mediaFailed = true;
                        });
                      }
                    });
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent, Colors.black38],
                stops: [0, .28, 1],
              ),
            ),
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.sky),
            ),
          Positioned(
            top: topInset + 10,
            left: 14,
            right: 14,
            child: Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < widget.stories.length; i++) ...[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: i < _index
                                ? 1
                                : i > _index
                                ? 0
                                : _progress,
                            minHeight: 3,
                            backgroundColor: Colors.white38,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (i != widget.stories.length - 1)
                        const SizedBox(width: 4),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundImage: _story.avatarUrl == null
                          ? null
                          : NetworkImage(_story.avatarUrl!),
                      child: _story.avatarUrl == null
                          ? Text(
                              _story.creator.isEmpty
                                  ? '?'
                                  : _story.creator[0].toUpperCase(),
                            )
                          : null,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _story.creator,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _story.locationLabel == null
                                ? _timeLabel(_story.createdAt)
                                : '${_timeLabel(_story.createdAt)} · ${_story.locationLabel}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isVideo)
                      IconButton(
                        onPressed: _toggleMute,
                        tooltip: video?.value.volume == 0 ? 'Unmute' : 'Mute',
                        icon: Icon(
                          video?.value.volume == 0
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                        ),
                      ),
                    if (_story.music != null)
                      IconButton(
                        onPressed: _toggleMusicMute,
                        tooltip: (_music?.value.volume ?? .25) == 0
                            ? 'Unmute music'
                            : 'Mute music',
                        icon: Icon(
                          (_music?.value.volume ?? .25) == 0
                              ? Icons.music_off_rounded
                              : Icons.music_note_rounded,
                          color: Colors.white,
                        ),
                      ),
                    if (IdeaLabBackend.currentUser?.id == _story.creatorId)
                      IconButton(
                        onPressed: _deleteStory,
                        tooltip: 'Delete your story',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Close story',
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_musicFailed)
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 70,
              left: 20,
              right: 20,
              child: const Text(
                'Background music could not be played.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          Positioned.fill(
            top: topInset + 100,
            bottom: 72,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) =>
                  details.localPosition.dx <
                      MediaQuery.sizeOf(context).width / 2
                  ? _previous()
                  : _next(),
              onLongPress: _togglePause,
              onLongPressEnd: (_) {
                if (_paused) _togglePause();
              },
            ),
          ),
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 14,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _toggleStoryLike,
                  icon: Icon(
                    _storyLiked ? Icons.favorite : Icons.favorite_border,
                    color: _storyLiked ? Colors.pinkAccent : Colors.white,
                  ),
                  label: Text(
                    '$_storyLikes',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _togglePause,
                  tooltip: _paused ? 'Resume story' : 'Pause story',
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                ),
                TextButton.icon(
                  onPressed: _story.repliesAccess == 'off'
                      ? null
                      : _openStoryComments,
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                    color: Colors.white,
                  ),
                  label: Text(
                    '$_storyCommentCount',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          if (_mediaFailed)
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + 14,
              right: 16,
              child: FilledButton.tonalIcon(
                onPressed: _next,
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Next'),
              ),
            ),
        ],
      ),
    );
  }
}
