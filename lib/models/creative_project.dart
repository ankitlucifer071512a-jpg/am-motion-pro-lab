class CreativeProject {
  const CreativeProject({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.notes,
    required this.tasks,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String difficulty;
  final String notes;
  final List<CreativeProjectTask> tasks;
  final DateTime createdAt;

  bool get isComplete => tasks.isNotEmpty && tasks.every((task) => task.done);

  CreativeProject copyWith({
    String? name,
    String? description,
    String? category,
    String? difficulty,
    String? notes,
    List<CreativeProjectTask>? tasks,
  }) =>
      CreativeProject(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category ?? this.category,
        difficulty: difficulty ?? this.difficulty,
        notes: notes ?? this.notes,
        tasks: tasks ?? this.tasks,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'difficulty': difficulty,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'tasks': [for (final task in tasks) task.toJson()],
      };

  factory CreativeProject.fromJson(Map<String, Object?> json) =>
      CreativeProject(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Untitled project',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'Graphic Design',
        difficulty: json['difficulty'] as String? ?? 'Beginner',
        notes: json['notes'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        tasks: (json['tasks'] as List<Object?>? ?? const [])
            .whereType<Map<String, Object?>>()
            .map(CreativeProjectTask.fromJson)
            .toList(),
      );
}

class CreativeProjectTask {
  const CreativeProjectTask(
      {required this.id, required this.title, this.done = false});
  final String id;
  final String title;
  final bool done;

  CreativeProjectTask copyWith({bool? done}) => CreativeProjectTask(
        id: id,
        title: title,
        done: done ?? this.done,
      );

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'done': done};

  factory CreativeProjectTask.fromJson(Map<String, Object?> json) =>
      CreativeProjectTask(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        done: json['done'] as bool? ?? false,
      );
}
