import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/creative_challenge.dart';
import '../../services/learning_progress_store.dart';
import '../../services/creative_challenge_repository.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/premium_lighting.dart';

final _rescueChallenge = CreativeChallengeRepository.daily;

class CreativeVerseArenaScreen extends StatelessWidget {
  const CreativeVerseArenaScreen({super.key});

  static const _modes = [
    ('EditRush', 'Editing rhythm, cuts and transitions', Icons.movie_outlined),
    (
      'Motion Master',
      'Timing, easing and keyframe choices',
      Icons.motion_photos_auto_outlined
    ),
    (
      'ColorCraft',
      'Palette, type and visual hierarchy',
      Icons.palette_outlined
    ),
    (
      'FrameForge',
      'Story beats, poses and animation timing',
      Icons.auto_awesome_motion_outlined
    ),
    (
      'ModelVerse',
      'Materials, lighting and camera choices',
      Icons.view_in_ar_outlined
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('CreativeVerse AI Arena')),
        body: LivingLightField(
          grid: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            children: [
              _hero(),
              const SizedBox(height: 18),
              Text('YOUR SKILL MAP', style: AppText.label),
              const SizedBox(height: 8),
              const _SkillMap(),
              const SizedBox(height: 10),
              _ModeCard(
                title: 'Challenge Generator',
                subtitle: 'Choose from curated practice missions',
                icon: Icons.shuffle_rounded,
                available: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const CreativeChallengeLibraryScreen(),
                )),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: Text('Arena modes', style: AppText.h2)),
                Text('1 playable mission', style: AppText.caption),
              ]),
              const SizedBox(height: 9),
              for (final mode in _modes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _ModeCard(
                    title: mode.$1,
                    subtitle: mode.$2,
                    icon: mode.$3,
                    available: mode.$1 == 'ColorCraft',
                    onTap: mode.$1 == 'ColorCraft'
                        ? () =>
                            Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => const CreativeRescueScreen(),
                            ))
                        : null,
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                'Other modes are planned for later stages. Your practice progress is stored on this device.',
                style: AppText.caption,
              ),
            ],
          ),
        ),
      );

  Widget _hero() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.blue.fade(.3),
              AppColors.violet.fade(.22),
              AppColors.navy
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.glassBorderStrong),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.auto_awesome, color: AppColors.sky, size: 26),
          const SizedBox(height: 12),
          Text('Make better creative decisions.', style: AppText.h1),
          const SizedBox(height: 7),
          Text(
            'Short hands-on missions teach the reason behind each edit, design and animation choice.',
            style: AppText.body,
          ),
          const SizedBox(height: 14),
          const _DailyMission(),
        ]),
      );
}

class _DailyMission extends StatelessWidget {
  const _DailyMission();
  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(13),
        child: Row(children: [
          const Icon(Icons.today_outlined, color: AppColors.sky),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TODAY’S CREATIVE MISSION', style: AppText.label),
              const SizedBox(height: 3),
              Text('Rescue a crowded event poster', style: AppText.body),
            ]),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const CreativeRescueScreen(),
            )),
            child: const Text('Play'),
          ),
        ]),
      );
}

class _SkillMap extends StatelessWidget {
  const _SkillMap();
  static const _skills = <(String, List<String>, int)>[
    ('Video Editing', ['video-', 'creativeverse-edit-sequence-'], 5),
    (
      'Graphic Design',
      [
        'design-',
        'creativeverse-rescue',
        'gamelab-pick-the-palette',
        'gamelab-make-the-headline-readable',
        'gamelab-balance-the-layout',
      ],
      8,
    ),
    (
      'Motion Graphics',
      ['motion-', 'gamelab-choose-the-motion-curve'],
      5,
    ),
    ('2D Animation', ['animation2d-', 'gamelab-order-the-poses'], 5),
    (
      '3D Animation',
      [
        'animation3d-',
        'creativeverse-model-light-',
        'gamelab-light-the-3d-subject',
      ],
      6,
    ),
  ];
  @override
  Widget build(BuildContext context) => FutureBuilder<Set<String>>(
        future: LearningProgressStore.instance.completed,
        builder: (context, snapshot) {
          final completed = snapshot.data ?? const <String>{};
          return GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              for (final skill in _skills)
                Builder(builder: (context) {
                  final count = completed
                      .where((id) => skill.$2.any(id.startsWith))
                      .length;
                  final progress = (count / skill.$3).clamp(0.0, 1.0);
                  return InkWell(
                    onTap: () => _showSkillDetails(context, skill, count),
                    borderRadius: BorderRadius.circular(9),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        SizedBox(
                            width: 112,
                            child: Text(skill.$1, style: AppText.caption)),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: AppColors.glassBorder,
                              color: AppColors.sky,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$count/${skill.$3}', style: AppText.caption),
                        const Icon(Icons.chevron_right,
                            size: 17, color: AppColors.inkFaint),
                      ]),
                    ),
                  );
                }),
            ]),
          );
        },
      );

  void _showSkillDetails(
    BuildContext context,
    (String, List<String>, int) skill,
    int count,
  ) {
    final pageContext = context;
    final level = count == 0
        ? 'New'
        : count < 3
            ? 'Practicing'
            : 'Building confidence';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => FutureBuilder<Set<String>>(
        future: LearningProgressStore.instance.completed,
        builder: (context, snapshot) {
          final done = snapshot.data ?? const <String>{};
          final suggested = CreativeChallengeRepository.missions.where(
              (challenge) =>
                  skill.$2.any(challenge.id.startsWith) &&
                  !done.contains(challenge.id));
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(skill.$1, style: AppText.h2),
                  const SizedBox(height: 6),
                  Text('Local practice level: $level', style: AppText.body),
                  Text(
                      'Completed ${count.clamp(0, skill.$3)} of ${skill.$3} available challenges.',
                      style: AppText.caption),
                  const SizedBox(height: 12),
                  Text('Suggested next step', style: AppText.h3),
                  Text(
                      suggested.isEmpty
                          ? 'Try a course practice challenge in this skill.'
                          : suggested.first.title,
                      style: AppText.body),
                  const SizedBox(height: 5),
                  Text(
                      '${(skill.$3 - count).clamp(0, skill.$3)} challenges still to practice',
                      style: AppText.caption),
                  if (suggested.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          final challenge = suggested.first;
                          Navigator.of(context).pop();
                          Navigator.of(pageContext)
                              .push(MaterialPageRoute<void>(
                            builder: (_) => CreativeMissionDetailScreen(
                                challenge: challenge),
                          ));
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start suggested challenge'),
                      ),
                    ),
                ]),
          );
        },
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.available,
      this.onTap});
  final String title, subtitle;
  final IconData icon;
  final bool available;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: GlassCard(
          padding: const EdgeInsets.all(13),
          child: Row(children: [
            Icon(icon, color: available ? AppColors.sky : AppColors.inkFaint),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: AppText.h3.copyWith(fontSize: 15)),
                  Text(subtitle, style: AppText.caption),
                ])),
            Text(available ? 'PLAY' : 'SOON',
                style: AppText.label.copyWith(fontSize: 9)),
          ]),
        ),
      );
}

class CreativeRescueScreen extends StatefulWidget {
  const CreativeRescueScreen({super.key});
  @override
  State<CreativeRescueScreen> createState() => _CreativeRescueScreenState();
}

class _CreativeRescueScreenState extends State<CreativeRescueScreen> {
  final _engine = const CreativeChallengeEngine();
  int? _selected;
  bool _showHint = false;
  bool _saved = false;
  bool get _isCorrect => _selected == _rescueChallenge.answerIndex;

  Future<void> _answer(int index) async {
    if (_selected != null) return;
    final result = _engine.evaluate(_rescueChallenge, index);
    setState(() => _selected = index);
    if (result.correct) {
      await LearningProgressStore.instance.completeChallenge(
        _rescueChallenge.id,
        xpAward: result.xpEarned,
      );
      if (mounted) setState(() => _saved = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Creative Rescue')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Row(children: [
            Expanded(
                child: Text('COLORCRAFT · MISSION 01', style: AppText.label)),
            const Icon(Icons.bolt, color: AppColors.sky, size: 18),
            Text(' +30 XP', style: AppText.caption),
          ]),
          const SizedBox(height: 9),
          Text(_rescueChallenge.title, style: AppText.h1),
          const SizedBox(height: 5),
          Text(_rescueChallenge.brief, style: AppText.body),
          const SizedBox(height: 15),
          _PosterPreview(isFixed: _selected != null && _isCorrect),
          const SizedBox(height: 17),
          Text(_rescueChallenge.prompt, style: AppText.h2),
          const SizedBox(height: 10),
          for (var i = 0; i < _rescueChallenge.options.length; i++)
            _OptionTile(
              label: _rescueChallenge.options[i],
              index: i,
              selected: _selected == i,
              correct: i == _rescueChallenge.answerIndex,
              answered: _selected != null,
              onTap: () => _answer(i),
            ),
          if (_selected == null)
            TextButton.icon(
              onPressed: () => setState(() => _showHint = !_showHint),
              icon: const Icon(Icons.lightbulb_outline),
              label: Text(_showHint
                  ? 'Hide hint'
                  : 'Ask the Creative Director for a hint'),
            ),
          if (_showHint && _selected == null)
            GlassCard(
                padding: const EdgeInsets.all(12),
                child: Text(_rescueChallenge.hint, style: AppText.body)),
          if (_selected != null) ...[
            const SizedBox(height: 7),
            GlassCard(
              selected: _isCorrect,
              padding: const EdgeInsets.all(15),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _isCorrect
                            ? 'Nice creative call${_saved ? ' · +30 XP saved' : ''}'
                            : 'Try another direction',
                        style: AppText.h3.copyWith(
                            color: _isCorrect
                                ? Colors.greenAccent
                                : Colors.orangeAccent)),
                    const SizedBox(height: 5),
                    Text(_rescueChallenge.explanation, style: AppText.body),
                    if (!_isCorrect)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: () => setState(() => _selected = null),
                            child: const Text('Try again')),
                      ),
                  ]),
            ),
          ],
          const SizedBox(height: 14),
          Text(
              'Scoring rewards a correct decision and its learning value, not speed.',
              style: AppText.caption),
        ]),
      );
}

class _PosterPreview extends StatelessWidget {
  const _PosterPreview({required this.isFixed});
  final bool isFixed;
  @override
  Widget build(BuildContext context) => Container(
        height: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF253A62),
                Color(0xFF11182A),
                Color(0xFF572C58)
              ]),
          border: Border.all(color: AppColors.glassBorderStrong),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 350),
          alignment: isFixed ? Alignment.center : Alignment.topLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: isFixed ? 210 : 175,
            padding: EdgeInsets.all(isFixed ? 15 : 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .48),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: .18)),
            ),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isFixed
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(isFixed ? 'WEEKEND' : 'WEEKEND  ·  NEW  ·  FREE',
                      style: AppText.label.copyWith(
                          fontSize: isFixed ? 10 : 8,
                          color: const Color(0xFFFFD57A))),
                  const SizedBox(height: 6),
                  Text('DESIGN\nWORKSHOP',
                      textAlign: isFixed ? TextAlign.center : TextAlign.left,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: isFixed ? 25 : 16,
                          fontWeight: FontWeight.w800,
                          height: 1.05)),
                  if (isFixed) ...[
                    const SizedBox(height: 6),
                    Text('Make something memorable',
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(color: Colors.white70)),
                  ],
                ]),
          ),
        ),
      );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile(
      {required this.label,
      required this.index,
      required this.selected,
      required this.correct,
      required this.answered,
      required this.onTap});
  final String label;
  final int index;
  final bool selected, correct, answered;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final showRight = answered && correct;
    final showWrong = selected && answered && !correct;
    final color = showRight
        ? Colors.greenAccent
        : showWrong
            ? Colors.redAccent
            : AppColors.glassBorder;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: answered ? null : onTap,
        borderRadius: BorderRadius.circular(13),
        child: GlassCard(
          padding: const EdgeInsets.all(13),
          child: Row(children: [
            Icon(
                showRight
                    ? Icons.check_circle
                    : showWrong
                        ? Icons.cancel
                        : Icons.circle_outlined,
                color: color,
                size: 19),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: AppText.body.copyWith(color: AppColors.ink))),
          ]),
        ),
      ),
    );
  }
}

class CreativeChallengeLibraryScreen extends StatelessWidget {
  const CreativeChallengeLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Creative Challenge Generator')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text('Choose your next practice', style: AppText.h1),
            const SizedBox(height: 6),
            Text(
              'Curated sample missions for now. These are not generated by AI.',
              style: AppText.body,
            ),
            const SizedBox(height: 15),
            for (final challenge in CreativeChallengeRepository.missions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) =>
                        CreativeMissionDetailScreen(challenge: challenge),
                  )),
                  child: GlassCard(
                    padding: const EdgeInsets.all(15),
                    child: Row(children: [
                      const Icon(Icons.auto_awesome, color: AppColors.sky),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(challenge.mode.toUpperCase(),
                                style: AppText.label),
                            const SizedBox(height: 3),
                            Text(challenge.title, style: AppText.h3),
                            Text(
                                '${challenge.difficulty} · ${challenge.skill} · ${challenge.xp} XP',
                                style: AppText.caption),
                          ])),
                      const Icon(Icons.chevron_right,
                          color: AppColors.inkFaint),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      );
}

class CreativeMissionDetailScreen extends StatefulWidget {
  const CreativeMissionDetailScreen({super.key, required this.challenge});
  final CreativeChallenge challenge;

  @override
  State<CreativeMissionDetailScreen> createState() =>
      _CreativeMissionDetailScreenState();
}

class _CreativeMissionDetailScreenState
    extends State<CreativeMissionDetailScreen> {
  final _engine = const CreativeChallengeEngine();
  int? _answer;
  bool _showHint = false;
  bool _saved = false;

  Future<void> _submit(int index) async {
    if (_answer != null) return;
    final result = _engine.evaluate(widget.challenge, index);
    setState(() => _answer = index);
    if (result.correct) {
      await LearningProgressStore.instance.completeChallenge(
        widget.challenge.id,
        xpAward: result.xpEarned,
      );
      if (mounted) setState(() => _saved = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final correct = _answer == challenge.answerIndex;
    return Scaffold(
      appBar: AppBar(title: Text(challenge.mode)),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Text(challenge.title, style: AppText.h1),
        const SizedBox(height: 7),
        Text(challenge.brief, style: AppText.body),
        const SizedBox(height: 12),
        GlassCard(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${challenge.difficulty} · ${challenge.xp} XP',
                  style: AppText.label),
              const SizedBox(height: 7),
              Text('Focus skill: ${challenge.skill}', style: AppText.h3),
              if (challenge.requiredSkills.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text('Required skills: ${challenge.requiredSkills.join(' · ')}',
                    style: AppText.caption),
              ],
              const SizedBox(height: 10),
              Text('Instructions', style: AppText.h3),
              for (var i = 0; i < challenge.instructions.length; i++)
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${i + 1}. ${challenge.instructions[i]}',
                        style: AppText.body)),
              if (challenge.referenceAssets.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Reference material', style: AppText.h3),
                for (final asset in challenge.referenceAssets)
                  Text('• $asset', style: AppText.body),
              ],
            ])),
        const SizedBox(height: 12),
        Text(challenge.prompt, style: AppText.h2),
        const SizedBox(height: 8),
        for (var i = 0; i < challenge.options.length; i++)
          _OptionTile(
            label: challenge.options[i],
            index: i,
            selected: _answer == i,
            correct: i == challenge.answerIndex,
            answered: _answer != null,
            onTap: () => _submit(i),
          ),
        if (_answer == null)
          TextButton.icon(
            onPressed: () => setState(() => _showHint = !_showHint),
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(_showHint ? 'Hide hint' : 'Show a hint'),
          ),
        if (_showHint && _answer == null)
          GlassCard(
              padding: const EdgeInsets.all(12),
              child: Text(challenge.hint, style: AppText.body)),
        if (_answer != null) ...[
          GlassCard(
            selected: correct,
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  correct
                      ? 'Good decision${_saved ? ' · progress saved' : ''}'
                      : 'Review this choice',
                  style: AppText.h3),
              const SizedBox(height: 5),
              Text(challenge.explanation, style: AppText.body),
              const SizedBox(height: 8),
              Text(
                  correct
                      ? challenge.completionSummary
                      : 'Practical next step: compare your choice with the evaluation criteria below, then try again.',
                  style: AppText.body),
              if (!correct)
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () => setState(() => _answer = null),
                        child: const Text('Try again'))),
            ]),
          ),
          const SizedBox(height: 12),
          Text('Evaluation criteria', style: AppText.h3),
          for (final criterion in challenge.evaluationCriteria)
            Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                          correct
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          color:
                              correct ? Colors.greenAccent : AppColors.inkFaint,
                          size: 17),
                      const SizedBox(width: 7),
                      Expanded(child: Text(criterion, style: AppText.body)),
                    ])),
          const SizedBox(height: 7),
          Text(
              'Feedback is based on your selected answer and the curated rubric. It is not an AI review of a submitted file.',
              style: AppText.caption),
        ],
      ]),
    );
  }
}
