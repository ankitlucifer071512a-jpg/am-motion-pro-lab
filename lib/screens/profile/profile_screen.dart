import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/challenge_repository.dart';
import '../../services/course_repository.dart';
import '../../services/learning_progress_store.dart';
import '../../widgets/glass_card.dart';
import 'support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _xp = 0;
  Set<String> _done = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = LearningProgressStore.instance;
    final data = await Future.wait([s.xp, s.completed]);
    if (mounted)
      setState(() {
        _xp = data[0] as int;
        _done = data[1] as Set<String>;
      });
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 30), children: [
        Text('STUDENT DASHBOARD', style: AppText.label),
        const SizedBox(height: 6),
        Text('Profile & progress', style: AppText.h1),
        const SizedBox(height: 16),
        GlassCard(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.glassFillStrong,
                  child: Icon(Icons.person_outline,
                      color: AppColors.sky, size: 30)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Guest learner', style: AppText.h3),
                    Text('Demo mode • Sign-in is not configured',
                        style: AppText.caption)
                  ]))
            ])),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _stat('$_xp', 'Game XP', Icons.bolt_outlined)),
          const SizedBox(width: 10),
          Expanded(
              child: _stat('${_done.length}', 'Challenges done',
                  Icons.check_circle_outline))
        ]),
        const SizedBox(height: 20),
        Text('Purchased courses', style: AppText.h2),
        const SizedBox(height: 8),
        GlassCard(
            padding: const EdgeInsets.all(16),
            child: Text(
                'No enrollment data is connected. Purchased courses will appear here after account and backend integration.',
                style: AppText.body)),
        const SizedBox(height: 20),
        Text('Learning progress • Local prototype', style: AppText.h2),
        const SizedBox(height: 8),
        for (final course in CourseRepository.courses) ...[
          Builder(builder: (context) {
            final challenges = ChallengeRepository.forCourse(course);
            final complete =
                challenges.where((c) => _done.contains(c.id)).length;
            return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(course.name, style: AppText.body)),
                            Text('$complete/${challenges.length}',
                                style: AppText.caption)
                          ]),
                          const SizedBox(height: 8),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                  value: challenges.isEmpty
                                      ? 0
                                      : complete / challenges.length,
                                  minHeight: 5,
                                  backgroundColor: AppColors.glassBorder,
                                  valueColor: const AlwaysStoppedAnimation(
                                      AppColors.sky)))
                        ])));
          }),
        ],
        const SizedBox(height: 12),
        Text('Achievements & certificates', style: AppText.h2),
        const SizedBox(height: 8),
        GlassCard(
            padding: const EdgeInsets.all(16),
            child: Text(
                _done.isEmpty
                    ? 'Complete practice challenges to earn local XP and achievements.'
                    : 'Practice streak • ${_done.length} challenge${_done.length == 1 ? '' : 's'} completed. Certificates are a placeholder until course completion is verified.',
                style: AppText.body)),
        const SizedBox(height: 20),
        Text('Account', style: AppText.h2),
        const SizedBox(height: 8),
        GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                  leading: const Icon(Icons.support_agent_outlined,
                      color: AppColors.sky),
                  title: Text('Support', style: AppText.body),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const SupportScreen()))),
              const Divider(height: 1, color: AppColors.glassBorder),
              ListTile(
                  leading:
                      const Icon(Icons.settings_outlined, color: AppColors.sky),
                  title: Text('Settings', style: AppText.body),
                  subtitle: Text('Profile and preferences are demo-only',
                      style: AppText.caption),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Settings will be available after account setup')))),
              const Divider(height: 1, color: AppColors.glassBorder),
              ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.inkDim),
                  title: Text('Logout', style: AppText.body),
                  subtitle:
                      Text('No account is signed in', style: AppText.caption),
                  onTap: () {})
            ])),
      ]);

  Widget _stat(String value, String label, IconData icon) => GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Icon(icon, color: AppColors.sky),
        const SizedBox(height: 6),
        Text(value, style: AppText.h2),
        Text(label, style: AppText.caption)
      ]));
}
