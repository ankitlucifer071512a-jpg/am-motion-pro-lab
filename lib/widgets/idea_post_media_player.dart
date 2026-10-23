import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:video_player/video_player.dart';

import '../core/theme/app_colors.dart';
import '../models/idea_music_track.dart';
import '../services/idea_lab_backend.dart';

/// In-app playback mixer. The source media is never modified or represented as
/// a downloaded, music-embedded file; it plays the original video and music as
/// two streams with headroom to reduce clipping.
class IdeaPostMediaPlayer extends StatefulWidget {
  const IdeaPostMediaPlayer({super.key, required this.media, this.music});
  final IdeaLabPostMedia media;
  final IdeaMusicSelection? music;

  @override
  State<IdeaPostMediaPlayer> createState() => _IdeaPostMediaPlayerState();
}

class _IdeaPostMediaPlayerState extends State<IdeaPostMediaPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  VideoPlayerController? _music;
  String? _error;
  bool _loading = false;
  bool _resumeAfterBackground = false;

  bool get _isVideo => widget.media.mimeType.startsWith('video/');
  IdeaMusicSelection? get _effectiveMusic => widget.music;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _resumeAfterBackground) {
      _resumeAfterBackground = false;
      _start();
    } else if (state != AppLifecycleState.resumed) {
      _resumeAfterBackground =
          _video?.value.isPlaying == true || _music?.value.isPlaying == true;
      _video?.pause();
      _music?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _music?.removeListener(_musicTick);
    _video?.dispose();
    _music?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isVideo && _video == null) {
        final video = VideoPlayerController.networkUrl(
          Uri.parse(widget.media.url),
        );
        _video = video;
        await video.initialize();
        await video.setLooping(true);
        await video.setVolume(0);
      }
      final music = _effectiveMusic;
      if (music != null && _music == null) {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(music.track.audioUrl),
        );
        _music = controller;
        await controller.initialize();
        controller.addListener(_musicTick);
        await controller.seekTo(music.start);
        await controller.setVolume(music.volume);
      }
      if (_isVideo) await _video!.play();
      if (_effectiveMusic != null && _music != null) await _music!.play();
    } catch (_) {
      _error = 'Playback failed. The media source may be unavailable.';
      await _video?.pause();
      await _music?.pause();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _musicTick() {
    final player = _music;
    final selection = _effectiveMusic;
    if (player == null || selection == null || !player.value.isInitialized) {
      return;
    }
    if (player.value.position >= selection.end && player.value.isPlaying) {
      player.pause();
      if (mounted) setState(() {});
    } else if (player.value.hasError) {
      if (mounted) setState(() => _error = 'Background music playback failed.');
    }
  }

  Future<void> _toggle() async {
    final videoPlaying = _video?.value.isPlaying ?? false;
    final musicPlaying = _music?.value.isPlaying ?? false;
    if (videoPlaying || musicPlaying) {
      await _video?.pause();
      await _music?.pause();
      if (mounted) setState(() {});
    } else {
      await _start();
    }
  }

  Future<void> _toggleVideoMute() async {
    final player = _video;
    if (player == null || !player.value.isInitialized) return;
    await player.setVolume(player.value.volume == 0 ? .7 : 0);
    if (mounted) setState(() {});
  }

  Future<void> _toggleMusicMute() async {
    final player = _music;
    if (player == null || !player.value.isInitialized) return;
    await player.setVolume(
      player.value.volume == 0 ? (_effectiveMusic?.volume ?? .25) : 0,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final hasVideoFrame =
        _isVideo &&
        video?.value.isInitialized == true &&
        video!.value.size.width > 0 &&
        video.value.size.height > 0;
    final isPlaying =
        (video?.value.isPlaying ?? false) || (_music?.value.isPlaying ?? false);
    if (!_isVideo && _effectiveMusic == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          widget.media.url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: widget.media.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isVideo && widget.media.thumbnailUrl != null)
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: MediaQuery.disableAnimationsOf(context) ? 0 : 16,
                sigmaY: MediaQuery.disableAnimationsOf(context) ? 0 : 16,
              ),
              child: Image.network(
                widget.media.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: AppColors.navyDeep),
              ),
            )
          else if (_isVideo)
            const ColoredBox(color: AppColors.navyDeep)
          else if (!_isVideo)
            Image.network(
              widget.media.url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            )
          else
            const SizedBox.shrink(),
          if (hasVideoFrame)
            Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: video.value.size.width,
                  height: video.value.size.height,
                  child: VideoPlayer(video),
                ),
              ),
            ),
          if (_loading ||
              (_isVideo &&
                  video?.value.isInitialized == true &&
                  !hasVideoFrame))
            const Center(child: CircularProgressIndicator()),
          if (!isPlaying &&
              !_loading &&
              !(_isVideo &&
                  video?.value.isInitialized == true &&
                  !hasVideoFrame))
            Center(
              child: IconButton.filledTonal(
                tooltip: _isVideo ? 'Play post' : 'Play post music',
                onPressed: _toggle,
                icon: const Icon(
                  Icons.play_arrow_rounded,
                  size: 34,
                  color: Colors.white,
                ),
              ),
            ),
          if ((_isVideo && video?.value.isInitialized == true) ||
              (_effectiveMusic != null && _music?.value.isInitialized == true))
            Positioned(
              right: 3,
              bottom: 3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isVideo)
                    IconButton(
                      onPressed: _toggleVideoMute,
                      tooltip: 'Toggle video audio',
                      icon: Icon(
                        (_video?.value.volume ?? 0) == 0
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                      ),
                    ),
                  if (_effectiveMusic != null)
                    IconButton(
                      onPressed: _toggleMusicMute,
                      tooltip: 'Toggle background music',
                      icon: Icon(
                        (_music?.value.volume ?? .25) == 0
                            ? Icons.music_off_rounded
                            : Icons.music_note_rounded,
                        color: Colors.white,
                      ),
                    ),
                  IconButton(
                    onPressed: _toggle,
                    tooltip: isPlaying ? 'Pause' : 'Play',
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          if (_isVideo && video?.value.isInitialized == true)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                video!,
                allowScrubbing: false,
                colors: const VideoProgressColors(
                  playedColor: AppColors.sky,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          if (_error != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
