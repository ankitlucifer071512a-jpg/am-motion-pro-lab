import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import 'pressable.dart';

/// Primary = blue->violet gradient with soft glow. Secondary = glass outline.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = true,
    this.expand = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            gradient: primary ? AppColors.brandGradient : null,
            color: primary ? null : AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(12),
            border: primary ? null : Border.all(color: AppColors.glassBorderStrong),
            boxShadow: primary
                ? [BoxShadow(color: AppColors.blue.fade(0.35), blurRadius: 20, offset: const Offset(0, 6))]
                : const [],
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: AppColors.offWhite,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 18, color: AppColors.offWhite),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
