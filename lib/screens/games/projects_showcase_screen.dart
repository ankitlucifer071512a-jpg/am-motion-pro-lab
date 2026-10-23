import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/showcase_project.dart';
import '../../services/showcase_project_repository.dart';
import '../../widgets/glass_card.dart';

class ProjectsShowcaseScreen extends StatelessWidget {
  const ProjectsShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Projects & Portfolio')),
        body: FutureBuilder<List<ShowcaseProject>>(
          future: ShowcaseProjectRepository.load(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Project samples could not load.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                Text('MAKE SOMETHING REAL', style: AppText.label),
                const SizedBox(height: 6),
                Text('Creative projects', style: AppText.h1),
                const SizedBox(height: 7),
                Text(
                  'Each card is a sample brief. Replace its preview and project entry with your own portfolio work.',
                  style: AppText.body,
                ),
                const SizedBox(height: 18),
                for (final project in snapshot.data!) ...[
                  _ProjectCard(
                    project: project,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProjectShowcaseDetail(project: project),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 5),
                Text(
                  'Add entries in assets/data/projects/project_catalog.json and previews in assets/images/projects/.',
                  style: AppText.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
      );
}

class ProjectShowcaseDetail extends StatelessWidget {
  const ProjectShowcaseDetail({super.key, required this.project});
  final ShowcaseProject project;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Project brief')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _ProjectArtwork(project: project, height: 230),
            const SizedBox(height: 16),
            Text('${project.category.toUpperCase()} · SAMPLE PROJECT',
                style: AppText.label),
            const SizedBox(height: 5),
            Text(project.title, style: AppText.h1),
            const SizedBox(height: 8),
            Text(project.description, style: AppText.body),
            const SizedBox(height: 20),
            _DetailSection(title: 'Project brief', children: [
              Text(project.brief, style: AppText.body),
            ]),
            const SizedBox(height: 14),
            _DetailSection(title: 'Tools used', children: [
              _Tags(values: project.tools),
            ]),
            const SizedBox(height: 14),
            _DetailSection(title: 'Learning outcomes', children: [
              for (final outcome in project.outcomes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 18, color: AppColors.sky),
                      const SizedBox(width: 9),
                      Expanded(child: Text(outcome, style: AppText.body)),
                    ],
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            _Tags(values: project.tags),
          ],
        ),
      );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onTap});
  final ShowcaseProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(17)),
                child: _ProjectArtwork(project: project, height: 168),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${project.category.toUpperCase()} · SAMPLE',
                        style: AppText.label),
                    const SizedBox(height: 5),
                    Text(project.title, style: AppText.h3),
                    const SizedBox(height: 5),
                    Text(project.description, style: AppText.caption),
                    const SizedBox(height: 10),
                    _Tags(values: project.tags),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ProjectArtwork extends StatelessWidget {
  const _ProjectArtwork({required this.project, required this.height});
  final ShowcaseProject project;
  final double height;

  @override
  Widget build(BuildContext context) {
    final image = project.imagePath;
    if (image != null) {
      return Image.asset(image,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder());
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: double.infinity,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF223D70), Color(0xFF171334), Color(0xFF0C1222)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -34,
              child: Container(
                width: height * .82,
                height: height * .82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.sky.withValues(alpha: .3), width: 2),
                  boxShadow: [
                    BoxShadow(color: AppColors.violet.withValues(alpha: .26), blurRadius: 36),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 14,
              right: 16,
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.sky),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('SAMPLE PREVIEW · ${project.category}',
                        style: AppText.label),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.h3),
            const SizedBox(height: 9),
            ...children,
          ],
        ),
      );
}

class _Tags extends StatelessWidget {
  const _Tags({required this.values});
  final List<String> values;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final value in values)
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(value, style: AppText.caption),
              ),
            ),
        ],
      );
}
