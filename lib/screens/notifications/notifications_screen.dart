import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/learning_progress_store.dart';
import '../../widgets/glass_card.dart';

class _Notice {
  const _Notice(this.id, this.icon, this.title, this.body, this.when,
      {this.hasCourseLink = false});
  final String id;
  final IconData icon;
  final String title;
  final String body;
  final String when;
  final bool hasCourseLink;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen(
      {super.key, required this.onBack, required this.onOpenCourses});
  final VoidCallback onBack;
  final VoidCallback onOpenCourses;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _items = [
    _Notice(
        'demo-course',
        Icons.school_outlined,
        'Welcome to your learning dashboard',
        'Explore the creative courses and practice labs. Demo announcement.',
        'Today',
        hasCourseLink: true),
    _Notice(
        'demo-lesson',
        Icons.play_lesson_outlined,
        'New lesson announcements',
        'Course lesson announcements will appear here when connected to the course service. Demo content.',
        'Demo',
        hasCourseLink: true),
    _Notice(
        'demo-project',
        Icons.assignment_outlined,
        'Project reminder',
        'Save your practice work and add finished projects to your portfolio. Demo reminder.',
        'Demo'),
    _Notice(
        'demo-achievement',
        Icons.emoji_events_outlined,
        'Quiz achievements',
        'Challenge XP and achievements are stored locally on this device. Demo activity.',
        'Demo'),
    _Notice(
        'demo-support',
        Icons.support_agent_outlined,
        'Support replies',
        'Support history will appear here after a support backend is connected. Demo content.',
        'Demo'),
  ];
  Set<String> _read = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await LearningProgressStore.instance.readNotifications;
    if (mounted) setState(() => _read = value);
  }

  Future<void> _mark(String id) async {
    await LearningProgressStore.instance.markNotificationRead(id);
    await _load();
  }

  Future<void> _markAll() async {
    await LearningProgressStore.instance
        .markAllNotificationsRead(_items.map((n) => n.id));
    await _load();
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(14, 14, 20, 28), children: [
        Row(children: [
          IconButton(
              tooltip: 'Back',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(width: 2),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('UPDATES', style: AppText.label),
                const SizedBox(height: 6),
                Text('Notifications', style: AppText.h1)
              ])),
          TextButton(onPressed: _markAll, child: const Text('Mark all read'))
        ]),
        const SizedBox(height: 4),
        Text('Local demo feed • Not delivered to other students',
            style: AppText.caption),
        const SizedBox(height: 16),
        if (_items.every((n) => _read.contains(n.id)))
          GlassCard(
              padding: const EdgeInsets.all(24),
              child: Center(
                  child: Column(children: [
                const Icon(Icons.notifications_off_outlined,
                    color: AppColors.sky, size: 38),
                const SizedBox(height: 10),
                Text('You’re all caught up', style: AppText.h3)
              ]))),
        for (final n in _items.where((n) => !_read.contains(n.id)))
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                  onTap: () async {
                    await _mark(n.id);
                    if (!context.mounted) return;
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => _NotificationDetailScreen(
                        notice: n,
                        onOpenCourses: widget.onOpenCourses,
                      ),
                    ));
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(n.icon, color: AppColors.sky),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(n.title,
                                            style: AppText.h3
                                                .copyWith(fontSize: 15))),
                                    const Icon(Icons.circle,
                                        size: 8, color: AppColors.sky)
                                  ]),
                                  const SizedBox(height: 5),
                                  Text(n.body,
                                      style:
                                          AppText.body.copyWith(fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Text('${n.when} • Tap to mark as read',
                                      style: AppText.caption)
                                ]))
                          ])))),
      ]);
}

class _NotificationDetailScreen extends StatelessWidget {
  const _NotificationDetailScreen(
      {required this.notice, required this.onOpenCourses});
  final _Notice notice;
  final VoidCallback onOpenCourses;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notification')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          GlassCard(
            strong: true,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(notice.icon, size: 34, color: AppColors.sky),
                const SizedBox(height: 14),
                Text(notice.title, style: AppText.h2),
                const SizedBox(height: 8),
                Text('${notice.when} • Demo notification',
                    style: AppText.caption),
                const SizedBox(height: 18),
                Text(notice.body, style: AppText.body),
              ],
            ),
          ),
          if (notice.hasCourseLink) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                onOpenCourses();
              },
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Browse courses'),
            ),
          ],
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to notifications'),
          ),
        ]),
      );
}
