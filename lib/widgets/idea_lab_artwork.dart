import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/idea_lab_idea.dart';

class IdeaLabArtwork extends StatelessWidget {
  const IdeaLabArtwork({
    super.key,
    required this.idea,
    required this.height,
    this.borderRadius = 14,
    this.showLabel = true,
  });

  final IdeaLabIdea idea;
  final double height;
  final double borderRadius;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final asset = idea.imageAsset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (asset == null)
              _IdeaMediaPlaceholder(idea: idea)
            else
              Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _IdeaMediaPlaceholder(idea: idea),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x1A090E1A), Color(0x99090E1A)],
                  stops: [.35, 1],
                ),
              ),
            ),
            if (showLabel)
              Positioned(
                left: 10,
                bottom: 9,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.navyDeep.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    asset == null ? 'CONCEPT PREVIEW · NO MEDIA' : idea.category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label.copyWith(
                      fontSize: 8,
                      letterSpacing: .7,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IdeaMediaPlaceholder extends StatelessWidget {
  const _IdeaMediaPlaceholder({required this.idea});
  final IdeaLabIdea idea;

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(idea.category);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.navy,
            accent.withValues(alpha: .34),
            AppColors.navyDeep,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -44,
            right: -26,
            child: Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: .24)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: .2),
                    blurRadius: 38,
                    spreadRadius: 9,
                  )
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconFor(idea.category),
                    size: 38, color: accent.withValues(alpha: .94)),
                const SizedBox(height: 9),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    idea.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.h3.copyWith(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Concept preview · no media',
                  style: AppText.caption.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _accentFor(String category) {
  switch (category) {
    case 'Video Editing':
      return AppColors.sky;
    case 'Motion Graphics':
      return AppColors.violet;
    case '2D Animation':
      return const Color(0xFFFFB86B);
    case '3D Animation':
      return const Color(0xFF52D7D0);
    case 'Graphic Design':
      return const Color(0xFFFF7EAE);
    case 'Branding & Advertising':
      return const Color(0xFFB9A0FF);
    default:
      return const Color(0xFFFF8D78);
  }
}

IconData _iconFor(String category) {
  switch (category) {
    case 'Video Editing':
      return Icons.movie_creation_outlined;
    case 'Motion Graphics':
      return Icons.auto_awesome_motion_outlined;
    case '2D Animation':
      return Icons.animation_outlined;
    case '3D Animation':
      return Icons.view_in_ar_outlined;
    case 'Graphic Design':
      return Icons.palette_outlined;
    case 'Branding & Advertising':
      return Icons.campaign_outlined;
    default:
      return Icons.layers_outlined;
  }
}
