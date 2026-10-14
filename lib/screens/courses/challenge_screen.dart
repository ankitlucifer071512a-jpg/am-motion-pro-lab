import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/course.dart';
import '../../models/learning_challenge.dart';
import '../../services/challenge_repository.dart';
import '../../services/learning_progress_store.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/glass_card.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key, required this.course});
  final Course course;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  late final List<LearningChallenge> _challenges =
      ChallengeRepository.forCourse(widget.course);
  int _index = 0;
  int? _selected;
  bool _submitted = false;
  int _streak = 0;
  int _xp = 0;
  Set<String> _completed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = LearningProgressStore.instance;
    final values = await Future.wait([store.xp, store.completed]);
    if (mounted)
      setState(() {
        _xp = values[0] as int;
        _completed = values[1] as Set<String>;
      });
  }

  LearningChallenge get _challenge => _challenges[_index];

  Future<void> _answer() async {
    if (_selected == null || _submitted) return;
    final correct = _selected == _challenge.answerIndex;
    setState(() {
      _submitted = true;
      _streak = correct ? _streak + 1 : 0;
    });
    if (correct) {
      await LearningProgressStore.instance.completeChallenge(_challenge.id);
      await _load();
    }
  }

  void _next() {
    setState(() {
      _index = (_index + 1) % _challenges.length;
      _selected = null;
      _submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_challenges.isEmpty)
      return const Scaffold(
          body: Center(child: Text('No challenges available yet.')));
    final done = _completed.contains(_challenge.id);
    final correct = _selected == _challenge.answerIndex;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.course.name} • Practice lab')),
      body: AmbientBackground(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Row(children: [
            Expanded(
                child: Text('CHALLENGE ${_index + 1} / ${_challenges.length}',
                    style: AppText.label)),
            Text('$_xp XP', style: AppText.h3.copyWith(color: AppColors.sky))
          ]),
          const SizedBox(height: 10),
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                  value: (_index + (done ? 1 : 0)) / _challenges.length,
                  minHeight: 6,
                  backgroundColor: AppColors.glassBorder,
                  valueColor: const AlwaysStoppedAnimation(AppColors.sky))),
          const SizedBox(height: 20),
          Text(_challenge.title, style: AppText.h1),
          const SizedBox(height: 14),
          GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Icon(Icons.image_outlined,
                    size: 46, color: AppColors.sky),
                const SizedBox(height: 10),
                Text(_challenge.visualLabel, style: AppText.caption),
                const SizedBox(height: 12),
                Text(_challenge.prompt,
                    style: AppText.h3, textAlign: TextAlign.center),
              ])),
          const SizedBox(height: 16),
          for (var i = 0; i < _challenge.options.length; i++)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap:
                      _submitted ? null : () => setState(() => _selected = i),
                  borderRadius: BorderRadius.circular(14),
                  child: GlassCard(
                      selected: _selected == i,
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Icon(
                            _submitted && i == _challenge.answerIndex
                                ? Icons.check_circle
                                : _selected == i
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                            color: _submitted && i == _challenge.answerIndex
                                ? Colors.greenAccent
                                : AppColors.sky),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(_challenge.options[i],
                                style: AppText.body)),
                      ])),
                )),
          if (_submitted) ...[
            GlassCard(
                selected: true,
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          correct
                              ? (done
                                  ? 'Already completed'
                                  : 'Correct • +25 XP')
                              : 'Not quite',
                          style: AppText.h3.copyWith(
                              color: correct
                                  ? Colors.greenAccent
                                  : AppColors.sky)),
                      const SizedBox(height: 6),
                      Text(_challenge.explanation, style: AppText.body),
                      const SizedBox(height: 6),
                      Text('Current streak: $_streak', style: AppText.caption),
                    ])),
            const SizedBox(height: 14),
            if (correct)
              FilledButton(
                  onPressed: _next,
                  child: Text(_index == _challenges.length - 1
                      ? 'Review practice lab'
                      : 'Next challenge'))
            else
              TextButton(
                  onPressed: () => setState(() {
                        _selected = null;
                        _submitted = false;
                      }),
                  child: const Text('Retry')),
          ] else ...[
            const SizedBox(height: 8),
            FilledButton(
                onPressed: _selected == null ? null : _answer,
                child: const Text('Check answer')),
          ],
          const SizedBox(height: 10),
          Text('Challenge completion and XP are saved locally on this device.',
              style: AppText.caption, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
