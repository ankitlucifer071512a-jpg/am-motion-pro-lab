import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Very slow, soft blue/violet light behind the whole app.
/// One controller, three gradient circles (no blur filters = cheap on GPU).
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.child});
  final Widget child;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 30));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.navyDeep),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_c.value);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment(-1.0 + 0.6 * t, -0.95 + 0.25 * t),
                    child: const _Orb(color: AppColors.blue, size: 400, opacity: 0.28),
                  ),
                  Align(
                    alignment: Alignment(1.0 - 0.5 * t, -0.1 + 0.4 * t),
                    child: const _Orb(color: AppColors.violet, size: 360, opacity: 0.22),
                  ),
                  Align(
                    alignment: Alignment(-0.4 + 0.5 * t, 1.05),
                    child: const _Orb(color: AppColors.sky, size: 300, opacity: 0.09),
                  ),
                ],
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size, required this.opacity});
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.fade(opacity), color.fade(0)]),
        ),
      ),
    );
  }
}
