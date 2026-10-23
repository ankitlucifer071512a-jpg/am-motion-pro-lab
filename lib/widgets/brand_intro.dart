import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'brand_logo.dart';

class BrandIntro extends StatefulWidget {
  const BrandIntro({super.key, required this.child, this.initialization});

  final Widget child;
  final Future<void>? initialization;

  @override
  State<BrandIntro> createState() => _BrandIntroState();
}

class _BrandIntroState extends State<BrandIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final Animation<double> _glow = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, .4, curve: Curves.easeOut),
  );
  late final Animation<double> _logoIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.2 / 2.6, 1.1 / 2.6, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.2 / 2.6, 1.1 / 2.6, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _logoReveal = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.7 / 2.6, 1.4 / 2.6, curve: Curves.easeInOutCubic),
  );
  late final Animation<double> _sweep = CurvedAnimation(
    parent: _controller,
    curve: const Interval(1.2 / 2.6, 1.9 / 2.6, curve: Curves.easeInOut),
  );
  late final Animation<double> _tagline = CurvedAnimation(
    parent: _controller,
    curve: const Interval(1.5 / 2.6, 2.1 / 2.6, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _taglineSpacing = Tween<double>(
    begin: 4.0,
    end: 1.8,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(1.5 / 2.6, 2.1 / 2.6, curve: Curves.easeOutCubic),
  ));
  late final Animation<double> _fadeOut = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.8, 1, curve: Curves.easeIn),
  );

  bool _started = false;
  bool _showIntro = true;
  bool _reducedMotion = false;
  bool _reducedVisible = false;
  bool _animationDone = false;
  bool _initializationDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _runIntro();
  }

  Future<void> _runIntro() async {
    const asset = AssetImage('assets/brand/full-logo.png');
    try {
      await precacheImage(asset, context);
    } catch (_) {
      // BrandLogo retains its existing fallback if the configured asset is absent.
    }
    if (!mounted) return;
    if (_reducedMotion) {
      setState(() => _reducedVisible = true);
      await Future<void>.delayed(const Duration(milliseconds: 280));
    } else {
      try {
        await _controller.forward().orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    _animationDone = true;
    await _waitForInitialization();
  }

  Future<void> _waitForInitialization() async {
    try {
      await (widget.initialization ?? Future<void>.value()).timeout(
        const Duration(seconds: 8),
      );
    } catch (_) {
      // Startup continues when auth setup fails or exceeds the splash timeout.
    }
    if (!mounted) return;
    _initializationDone = true;
    _maybeContinue();
  }

  void _skip() {
    if (!_showIntro || _animationDone) return;
    _controller.stop();
    _animationDone = true;
    if (_reducedMotion) setState(() => _reducedVisible = true);
    _maybeContinue();
  }

  void _maybeContinue() {
    if (_animationDone && _initializationDone && mounted && _showIntro) {
      setState(() => _showIntro = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: AppColors.navyDeep,
        child: _showIntro
            ? GestureDetector(
                key: const ValueKey('am-motion-intro'),
                behavior: HitTestBehavior.opaque,
                onTap: _skip,
                child: RepaintBoundary(child: _buildIntro()),
              )
            : KeyedSubtree(
                key: const ValueKey('am-motion-home'),
                child: widget.child,
              ),
      ),
    );
  }

  Widget _buildIntro() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth * .66, 420.0);
        final logoHeight = width * .34;
        final screenHeight = constraints.maxHeight;
        final logoTop = math.max(0.0, screenHeight * .42 - logoHeight / 2);
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(
            opacity: _reducedMotion ? 1 : 1 - _fadeOut.value,
            child: child,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _IntroGlowPainter(_glow.value),
                ),
              ),
            ),
            Positioned(
              top: logoTop,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: width,
                  height: logoHeight,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final fade = _reducedMotion
                            ? (_reducedVisible ? 1.0 : 0.0)
                            : _logoFade.value;
                        final rise = _reducedMotion ? 0.0 : 12 * (1 - _logoIn.value);
                        final scale = _reducedMotion
                            ? 1.0
                            : .92 + .08 * _logoIn.value;
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 280),
                          opacity: fade,
                          child: Transform.translate(
                            offset: Offset(0, rise),
                            child: Transform.scale(
                              scale: scale,
                              child: _logoWithReveal(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: logoTop + logoHeight + 24,
              left: 12,
              right: 12,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => AnimatedOpacity(
                    duration: const Duration(milliseconds: 280),
                    opacity: _reducedMotion
                        ? (_reducedVisible ? 1.0 : 0.0)
                        : _tagline.value,
                    child: Transform.translate(
                      offset: Offset(0, _reducedMotion ? 0 : 8 * (1 - _tagline.value)),
                      child: Text(
                        'LEARN . CREATE . EARN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.sky.withValues(alpha: .82),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: _reducedMotion ? 1.8 : _taglineSpacing.value,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ],
          ),
        );
      },
    );
  }

  Widget _logoWithReveal() {
    final progress = _reducedMotion ? 1.0 : _logoReveal.value;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        if (progress >= 1) {
          return const LinearGradient(colors: [Colors.white, Colors.white])
              .createShader(bounds);
        }
        final edge = progress.clamp(0.0, 1.0);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [edge * .86, (edge + .14).clamp(0.0, 1.0)],
          colors: const [Colors.white, Colors.transparent],
        ).createShader(bounds);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Center(child: BrandLogo(size: 132, full: true)),
          if (!_reducedMotion)
            IgnorePointer(
              child: ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (bounds) {
                  final progress = _sweep.value;
                  final center = -0.55 + progress * 2.1;
                  return LinearGradient(
                    begin: Alignment(center - .16, -1),
                    end: Alignment(center + .16, 1),
                    colors: const [
                      Colors.transparent,
                      Color(0x1078CFFF),
                      Color(0x18FFFFFF),
                      Colors.transparent,
                    ],
                    stops: const [0, .42, .55, 1],
                  ).createShader(bounds);
                },
                child: const Center(child: BrandLogo(size: 132, full: true)),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntroGlowPainter extends CustomPainter {
  const _IntroGlowPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = Curves.easeOut.transform(progress);
    final center = Offset(size.width / 2, size.height * .42);
    for (final entry in [
      (AppColors.blue, Offset(-size.width * .13, 0)),
      (AppColors.violet, Offset(size.width * .13, size.height * .02)),
    ]) {
      final radius = math.min(size.width * .58, size.height * .44);
      final rect = Rect.fromCircle(center: center + entry.$2, radius: radius);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            entry.$1.withValues(alpha: .17 * alpha),
            entry.$1.withValues(alpha: .045 * alpha),
            Colors.transparent,
          ],
          stops: const [0, .48, 1],
        ).createShader(rect);
      canvas.drawCircle(rect.center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IntroGlowPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
