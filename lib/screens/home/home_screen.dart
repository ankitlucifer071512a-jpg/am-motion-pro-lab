import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../app/route_observer.dart';
import '../../services/course_repository.dart';
import '../../services/learning_progress_store.dart';
import '../../models/course.dart';
import '../../models/showcase_project.dart';
import '../../services/showcase_project_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/course_card.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/animated_progress_bar.dart';
import '../../widgets/light_sweep_text.dart';
import '../../widgets/home_character_hero.dart';
import '../../widgets/home_idea_gallery.dart';
import '../../widgets/reveal.dart';
import '../../widgets/section_header.dart';
import '../courses/course_detail_screen.dart';
import '../courses/course_learning_screen.dart';
import '../profile/support_screen.dart';
import '../games/projects_showcase_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onNavigate,
    this.isActive = true,
  });

  /// Switches the bottom-nav tab (1 = Courses, 2 = Game Lab).
  final ValueChanged<int> onNavigate;
  final bool isActive;

  static const _why = [
    (
      Icons.school_outlined,
      'Guided Learning',
      'Build skills through structured lessons, practice, and creative projects.'
    ),
    (
      Icons.work_outline_rounded,
      'Real Projects',
      'Practice on practical creative briefs, not just isolated tutorials.'
    ),
    (
      Icons.forum_outlined,
      'Mentorship',
      'Get feedback and direction as you build your creative skillset.'
    ),
    (
      Icons.trending_up_rounded,
      'Freelancing Guidance',
      'Understand how creative skills translate into freelance opportunities.'
    ),
    (
      Icons.handyman_outlined,
      'Practical Learning',
      'Focused on doing the work, not just watching it get done.'
    ),
    (
      Icons.tune_rounded,
      'Industry-Focused Skills',
      'Tools and workflows aligned with how creative work is actually made.'
    ),
  ];

  static const _journey = [
    ('Learn', 'Understand the fundamentals.'),
    ('Practice', 'Apply the concepts through exercises.'),
    ('Build', 'Create real creative projects.'),
    ('Improve', 'Get feedback and refine your work.'),
    ('Showcase', 'Build work that can become part of your portfolio.'),
    ('Grow', 'Use your skills for freelance or professional opportunities.'),
  ];

  @override
  Widget build(BuildContext context) {
    final courses = CourseRepository.courses;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        HomeCharacterHero(
          course: courses.firstWhere((course) => course.id == '3d-animation'),
          onExplore: () {
            final course =
                courses.firstWhere((course) => course.id == '3d-animation');
            CourseDetailScreen.open(
              context,
              course,
              'home-hero-${course.id}',
            );
          },
        ),
        const SizedBox(height: 18),
        Reveal(
            delay: const Duration(milliseconds: 1900),
            child: GlassCard(
                selected: true,
                strong: true,
                padding: const EdgeInsets.all(17),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('YOUR NEXT IDEA STARTS HERE',
                            style: AppText.label),
                        const SizedBox(height: 6),
                        Text('Learn by making.', style: AppText.h2),
                        const SizedBox(height: 4),
                        Text(
                            'Try a quick challenge and build your creative confidence.',
                            style: AppText.caption),
                        const SizedBox(height: 12),
                        AppButton(
                            label: 'Start a Game',
                            icon: Icons.play_arrow_rounded,
                            onTap: () => onNavigate(2))
                      ])),
                  const SizedBox(width: 10),
                  Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.violet.fade(.28),
                                blurRadius: 22)
                          ]),
                      child: const Icon(Icons.palette_rounded,
                          color: Colors.white, size: 29))
                ]))),
        const _ContinueLearningCard(),
        const SizedBox(height: 25),
        Reveal(
          delay: const Duration(milliseconds: 900),
          child: Column(
            children: [
              LightSweepText(
                'EXPLORE YOUR CREATIVE POTENTIAL',
                style: AppText.h1,
                textAlign: TextAlign.center,
                delay: const Duration(milliseconds: 2600),
                loop: true,
              ),
              const SizedBox(height: 12),
              Text(
                'Build real creative skills. Work on real projects. Turn your skills into opportunities.',
                style: AppText.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  AppButton(
                      label: 'Explore Courses',
                      icon: Icons.arrow_forward_rounded,
                      onTap: () => onNavigate(1)),
                  AppButton(
                      label: 'Talk to Us',
                      primary: false,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const SupportScreen()))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 44),
        const Reveal(
            child: SectionHeader(
                eyebrow: 'Featured',
                title: 'Start with a creative discipline')),
        const SizedBox(height: 16),
        _FeaturedCoursesCarousel(courses: courses, isActive: isActive),
        const SizedBox(height: 38),
        Row(
          children: [
            const Expanded(
              child: SectionHeader(
                eyebrow: 'Creative portfolio',
                title: 'Projects to make',
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProjectsShowcaseScreen(),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _HomeProjectHighlights(),
        const SizedBox(height: 44),
        const Reveal(
            child: SectionHeader(
                eyebrow: 'Why AM Motion Lab',
                title: 'Built around practical creative growth')),
        const SizedBox(height: 16),
        Reveal(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < _why.length; i++) ...[
                  if (i > 0)
                    const Divider(
                        height: 1, thickness: 1, color: AppColors.glassBorder),
                  _WhyRow(
                      icon: _why[i].$1, title: _why[i].$2, text: _why[i].$3),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 44),
        const Reveal(
            child: SectionHeader(
                eyebrow: 'Student journey', title: 'One path, six steps')),
        const SizedBox(height: 18),
        Reveal(
          child: Column(
            children: [
              for (var i = 0; i < _journey.length; i++)
                _JourneyStep(
                  number: i + 1,
                  title: _journey[i].$1,
                  text: _journey[i].$2,
                  last: i == _journey.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Reveal(
          child: GlassCard(
            strong: true,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('START TODAY', style: AppText.label),
                const SizedBox(height: 8),
                Text('Tell us what you want to create.', style: AppText.h2),
                const SizedBox(height: 8),
                Text(
                    'Pick a course, choose your level and begin your journey from curiosity to opportunity.',
                    style: AppText.body),
                const SizedBox(height: 18),
                AppButton(
                    label: 'View Courses',
                    expand: true,
                    icon: Icons.arrow_forward_rounded,
                    onTap: () => onNavigate(1)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
            child: Text('Learn \u2022 Create \u2022 Earn',
                style: AppText.caption)),
        const SizedBox(height: 40),
        const Reveal(
          child: SectionHeader(
            eyebrow: 'Community gallery',
            title: 'Explore what you can create',
          ),
        ),
        const SizedBox(height: 16),
        HomeIdeaGallery(isActive: isActive),
      ],
    );
  }
}

class _FeaturedCoursesCarousel extends StatefulWidget {
  const _FeaturedCoursesCarousel({
    required this.courses,
    required this.isActive,
  });
  final List<Course> courses;
  final bool isActive;

  @override
  State<_FeaturedCoursesCarousel> createState() =>
      _FeaturedCoursesCarouselState();
}

class _FeaturedCoursesCarouselState extends State<_FeaturedCoursesCarousel>
    with WidgetsBindingObserver {
  static const _initialPage = 10000;
  static const _transitionDuration = Duration(milliseconds: 1500);
  static const _interactionPause = Duration(seconds: 5);

  late PageController _controller;
  double _viewportFraction = .82;
  int _page = 0;
  bool _appIsForeground = true;
  Timer? _advanceTimer;
  Timer? _resumeTimer;

  bool get _canAutoplay =>
      widget.isActive && _appIsForeground && widget.courses.length > 1;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: _initialPage,
      viewportFraction: _viewportFraction,
    );
    WidgetsBinding.instance.addObserver(this);
    _syncAutoplay();
  }

  void _setViewportFraction(double fraction) {
    if ((_viewportFraction - fraction).abs() < .001) return;
    final previous = _controller;
    final page = previous.hasClients
        ? previous.page?.round() ?? _page
        : _page == 0
            ? _initialPage
            : _page;
    _viewportFraction = fraction;
    _controller = PageController(
      initialPage: page,
      viewportFraction: fraction,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  @override
  void didUpdateWidget(covariant _FeaturedCoursesCarousel oldWidget) {
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
    if (!mounted ||
        !_canAutoplay ||
        _advanceTimer != null ||
        _resumeTimer != null) {
      return;
    }
    _advanceTimer = Timer(const Duration(seconds: 6), () {
      _advanceTimer = null;
      if (!_canAutoplay || !_controller.hasClients) return;
      final current = _controller.page?.round() ?? _initialPage;
      _controller
          .animateToPage(
            current + 1,
            duration: _transitionDuration,
            curve: Curves.easeInOutCubic,
          )
          .then((_) {
            if (mounted) _scheduleAdvance();
          });
    });
  }

  void _pauseAutoplay() {
    _advanceTimer?.cancel();
    _advanceTimer = null;
    _resumeTimer?.cancel();
    _resumeTimer = null;
  }

  void _resumeAutoplay(PointerEvent _) {
    if (!_canAutoplay) return;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_interactionPause, () {
      _resumeTimer = null;
      _scheduleAdvance();
    });
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
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth * .78 < 320
              ? constraints.maxWidth * .78
              : 320.0;
          final viewportFraction = ((cardWidth + 20) / constraints.maxWidth)
              .clamp(.22, .82)
              .toDouble();
          _setViewportFraction(viewportFraction);
          return Column(
            children: [
              SizedBox(
                height: 280,
                child: Listener(
                  onPointerDown: (_) => _pauseAutoplay(),
                  onPointerUp: _resumeAutoplay,
                  onPointerCancel: _resumeAutoplay,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: widget.courses.length > 1
                        ? null
                        : widget.courses.length,
                    onPageChanged: (index) => setState(
                      () => _page = index % widget.courses.length,
                    ),
                    itemBuilder: (context, index) {
                      final course =
                          widget.courses[index % widget.courses.length];
                      final tag = 'course-img-${course.id}-featured';
                      return Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: cardWidth
                              .clamp(1.0, constraints.maxWidth - 10)
                              .toDouble(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: CourseCard(
                              course: course,
                              heroTag: tag,
                              compact: true,
                              imageAspectRatio: 16 / 9,
                              onTap: () => CourseDetailScreen.open(
                                context,
                                course,
                                tag,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < widget.courses.length; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _page == index ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color:
                            _page == index ? AppColors.sky : AppColors.inkFaint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      );
}

class _HomeProjectHighlights extends StatelessWidget {
  const _HomeProjectHighlights();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ShowcaseProject>>(
        future: ShowcaseProjectRepository.load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: snapshot.data!.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final project = snapshot.data![index];
                return SizedBox(
                  width: 250,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProjectShowcaseDetail(project: project),
                      ),
                    ),
                    child: GlassCard(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(project.category.toUpperCase(),
                              style: AppText.label),
                          const SizedBox(height: 5),
                          Text(project.title, style: AppText.h3),
                          const SizedBox(height: 4),
                          Text(project.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption),
                          const Spacer(),
                          Text('SAMPLE BRIEF', style: AppText.label),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
}

class _ContinueLearningCard extends StatefulWidget {
  const _ContinueLearningCard();

  @override
  State<_ContinueLearningCard> createState() => _ContinueLearningCardState();
}

class _ContinueLearningCardState extends State<_ContinueLearningCard>
    with RouteAware {
  late Future<Set<String>> _progress;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _progress = LearningProgressStore.instance.completedCourseLessons;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    if (_route != null) appRouteObserver.unsubscribe(this);
    _route = route;
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPopNext() {
    setState(() {
      _progress = LearningProgressStore.instance.completedCourseLessons;
    });
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Set<String>>(
        future: _progress,
        builder: (context, snapshot) {
          final completed = snapshot.data;
          if (completed == null || completed.isEmpty) {
            return const SizedBox.shrink();
          }

          for (final course in CourseRepository.courses) {
            final lessons = [
              for (final module in course.modules)
                for (final topic in module.topics) topic,
            ];
            final done = List<bool>.generate(
              lessons.length,
              (index) => completed.contains('${course.id}:lesson-$index'),
            );
            final doneCount = done.where((value) => value).length;
            if (doneCount == 0 || doneCount == lessons.length) continue;

            final nextIndex = done.indexOf(false);
            return Padding(
              padding: const EdgeInsets.only(top: 14),
              child: GlassCard(
                selected: true,
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CONTINUE LEARNING', style: AppText.label),
                    const SizedBox(height: 5),
                    Text(course.name, style: AppText.h3),
                    const SizedBox(height: 3),
                    Text('Next: ${lessons[nextIndex]}', style: AppText.caption),
                    const SizedBox(height: 10),
                    AnimatedProgressBar(value: doneCount / lessons.length),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('$doneCount of ${lessons.length} demo lessons',
                            style: AppText.caption),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () =>
                              CourseLearningScreen.open(context, course),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Resume'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      );
}

class _WhyRow extends StatelessWidget {
  const _WhyRow({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.blue.fade(0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.sky),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.h3.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(text, style: AppText.body.copyWith(fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep(
      {required this.number,
      required this.title,
      required this.text,
      required this.last});
  final int number;
  final String title;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.sky.fade(0.6)),
                  ),
                  child: Text(number.toString().padLeft(2, '0'),
                      style: AppText.caption.copyWith(
                          color: AppColors.sky, fontWeight: FontWeight.w600)),
                ),
                if (!last)
                  Expanded(
                      child: Container(
                          width: 1, color: AppColors.glassBorderStrong)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 20, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.h3.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(text, style: AppText.body.copyWith(fontSize: 13.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
