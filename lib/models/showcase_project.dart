class ShowcaseProject {
  const ShowcaseProject({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.brief,
    required this.tools,
    required this.outcomes,
    required this.tags,
    this.imagePath,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String brief;
  final List<String> tools;
  final List<String> outcomes;
  final List<String> tags;
  final String? imagePath;

  factory ShowcaseProject.fromJson(Map<String, dynamic> json) => ShowcaseProject(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        description: json['description'] as String,
        brief: json['brief'] as String,
        tools: (json['tools'] as List<dynamic>).cast<String>(),
        outcomes: (json['outcomes'] as List<dynamic>).cast<String>(),
        tags: (json['tags'] as List<dynamic>).cast<String>(),
        imagePath: json['imagePath'] as String?,
      );
}
