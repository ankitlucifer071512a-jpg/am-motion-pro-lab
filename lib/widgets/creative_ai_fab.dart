import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../screens/idea_lab/creative_ai_chat_screen.dart';

class CreativeAiFab extends StatefulWidget {
  const CreativeAiFab({super.key});

  @override
  State<CreativeAiFab> createState() => _CreativeAiFabState();
}

class _CreativeAiFabState extends State<CreativeAiFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -1.5 * _controller.value),
      child: child,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: .24),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CreativeAiChatScreen(),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 17, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 19, color: Colors.white),
                SizedBox(width: 9),
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
