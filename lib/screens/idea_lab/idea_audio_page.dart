import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../models/idea_music_track.dart';
import '../../services/idea_audio_service.dart';
import '../../services/idea_lab_backend.dart' show IdeaLabBackend, IdeaLabPost, IdeaLabPostService;
import 'idea_reels_screen.dart';

class IdeaAudioPage extends StatefulWidget {
  const IdeaAudioPage({super.key, required this.audioId});
  final String audioId;

  @override
  State<IdeaAudioPage> createState() => _IdeaAudioPageState();
}

class _IdeaAudioPageState extends State<IdeaAudioPage> {
  final _service = IdeaAudioService();
  final _posts = IdeaLabPostService();
  final _scroll = ScrollController();
  IdeaAudio? _audio;
  VideoPlayerController? _player;
  List<IdeaLabPost> _reels = [];
  Map<String, int> _views = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _saved = false;
  bool _admin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_nearEnd);
    _load();
  }

  Future<void> _load() async {
    try {
      final audio = await _service.get(widget.audioId);
      final results = await Future.wait([
        _posts.fetchAudioPosts(widget.audioId),
        _service.isSaved(widget.audioId),
        _service.isAdmin(),
      ]);
      if (!mounted) return;
      final reels = results[0] as List<IdeaLabPost>;
      setState(() {
        _audio = audio;
        _reels = reels;
        _saved = results[1] as bool;
        _admin = results[2] as bool;
        _loading = false;
      });
      await _loadViews(reels);
    } catch (error) {
      if (mounted) {
        final detail = '$error'.toLowerCase();
        final missingObject = detail.contains('404') ||
            detail.contains('not_found') ||
            detail.contains('object not found');
        setState(() {
          _error = missingObject
              ? 'The audio file is missing or inaccessible in its configured Storage bucket. Retry once; if it still fails, the audio owner needs to restore that exact file. No other track was substituted. ($error)'
              : '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadViews(List<IdeaLabPost> posts) async {
    if (posts.isEmpty) return;
    try {
      final rows = await IdeaLabBackend.client.rpc(
        'idea_audio_reel_view_counts',
        params: {'target_posts': posts.map((post) => post.id).toList()},
      );
      if (!mounted) return;
      setState(() => _views = {
        for (final row in rows)
          (row['post_id'] as String): (row['view_count'] as num).toInt(),
      });
    } catch (_) {
      // The reel grid remains available when view counts are not readable.
    }
  }

  void _nearEnd() {
    if (_scroll.position.extentAfter < 500) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _reels.length < IdeaLabPostService.pageSize) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final more = await _posts.fetchAudioPosts(widget.audioId, offset: _reels.length);
      if (!mounted) return;
      final seen = _reels.map((post) => post.id).toSet();
      final fresh = more.where((post) => seen.add(post.id)).toList();
      setState(() { _reels = [..._reels, ...fresh]; _loadingMore = false; });
      await _loadViews(fresh);
    } catch (error) {
      if (mounted) setState(() { _error = '$error'; _loadingMore = false; });
    }
  }

  Future<void> _togglePlay() async {
    final audio = _audio;
    if (audio == null) return;
    try {
      final existing = _player;
      if (existing != null && existing.value.isInitialized) {
        if (existing.value.isPlaying) {
          await existing.pause();
        } else {
          await existing.play();
        }
      } else {
        final player = VideoPlayerController.networkUrl(Uri.parse(audio.playableUrl));
        _player = player;
        await player.initialize();
        player.addListener(_playerTick);
        await player.setLooping(false);
        await player.play();
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio preview could not be played from its source.')),
      );
      }
    }
  }

  void _playerTick() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleSave() async {
    final audio = _audio;
    if (audio == null) return;
    try {
      await _service.toggleSave(audio.id, saved: _saved);
      if (mounted) setState(() => _saved = !_saved);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _report() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.navy,
      builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final item in const [('copyright', 'Copyright concern'), ('inappropriate', 'Inappropriate'), ('spam', 'Spam')])
          ListTile(title: Text(item.$2), onTap: () => Navigator.pop(context, item.$1)),
      ])),
    );
    if (reason == null || !mounted) return;
    try {
      await _service.report(widget.audioId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report received. Thank you.')),
      );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _hide() async {
    try {
      // Re-check membership at action time in case this page was left open
      // after the account's admin membership changed. The database RPC also
      // enforces is_audio_admin() and remains the authoritative check.
      if (!await _service.isAdmin()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Administrator access is required.')),
          );
        }
        return;
      }
      await _service.moderate(widget.audioId, 'hidden');
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  IdeaMusicTrack _asTrack(IdeaAudio audio) => IdeaMusicTrack(
    id: audio.id,
    audioId: audio.id,
    title: audio.title,
    creator: audio.artist,
    duration: Duration(seconds: audio.durationSeconds),
    audioUrl: audio.playableUrl,
    sourceUrl: audio.sourceUrl ?? audio.playableUrl,
    license: audio.license ?? 'Original audio',
    licenseCode: '',
    licenseUrl: '',
    attribution: audio.attribution ?? 'Original audio by ${audio.artist}',
    artworkUrl: audio.artworkUrl,
    provider: audio.kind == 'original' ? 'AM Motion Lab' : 'Openverse',
  );

  @override
  void dispose() {
    _scroll.dispose();
    _player?.removeListener(_playerTick);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = _audio;
    final player = _player;
    return Scaffold(
      appBar: AppBar(title: const Text('Audio')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && audio == null
              ? _MessageState(message: 'Could not load audio: $_error', retry: _load)
              : audio == null
                  ? const _MessageState(message: 'This audio is no longer available.')
                  : Stack(children: [
                    CustomScrollView(
                      controller: _scroll,
                      slivers: [
                        SliverToBoxAdapter(child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Center(child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: SizedBox(width: 220, height: 220, child: audio.artworkUrl == null
                                  ? const ColoredBox(color: AppColors.glassFillStrong, child: Icon(Icons.music_note_rounded, size: 70, color: AppColors.sky))
                                  : Image.network(audio.artworkUrl!, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.glassFillStrong, child: Icon(Icons.music_note_rounded, size: 70, color: AppColors.sky)))),
                            )),
                            const SizedBox(height: 18),
                            Text(audio.title, style: Theme.of(context).textTheme.headlineSmall),
                            Text(audio.artist, style: Theme.of(context).textTheme.bodyLarge),
                            Text('${audio.usesCount} reels', style: Theme.of(context).textTheme.bodyMedium),
                            if (audio.kind == 'original')
                              const Text('Audio is taken from the post video. Rights are not verified; reuse only when you have permission.'),
                            if ((audio.license ?? '').isNotEmpty) Text('Licence: ${audio.license}'),
                            if ((audio.attribution ?? '').isNotEmpty) Text(audio.attribution!, style: Theme.of(context).textTheme.bodySmall),
                            if (player != null && player.value.isInitialized) ...[
                              VideoProgressIndicator(player, allowScrubbing: true,
                                colors: const VideoProgressColors(playedColor: AppColors.sky, bufferedColor: Colors.white38, backgroundColor: Colors.white12)),
                              Text('${_time(player.value.position)} / ${_time(player.value.duration)}'),
                            ],
                            Wrap(spacing: 8, children: [
                              FilledButton.tonalIcon(onPressed: _togglePlay,
                                icon: Icon(player?.value.isPlaying == true ? Icons.pause : Icons.play_arrow),
                                label: Text(player?.value.isPlaying == true ? 'Pause' : 'Play')),
                              OutlinedButton.icon(onPressed: _toggleSave,
                                icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
                                label: Text(_saved ? 'Saved' : 'Save audio')),
                              if (audio.allowUse) FilledButton.icon(
                                onPressed: () => Navigator.pop(context, _asTrack(audio)),
                                icon: const Icon(Icons.add_to_photos_outlined), label: const Text('Use audio')),
                              TextButton.icon(onPressed: _report, icon: const Icon(Icons.flag_outlined), label: const Text('Report')),
                              if (_admin) TextButton.icon(onPressed: _hide, icon: const Icon(Icons.visibility_off_outlined), label: const Text('Hide audio')),
                            ]),
                            const SizedBox(height: 12),
                            Text('Reels using this audio', style: Theme.of(context).textTheme.titleLarge),
                          ]),
                        )),
                        if (_reels.isEmpty)
                          const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('No public reels use this audio yet.')))
                        else SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          sliver: SliverGrid.builder(
                            itemCount: _reels.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: .62),
                            itemBuilder: (context, index) {
                              final post = _reels[index];
                              final media = post.media.firstWhere((item) => item.mimeType == 'video/mp4');
                              return InkWell(
                                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                  builder: (_) => IdeaReelsScreen(posts: _reels, initialPostId: post.id),
                                )),
                                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Stack(fit: StackFit.expand, children: [
                                  if (media.thumbnailUrl != null) Image.network(media.thumbnailUrl!, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const _AudioPosterFallback())
                                  else const _AudioPosterFallback(),
                                  const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 38)),
                                  Positioned(left: 6, bottom: 6, child: DecoratedBox(
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      child: Text('${_views[post.id] ?? 0} views', style: const TextStyle(color: Colors.white, fontSize: 10))),
                                  )),
                                ])),
                              );
                            },
                          ),
                        ),
                        if (_loadingMore) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))),
                        if (_error != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text('Could not load more reels: $_error'),
                                  TextButton.icon(
                                    onPressed: _loadMore,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (player?.value.isInitialized == true)
                      Offstage(offstage: true, child: SizedBox(width: 1, height: 1, child: VideoPlayer(player!))),
                  ]),
    );
  }

  String _time(Duration value) => '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _AudioPosterFallback extends StatelessWidget {
  const _AudioPosterFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, AppColors.violet])),
    child: Center(child: Icon(Icons.movie_creation_outlined, color: AppColors.sky, size: 38)),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(message, textAlign: TextAlign.center),
      if (retry != null) TextButton(onPressed: retry, child: const Text('Retry')),
    ]),
  ));
}
