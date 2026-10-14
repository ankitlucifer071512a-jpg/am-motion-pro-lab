import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/creative_project.dart';
import '../../services/creative_project_store.dart';
import '../../widgets/glass_card.dart';

const _categories = [
  'Video Editing',
  'Motion Graphics',
  'Graphic Design',
  '2D Animation',
  '3D Animation'
];
const _levels = ['Beginner', 'Intermediate', 'Advanced'];
const _goals = [
  'Improve video editing',
  'Become a motion graphics designer',
  'Learn 3D animation',
  'Build a professional portfolio',
  'Prepare for freelance projects',
];

class CreativeProjectWorkspaceScreen extends StatefulWidget {
  const CreativeProjectWorkspaceScreen({super.key});
  @override
  State<CreativeProjectWorkspaceScreen> createState() =>
      _CreativeProjectWorkspaceScreenState();
}

class _CreativeProjectWorkspaceScreenState
    extends State<CreativeProjectWorkspaceScreen> {
  late Future<List<CreativeProject>> _projects =
      CreativeProjectStore.instance.getAll();
  String? _goal;

  @override
  void initState() {
    super.initState();
    CreativeProjectStore.instance.getGoal().then((value) {
      if (mounted) setState(() => _goal = value);
    });
  }

  void _reload() {
    setState(() {
      _projects = CreativeProjectStore.instance.getAll();
    });
  }

  String get _categoryForGoal {
    final goal = (_goal ?? '').toLowerCase();
    if (goal.contains('motion')) return 'Motion Graphics';
    if (goal.contains('3d')) return '3D Animation';
    if (goal.contains('video') || goal.contains('freelance')) {
      return 'Video Editing';
    }
    return 'Graphic Design';
  }

  Future<void> _createProject() async {
    final project = await showDialog<CreativeProject>(
      context: context,
      builder: (_) => _ProjectEditorDialog(initialCategory: _categoryForGoal),
    );
    if (project == null) return;
    await CreativeProjectStore.instance.save(project);
    _reload();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          CreativeProjectDetailScreen(project: project, onChanged: _reload),
    ));
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Creative Project Workspace')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createProject,
          icon: const Icon(Icons.add),
          label: const Text('New project'),
        ),
        body: FutureBuilder<List<CreativeProject>>(
          future: _projects,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                  child: Text(
                      'Projects could not be loaded. Please reopen this page.'));
            }
            final projects = snapshot.data ?? const <CreativeProject>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
              children: [
                Text('Your ideas, one step at a time.', style: AppText.h1),
                const SizedBox(height: 6),
                Text(
                    'Create a brief, track tasks, and keep your own notes on this device.',
                    style: AppText.body),
                const SizedBox(height: 15),
                GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                  child: DropdownButtonFormField<String>(
                    initialValue: _goal,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'My learning goal',
                        border: InputBorder.none),
                    hint: const Text('Choose a goal'),
                    items: [
                      for (final goal in _goals)
                        DropdownMenuItem(
                            value: goal,
                            child: Text(goal, overflow: TextOverflow.ellipsis))
                    ],
                    onChanged: (value) {
                      setState(() => _goal = value);
                      if (value != null) {
                        CreativeProjectStore.instance.setGoal(value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.all(13),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome_outlined,
                        color: AppColors.sky),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            'AI planning suggestions need the secure AI service, which is not connected yet.',
                            style: AppText.caption)),
                  ]),
                ),
                const SizedBox(height: 19),
                Row(children: [
                  Expanded(child: Text('My projects', style: AppText.h2)),
                  Text('${projects.length} saved', style: AppText.caption),
                ]),
                const SizedBox(height: 9),
                if (projects.isEmpty)
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      const Icon(Icons.folder_open_outlined,
                          size: 38, color: AppColors.sky),
                      const SizedBox(height: 8),
                      Text('No projects yet', style: AppText.h3),
                      const SizedBox(height: 4),
                      Text(
                          'Start with a small brief, then add practical tasks.',
                          textAlign: TextAlign.center,
                          style: AppText.body),
                    ]),
                  )
                else
                  for (final project in projects)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await Navigator.of(context)
                              .push(MaterialPageRoute<void>(
                            builder: (_) => CreativeProjectDetailScreen(
                                project: project, onChanged: _reload),
                          ));
                          _reload();
                        },
                        child: GlassCard(
                          padding: const EdgeInsets.all(15),
                          child: Row(children: [
                            Icon(
                                project.isComplete
                                    ? Icons.task_alt
                                    : Icons.folder_copy_outlined,
                                color: project.isComplete
                                    ? Colors.greenAccent
                                    : AppColors.sky),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(project.name, style: AppText.h3),
                                  Text(
                                      '${project.category} · ${project.difficulty}',
                                      style: AppText.caption),
                                  const SizedBox(height: 3),
                                  Text(
                                      '${project.tasks.where((task) => task.done).length}/${project.tasks.length} tasks · ${project.isComplete ? 'Portfolio ready' : 'In progress'}',
                                      style: AppText.caption),
                                ])),
                            const Icon(Icons.chevron_right,
                                color: AppColors.inkFaint),
                          ]),
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      );
}

class _ProjectEditorDialog extends StatefulWidget {
  const _ProjectEditorDialog({required this.initialCategory});
  final String initialCategory;
  @override
  State<_ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<_ProjectEditorDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _tasks = TextEditingController(
      text:
          'Write a short creative brief\nCreate the first draft\nReview and refine the result');
  late String _category = widget.initialCategory;
  String _level = _levels.first;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _tasks.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final now = DateTime.now();
    final tasks = _tasks.text
        .split('\n')
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    Navigator.of(context).pop(CreativeProject(
      id: 'project-${now.microsecondsSinceEpoch}',
      name: name,
      description: _description.text.trim(),
      category: _category,
      difficulty: _level,
      notes: '',
      tasks: [
        for (var i = 0; i < tasks.length; i++)
          CreativeProjectTask(id: '$i', title: tasks[i])
      ],
      createdAt: now,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create a project'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Project name')),
          TextField(
              controller: _description,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Description or brief')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final item in _categories)
                  DropdownMenuItem(value: item, child: Text(item))
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category)),
          DropdownButtonFormField<String>(
              initialValue: _level,
              decoration: const InputDecoration(labelText: 'Difficulty'),
              items: [
                for (final item in _levels)
                  DropdownMenuItem(value: item, child: Text(item))
              ],
              onChanged: (value) => setState(() => _level = value ?? _level)),
          TextField(
              controller: _tasks,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Starter checklist',
                  helperText: 'One task per line')),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: _save, child: const Text('Create'))
        ],
      );
}

class CreativeProjectDetailScreen extends StatefulWidget {
  const CreativeProjectDetailScreen(
      {super.key, required this.project, required this.onChanged});
  final CreativeProject project;
  final VoidCallback onChanged;
  @override
  State<CreativeProjectDetailScreen> createState() =>
      _CreativeProjectDetailScreenState();
}

class _EditProjectDialog extends StatefulWidget {
  const _EditProjectDialog({required this.project});
  final CreativeProject project;
  @override
  State<_EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends State<_EditProjectDialog> {
  late final _name = TextEditingController(text: widget.project.name);
  late final _description =
      TextEditingController(text: widget.project.description);
  late String _category = widget.project.category;
  late String _level = widget.project.difficulty;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit project'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Project name')),
          TextField(
              controller: _description,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Description or brief')),
          DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final item in _categories)
                  DropdownMenuItem(value: item, child: Text(item))
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category)),
          DropdownButtonFormField<String>(
              initialValue: _level,
              decoration: const InputDecoration(labelText: 'Difficulty'),
              items: [
                for (final item in _levels)
                  DropdownMenuItem(value: item, child: Text(item))
              ],
              onChanged: (value) => setState(() => _level = value ?? _level)),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _name.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                        context,
                        widget.project.copyWith(
                          name: _name.text.trim(),
                          description: _description.text.trim(),
                          category: _category,
                          difficulty: _level,
                        ),
                      ),
              child: const Text('Save')),
        ],
      );
}

class _CreativeProjectDetailScreenState
    extends State<CreativeProjectDetailScreen> {
  late CreativeProject _project = widget.project;
  late final _notes = TextEditingController(text: _project.notes);
  final _newTask = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    _newTask.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await CreativeProjectStore.instance
        .save(_project.copyWith(notes: _notes.text));
    if (mounted) widget.onChanged();
  }

  Future<void> _toggleTask(int index, bool? value) async {
    final tasks = [..._project.tasks];
    tasks[index] = tasks[index].copyWith(done: value ?? false);
    setState(() => _project = _project.copyWith(tasks: tasks));
    await _save();
  }

  Future<void> _addTask() async {
    final title = _newTask.text.trim();
    if (title.isEmpty) return;
    final task = CreativeProjectTask(
        id: DateTime.now().microsecondsSinceEpoch.toString(), title: title);
    setState(() {
      _project = _project.copyWith(tasks: [..._project.tasks, task]);
      _newTask.clear();
    });
    await _save();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete this project?'),
              content: const Text(
                  'This removes the project and its notes from this device.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'))
              ],
            ));
    if (confirm != true || !mounted) return;
    await CreativeProjectStore.instance.delete(_project.id);
    widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editDetails() async {
    final updated = await showDialog<CreativeProject>(
      context: context,
      builder: (_) => _EditProjectDialog(project: _project),
    );
    if (updated == null) return;
    setState(() => _project = updated);
    await _save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Project details'),
          actions: [
            IconButton(
                onPressed: _editDetails,
                tooltip: 'Edit project details',
                icon: const Icon(Icons.edit_outlined)),
            IconButton(
                onPressed: _delete,
                tooltip: 'Delete project',
                icon: const Icon(Icons.delete_outline))
          ],
        ),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
            children: [
              Text(_project.name, style: AppText.h1),
              const SizedBox(height: 4),
              Text(
                  '${_project.category} · ${_project.difficulty} · ${_project.isComplete ? 'Portfolio ready' : 'In progress'}',
                  style: AppText.caption),
              if (_project.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_project.description, style: AppText.body),
              ],
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: Text('Task checklist', style: AppText.h2)),
                Text(
                    '${_project.tasks.where((task) => task.done).length}/${_project.tasks.length}',
                    style: AppText.caption)
              ]),
              const SizedBox(height: 8),
              GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(children: [
                    for (var i = 0; i < _project.tasks.length; i++)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _toggleTask(i, !_project.tasks[i].done),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Checkbox(
                              value: _project.tasks[i].done,
                              onChanged: (value) => _toggleTask(i, value),
                            ),
                            Expanded(
                              child: Text(
                                _project.tasks[i].title,
                                style: AppText.body.copyWith(
                                  color: AppColors.ink,
                                  decoration: _project.tasks[i].done
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: _newTask,
                              onSubmitted: (_) => _addTask(),
                              decoration: const InputDecoration(
                                  hintText: 'Add a task', isDense: true))),
                      IconButton(
                          onPressed: _addTask,
                          tooltip: 'Add task',
                          icon: const Icon(Icons.add_circle_outline,
                              color: AppColors.sky))
                    ]),
                  ])),
              const SizedBox(height: 18),
              Text('Project notes', style: AppText.h2),
              const SizedBox(height: 7),
              TextField(
                  controller: _notes,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                      hintText: 'Ideas, feedback, next steps…',
                      alignLabelWithHint: true)),
              const SizedBox(height: 10),
              FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save notes')),
              const SizedBox(height: 12),
              Text(
                  'Project data is saved locally on this device. Reference-file sync and portfolio publishing need a backend.',
                  style: AppText.caption),
            ]),
      );
}
