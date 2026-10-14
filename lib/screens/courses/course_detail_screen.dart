import 'package:flutter/material.dart';

import '../../app/transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/course.dart';
import '../../services/challenge_repository.dart';
import '../../utils/formatters.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_button.dart';
import '../../widgets/course_image.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pressable.dart';
import '../../widgets/reveal.dart';
import 'challenge_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen(
      {super.key, required this.course, required this.heroTag});
  final Course course;
  final String heroTag;

  static void open(BuildContext context, Course course, String heroTag) {
    Navigator.of(context).push(AppRoutes.fadeScale(
        CourseDetailScreen(course: course, heroTag: heroTag)));
  }

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  String _levelId = 'basic';

  Plan get _plan =>
      widget.course.plans.firstWhere((p) => p.levelId == _levelId);

  void _buy() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text(
            'Login and secure payment will be enabled in the next build phase.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: AmbientBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 290 + top,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(tag: widget.heroTag, child: CourseImage(course: c)),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.navyDeep.fade(0.35),
                            AppColors.navyDeep.fade(0.0),
                            AppColors.navyDeep
                          ],
                          stops: const [0, 0.35, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: top + 10,
                      left: 16,
                      child: Pressable(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.navyDeep.fade(0.6),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: AppColors.glassBorderStrong),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              size: 20, color: AppColors.offWhite),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name.toUpperCase(),
                              style: AppText.mark(40, spacing: 2)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Chip(
                                  icon: Icons.schedule_rounded,
                                  text: c.durationLabel),
                              _Chip(
                                  icon: Icons.layers_outlined,
                                  text: '${c.plans.length} Levels'),
                              _Chip(
                                  icon: Icons.sell_outlined,
                                  text: 'From ${rupees(c.startingPrice)}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Reveal(
                      child: Text(c.description,
                          style: AppText.body.copyWith(fontSize: 15))),
                  const SizedBox(height: 22),
                  Reveal(
                    delay: const Duration(milliseconds: 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SKILLS YOU\u2019LL GAIN', style: AppText.label),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final s in c.skills) _SkillChip(s)],
                        ),
                        if (c.tools.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text('SOFTWARE / TOOLS', style: AppText.label),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final t in c.tools) _SkillChip(t)
                          ]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Reveal(
                    delay: const Duration(milliseconds: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WHAT YOU\u2019LL LEARN', style: AppText.label),
                        const SizedBox(height: 6),
                        Text('Course modules', style: AppText.h2),
                        const SizedBox(height: 14),
                        for (var i = 0; i < c.modules.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child:
                                _ModuleTile(index: i + 1, module: c.modules[i]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Reveal(
                      child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PRACTICE & PORTFOLIO', style: AppText.label),
                          const SizedBox(height: 6),
                          Text(
                              'Practice tasks, lesson challenges, and a portfolio brief are part of this learning path.',
                              style: AppText.body),
                          const SizedBox(height: 12),
                          AppButton(
                              label: 'Open Practice Lab',
                              icon: Icons.extension_outlined,
                              onTap: () => Navigator.of(context).push(
                                  AppRoutes.fadeScale(
                                      ChallengeScreen(course: c)))),
                          const SizedBox(height: 8),
                          Text(
                              '${ChallengeRepository.forCourse(c).length} interactive lesson challenges • Local demo progress',
                              style: AppText.caption),
                        ]),
                  )),
                  const SizedBox(height: 18),
                  Reveal(
                    delay: const Duration(milliseconds: 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PLANS', style: AppText.label),
                        const SizedBox(height: 6),
                        Text('Choose your level', style: AppText.h2),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            for (var i = 0; i < c.plans.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(
                                child: _LevelTab(
                                  plan: c.plans[i],
                                  selected: c.plans[i].levelId == _levelId,
                                  onTap: () => setState(
                                      () => _levelId = c.plans[i].levelId),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: KeyedSubtree(
                                key: ValueKey(_levelId),
                                child: _PlanDetails(plan: _plan)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.navy.fade(0.97),
          border: const Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_plan.shortLabel, style: AppText.caption),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(rupees(_plan.price),
                            key: ValueKey(_plan.price),
                            style:
                                AppText.h2.copyWith(color: AppColors.offWhite)),
                      ),
                    ],
                  ),
                ),
                AppButton(
                    label: 'Buy Now',
                    icon: Icons.lock_outline_rounded,
                    onTap: _buy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navyDeep.fade(0.65),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.sky),
          const SizedBox(width: 6),
          Text(text, style: AppText.caption.copyWith(color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(text,
          style:
              AppText.caption.copyWith(color: AppColors.ink, fontSize: 12.5)),
    );
  }
}

class _ModuleTile extends StatefulWidget {
  const _ModuleTile({required this.index, required this.module});
  final int index;
  final CourseModule module;

  @override
  State<_ModuleTile> createState() => _ModuleTileState();
}

class _ModuleTileState extends State<_ModuleTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.index.toString().padLeft(2, '0');
    return Pressable(
      scale: 0.99,
      onTap: () => setState(() => _open = !_open),
      child: GlassCard(
        selected: _open,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MODULE $n',
                          style: AppText.label.copyWith(fontSize: 10.5)),
                      const SizedBox(height: 2),
                      Text(widget.module.title,
                          style: AppText.h3.copyWith(fontSize: 15)),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.inkDim),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _open
                  ? SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _Bullets(widget.module.topics),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelTab extends StatelessWidget {
  const _LevelTab(
      {required this.plan, required this.selected, required this.onTap});
  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: GlassCard(
        selected: selected,
        strong: selected,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(plan.shortLabel,
                  style: AppText.caption.copyWith(
                      color: selected ? AppColors.offWhite : AppColors.inkDim,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(rupees(plan.price),
                  style: AppText.h3.copyWith(
                      fontSize: 15,
                      color: selected ? AppColors.sky : AppColors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanDetails extends StatelessWidget {
  const _PlanDetails({required this.plan});
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.label, style: AppText.h3),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 14, color: AppColors.sky),
                const SizedBox(width: 6),
                Text(plan.duration,
                    style: AppText.caption.copyWith(color: AppColors.ink)),
              ],
            ),
            const SizedBox(height: 16),
            Text('WHAT\u2019S INCLUDED',
                style: AppText.label.copyWith(fontSize: 10.5)),
            const SizedBox(height: 8),
            _Bullets(plan.features),
            const SizedBox(height: 16),
            Text('SUPPORT', style: AppText.label.copyWith(fontSize: 10.5)),
            const SizedBox(height: 8),
            _Bullets(plan.support),
          ],
        ),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items);
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child:
                      Icon(Icons.check_rounded, size: 15, color: AppColors.sky),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child:
                        Text(t, style: AppText.body.copyWith(fontSize: 13.5))),
              ],
            ),
          ),
      ],
    );
  }
}
