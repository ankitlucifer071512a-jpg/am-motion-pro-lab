import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/course.dart';
import 'app_button.dart';
import 'glass_card.dart';
import 'pressable.dart';

/// A single, staged hero using one bundled character. The local poster remains
/// visible while the GLB loads and if the browser cannot render the model.
class HomeCharacterHero extends StatefulWidget {
  const HomeCharacterHero({
    super.key,
    required this.course,
    required this.onExplore,
  });

  final Course course;
  final VoidCallback onExplore;

  @override
  State<HomeCharacterHero> createState() => _HomeCharacterHeroState();
}

class _HomeCharacterHeroState extends State<HomeCharacterHero>
    with SingleTickerProviderStateMixin {
  static const _character =
      'assets/models/gallery/3d_anime_character_girl_for_blender.glb';
  static const _poster = 'assets/images/courses/3d animation.png';

  late final AnimationController _sequence = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..forward();

  late final Animation<double> _characterReveal = CurvedAnimation(
    parent: _sequence,
    curve: const Interval(0, .58, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _cardReveal = CurvedAnimation(
    parent: _sequence,
    curve: const Interval(.28, .72, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _glow = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: .22, end: .36), weight: 3),
    TweenSequenceItem(tween: Tween(begin: .36, end: .9), weight: 1),
    TweenSequenceItem(tween: Tween(begin: .9, end: .34), weight: 2),
    TweenSequenceItem(tween: Tween(begin: .34, end: .28), weight: 4),
  ]).animate(CurvedAnimation(
    parent: _sequence,
    curve: const Interval(.42, 1, curve: Curves.easeInOut),
  ));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _sequence.value = 1;
    } else if (!_sequence.isAnimating && _sequence.value == 0) {
      _sequence.forward();
    }
  }

  @override
  void dispose() {
    _sequence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final height = wide ? 438.0 : 390.0;
          return SizedBox(
            height: height,
            child: AnimatedBuilder(
              animation: _glow,
              builder: (context, child) {
                final glow = _glow.value;
                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: AppColors.sky.withValues(alpha: .12 + glow * .16),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xE6162849),
                        Color(0xD60D1529),
                        Color(0xE9101028)
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blue.withValues(alpha: glow * .2),
                        blurRadius: 28 + glow * 22,
                        spreadRadius: glow * 2,
                      ),
                      BoxShadow(
                        color: AppColors.violet.withValues(alpha: glow * .13),
                        blurRadius: 48,
                        offset: const Offset(20, 12),
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const _HeroLightTrails(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        wide ? 24 : 8, 16, wide ? 24 : 8, 16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: wide ? 11 : 9,
                          child: FadeTransition(
                            opacity: _characterReveal,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(-.08, .06),
                                end: Offset.zero,
                              ).animate(_characterReveal),
                              child: const _CharacterStage(
                                glow: .35,
                                assetPath: _character,
                                posterPath: _poster,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: wide ? 20 : 3),
                        Expanded(
                          flex: wide ? 9 : 10,
                          child: FadeTransition(
                            opacity: _cardReveal,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(.08, .1),
                                end: Offset.zero,
                              ).animate(_cardReveal),
                              child: _CourseFloatingCard(
                                course: widget.course,
                                onExplore: widget.onExplore,
                                compact: !wide,
                                glow: .35,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _CharacterStage extends StatelessWidget {
  const _CharacterStage({
    required this.glow,
    required this.assetPath,
    required this.posterPath,
  });

  final double glow;
  final String assetPath;
  final String posterPath;

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-.1, -.15),
                  radius: .88,
                  colors: [
                    AppColors.sky.withValues(alpha: .12 + glow * .08),
                    AppColors.violet.withValues(alpha: .08),
                    Colors.transparent,
                  ],
                  stops: const [0, .5, 1],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 19,
            left: 12,
            right: 12,
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: .16 + glow * .1),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: ModelViewer(
              src: assetPath,
              alt: 'Anime character 3D model for the 3D Animation course',
              poster: posterPath,
              loading: Loading.eager,
              reveal: Reveal.auto,
              cameraControls: true,
              autoRotate: true,
              rotationPerSecond: '7deg',
              autoRotateDelay: 0,
              cameraTarget: '0m 0.78m 0m',
              cameraOrbit: '0deg 75deg 145%',
              fieldOfView: '38deg',
              relatedCss: '''
                model-viewer::part(default-progress-bar) { display: none; }
              ''',
              shadowIntensity: .45,
              shadowSoftness: .8,
              exposure: 1,
              environmentImage: 'neutral',
              backgroundColor: Colors.transparent,
              debugLogging: false,
            ),
          ),
          const Positioned(
            left: 8,
            bottom: 5,
            child: _ModelLabel(),
          ),
        ],
      );
}

class _ModelLabel extends StatelessWidget {
  const _ModelLabel();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.navyDeep.withValues(alpha: .74),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text('IMPORTED CHARACTER  ·  SLOW ORBIT',
              style: AppText.label.copyWith(fontSize: 8, letterSpacing: 1)),
        ),
      );
}

class _CourseFloatingCard extends StatelessWidget {
  const _CourseFloatingCard({
    required this.course,
    required this.onExplore,
    required this.compact,
    required this.glow,
  });

  final Course course;
  final VoidCallback onExplore;
  final bool compact;
  final double glow;

  @override
  Widget build(BuildContext context) => GlassCard(
        selected: true,
        strong: true,
        padding: EdgeInsets.all(compact ? 13 : 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 30 : 38,
                  height: compact ? 30 : 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(compact ? 9 : 12),
                    gradient: AppColors.brandGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.violet
                            .withValues(alpha: .22 + glow * .14),
                        blurRadius: 18 + glow * 10,
                      ),
                    ],
                  ),
                  child: Icon(course.icon,
                      color: Colors.white, size: compact ? 17 : 21),
                ),
                const Spacer(),
                if (!compact) Text('FEATURED COURSE', style: AppText.label),
              ],
            ),
            if (compact) ...[
              const SizedBox(height: 8),
              Text('FEATURED COURSE',
                  style: AppText.label.copyWith(fontSize: 8.5)),
            ],
            SizedBox(height: compact ? 7 : 16),
            Text(
              course.name,
              maxLines: compact ? 2 : 2,
              overflow: TextOverflow.ellipsis,
              style: compact
                  ? AppText.h3.copyWith(fontSize: 17, height: 1.12)
                  : AppText.h1.copyWith(fontSize: 30),
            ),
            SizedBox(height: compact ? 7 : 9),
            Text(
              course.tagline,
              maxLines: compact ? 4 : 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(fontSize: compact ? 11.5 : 14),
            ),
            if (!compact) ...[
              const SizedBox(height: 15),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final skill in course.skills.take(2)) _SkillPill(skill),
                ],
              ),
            ],
            SizedBox(height: compact ? 14 : 22),
            if (compact)
              _CompactExploreButton(onTap: onExplore)
            else
              AppButton(
                label: 'Explore Course',
                icon: Icons.arrow_forward_rounded,
                expand: true,
                onTap: onExplore,
              ),
          ],
        ),
      );
}

class _CompactExploreButton extends StatelessWidget {
  const _CompactExploreButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withValues(alpha: .28),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            'Explore Course',
            maxLines: 1,
            softWrap: false,
            style: AppText.h3.copyWith(fontSize: 11.5),
          ),
        ),
      );
}

class _SkillPill extends StatelessWidget {
  const _SkillPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(label, style: AppText.caption.copyWith(fontSize: 11)),
        ),
      );
}

class _HeroLightTrails extends StatelessWidget {
  const _HeroLightTrails();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(painter: _LightTrailPainter()),
      );
}

class _LightTrailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Color(0x4D50CFFF),
          Color(0x386C5BFF),
          Colors.transparent
        ],
      ).createShader(Offset.zero & size);
    final path = Path()
      ..moveTo(size.width * .36, -20)
      ..cubicTo(size.width * .6, size.height * .16, size.width * .45,
          size.height * .42, size.width * .78, size.height * .65)
      ..cubicTo(size.width * .91, size.height * .75, size.width * .76,
          size.height * .87, size.width * 1.08, size.height + 20);
    canvas.drawPath(path, paint);
    final second = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6
      ..color = AppColors.violet.withValues(alpha: .18);
    canvas.drawArc(
      Rect.fromLTWH(size.width * .54, -size.height * .33, size.width * .8,
          size.height * .95),
      .4,
      1.5,
      false,
      second,
    );
  }

  @override
  bool shouldRepaint(covariant _LightTrailPainter oldDelegate) => false;
}
