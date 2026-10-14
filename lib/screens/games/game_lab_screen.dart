import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/course_repository.dart';
import '../../services/learning_progress_store.dart';
import '../../widgets/glass_card.dart';
import '../courses/challenge_screen.dart';
import 'learning_community_screen.dart';
import 'creative_verse_arena_screen.dart';
import 'creative_project_workspace_screen.dart';
import 'neon_rush_screen.dart';
import 'studio_coach_screen.dart';
import 'three_d_studio_screen.dart';
import 'client_work_lab_screen.dart';

class _PracticeActivity {
  const _PracticeActivity(
      {required this.title,
      required this.course,
      required this.question,
      required this.options,
      required this.answer,
      required this.why,
      required this.accent,
      this.example});
  final String title, course, question, why;
  final List<String> options;
  final int answer;
  final Color accent;
  final String? example;
}

const _activities = <_PracticeActivity>[
  _PracticeActivity(
      title: 'Pick the palette',
      course: 'Graphic design',
      question: 'Choose colors for a calm organic skincare brand.',
      options: [
        'Sage green + warm cream',
        'Neon red + electric blue',
        'Black + bright yellow'
      ],
      answer: 0,
      why: 'Soft greens and warm neutrals communicate a natural, calm mood.',
      accent: Color(0xFF8FB89A)),
  _PracticeActivity(
      title: 'Make the headline readable',
      course: 'Typography',
      question: 'Which treatment works best for a clear poster headline?',
      options: [
        'Bold white text on a dark navy panel',
        'Thin grey type on a busy photo',
        'Three decorative fonts at equal size'
      ],
      answer: 0,
      why:
          'Strong contrast and a clear type hierarchy help people read the key message.',
      accent: Color(0xFF8CB8FF),
      example: 'DESIGN\nFESTIVAL'),
  _PracticeActivity(
      title: 'Balance the layout',
      course: 'Graphic design',
      question: 'Where should the main headline go in this composition?',
      options: [
        'Near the focal point with generous margins',
        'Over the busiest image detail',
        'Touching the canvas edges'
      ],
      answer: 0,
      why:
          'Spacing around a focal headline makes the composition easier to scan.',
      accent: Color(0xFFB89CFF)),
  _PracticeActivity(
      title: 'Order the poses',
      course: '2D animation',
      question: 'Which sequence makes a jump read clearly?',
      options: [
        'Anticipation → take-off → air → landing',
        'Landing → air → anticipation → take-off',
        'Air → landing → take-off → anticipation'
      ],
      answer: 0,
      why: 'Preparation, action, and recovery make movement feel intentional.',
      accent: Color(0xFFFFC36E)),
  _PracticeActivity(
      title: 'Light the 3D subject',
      course: '3D animation',
      question: 'Choose a setup that gives a portrait depth.',
      options: [
        'Key light + soft fill + rim separation',
        'Flat light from every direction',
        'Only a bright light behind the camera'
      ],
      answer: 0,
      why:
          'Key, fill, and rim lighting define shape and help separate the subject.',
      accent: Color(0xFF7CC7D7)),
  _PracticeActivity(
      title: 'Choose the motion curve',
      course: 'Motion graphics',
      question: 'How should a title settle into its final position?',
      options: [
        'Ease out as it arrives',
        'Stop at full speed with no easing',
        'Reverse direction at the final frame'
      ],
      answer: 0,
      why:
          'Easing out reduces speed near the destination and feels more natural.',
      accent: Color(0xFFFF8DA6)),
];

class GameLabScreen extends StatelessWidget {
  const GameLabScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 32), children: [
        Text('CREATE • PRACTICE • IMPROVE', style: AppText.label),
        const SizedBox(height: 7),
        Text('Game Lab', style: AppText.h1),
        const SizedBox(height: 6),
        Text(
            'Quick creative challenges with instant feedback. Pick an activity and try a new idea.',
            style: AppText.body),
        const SizedBox(height: 18),
        _ActionCard(
            icon: Icons.bolt_rounded,
            title: 'AM Arcade · Neon Rush',
            subtitle:
                'Swipe, jump, slide and collect energy in three neon worlds',
            onTap: () => Navigator.push(
                context, AppRoutes.fadeScale(const NeonRushScreen()))),
        const SizedBox(height: 10),
        _ActionCard(
            icon: Icons.workspaces_outline,
            title: 'Client Work Lab',
            subtitle:
                'Four fictional client briefs, practical missions and review cycles',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const ClientWorkLabScreen()))),
        const SizedBox(height: 10),
        _ActionCard(
            icon: Icons.auto_awesome,
            title: 'CreativeVerse AI Arena',
            subtitle: 'One connected arena for creative skill missions',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const CreativeVerseArenaScreen()))),
        const SizedBox(height: 10),
        _ActionCard(
            icon: Icons.folder_copy_outlined,
            title: 'Creative Project Workspace',
            subtitle:
                'Create projects, manage tasks and keep notes on this device',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const CreativeProjectWorkspaceScreen()))),
        const SizedBox(height: 10),
        _ActionCard(
            icon: Icons.palette_outlined,
            title: 'Color & design games',
            subtitle: 'Palettes, typography, layout, 2D, 3D and motion',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const _ActivityListScreen()))),
        const SizedBox(height: 10),
        _ActionCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Upload & get a rating',
            subtitle: 'Review a design or creative practice image',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const PortfolioReviewScreen()))),
        const SizedBox(height: 10),
        _ActionCard(
            icon: Icons.view_in_ar_outlined,
            title: '3D Model Studio',
            subtitle: 'Import and inspect a GLB model in 3D',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const ThreeDStudioScreen()))),
        const SizedBox(height: 10),
        _ActionCard(
            icon: Icons.groups_2_outlined,
            title: 'Student group room',
            subtitle: 'Share image references and chat • local preview',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const LearningCommunityScreen()))),
        const SizedBox(height: 10),
        _ActionCard(
            icon: Icons.smart_toy_outlined,
            title: 'AM Creative AI',
            subtitle:
                'Creative tutor interface • secure AI service not connected',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const StudioCoachScreen()))),
        const SizedBox(height: 22),
        Text('Pick up a course challenge', style: AppText.h2),
        const SizedBox(height: 10),
        for (final course in CourseRepository.courses)
          Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _ActionCard(
                  icon: course.icon,
                  title: course.name,
                  subtitle: 'Lesson challenges • practice and earn XP',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => ChallengeScreen(course: course))))),
        const SizedBox(height: 6),
        Text(
            'XP and challenge completion save on this device. Upload ratings are practice feedback, not a professional or AI assessment.',
            style: AppText.caption),
      ]);
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: AppColors.blue.fade(.16),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.sky)),
            const SizedBox(width: 13),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: AppText.h3.copyWith(fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppText.caption)
                ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint)
          ])));
}

class _ActivityListScreen extends StatelessWidget {
  const _ActivityListScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Creative challenges')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        for (final a in _activities)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ActivityCard(activity: a))
      ]));
}

class _ActivityCard extends StatefulWidget {
  const _ActivityCard({required this.activity});
  final _PracticeActivity activity;
  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  int? _picked;
  bool _saved = false;
  Future<void> _choose(int index) async {
    if (_picked != null) return;
    setState(() => _picked = index);
    if (index == widget.activity.answer) {
      await LearningProgressStore.instance.completeChallenge(
          'gamelab-${widget.activity.title.toLowerCase().replaceAll(' ', '-')}');
      if (mounted) setState(() => _saved = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final correct = _picked == a.answer;
    return GlassCard(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.course.toUpperCase(),
              style: AppText.label.copyWith(color: a.accent)),
          const SizedBox(height: 5),
          Text(a.title, style: AppText.h3),
          const SizedBox(height: 10),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    a.accent.withValues(alpha: .2),
                    AppColors.glassFill
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: a.accent.withValues(alpha: .45))),
              child: a.example == null
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (final c in [
                        a.accent,
                        const Color(0xFFFAEBD7),
                        const Color(0xFF35475D)
                      ])
                        Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 35,
                            height: 35,
                            decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24)))
                    ])
                  : Text(a.example!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: a.accent,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.05))),
          const SizedBox(height: 12),
          Text(a.question, style: AppText.body.copyWith(color: AppColors.ink)),
          const SizedBox(height: 8),
          for (var i = 0; i < a.options.length; i++)
            Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: InkWell(
                    onTap: _picked == null ? () => _choose(i) : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: _picked == i
                                ? (correct
                                    ? const Color(0xFF174A3A)
                                    : const Color(0xFF522D39))
                                : AppColors.glassFill,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _picked == i
                                    ? (correct
                                        ? Colors.greenAccent
                                        : Colors.redAccent)
                                    : AppColors.glassBorder)),
                        child: Row(children: [
                          if (_picked != null && i == a.answer)
                            const Icon(Icons.check_circle,
                                size: 18, color: Colors.greenAccent)
                          else if (_picked == i)
                            const Icon(Icons.cancel,
                                size: 18, color: Colors.redAccent)
                          else
                            const Icon(Icons.circle_outlined,
                                size: 18, color: AppColors.inkDim),
                          const SizedBox(width: 9),
                          Expanded(
                              child: Text(a.options[i],
                                  style: AppText.body.copyWith(fontSize: 13)))
                        ])))),
          if (_picked != null)
            Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                    correct
                        ? 'Correct${_saved ? ' • +25 XP' : ''}  ${a.why}'
                        : 'Not quite. ${a.why}',
                    style: AppText.body.copyWith(
                        color: correct ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 13))),
          if (_picked != null && !correct)
            Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () => setState(() => _picked = null),
                    child: const Text('Try again'))),
        ]));
  }
}

class PortfolioReviewScreen extends StatefulWidget {
  const PortfolioReviewScreen({super.key});
  @override
  State<PortfolioReviewScreen> createState() => _PortfolioReviewScreenState();
}

class _PortfolioReviewScreenState extends State<PortfolioReviewScreen> {
  final _picker = ImagePicker();
  Uint8List? _bytes;
  String? _fileName;
  final List<double> _ratings = [3, 3, 3];
  bool _rated = false;
  Future<void> _pick() async {
    final file = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1800, imageQuality: 88);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() {
        _bytes = bytes;
        _fileName = file.name;
        _rated = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Portfolio practice review')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Upload a design', style: AppText.h1),
          const SizedBox(height: 6),
          Text('Choose a graphic, 2D frame, 3D render or motion-design still.',
              style: AppText.body),
          const SizedBox(height: 15),
          InkWell(
            onTap: _pick,
            borderRadius: BorderRadius.circular(16),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: _bytes == null
                  ? const SizedBox(
                      height: 200,
                      child: Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: AppColors.sky, size: 44),
                          SizedBox(height: 9),
                          Text('Choose an image from your device'),
                        ]),
                      ),
                    )
                  : Column(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_bytes!,
                            fit: BoxFit.contain, height: 260),
                      ),
                      const SizedBox(height: 8),
                      Text(_fileName ?? 'Selected image',
                          style: AppText.caption),
                    ]),
            ),
          ),
          const SizedBox(height: 18),
          Text('Rate your work', style: AppText.h2),
          const SizedBox(height: 4),
          Text(
              'Use this quick self-review rubric. It does not send the image or use AI.',
              style: AppText.caption),
          for (var i = 0; i < 3; i++) _ratingSlider(i),
          FilledButton.icon(
            onPressed:
                _bytes == null ? null : () => setState(() => _rated = true),
            icon: const Icon(Icons.star_outline_rounded),
            label: const Text('Show practice rating'),
          ),
          if (_rated) ...[
            const SizedBox(height: 14),
            GlassCard(
              selected: true,
              padding: const EdgeInsets.all(18),
              child: Center(
                child: Column(children: [
                  Text(
                      '${(_ratings.reduce((a, b) => a + b) / _ratings.length).toStringAsFixed(1)} / 5',
                      style: AppText.h1.copyWith(color: AppColors.sky)),
                  Text('Practice rubric score', style: AppText.h3),
                  const SizedBox(height: 6),
                  const Text(
                      'Consider hierarchy, readability and craft before sharing your next draft.',
                      textAlign: TextAlign.center),
                ]),
              ),
            ),
          ],
        ]),
      );
  Widget _ratingSlider(int index) {
    const labels = [
      'Composition balance',
      'Readability / clarity',
      'Craft and polish'
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Text(labels[index], style: AppText.body)),
        Text('${_ratings[index].round()}/5', style: AppText.caption)
      ]),
      Slider(
          value: _ratings[index],
          min: 1,
          max: 5,
          divisions: 4,
          onChanged: (v) => setState(() {
                _ratings[index] = v;
                _rated = false;
              }))
    ]);
  }
}
