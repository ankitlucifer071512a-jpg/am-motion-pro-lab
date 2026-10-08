import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Text with a soft blue/violet light passing through it.
/// loop=false: plays once. loop=true: sweeps, then rests (8s cycle, sweep ~3s).
/// Use only for hero / important headings.
class LightSweepText extends StatefulWidget {
  const LightSweepText(
    this.text, {
    super.key,
    required this.style,
    this.delay = const Duration(milliseconds: 600),
    this.loop = false,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle style;
  final Duration delay;
  final bool loop;
  final TextAlign textAlign;

  @override
  State<LightSweepText> createState() => _LightSweepTextState();
}

class _LightSweepTextState extends State<LightSweepText> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: widget.loop ? const Duration(seconds: 8) : const Duration(milliseconds: 2200),
    );
    _timer = Timer(widget.delay, () {
      if (!mounted) return;
      widget.loop ? _c.repeat() : _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _timer?.cancel();
      _c.stop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Text(
      widget.text,
      textAlign: widget.textAlign,
      style: widget.style.copyWith(
        shadows: [Shadow(color: AppColors.blue.fade(0.35), blurRadius: 16)],
      ),
    );
    return AnimatedBuilder(
      animation: _c,
      child: base,
      builder: (context, child) {
        final v = _c.value;
        final p = widget.loop ? (v / 0.4).clamp(0.0, 1.0) : v;
        final active = v > 0 && p < 1;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            if (active)
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (rect) {
                  final slide = -1.0 + 2.0 * Curves.easeInOut.transform(p);
                  final clear = AppColors.sky.fade(0);
                  return LinearGradient(
                    colors: [clear, clear, AppColors.sky, clear, clear],
                    stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                    transform: _Slide(slide),
                  ).createShader(rect);
                },
                child: Text(
                  widget.text,
                  textAlign: widget.textAlign,
                  style: widget.style.copyWith(color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.slide);
  final double slide;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slide, 0, 0);
}
