import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/course_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/course_card.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/light_sweep_text.dart';
import '../../widgets/reveal.dart';
import '../../widgets/section_header.dart';
import '../courses/course_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});

  /// Switches the bottom-nav tab (1 = Courses, 3 = Support).
  final ValueChanged<int> onNavigate;

  static const _why = [
    (Icons.videocam_outlined, 'Live Online Classes', 'Learn in real time, ask questions and follow along at your own pace.'),
    (Icons.work_outline_rounded, 'Real Projects', 'Practice on practical creative briefs, not just isolated tutorials.'),
    (Icons.forum_outlined, 'Mentorship', 'Get feedback and direction as you build your creative skillset.'),
    (Icons.trending_up_rounded, 'Freelancing Guidance', 'Understand how creative skills translate into freelance opportunities.'),
    (Icons.handyman_outlined, 'Practical Learning', 'Focused on doing the work, not just watching it get done.'),
    (Icons.tune_rounded, 'Industry-Focused Skills', 'Tools and workflows aligned with how creative work is actually made.'),
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
        const _HeroIntro(),
        const SizedBox(height: 30),
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
                  AppButton(label: 'Explore Courses', icon: Icons.arrow_forward_rounded, onTap: () => onNavigate(1)),
                  AppButton(label: 'Talk to Us', primary: false, onTap: () => onNavigate(3)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 44),
        const Reveal(child: SectionHeader(eyebrow: 'Featured', title: 'Start with a creative discipline')),
        const SizedBox(height: 16),
        SizedBox(
          height: 262,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final c = courses[i];
              final tag = 'course-img-${c.id}-featured';
              return SizedBox(
                width: 260,
                child: CourseCard(
                  course: c,
                  heroTag: tag,
                  compact: true,
                  onTap: () => CourseDetailScreen.open(context, c, tag),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 44),
        const Reveal(child: SectionHeader(eyebrow: 'Why AM Motion Lab', title: 'Built around practical creative growth')),
        const SizedBox(height: 16),
        Reveal(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < _why.length; i++) ...[
                  if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.glassBorder),
                  _WhyRow(icon: _why[i].$1, title: _why[i].$2, text: _why[i].$3),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 44),
        const Reveal(child: SectionHeader(eyebrow: 'Student journey', title: 'One path, six steps')),
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
                Text('Pick a course, choose your level and begin your journey from curiosity to opportunity.',
                    style: AppText.body),
                const SizedBox(height: 18),
                AppButton(label: 'View Courses', expand: true, icon: Icons.arrow_forward_rounded, onTap: () => onNavigate(1)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(child: Text('Learn \u2022 Create \u2022 Earn', style: AppText.caption)),
      ],
    );
  }
}

/// Logo -> AM MOTION LAB (with light sweep) -> LEARN * CREATE * EARN. Plays once.
class _HeroIntro extends StatefulWidget {
  const _HeroIntro();

  @override
  State<_HeroIntro> createState() => _HeroIntroState();
}

class _HeroIntroState extends State<_HeroIntro> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..forward();
  late final Animation<double> _logo = _interval(0.0, 0.45);
  late final Animation<double> _title = _interval(0.25, 0.7);
  late final Animation<double> _tag = _interval(0.5, 0.9);

  Animation<double> _interval(double a, double b) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Appear(
          anim: _logo,
          scaleFrom: 0.9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppColors.blue.fade(0.28), AppColors.blue.fade(0)]),
                ),
              ),
              const BrandLogo(size: 84),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _Appear(
          anim: _title,
          dy: 0.3,
          child: LightSweepText(
            'AM MOTION LAB',
            style: AppText.mark(44, spacing: 5),
            delay: const Duration(milliseconds: 900),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        _Appear(
          anim: _tag,
          dy: 0.4,
          child: Text(
            'LEARN \u2022 CREATE \u2022 EARN',
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(letterSpacing: 4, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _Appear extends StatelessWidget {
  const _Appear({required this.anim, required this.child, this.dy = 0, this.scaleFrom = 1});
  final Animation<double> anim;
  final Widget child;
  final double dy;
  final double scaleFrom;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, dy), end: Offset.zero).animate(anim),
        child: ScaleTransition(
          scale: Tween<double>(begin: scaleFrom, end: 1).animate(anim),
          child: child,
        ),
      ),
    );
  }
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
  const _JourneyStep({required this.number, required this.title, required this.text, required this.last});
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
                      style: AppText.caption.copyWith(color: AppColors.sky, fontWeight: FontWeight.w600)),
                ),
                if (!last) Expanded(child: Container(width: 1, color: AppColors.glassBorderStrong)),
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
