import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/idea_music_track.dart';
import '../../services/idea_music_catalog.dart';
import '../../services/idea_audio_service.dart';
import '../../services/idea_lab_backend.dart';
import 'idea_audio_page.dart';

class IdeaMusicLibraryScreen extends StatefulWidget {
  const IdeaMusicLibraryScreen({super.key, this.catalog, this.initialTab = 0});
  final IdeaMusicCatalog? catalog;
  final int initialTab;

  @override
  State<IdeaMusicLibraryScreen> createState() => _IdeaMusicLibraryScreenState();
}

class _IdeaMusicLibraryScreenState extends State<IdeaMusicLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final IdeaMusicCatalog _catalog = widget.catalog ?? IdeaMusicCatalog();
  final _search = TextEditingController();
  Timer? _debounce;
  List<IdeaMusicTrack> _tracks = [];
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _requestId = 0;
  String? _moreError;
  String? _playingId;
  VideoPlayerController? _player;
  String? _playbackError;
  String? _relatedFor;
  bool _relatedLoading = false;
  String? _relatedError;
  List<IdeaMusicTrack> _relatedTracks = [];
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 3),
  );
  List<_VideoMusicEntry> _videoMusic = [];
  List<IdeaMusicTrack> _savedTracks = [];
  List<IdeaAudio> _originalAudios = [];
  String? _originalAudioError;
  bool _originalAudioLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadVideoMusic();
    _loadSavedTracks();
    _loadOriginalAudios();
  }

  Future<void> _loadOriginalAudios() async {
    if (mounted) setState(() => _originalAudioLoading = true);
    try {
      final audios = await IdeaAudioService().originals();
      if (mounted) {
        setState(() {
          _originalAudios = audios;
          _originalAudioError = null;
          _originalAudioLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _originalAudioError = '$error';
          _originalAudioLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _player?.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadVideoMusic() async {
    try {
      final rows = await IdeaLabBackend.client
          .from('idea_posts')
          .select('id,creator_id,music_metadata,idea_profiles(display_name)')
          .not('published_at', 'is', null)
          .not('music_metadata', 'is', null)
          .order('created_at', ascending: false)
          .limit(100);
      final entries = <_VideoMusicEntry>[];
      for (final raw in rows) {
        try {
          final row = Map<String, dynamic>.from(raw);
          final selection = IdeaMusicSelection.fromJson(
            Map<String, dynamic>.from(row['music_metadata'] as Map),
          );
          final profile = row['idea_profiles'] as Map<String, dynamic>?;
          entries.add(
            _VideoMusicEntry(
              selection: selection,
              creatorId: row['creator_id'] as String,
              creator: profile?['display_name'] as String? ?? 'Creator',
            ),
          );
        } catch (_) {
          // Skip malformed/legacy metadata rather than showing an unplayable row.
        }
      }
      if (mounted) setState(() => _videoMusic = entries);
    } catch (_) {
      // The catalogue remains usable if community post music is unavailable.
    }
  }

  Future<void> _loadSavedTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final values =
          prefs.getStringList('idea_saved_music_v1') ?? const <String>[];
      final tracks = <IdeaMusicTrack>[];
      for (final value in values) {
        try {
          tracks.add(
            IdeaMusicSelection.fromJson(
              Map<String, dynamic>.from(jsonDecode(value) as Map),
            ).track,
          );
        } catch (_) {}
      }
      if (mounted) setState(() => _savedTracks = tracks);
    } catch (_) {}
  }

  Future<void> _toggleSaved(IdeaMusicTrack track) async {
    final values = [..._savedTracks];
    final existing = values.indexWhere(
      (item) => item.provider == track.provider && item.id == track.id,
    );
    if (existing >= 0) {
      values.removeAt(existing);
    } else {
      values.insert(0, track);
    }
    setState(() => _savedTracks = values);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'idea_saved_music_v1',
      values
          .map(
            (item) => jsonEncode(
              item.toJson(start: Duration.zero, end: item.duration),
            ),
          )
          .toList(),
    );
  }

  bool _matchesSearch(IdeaMusicTrack track) =>
      _search.text.trim().isEmpty ||
      '${track.title} ${track.creator} ${track.tags.join(' ')} ${track.genres.join(' ')}'
          .toLowerCase()
          .contains(_search.text.trim().toLowerCase());

  List<_VideoMusicEntry> get _visibleVideoMusic => _videoMusic
      .where((entry) => _matchesSearch(entry.selection.track))
      .toList(growable: false);

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _moreError = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final result = await _catalog.search(
        query: _search.text,
        category: 'popular',
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _tracks = result.tracks;
        _loading = false;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = _friendlyError(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final nextPage = _page + 1;
      final result = await _catalog.search(
        query: _search.text,
        category: 'popular',
        page: nextPage,
      );
      if (!mounted) return;
      final seen = _tracks.map((track) => track.id).toSet();
      final unique = result.tracks
          .where((track) => seen.add(track.id))
          .toList();
      setState(() {
        _tracks = [..._tracks, ...unique];
        _page = nextPage;
        _hasMore = result.hasMore && _page < 20;
        _loadingMore = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _moreError = _friendlyError(error);
          _loadingMore = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
    if (message.contains('Sign in')) return message;
    return message;
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
  }

  Future<void> _togglePreview(IdeaMusicTrack track) async {
    if (_playingId == track.id && _player != null) {
      if (_player!.value.isPlaying) {
        await _player!.pause();
      } else {
        try {
          await _player!.play();
          if (mounted) setState(() => _playbackError = null);
        } catch (_) {
          if (mounted) {
            setState(
              () => _playbackError =
                  'This preview could not be played. Try another track.',
            );
          }
        }
      }
      if (mounted) setState(() {});
      return;
    }
    final old = _player;
    _player = null;
    await old?.dispose();
    if (!mounted) return;
    setState(() {
      _playingId = track.id;
      _playbackError = null;
    });
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(track.audioUrl),
      );
      _player = controller;
      await controller.initialize();
      if (!mounted || controller != _player) return;
      controller.addListener(_playerTick);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() {
          _playingId = null;
          _playbackError =
              'Preview unavailable. The source may have moved or blocked playback.';
        });
      }
    }
  }

  void _playerTick() {
    final player = _player;
    if (!mounted || player == null) return;
    if (player.value.hasError) {
      setState(() {
        _playbackError =
            'Preview playback failed. Try another track or retry search.';
        _playingId = null;
      });
    } else {
      setState(() {});
    }
  }

  String _duration(Duration duration) {
    final total = duration.inSeconds;
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _useTrack(IdeaMusicTrack track) async {
    await _player?.pause();
    if (mounted) Navigator.of(context).pop(track);
  }

  Future<void> _loadRelated(IdeaMusicTrack track) async {
    if (_relatedFor == track.id) {
      setState(() => _relatedFor = null);
      return;
    }
    setState(() {
      _relatedFor = track.id;
      _relatedLoading = true;
      _relatedError = null;
      _relatedTracks = [];
    });
    try {
      final tracks = await _catalog.related(track);
      if (!mounted || _relatedFor != track.id) return;
      setState(() {
        _relatedTracks = tracks;
        _relatedLoading = false;
      });
    } catch (error) {
      if (!mounted || _relatedFor != track.id) return;
      setState(() {
        _relatedError = _friendlyError(error);
        _relatedLoading = false;
      });
    }
  }

  Future<void> _openLink(String? value) async {
    final uri = Uri.tryParse(value ?? '');
    if (uri == null || uri.scheme != 'https') return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this link.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.music_note_rounded, color: AppColors.sky),
            const SizedBox(width: 10),
            Text('Music Library', style: AppText.h3),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  width < 600 ? 14 : 26,
                  14,
                  width < 600 ? 14 : 26,
                  8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: _searchChanged,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {
                        _debounce?.cancel();
                        _load();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search songs, artists, sounds…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Search',
                          onPressed: () {
                            _debounce?.cancel();
                            _load();
                          },
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_playbackError != null)
                MaterialBanner(
                  content: Text(_playbackError!),
                  actions: [
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              TabBar(
                isScrollable: true,
                controller: _tabs,
                tabs: const [
                  Tab(text: 'Music'),
                  Tab(text: 'Original audios'),
                  Tab(text: 'Your music'),
                  Tab(text: 'Saved music'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _buildMusicList(width),
                    _buildOriginalAudioList(width),
                    _buildVideoMusicList(width, onlyMine: true),
                    _savedTracks.isEmpty
                        ? const _StatePanel(
                            icon: Icons.bookmark_border,
                            title: 'No saved music',
                            message: 'Save tracks here to find them again.',
                            action: 'Browse music',
                            onRetry: null,
                          )
                        : ListView(
                            padding: const EdgeInsets.all(14),
                            children: [
                              for (final track in _savedTracks)
                                _trackTile(track),
                            ],
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOriginalAudioList(double width) {
    if (_originalAudioLoading && _originalAudios.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_originalAudioError != null && _originalAudios.isEmpty) {
      return _StatePanel(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load original audios',
        message: _originalAudioError!,
        action: 'Retry',
        onRetry: _loadOriginalAudios,
      );
    }
    if (_originalAudios.isEmpty) {
      return _StatePanel(
        icon: Icons.music_off_outlined,
        title: 'No original audios yet',
        message: 'Audio from published video posts will appear here.',
        action: 'Refresh',
        onRetry: _loadOriginalAudios,
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        width < 600 ? 14 : 26,
        8,
        width < 600 ? 14 : 26,
        24,
      ),
      children: [
        for (final audio in _originalAudios)
          Card(
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: audio.artworkUrl == null
                        ? const ColoredBox(
                            color: AppColors.glassFillStrong,
                            child: Icon(
                              Icons.music_note_rounded,
                              color: AppColors.sky,
                            ),
                          )
                        : Image.network(
                            audio.artworkUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: AppColors.glassFillStrong,
                              child: Icon(
                                Icons.music_note_rounded,
                                color: AppColors.sky,
                              ),
                            ),
                          ),
                  ),
                ),
                title: Text(
                  audio.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${audio.artist} · ${audio.usesCount} reels'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final track = await Navigator.of(context)
                      .push<IdeaMusicTrack>(
                        MaterialPageRoute(
                          builder: (_) => IdeaAudioPage(audioId: audio.id),
                        ),
                      );
                  if (track != null) await _useTrack(track);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMusicList(double width) {
    if (_loading && _tracks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _tracks.isEmpty) {
      return _StatePanel(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load music',
        message: _error!,
        action: 'Retry',
        onRetry: _load,
      );
    }
    final tracks = _tracks.where(_matchesSearch).toList(growable: false);
    final community = _visibleVideoMusic;
    if (tracks.isEmpty && community.isEmpty) {
      return _StatePanel(
        icon: Icons.music_off_outlined,
        title: 'No matching tracks',
        message: 'Try another search or load more catalogue results.',
        action: _hasMore ? 'Load more' : 'Clear search',
        onRetry: _hasMore
            ? _loadMore
            : () {
                _search.clear();
                _load();
              },
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        width < 600 ? 14 : 26,
        8,
        width < 600 ? 14 : 26,
        24,
      ),
      children: [
        if (tracks.isNotEmpty) ...[
          for (final track in tracks) _trackTile(track),
          if (_hasMore || _loadingMore || _moreError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _moreError != null
                    ? TextButton(
                        onPressed: _loadMore,
                        child: Text('Retry: $_moreError'),
                      )
                    : OutlinedButton.icon(
                        onPressed: _loadingMore ? null : _loadMore,
                        icon: _loadingMore
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.expand_more_rounded),
                        label: Text(
                          _loadingMore ? 'Loading tracks…' : 'Load more tracks',
                        ),
                      ),
              ),
            ),
        ],
        if (community.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text('Music from video posts', style: AppText.h3),
          ),
          for (final entry in community)
            _trackTile(entry.selection.track, creatorLabel: entry.creator),
        ],
      ],
    );
  }

  Widget _buildVideoMusicList(double width, {required bool onlyMine}) {
    final userId = IdeaLabBackend.currentUser?.id;
    final entries = _visibleVideoMusic
        .where(
          (entry) => !onlyMine || (userId != null && entry.creatorId == userId),
        )
        .toList(growable: false);
    if (entries.isEmpty) {
      return _StatePanel(
        icon: Icons.music_off_outlined,
        title: onlyMine
            ? 'No music on your videos yet'
            : 'No video music available',
        message: onlyMine
            ? 'Music selected for your published videos will appear here.'
            : 'Music selected for published videos appears here.',
        action: 'Refresh',
        onRetry: _loadVideoMusic,
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        width < 600 ? 14 : 26,
        8,
        width < 600 ? 14 : 26,
        24,
      ),
      children: [
        for (final entry in entries)
          _trackTile(entry.selection.track, creatorLabel: entry.creator),
      ],
    );
  }

  Widget _trackTile(
    IdeaMusicTrack track, {
    bool showRelated = true,
    String? creatorLabel,
  }) {
    final player = _playingId == track.id ? _player : null;
    final initialized = player?.value.isInitialized == true;
    final playing = player?.value.isPlaying == true;
    final position = initialized ? player!.value.position : Duration.zero;
    final duration = initialized ? player!.value.duration : track.duration;
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: track.artworkUrl == null
                        ? const ColoredBox(
                            color: AppColors.glassFillStrong,
                            child: Icon(
                              Icons.music_note_rounded,
                              color: AppColors.sky,
                            ),
                          )
                        : Image.network(
                            track.artworkUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: AppColors.glassFillStrong,
                              child: Icon(
                                Icons.music_note_rounded,
                                color: AppColors.sky,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.h3,
                      ),
                      Text(
                        '${creatorLabel ?? track.creator} · ${_duration(track.duration)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                      Text(
                        '${track.provider} · ${track.license}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip:
                      _savedTracks.any(
                        (item) =>
                            item.provider == track.provider &&
                            item.id == track.id,
                      )
                      ? 'Remove saved music'
                      : 'Save music',
                  onPressed: () => _toggleSaved(track),
                  icon: Icon(
                    _savedTracks.any(
                          (item) =>
                              item.provider == track.provider &&
                              item.id == track.id,
                        )
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: AppColors.sky,
                  ),
                ),
                IconButton(
                  tooltip: playing ? 'Pause preview' : 'Play preview',
                  onPressed: () => _togglePreview(track),
                  icon: Icon(
                    playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: AppColors.sky,
                    size: 32,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => _useTrack(track),
                  child: const Text('Use'),
                ),
              ],
            ),
            if (_playingId == track.id)
              Row(
                children: [
                  Expanded(
                    child: initialized
                        ? LinearProgressIndicator(value: progress)
                        : const LinearProgressIndicator(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_duration(position)} / ${_duration(duration)}',
                    style: AppText.caption.copyWith(fontSize: 10),
                  ),
                ],
              ),
            if (showRelated)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _loadRelated(track),
                  icon: Icon(
                    _relatedFor == track.id
                        ? Icons.expand_less
                        : Icons.queue_music_rounded,
                  ),
                  label: Text(
                    _relatedFor == track.id
                        ? 'Hide related music'
                        : 'Related Music',
                  ),
                ),
              ),
            if (showRelated && _relatedFor == track.id)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _relatedLoading
                    ? const LinearProgressIndicator()
                    : _relatedError != null
                    ? Row(
                        children: [
                          Expanded(child: Text(_relatedError!)),
                          TextButton(
                            onPressed: () => _loadRelated(track),
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    : _relatedTracks.isEmpty
                    ? Text(
                        'No related tracks found. Try searching by a genre, mood, or instrument.',
                        style: AppText.caption,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Related Music', style: AppText.h3),
                          const SizedBox(height: 6),
                          for (final related in _relatedTracks)
                            _trackTile(related, showRelated: false),
                        ],
                      ),
              ),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () => _openLink(track.sourceUrl),
                  child: const Text('Source'),
                ),
                TextButton(
                  onPressed: () => _openLink(track.licenseUrl),
                  child: const Text('Licence'),
                ),
                if (track.creatorUrl != null)
                  TextButton(
                    onPressed: () => _openLink(track.creatorUrl),
                    child: const Text('Creator'),
                  ),
                TextButton.icon(
                  onPressed: () => _reportTrack(track),
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: const Text('Report'),
                ),
              ],
            ),
            if (track.attribution.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  track.attribution,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportTrack(IdeaMusicTrack track) async {
    final openSource = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report a music listing'),
        content: Text(
          'This track is listed by Openverse. To report its title, creator, or licence, open the original source page and use that provider’s report controls.\n\n${track.title}\n${track.creator} · ${track.provider}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open source'),
          ),
        ],
      ),
    );
    if (openSource == true) await _openLink(track.sourceUrl);
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onRetry,
  });
  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.sky),
          const SizedBox(height: 12),
          Text(title, style: AppText.h3, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: AppText.body, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (onRetry != null)
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(action),
            ),
        ],
      ),
    ),
  );
}

class _VideoMusicEntry {
  const _VideoMusicEntry({
    required this.selection,
    required this.creatorId,
    required this.creator,
  });
  final IdeaMusicSelection selection;
  final String creatorId;
  final String creator;
}
