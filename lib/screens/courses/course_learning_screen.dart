import 'package:flutter/material.dart';

import '../../app/transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/course.dart';
import '../../services/learning_progress_store.dart';
import '../../widgets/app_button.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/learning_media_placeholder.dart';

enum CourseLearningTab { live, recorded }

/// Per-course learning hub. Sample lesson outlines are intentionally not
/// represented as hosted recordings or proof of enrollment.
class CourseLearningScreen extends StatefulWidget {
  const CourseLearningScreen({
    super.key,
    required this.course,
    this.initialTab = CourseLearningTab.recorded,
  });

  final Course course;
  final CourseLearningTab initialTab;

  static void open(BuildContext context, Course course,
      {CourseLearningTab tab = CourseLearningTab.recorded}) {
    Navigator.of(context).push(AppRoutes.fadeScale(
        CourseLearningScreen(course: course, initialTab: tab)));
  }

  @override
  State<CourseLearningScreen> createState() => _CourseLearningScreenState();
}

class _CourseLearningScreenState extends State<CourseLearningScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Set<String> _completed = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == CourseLearningTab.live ? 0 : 1,
    );
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final progress =
        await LearningProgressStore.instance.completedCourseLessons;
    if (!mounted) return;
    setState(() {
      _completed = progress
          .where((item) => item.startsWith('${widget.course.id}:'))
          .map((item) => item.substring(widget.course.id.length + 1))
          .toSet();
      _loaded = true;
    });
  }

  List<_Lesson> get _lessons {
    var order = 0;
    return [
      for (final module in widget.course.modules)
        for (final topic in module.topics)
          _Lesson(
            id: 'lesson-$order',
            module: module.title,
            title: topic,
            durationMinutes: 6 + (order * 3 % 9),
            order: ++order,
          ),
    ];
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessons = _lessons;
    final doneCount = lessons.where((l) => _completed.contains(l.id)).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.sensors_outlined), text: 'Live Classes'),
            Tab(
                icon: Icon(Icons.play_lesson_outlined),
                text: 'Recorded Classes'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _liveClasses(),
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            const _DemoNotice(
              title: 'Sample lesson outlines',
              message:
                  'These course-specific lesson titles are a preview. No recorded videos have been supplied or connected yet.',
              icon: Icons.info_outline,
            ),
            const SizedBox(height: 16),
            if (_loaded) ...[
              Text('LEARNING PROGRESS', style: AppText.label),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$doneCount of ${lessons.length} demo lessons',
                            style: AppText.h3),
                        const SizedBox(height: 4),
                        Text(
                            doneCount == 0
                                ? 'Progress is saved on this device.'
                                : 'Demo progress saved on this device.',
                            style: AppText.caption),
                      ],
                    ),
                  ),
                  CircularProgressIndicator(
                    value: lessons.isEmpty ? 0 : doneCount / lessons.length,
                    color: AppColors.sky,
                    backgroundColor: AppColors.glassBorder,
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Text('COURSE MODULES', style: AppText.label),
              const SizedBox(height: 8),
              for (final lesson in lessons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _LessonTile(
                    lesson: lesson,
                    completed: _completed.contains(lesson.id),
                    onTap: () => Navigator.of(context).push(AppRoutes.slideUp(
                      _SampleLessonScreen(
                        course: widget.course,
                        lesson: lesson,
                        completed: _completed.contains(lesson.id),
                        onComplete: () => _markComplete(lesson),
                      ),
                    )),
                  ),
                ),
            ] else
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator())),
          ],
        ),
      ]),
    );
  }

  Widget _liveClasses() => ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _DemoNotice(
            title: 'Live class setup pending',
            message:
                'No live schedule or streaming provider is connected. There are no upcoming or live sessions to join for ${widget.course.name}.',
            icon: Icons.videocam_off_outlined,
          ),
          const SizedBox(height: 18),
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Icon(Icons.event_busy_outlined,
                  size: 38, color: AppColors.sky),
              const SizedBox(height: 10),
              Text('No live classes scheduled yet',
                  style: AppText.h3, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                  'Class dates, instructors, reminders and Join access will appear here when configured.',
                  style: AppText.caption,
                  textAlign: TextAlign.center),
            ]),
          ),
          const SizedBox(height: 12),
          Text(
              'This course only shows its own live sessions. No “Live Now” or Join button is shown without a verified schedule and access check.',
              style: AppText.caption),
        ],
      );

  Future<void> _markComplete(_Lesson lesson) async {
    await LearningProgressStore.instance
        .completeCourseLesson(widget.course.id, lesson.id);
    if (!mounted) return;
    setState(() => _completed.add(lesson.id));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Demo lesson progress saved on this device.')));
  }
}

class _Lesson {
  const _Lesson(
      {required this.id,
      required this.module,
      required this.title,
      required this.durationMinutes,
      required this.order});
  final String id;
  final String module;
  final String title;
  final int durationMinutes;
  final int order;
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice(
      {required this.title, required this.message, required this.icon});
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => GlassCard(
        selected: true,
        padding: const EdgeInsets.all(15),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.sky),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: AppText.h3),
                const SizedBox(height: 4),
                Text(message, style: AppText.caption)
              ])),
        ]),
      );
}

class _LessonTile extends StatelessWidget {
  const _LessonTile(
      {required this.lesson, required this.completed, required this.onTap});
  final _Lesson lesson;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(
                        completed
                            ? Icons.check_circle_outline
                            : Icons.play_circle_outline,
                        color: completed ? AppColors.sky : AppColors.violet)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          'LESSON ${lesson.order.toString().padLeft(2, '0')} • ${lesson.module.toUpperCase()}',
                          style: AppText.label.copyWith(fontSize: 9)),
                      const SizedBox(height: 3),
                      Text(lesson.title,
                          style: AppText.h3.copyWith(fontSize: 14)),
                      const SizedBox(height: 3),
                      Text('Sample outline • ${lesson.durationMinutes} min',
                          style: AppText.caption),
                    ])),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.inkDim),
              ])),
        ),
      );
}

class _SampleLessonScreen extends StatelessWidget {
  const _SampleLessonScreen(
      {required this.course,
      required this.lesson,
      required this.completed,
      required this.onComplete});
  final Course course;
  final _Lesson lesson;
  final bool completed;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Lesson preview')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          const LearningMediaPlaceholder(
              type: LearningMediaType.video,
              caption: 'Recording unavailable • Sample lesson outline'),
          const SizedBox(height: 18),
          Text(course.name.toUpperCase(), style: AppText.label),
          const SizedBox(height: 5),
          Text(lesson.title, style: AppText.h1),
          const SizedBox(height: 8),
          Text(
              '${lesson.module} • ${lesson.durationMinutes} minutes • Sample outline',
              style: AppText.caption),
          const SizedBox(height: 18),
          const _DemoNotice(
              title: 'Video not configured',
              message:
                  'A recording has not been uploaded for this lesson. This screen does not stream sample or fabricated video.',
              icon: Icons.movie_outlined),
          const SizedBox(height: 20),
          if (completed)
            const _DemoNotice(
                title: 'Completed on this device',
                message:
                    'This is local demo progress. It does not indicate course enrollment.',
                icon: Icons.check_circle_outline)
          else
            AppButton(
                label: 'Mark demo outline complete',
                icon: Icons.check_rounded,
                onTap: onComplete),
        ]),
      );
}
