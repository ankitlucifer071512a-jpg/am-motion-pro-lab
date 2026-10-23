import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../services/idea_lab_backend.dart';

/// A looping 3D-style carousel backed by recent published Idea Lab images.
class HomeIdeaGallery extends StatefulWidget {
  const HomeIdeaGallery({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<HomeIdeaGallery> createState() => _HomeIdeaGalleryState();
}

class _HomeIdeaGalleryState extends State<HomeIdeaGallery>
    with WidgetsBindingObserver {
  static const _maxImages = 20;
  static const _maxPostsToScan = IdeaLabPostService.pageSize * 4;
  static const _initialPage = 10000;
  static const _advanceInterval = Duration(seconds: 4);
  static const _transitionDuration = Duration(milliseconds: 850);
  static const _interactionPause = Duration(seconds: 5);

  final _service = IdeaLabPostService();
  late PageController _controller;
  double _viewportFraction = .5;
  List<_GalleryImageItem> _images = const [];
  int _currentPage = 0;
  bool _loading = false;
  bool _hasLoaded = false;
  bool _appIsForeground = true;
  bool _animationsDisabled = false;
  String? _error;
  Timer? _advanceTimer;
  Timer? _resumeTimer;

  bool get _canAutoplay =>
      widget.isActive &&
      _appIsForeground &&
      !_animationsDisabled &&
      _images.length > 1;

  int get _activeIndex => _images.isEmpty ? 0 : _currentPage % _images.length;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: _initialPage,
      viewportFraction: _viewportFraction,
    );
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _setViewportFraction(double fraction) {
    if ((_viewportFraction - fraction).abs() < .001) return;
    final previous = _controller;
    final page = previous.hasClients
        ? previous.page?.round() ?? _currentPage
        : _currentPage == 0
            ? _initialPage
            : _currentPage;
    _viewportFraction = fraction;
    _controller = PageController(
      initialPage: page,
      viewportFraction: fraction,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncAutoplay();
  }

  @override
  void didUpdateWidget(covariant HomeIdeaGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      if (_hasLoaded) _load();
      _syncAutoplay();
    } else if (oldWidget.isActive != widget.isActive) {
      _syncAutoplay();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsForeground = state == AppLifecycleState.resumed;
    _syncAutoplay();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _pauseAutoplay();

    try {
      final images = <_GalleryImageItem>[];
      var offset = 0;

      while (images.length < _maxImages && offset < _maxPostsToScan) {
        final page = await _service.fetchPage(offset: offset);
        for (final post in page) {
          for (final media in post.media) {
            if (!media.mimeType.startsWith('image/')) continue;
            images.add(_GalleryImageItem(post: post, media: media));
            if (images.length == _maxImages) break;
          }
          if (images.length == _maxImages) break;
        }

        offset += page.length;
        if (page.length < IdeaLabPostService.pageSize) break;
      }

      if (!mounted) return;
      setState(() {
        _images = images;
        _currentPage = _initialPage;
        _loading = false;
        _hasLoaded = true;
      });
      if (_controller.hasClients) _controller.jumpToPage(_initialPage);
      _syncAutoplay();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasLoaded = true;
        _error = _readableError(error);
      });
    }
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('Supabase is not initialized')) {
      return 'Connect Supabase to show published Idea Lab images here.';
    }
    return 'Could not load published images. Check your connection and try again.';
  }

  void _syncAutoplay() {
    if (!_canAutoplay) {
      _advanceTimer?.cancel();
      _advanceTimer = null;
      _resumeTimer?.cancel();
      _resumeTimer = null;
      return;
    }
    _scheduleAdvance();
  }

  void _scheduleAdvance() {
    if (!_canAutoplay || _advanceTimer != null || _resumeTimer != null) return;
    _advanceTimer = Timer(_advanceInterval, () {
      _advanceTimer = null;
      if (!_canAutoplay || !_controller.hasClients) return;
      _controller
          .animateToPage(
            _currentPage + 1,
            duration: _transitionDuration,
            curve: Curves.easeInOutCubic,
          )
          .then((_) => _scheduleAdvance());
    });
  }

  void _pauseAutoplay() {
    _advanceTimer?.cancel();
    _advanceTimer = null;
    _resumeTimer?.cancel();
    _resumeTimer = null;
  }

  void _resumeAutoplay() {
    if (!_canAutoplay) return;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_interactionPause, () {
      _resumeTimer = null;
      _scheduleAdvance();
    });
  }

  void _onPointerDown(PointerDownEvent _) => _pauseAutoplay();

  void _onPointerUp(PointerEvent _) => _resumeAutoplay();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _advanceTimer?.cancel();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 38),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _GalleryMessage(
        icon: Icons.cloud_off_outlined,
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    if (_images.isEmpty) {
      return const _GalleryMessage(
        icon: Icons.photo_library_outlined,
        message: 'No published graphics yet. Upload images in Idea Lab to see them here.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 600;
        final desiredFraction = constraints.maxWidth < 900
            ? .46
            : constraints.maxWidth < 1400
                ? .38
                : .27;
        _setViewportFraction(desiredFraction);
        final carouselHeight = narrow ? 330.0 : 430.0;
        return Column(
          children: [
            Listener(
              onPointerDown: _onPointerDown,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              child: SizedBox(
                height: carouselHeight,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _images.length > 1 ? null : 1,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  itemBuilder: (context, page) {
                    final item = _images[page % _images.length];
                    return AnimatedBuilder(
                      animation: _controller,
                      child: _CarouselArtwork(item: item),
                      builder: (context, child) {
                        final current = _controller.hasClients
                            ? _controller.page ?? _currentPage.toDouble()
                            : _currentPage.toDouble();
                        final distance = (current - page).clamp(-1.0, 1.0);
                        final strength = distance.abs();
                        return Transform(
                          alignment: distance < 0
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(distance * .32)
                            ..scaleByDouble(
                              1 - strength * .1,
                              1 - strength * .1,
                              1 - strength * .1,
                              1,
                            ),
                          child: Opacity(
                            opacity: 1 - strength * .26,
                            child: child,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 15),
            _ActiveImageDetails(item: _images[_activeIndex]),
            const SizedBox(height: 12),
            Text(
              '${_activeIndex + 1} / ${_images.length}',
              style: AppText.caption,
            ),
          ],
        );
      },
    );
  }
}

class _GalleryImageItem {
  const _GalleryImageItem({required this.post, required this.media});

  final IdeaLabPost post;
  final IdeaLabPostMedia media;
}

class _CarouselArtwork extends StatefulWidget {
  const _CarouselArtwork({required this.item});

  final _GalleryImageItem item;

  @override
  State<_CarouselArtwork> createState() => _CarouselArtworkState();
}

class _CarouselArtworkState extends State<_CarouselArtwork> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _aspectRatio;
  bool _imageFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _CarouselArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.media.url != widget.item.media.url) {
      _aspectRatio = null;
      _imageFailed = false;
      _resolveImage();
    }
  }

  void _resolveImage() {
    final oldStream = _stream;
    final oldListener = _listener;
    if (oldStream != null && oldListener != null) {
      oldStream.removeListener(oldListener);
    }

    final provider = NetworkImage(widget.item.media.url);
    _stream = provider.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() {
          _aspectRatio = info.image.width / info.image.height;
          _imageFailed = false;
        });
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!mounted) return;
        setState(() => _imageFailed = true);
      },
    );
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = (constraints.maxWidth - 16).clamp(1.0, 10000.0);
          final availableHeight = (constraints.maxHeight - 20).clamp(1.0, 10000.0);
          final ratio = _imageFailed ? 16 / 9 : (_aspectRatio ?? 16 / 9);
          final width = availableWidth < availableHeight * ratio
              ? availableWidth
              : availableHeight * ratio;
          final height = width / ratio;

          if (_aspectRatio == null && !_imageFailed) {
            return const Center(child: CircularProgressIndicator());
          }

          final dpr = MediaQuery.devicePixelRatioOf(context);
          final cacheWidth = (width * dpr).round().clamp(480, 1800).toInt();
          return Center(
            child: Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.glassBorderStrong),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: .2),
                    blurRadius: 25,
                    spreadRadius: -7,
                  ),
                ],
              ),
              child: _imageFailed
                  ? const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: AppColors.inkFaint, size: 38),
                    )
                  : Image.network(
                      widget.item.media.url,
                      width: width,
                      height: height,
                      fit: BoxFit.cover,
                      cacheWidth: cacheWidth,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: AppColors.inkFaint, size: 38),
                      ),
                    ),
            ),
          );
        },
      );
}

class _ActiveImageDetails extends StatelessWidget {
  const _ActiveImageDetails({required this.item});

  final _GalleryImageItem item;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('by ${item.post.creator}', style: AppText.caption),
          const SizedBox(height: 5),
          Text(
            item.post.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.h3,
          ),
          const SizedBox(height: 7),
          Text(item.post.category, style: AppText.caption),
        ],
      );
}

class _GalleryMessage extends StatelessWidget {
  const _GalleryMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.sky, size: 30),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: AppText.body),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      );
}
