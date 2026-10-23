import 'package:flutter/material.dart';

import '../../app/transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/idea_lab_idea.dart';
import '../../services/idea_lab_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/idea_lab_artwork.dart';

class IdeaDetailScreen extends StatefulWidget {
  const IdeaDetailScreen({
    super.key,
    required this.idea,
    required this.saved,
    required this.onToggleSaved,
    required this.onOpenRelated,
  });

  final IdeaLabIdea idea;
  final bool saved;
  final Future<bool> Function() onToggleSaved;
  final ValueChanged<IdeaLabIdea> onOpenRelated;

  @override
  State<IdeaDetailScreen> createState() => _IdeaDetailScreenState();
}

class _IdeaDetailScreenState extends State<IdeaDetailScreen> {
  late bool _saved = widget.saved;
  bool _saving = false;

  Future<void> _toggleSaved() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final didSave = await widget.onToggleSaved();
      if (mounted && didSave) setState(() => _saved = !_saved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _startPractice() {
    Navigator.of(context).push(
      AppRoutes.slideUp(IdeaPracticeScreen(idea: widget.idea)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idea = widget.idea;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Idea details'),
        actions: [
          IconButton(
            tooltip: _saved ? 'Remove saved idea' : 'Save idea',
            onPressed: _saving ? null : _toggleSaved,
            icon: Icon(
              _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _saved ? AppColors.sky : null,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth < 560 ? 16.0 : 28.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(padding, 8, padding, 36),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, mediaConstraints) {
                          final height = (mediaConstraints.maxWidth * .49)
                              .clamp(190.0, 430.0);
                          return Hero(
                            tag: 'idea-art-${idea.id}',
                            child: IdeaLabArtwork(
                              idea: idea,
                              height: height,
                              borderRadius: 20,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 21),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoPill(idea.category),
                          _InfoPill(idea.difficulty),
                          if (idea.durationLabel.isNotEmpty)
                            _InfoPill(idea.durationLabel),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(idea.title, style: AppText.h1),
                      const SizedBox(height: 8),
                      Text(idea.description, style: AppText.body),
                      const SizedBox(height: 18),
                      GlassCard(
                        selected: true,
                        padding: const EdgeInsets.all(17),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('WHAT YOU’LL PRACTICE', style: AppText.label),
                            const SizedBox(height: 7),
                            Text(idea.learningObjective, style: AppText.body),
                          ],
                        ),
                      ),
                      const SizedBox(height: 23),
                      _DetailSection(
                        title: 'Software & tools',
                        icon: Icons.handyman_outlined,
                        items: idea.software,
                      ),
                      const SizedBox(height: 17),
                      _DetailSection(
                        title: 'Required assets & references',
                        icon: Icons.folder_open_outlined,
                        items: idea.requiredAssets,
                      ),
                      const SizedBox(height: 23),
                      Text('Tutorial steps', style: AppText.h2),
                      const SizedBox(height: 10),
                      for (var i = 0; i < idea.tutorialSteps.length; i++)
                        _NumberedStep(
                          number: i + 1,
                          text: idea.tutorialSteps[i],
                        ),
                      const SizedBox(height: 20),
                      GlassCard(
                        strong: true,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PRACTICAL ASSIGNMENT', style: AppText.label),
                            const SizedBox(height: 7),
                            Text(idea.assignment, style: AppText.body),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text('Completion checklist', style: AppText.h2),
                      const SizedBox(height: 8),
                      for (final item in idea.checklist)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.check_box_outline_blank,
                                    size: 18, color: AppColors.sky),
                              ),
                              const SizedBox(width: 9),
                              Expanded(child: Text(item, style: AppText.body)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Start Practice',
                        icon: Icons.play_arrow_rounded,
                        expand: true,
                        onTap: _startPractice,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Practice prompts are educational examples, not client commissions.',
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 30),
                      Text('Related ideas', style: AppText.h2),
                      const SizedBox(height: 12),
                      ...IdeaLabRepository.relatedTo(idea).map(
                        (related) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RelatedIdeaTile(
                            idea: related,
                            onTap: () => widget.onOpenRelated(related),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class IdeaPracticeScreen extends StatefulWidget {
  const IdeaPracticeScreen({super.key, required this.idea});
  final IdeaLabIdea idea;

  @override
  State<IdeaPracticeScreen> createState() => _IdeaPracticeScreenState();
}

class _IdeaPracticeScreenState extends State<IdeaPracticeScreen> {
  late final List<bool> _checked =
      List<bool>.filled(widget.idea.checklist.length, false);

  @override
  Widget build(BuildContext context) {
    final idea = widget.idea;
    final completed = _checked.where((value) => value).length;
    final allComplete = completed == _checked.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Practice task')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth < 560 ? 16.0 : 28.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(padding, 18, padding, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR PRACTICE BRIEF', style: AppText.label),
                      const SizedBox(height: 6),
                      Text(idea.title, style: AppText.h1),
                      const SizedBox(height: 15),
                      GlassCard(
                        selected: true,
                        padding: const EdgeInsets.all(19),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ASSIGNMENT', style: AppText.label),
                            const SizedBox(height: 8),
                            Text(idea.assignment, style: AppText.body),
                            const SizedBox(height: 15),
                            Text('LEARNING OBJECTIVE', style: AppText.label),
                            const SizedBox(height: 6),
                            Text(idea.learningObjective, style: AppText.body),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text('Work through the tutorial', style: AppText.h2),
                      const SizedBox(height: 8),
                      for (var i = 0; i < idea.tutorialSteps.length; i++)
                        _NumberedStep(
                          number: i + 1,
                          text: idea.tutorialSteps[i],
                        ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child:
                                Text('Review your result', style: AppText.h2),
                          ),
                          Text(
                            '$completed/${_checked.length}',
                            style: AppText.h3.copyWith(color: AppColors.sky),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: _checked.isEmpty
                              ? 0
                              : completed / _checked.length,
                          minHeight: 6,
                          backgroundColor: AppColors.glassBorder,
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.sky),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var index = 0;
                          index < idea.checklist.length;
                          index++)
                        CheckboxListTile(
                          value: _checked[index],
                          onChanged: (value) => setState(
                            () => _checked[index] = value ?? false,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          title: Text(
                            idea.checklist[index],
                            style: AppText.body.copyWith(
                              color: _checked[index]
                                  ? AppColors.ink
                                  : AppColors.inkDim,
                            ),
                          ),
                          activeColor: AppColors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side:
                                const BorderSide(color: AppColors.glassBorder),
                          ),
                        ),
                      if (allComplete) ...[
                        const SizedBox(height: 8),
                        GlassCard(
                          selected: true,
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  color: AppColors.sky),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Your review checklist is complete. Compare your result with the brief and save your work.',
                                  style: AppText.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Checklist progress stays on this screen and is not recorded as course completion.',
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.h2),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 17, color: AppColors.sky),
                  const SizedBox(width: 9),
                  Expanded(child: Text(item, style: AppText.body)),
                ],
              ),
            ),
        ],
      );
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.blue.withValues(alpha: .2),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                '$number',
                style: AppText.caption.copyWith(color: AppColors.sky),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(text, style: AppText.body),
              ),
            ),
          ],
        ),
      );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Text(text, style: AppText.caption.copyWith(fontSize: 10)),
      );
}

class _RelatedIdeaTile extends StatelessWidget {
  const _RelatedIdeaTile({required this.idea, required this.onTap});
  final IdeaLabIdea idea;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 78,
                  child: IdeaLabArtwork(
                    idea: idea,
                    height: 58,
                    borderRadius: 9,
                    showLabel: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(idea.title, style: AppText.h3),
                      const SizedBox(height: 3),
                      Text(
                        idea.category,
                        style: AppText.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 15, color: AppColors.inkFaint),
              ],
            ),
          ),
        ),
      );
}
