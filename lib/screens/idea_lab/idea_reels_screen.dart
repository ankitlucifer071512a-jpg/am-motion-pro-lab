import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../models/idea_music_track.dart';
import '../../services/idea_audio_service.dart';
import '../../services/idea_music_catalog.dart';
import '../../services/idea_lab_backend.dart';
import '../../services/idea_lab_social_service.dart';
import '../../services/idea_watch_history_service.dart';
import '../../services/idea_video_preferences.dart';
import 'idea_audio_page.dart';
import 'idea_post_detail_dialog.dart';

/// Full-screen, vertical video feed. Only the selected page initializes a
/// player, keeping adjacent clips from downloading in the background.
class IdeaReelsScreen extends StatefulWidget {
  const IdeaReelsScreen({
    super.key,
    required this.posts,
    this.initialPostId,
    this.onUseAudio,
  });

  final List<IdeaLabPost> posts;
  final String? initialPostId;
  final ValueChanged<IdeaMusicTrack>? onUseAudio;

  @override
  State<IdeaReelsScreen> createState() => _IdeaReelsScreenState();
}

class _IdeaReelsScreenState extends State<IdeaReelsScreen> {
  int get _initialIndex => widget.posts.isEmpty
      ? 0
      : widget.posts
            .indexWhere((post) => post.id == widget.initialPostId)
            .clamp(0, widget.posts.length - 1);
  late final PageController _pages = PageController(initialPage: _initialIndex);
  late int _index = _initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = widget.posts
        .map(
          (post) => (
            post: post,
            media: post.media
                .where((m) => m.mimeType.startsWith('video/'))
                .firstOrNull,
          ),
        )
        .where((entry) => entry.media != null)
        .toList(growable: false);
    return Scaffold(
      backgroundColor: Colors.black,
      body: videos.isEmpty
          ? SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No video posts yet. Create a video post to start your Reels feed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : PageView.builder(
              controller: _pages,
              scrollDirection: Axis.vertical,
              itemCount: videos.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final entry = videos[index];
                return _ReelPage(
                  key: ValueKey(entry.post.id),
                  post: entry.post,
                  media: entry.media!,
                  active: index == _index,
                  onBack: () => Navigator.pop(context),
                  onUseAudio: widget.onUseAudio,
                );
              },
            ),
    );
  }
}

class _ReelPage extends StatefulWidget {
  const _ReelPage({
    super.key,
    required this.post,
    required this.media,
    required this.active,
    required this.onBack,
    this.onUseAudio,
  });
  final IdeaLabPost post;
  final IdeaLabPostMedia media;
  final bool active;
  final VoidCallback onBack;
  final ValueChanged<IdeaMusicTrack>? onUseAudio;

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> with WidgetsBindingObserver {
  final _social = IdeaLabSocialService();
  final _watchHistory = IdeaWatchHistoryService();
  final _audioService = IdeaAudioService();
  VideoPlayerController? _player;
  VideoPlayerController? _audioPlayer;
  bool _audioLoading = false;
  bool _loading = false;
  bool _liked = false;
  bool _likeBusy = false;
  int _likes = 0;
  int _comments = 0;
  String? _error;
  IdeaMusicSelection? _sessionMusic;
  bool _autoplayEnabled = true;
  Timer? _watchHistoryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEngagement();
    IdeaVideoPreferences.autoplayEnabled().then((enabled) {
      if (!mounted) return;
      setState(() => _autoplayEnabled = enabled);
      if (enabled && widget.active) _start();
    });
  }

  @override
  void didUpdateWidget(covariant _ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _start();
      } else {
        _watchHistoryTimer?.cancel();
        final oldPlayer = _player;
        _player = null;
        oldPlayer?.dispose();
        final oldAudio = _audioPlayer;
        _audioPlayer = null;
        oldAudio?.dispose();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _watchHistoryTimer?.cancel();
      _player?.pause();
      _audioPlayer?.pause();
    }
    if (state == AppLifecycleState.resumed &&
        widget.active &&
        _player != null) {
      _player!.play();
      _scheduleWatchHistory();
    }
  }

  Future<void> _start({bool manual = false}) async {
    if (_loading || !widget.active) return;
    if (!manual && !await IdeaVideoPreferences.autoplayEnabled()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final player = _player ??= VideoPlayerController.networkUrl(
        Uri.parse(widget.media.url),
      );
      if (!player.value.isInitialized) await player.initialize();
      await player.setLooping(true);
      await player.setVolume(0);
      player.removeListener(_syncAudio);
      player.addListener(_syncAudio);
      await player.play();
      _scheduleWatchHistory();
      await _startAudio();
    } catch (error) {
      _error = 'Video could not autoplay. Tap to try playing it.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scheduleWatchHistory() {
    _watchHistoryTimer?.cancel();
    if (!widget.active || IdeaLabBackend.currentUser == null) return;
    _watchHistoryTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.active) {
        _watchHistory.recordReelWatch(widget.post.id).catchError((_) {});
      }
    });
  }

  Future<void> _startAudio() async {
    if (_audioLoading || _audioPlayer != null) return;
    _audioLoading = true;
    try {
      String? url;
      var volume = 1.0;
      var start = Duration.zero;
      var end = Duration.zero;
      final music = _sessionMusic ?? widget.post.music;
      final audioId = music?.track.audioId ?? widget.post.audioId;
      if (audioId != null) {
        // Audio rows are authoritative. Their signed Storage URLs are short
        // lived, so refresh the URL when playback starts instead of reusing a
        // URL saved earlier in music_metadata.
        final audio = await _audioService.get(audioId);
        url = audio.playableUrl;
        if (music != null) {
          volume = music.volume;
          start = music.start;
          end = music.end;
        }
      } else if (music != null) {
        // External library tracks have no private Storage audio_id and keep
        // using their provider URL.
        url = music.track.audioUrl;
        volume = music.volume;
        start = music.start;
        end = music.end;
      }
      if (url == null ||
          !widget.active ||
          _player?.value.isPlaying != true) {
        return;
      }
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _audioPlayer = controller;
      await controller.initialize();
      if (!mounted || controller != _audioPlayer) return;
      await controller.setVolume(volume.clamp(0.0, 1.0));
      await controller.setLooping(end <= start || end == Duration.zero);
      if (start > Duration.zero) await controller.seekTo(start);
      await controller.play();
    } catch (error) {
      // Keep the video usable if the separate audio source cannot initialize,
      // but tell the viewer why the Reel is currently silent.
      if (mounted && widget.active) {
        final detail = '$error'.toLowerCase();
        final missingObject = detail.contains('404') ||
            detail.contains('not_found') ||
            detail.contains('object not found');
        _message(missingObject
            ? 'This audio file is missing from storage. The video will continue silently; ask the creator to restore the original track.'
            : 'Music could not be loaded. The video will continue silently.');
      }
    } finally {
      _audioLoading = false;
    }
  }

  void _syncAudio() {
    final video = _player;
    final audio = _audioPlayer;
    if (!mounted ||
        video?.value.isInitialized != true ||
        audio?.value.isInitialized != true) {
      return;
    }
    final videoPlayer = video!;
    final audioPlayer = audio!;
    if (videoPlayer.value.isPlaying && !audioPlayer.value.isPlaying) {
      audioPlayer.play();
    }
    if (!videoPlayer.value.isPlaying && audioPlayer.value.isPlaying) {
      audioPlayer.pause();
    }
    final music = _sessionMusic ?? widget.post.music;
    final start = music?.start ?? Duration.zero;
    final end = music?.end ?? Duration.zero;
    final segmentLength = end - start;
    final expected = end > start
        ? start +
              Duration(
                milliseconds:
                    videoPlayer.value.position.inMilliseconds %
                    segmentLength.inMilliseconds,
              )
        : start + videoPlayer.value.position;
    if ((audioPlayer.value.position - expected).abs() >
        const Duration(milliseconds: 450)) {
      audioPlayer.seekTo(expected);
    }
  }

  Future<void> _loadEngagement() async {
    try {
      final values = await _social.postEngagement(widget.post.id);
      if (mounted) {
        setState(() {
          _likes = values.$1;
          _comments = values.$2;
          _liked = values.$3;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    setState(() => _likeBusy = true);
    try {
      await _social.togglePostLike(widget.post.id, liked: _liked);
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _likes += _liked ? 1 : -1;
        });
      }
    } catch (error) {
      if (mounted) _message('Could not update like: $error');
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  Future<void> _openComments() async {
    await showDialog<void>(
      context: context,
      builder: (_) => IdeaPostDetailDialog(post: widget.post),
    );
    await _loadEngagement();
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '${widget.post.caption}\n\n${widget.media.url}',
          title: 'AM Motion Lab · ${widget.post.creator}',
        ),
      );
    } catch (error) {
      if (mounted) _message('Could not open sharing: $error');
    }
  }

  Future<void> _openAudioPage() async {
    final audioId = _sessionMusic?.track.audioId ?? widget.post.audioId;
    if (audioId != null) {
      final selected = await Navigator.of(context).push<IdeaMusicTrack>(
        MaterialPageRoute(builder: (_) => IdeaAudioPage(audioId: audioId)),
      );
      if (selected != null && mounted) {
        if (widget.onUseAudio != null) {
          widget.onUseAudio!(selected);
        } else {
          _message('Audio selected. Open Create Post to use it.');
        }
      }
      return;
    }
    final music = _sessionMusic ?? widget.post.music;
    if (music == null) return;
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.navy,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Music on this reel',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.music_note, color: AppColors.sky),
                  title: Text(
                    music.track.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${music.track.creator} · ${music.track.license}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              if (music.track.attribution.isNotEmpty)
                Text(
                  music.track.attribution,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMusicPicker() async {
    final selected = await showModalBottomSheet<IdeaMusicTrack>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy,
      builder: (_) => const _ReelMusicPicker(),
    );
    if (selected == null || !mounted) return;
    final oldAudio = _audioPlayer;
    _audioPlayer = null;
    await oldAudio?.dispose();
    setState(() {
      _sessionMusic = IdeaMusicSelection(
        track: selected,
        start: Duration.zero,
        end: selected.duration,
        volume: 0.25,
      );
    });
    await _startAudio();
    if (mounted) _message('Previewing ${selected.title} on this Reel.');
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _watchHistoryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _player?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final initialized = player?.value.isInitialized == true;
    final hasVideoFrame =
        initialized &&
        player!.value.size.width > 0 &&
        player.value.size.height > 0;
    final playing = player?.value.isPlaying == true;
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.navy, Color(0xFF14234A), Color(0xFF25134A)],
            ),
          ),
        ),
        if (_audioPlayer?.value.isInitialized == true)
          Offstage(
            offstage: true,
            child: SizedBox(
              width: 1,
              height: 1,
              child: VideoPlayer(_audioPlayer!),
            ),
          ),
        if (widget.media.thumbnailUrl != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: MediaQuery.disableAnimationsOf(context) ? 0 : 22,
              sigmaY: MediaQuery.disableAnimationsOf(context) ? 0 : 22,
            ),
            child: Image.network(
              widget.media.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Colors.black),
            ),
          ),
        if (hasVideoFrame)
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 1080,
                height: 1080 / player.value.aspectRatio,
                child: VideoPlayer(player),
              ),
            ),
          )
        else if (widget.media.thumbnailUrl != null)
          Center(
            child: Image.network(
              widget.media.thumbnailUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        if (initialized && !hasVideoFrame)
          const Center(child: CircularProgressIndicator()),
        GestureDetector(
          onTap: () async {
            if (!widget.active) return;
            if (playing) {
              await player?.pause();
              if (mounted) setState(() {});
            } else {
              await _start(manual: true);
            }
          },
          child: const ColoredBox(color: Colors.transparent),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            ),
          ),
        ),
        if (initialized && widget.active)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              player!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.sky,
                bufferedColor: Colors.white54,
                backgroundColor: Colors.white30,
              ),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReelAction(
                icon: _liked ? Icons.favorite : Icons.favorite_border,
                label: widget.post.hideLikeCount
                    ? (_liked ? 'Liked' : 'Like')
                    : '$_likes',
                color: _liked ? Colors.pinkAccent : Colors.white,
                onTap: _toggleLike,
              ),
              if (widget.post.commentsAccess != 'off')
                _ReelAction(
                  icon: Icons.mode_comment_outlined,
                  label: '$_comments',
                  onTap: _openComments,
                ),
              _ReelAction(
                icon: Icons.send_outlined,
                label: 'Share',
                onTap: _share,
              ),
              _ReelAction(
                icon: Icons.music_note_rounded,
                label: 'Music',
                onTap: _openMusicPicker,
              ),
            ],
          ),
        ),
        Positioned(
          left: 18,
          right: 86,
          bottom: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.post.creator,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.post.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              if ((_sessionMusic ?? widget.post.music) != null) ...[
                const SizedBox(height: 8),
                _audioChip(
                  '${(_sessionMusic ?? widget.post.music)!.track.title} - ${(_sessionMusic ?? widget.post.music)!.track.creator}',
                ),
              ] else if (widget.post.audioId != null) ...[
                const SizedBox(height: 8),
                _audioChip('Original audio - ${widget.post.creator}'),
              ],
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 32,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.post.audioId != null ||
                  (_sessionMusic ?? widget.post.music) != null)
                InkWell(
                  onTap: _openAudioPage,
                  borderRadius: BorderRadius.circular(9),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: (_sessionMusic ?? widget.post.music)?.track.artworkUrl != null
                          ? Image.network(
                              (_sessionMusic ?? widget.post.music)!.track.artworkUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _AudioCoverFallback(),
                            )
                          : widget.media.thumbnailUrl != null
                          ? Image.network(
                              widget.media.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _AudioCoverFallback(),
                            )
                          : const _AudioCoverFallback(),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: (_audioPlayer?.value.volume ?? 0) > 0
                    ? 'Mute audio'
                    : 'Unmute audio',
                onPressed: () async {
                  final audio = _audioPlayer;
                  if (audio?.value.isInitialized == true) {
                    await audio!.setVolume(
                      audio.value.volume > 0
                          ? 0
                          : ((_sessionMusic ?? widget.post.music)?.volume ?? 1),
                    );
                  } else if (initialized) {
                    await player!.setVolume(player.value.volume > 0 ? 0 : 1);
                  }
                  if (mounted) setState(() {});
                },
                icon: Icon(
                  (_audioPlayer?.value.volume ?? 0) > 0
                      ? Icons.volume_up
                      : Icons.volume_off,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: AppColors.sky)),
        if (_error != null)
          Positioned(
            left: 32,
            right: 32,
            top: MediaQuery.sizeOf(context).height * .4,
            child: FilledButton.icon(
              onPressed: () => _start(manual: true),
              icon: const Icon(Icons.play_arrow),
              label: Text(_error!),
            ),
          ),
        if (!playing && !_loading && _error == null &&
            (initialized || !_autoplayEnabled))
          Center(
            child: IconButton.filled(
              onPressed: () => _start(manual: true),
              iconSize: 52,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _audioChip(String label) => InkWell(
    onTap: _openAudioPage,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReelAction extends StatelessWidget {
  const _ReelAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _ReelMusicPicker extends StatefulWidget {
  const _ReelMusicPicker();

  @override
  State<_ReelMusicPicker> createState() => _ReelMusicPickerState();
}

class _ReelMusicPickerState extends State<_ReelMusicPicker> {
  final _search = TextEditingController();
  final _catalog = IdeaMusicCatalog();
  List<IdeaMusicTrack> _tracks = const [];
  VideoPlayerController? _preview;
  String? _playing;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _catalog.search(
        query: _search.text,
        category: 'popular',
      );
      if (mounted) setState(() => _tracks = result.tracks);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePreview(IdeaMusicTrack track) async {
    if (_playing == track.id) {
      await _preview?.pause();
      if (mounted) setState(() => _playing = null);
      return;
    }
    await _preview?.dispose();
    final player = VideoPlayerController.networkUrl(Uri.parse(track.audioUrl));
    _preview = player;
    setState(() {
      _playing = track.id;
      _error = null;
    });
    try {
      await player.initialize();
      await player.setVolume(0.7);
      await player.play();
    } catch (error) {
      if (mounted) setState(() => _error = 'Preview unavailable: $error');
    }
  }

  String _duration(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Choose music',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search title or creator',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.arrow_forward),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            if (_loading) const LinearProgressIndicator(color: AppColors.sky),
            Expanded(
              child: _loading && _tracks.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _tracks.isEmpty
                  ? const Center(
                      child: Text(
                        'No licensed tracks found.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _tracks.length,
                      separatorBuilder: (_, __) => const Divider(
                        color: Colors.white12,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final track = _tracks[index];
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 3,
                            ),
                            leading: IconButton(
                              tooltip: 'Preview track',
                              onPressed: () => _togglePreview(track),
                              icon: Icon(
                                _playing == track.id
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                                size: 34,
                                color: AppColors.sky,
                              ),
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${track.creator} · ${_duration(track.duration)} · ${track.license}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: TextButton(
                              onPressed: () => Navigator.pop(context, track),
                              child: const Text('Use'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Text(
              'Track licence and attribution details are provided by the source.',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AudioCoverFallback extends StatelessWidget {
  const _AudioCoverFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.navy,
    child: Center(child: Icon(Icons.music_note_rounded, color: AppColors.sky)),
  );
}
