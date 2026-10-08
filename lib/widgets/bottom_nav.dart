import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

class NavItemData {
  const NavItemData(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Bottom navigation with a glowing sliding indicator and small icon motion.
class AmBottomNav extends StatelessWidget {
  const AmBottomNav({super.key, required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const items = [
    NavItemData('Home', Icons.home_outlined, Icons.home_rounded),
    NavItemData('Courses', Icons.grid_view_outlined, Icons.grid_view_rounded),
    NavItemData('My Learning', Icons.play_circle_outline_rounded,
        Icons.play_circle_rounded),
    NavItemData(
        'Support', Icons.headset_mic_outlined, Icons.headset_mic_rounded),
    NavItemData('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.navy.fade(0.97),
        border: const Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: LayoutBuilder(
            builder: (context, cons) {
              final w = cons.maxWidth / items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: w * index + w * 0.28,
                    top: 0,
                    width: w * 0.44,
                    height: 2.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(3)),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.blue.fade(0.7),
                              blurRadius: 14,
                              spreadRadius: 1)
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavItem(
                              data: items[i],
                              active: i == index,
                              onTap: () => onChanged(i)),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.data, required this.active, required this.onTap});
  final NavItemData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: active ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: AnimatedSlide(
              offset: active ? const Offset(0, -0.06) : Offset.zero,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(
                    end: active ? AppColors.sky : AppColors.inkFaint),
                duration: const Duration(milliseconds: 220),
                builder: (context, color, _) => Icon(
                    active ? data.activeIcon : data.icon,
                    size: 24,
                    color: color),
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? AppColors.offWhite : AppColors.inkFaint,
              ),
              child: Text(data.label),
            ),
          ),
        ],
      ),
    );
  }
}
