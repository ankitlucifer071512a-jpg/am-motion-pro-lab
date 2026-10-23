import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/idea_lab_idea.dart';
import 'idea_lab_artwork.dart';

class IdeaLabCard extends StatelessWidget {
  const IdeaLabCard({
    super.key,
    required this.idea,
    required this.saved,
    required this.onTap,
    required this.onToggleSaved,
    required this.imageHeight,
  });

  final IdeaLabIdea idea;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;
  final double imageHeight;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.glassFill,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: 'idea-art-${idea.id}',
                    child: IdeaLabArtwork(
                      idea: idea,
                      height: imageHeight,
                      borderRadius: 0,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: AppColors.navyDeep.withValues(alpha: .86),
                      shape: const CircleBorder(
                        side: BorderSide(color: AppColors.glassBorder),
                      ),
                      child: IconButton(
                        tooltip: saved ? 'Remove saved idea' : 'Save idea',
                        onPressed: onToggleSaved,
                        visualDensity: VisualDensity.compact,
                        constraints:
                            const BoxConstraints.tightFor(width: 38, height: 38),
                        icon: Icon(
                          saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 19,
                          color: saved ? AppColors.sky : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      idea.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.h3.copyWith(fontSize: 14, height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      idea.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(fontSize: 11, height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetadataPill(idea.category),
                        _MetadataPill(idea.difficulty),
                        if (idea.durationLabel.isNotEmpty)
                          _MetadataPill(idea.durationLabel),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _MetadataPill extends StatelessWidget {
  const _MetadataPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption.copyWith(fontSize: 9),
        ),
      );
}
