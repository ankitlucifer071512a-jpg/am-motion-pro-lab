import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// A restrained, low-cost animated light field for featured creative screens.
/// It uses a single painter/controller and no image filters or blur layers.
class LivingLightField extends StatefulWidget {
  const LivingLightField({super.key, required this.child, this.grid = false});
  final Widget child;
  final bool grid;

  @override
  State<LivingLightField> createState() => _LivingLightFieldState();
}

class _LivingLightFieldState extends State<LivingLightField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 32),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.stop();
      _controller.value = .35;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.navyDeep),
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _LivingLightPainter(_controller.value, widget.grid),
              ),
            ),
          ),
          widget.child,
        ],
      );
}

class _LivingLightPainter extends CustomPainter {
  const _LivingLightPainter(this.phase, this.grid);
  final double phase;
  final bool grid;

  void _light(
      Canvas canvas, Size size, Offset center, double radius, Color color) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: .18),
          color.withValues(alpha: .045),
          color.withValues(alpha: 0)
        ],
        stops: const [0, .42, 1],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeInOut.transform(phase);
    _light(canvas, size, Offset(size.width * (.14 + .2 * t), size.height * .18),
        size.width * .78, AppColors.blue);
    _light(canvas, size, Offset(size.width * (.91 - .2 * t), size.height * .54),
        size.width * .72, AppColors.violet);
    _light(canvas, size, Offset(size.width * (.56 - .1 * t), size.height * .99),
        size.width * .64, AppColors.sky);
    if (grid) {
      final paint = Paint()
        ..color = AppColors.sky.withValues(alpha: .045)
        ..strokeWidth = 1;
      final horizon = size.height * .43;
      for (var i = -6; i <= 6; i++) {
        final x = size.width / 2 + i * size.width * .12;
        canvas.drawLine(
            Offset(size.width / 2, horizon), Offset(x, size.height), paint);
      }
      for (var i = 1; i <= 7; i++) {
        final f = i / 7;
        final y = horizon + math.pow(f, 1.8) * (size.height - horizon);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LivingLightPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.grid != grid;
}

/// Abstract 2D orb/ribbon for the home hero; intentionally not a 3D render.
class AnimatedHeroOrb extends StatefulWidget {
  const AnimatedHeroOrb({super.key, required this.child, this.size = 190});
  final Widget child;
  final double size;

  @override
  State<AnimatedHeroOrb> createState() => _AnimatedHeroOrbState();
}

class _AnimatedHeroOrbState extends State<AnimatedHeroOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 38),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.stop();
      _controller.value = .18;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _HeroOrbPainter(_controller.value),
            child: Center(child: widget.child),
          ),
        ),
      );
}

class _HeroOrbPainter extends CustomPainter {
  const _HeroOrbPainter(this.rotation);
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .36;
    final circle = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius * 1.36,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.blue.withValues(alpha: .28),
          AppColors.violet.withValues(alpha: .12),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: center, radius: radius * 1.36)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4B8BFF), Color(0xFF4432A3), Color(0xFF111B38)],
        ).createShader(circle),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * math.pi * 2);
    final ribbon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * .13
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
              colors: [Color(0xFFB5E8FF), Color(0xFF7B61FF), Color(0xFF5AC8FA)])
          .createShader(
              Rect.fromCircle(center: Offset.zero, radius: radius * 1.3));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero, width: radius * 2.48, height: radius * .76),
        ribbon);
    canvas.restore();
    final highlight = Paint()..color = Colors.white.withValues(alpha: .48);
    canvas.drawCircle(
        Offset(center.dx - radius * .31, center.dy - radius * .45),
        radius * .075,
        highlight);
  }

  @override
  bool shouldRepaint(covariant _HeroOrbPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}
