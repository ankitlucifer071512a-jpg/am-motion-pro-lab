import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/course.dart';
import 'pressable.dart';

/// Independent 16:9 course-art carousel shown after the existing Home content.
class HomeMediaShowcase extends StatefulWidget {
  const HomeMediaShowcase({
    super.key,
    required this.courses,
    required this.onExplore,
    this.isActive = true,
  });

  final List<Course> courses;
  final ValueChanged<Course> onExplore;
  final bool isActive;

  @override
  State<HomeMediaShowcase> createState() => _HomeMediaShowcaseState();
}

class _HomeMediaShowcaseState extends State<HomeMediaShowcase>
    with WidgetsBindingObserver {
  static const _pageOffset = 100000;
  static const _advanceInterval = Duration(seconds: 8);
  static const _interactionPause = Duration(seconds: 5);
  static const _transitionDuration = Duration(milliseconds: 760);

  int get _initialPage {
    final index =
        widget.courses.indexWhere((course) => course.id == '3d-animation');
    return index < 0 ? 0 : index;
  }

  late final PageController _controller =
      PageController(initialPage: _pageOffset + _initialPage);
  late int _page = _initialPage;
  Timer? _advanceTimer;
  Timer? _resumeTimer;
  bool _animationsDisabled = false;
  bool _appIsForeground = true;

  bool get _canAutoplay =>
      widget.isActive &&
      _appIsForeground &&
      !_animationsDisabled &&
      widget.courses.length > 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncAutoplay();
  }

  @override
  void didUpdateWidget(covariant HomeMediaShowcase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.courses.length != widget.courses.length) {
      _syncAutoplay();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsForeground = state == AppLifecycleState.resumed;
    _syncAutoplay();
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
      if (!_canAutoplay) return;
      if (!_controller.hasClients) {
        _scheduleAdvance();
        return;
      }
      _controller
          .animateToPage(
            _currentPage + 1,
            duration: _transitionDuration,
            curve: Curves.easeInOutCubic,
          )
          .then((_) => _scheduleAdvance());
    });
  }

  void _pauseForInteraction() {
    _advanceTimer?.cancel();
    _advanceTimer = null;
    _resumeTimer?.cancel();
    _resumeTimer = null;
  }

  void _resumeAfterInteraction() {
    if (!_canAutoplay) return;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_interactionPause, () {
      _resumeTimer = null;
      _scheduleAdvance();
    });
  }

  void _onPointerDown(PointerDownEvent _) => _pauseForInteraction();

  void _onPointerUp(PointerEvent _) => _resumeAfterInteraction();

  void _goToPage(int index) {
    _pauseForInteraction();
    _resumeAfterInteraction();
    if (!_controller.hasClients || index == _currentPage) return;
    _controller.animateToPage(
      index,
      duration: _transitionDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  int get _currentPage => _controller.hasClients
      ? (_controller.page ?? (_pageOffset + _page)).round()
      : _pageOffset + _page;

  void _goToCourse(int index) {
    final count = widget.courses.length;
    var distance = (index - _page) % count;
    if (distance > count ~/ 2) distance -= count;
    if (distance < -(count ~/ 2)) distance += count;
    _goToPage(_currentPage + distance);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _advanceTimer?.cancel();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerUp,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.sky.withValues(alpha: .2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blue.withValues(alpha: .15),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                    child: PageView.builder(
                      controller: _controller,
                      onPageChanged: (index) =>
                          setState(() => _page = index % widget.courses.length),
                      itemBuilder: (context, index) {
                        final course =
                            widget.courses[index % widget.courses.length];
                        return AnimatedBuilder(
                          animation: _controller,
                          child: _ShowcaseSlide(
                            course: course,
                            page: index % widget.courses.length,
                            pageCount: widget.courses.length,
                            onExplore: () => widget.onExplore(course),
                          ),
                          builder: (context, child) {
                            final current = _controller.hasClients
                                ? _controller.page ?? _page.toDouble()
                                : _page.toDouble();
                            final distance =
                                (current - index).abs().clamp(0.0, 1.0);
                            return Opacity(
                              opacity: 1 - distance * .2,
                              child: Transform.scale(
                                scale: 1 - distance * .025,
                                child: child,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ShowcaseControl(
                      tooltip: 'Previous course',
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _goToPage(_currentPage - 1),
                    ),
                    const SizedBox(width: 6),
                    for (var index = 0; index < widget.courses.length; index++)
                      Semantics(
                        button: true,
                        selected: index == _page,
                        label: 'Show ${widget.courses[index].name}',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _goToCourse(index),
                          child: SizedBox(
                            width: 22,
                            height: 36,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: _page == index ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _page == index
                                      ? AppColors.sky
                                      : AppColors.inkFaint,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    _ShowcaseControl(
                      tooltip: 'Next course',
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _goToPage(_currentPage + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _ShowcaseSlide extends StatelessWidget {
  const _ShowcaseSlide({
    required this.course,
    required this.page,
    required this.pageCount,
    required this.onExplore,
  });

  final Course course;
  final int page;
  final int pageCount;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 540;
          return Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'home-showcase-${course.id}',
                child: Image.asset(
                  course.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.navy, AppColors.blue, AppColors.violet],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'ARTWORK PREVIEW UNAVAILABLE',
                        style: AppText.label.copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x11090E1A),
                      Color(0x55090E1A),
                      Color(0xF2090E1A),
                    ],
                    stops: [0, .4, 1],
                  ),
                ),
              ),
              Positioned(
                left: compact ? 14 : 34,
                right: compact ? 14 : 34,
                bottom: compact ? 12 : 30,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'COURSE SHOWCASE',
                          style: AppText.label.copyWith(
                            color: AppColors.sky,
                            fontSize: compact ? 8 : 10,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(page + 1).toString().padLeft(2, '0')} / ${pageCount.toString().padLeft(2, '0')}',
                          style: AppText.caption.copyWith(
                            fontSize: compact ? 8 : 10,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 3 : 8),
                    Text(
                      course.name,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.h1.copyWith(
                        fontSize: compact ? 18 : 32,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 6),
                    Text(
                      course.tagline,
                      maxLines: compact ? 2 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(
                        fontSize: compact ? 10 : 14,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: compact ? 7 : 14),
                    _ExploreShowcaseButton(
                      courseName: course.name,
                      compact: compact,
                      onTap: onExplore,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
}

class _ExploreShowcaseButton extends StatelessWidget {
  const _ExploreShowcaseButton({
    required this.courseName,
    required this.compact,
    required this.onTap,
  });

  final String courseName;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Explore $courseName',
        child: Pressable(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 34 : 44),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 16,
              vertical: compact ? 7 : 11,
            ),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blue.withValues(alpha: .28),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Explore course',
                  style: AppText.h3.copyWith(fontSize: compact ? 10 : 13),
                ),
                SizedBox(width: compact ? 4 : 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: compact ? 13 : 17,
                  color: AppColors.offWhite,
                ),
              ],
            ),
          ),
        ),
      );
}

class _ShowcaseControl extends StatelessWidget {
  const _ShowcaseControl({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.glassFillStrong,
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        icon: Icon(icon, size: 21),
      );
}
