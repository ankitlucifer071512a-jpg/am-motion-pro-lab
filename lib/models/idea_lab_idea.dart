class IdeaLabIdea {
  const IdeaLabIdea({
    required this.id,
    required this.title,
    required this.description,
    required this.learningObjective,
    required this.category,
    required this.tags,
    required this.difficulty,
    required this.practiceMinutes,
    required this.imageAsset,
    required this.software,
    required this.requiredAssets,
    required this.tutorialSteps,
    required this.assignment,
    required this.checklist,
    required this.relatedIdeaIds,
  });

  final String id;
  final String title;
  final String description;
  final String learningObjective;
  final String category;
  final List<String> tags;
  final String difficulty;
  final int? practiceMinutes;
  final String? imageAsset;
  final List<String> software;
  final List<String> requiredAssets;
  final List<String> tutorialSteps;
  final String assignment;
  final List<String> checklist;
  final List<String> relatedIdeaIds;

  String get durationLabel {
    final minutes = practiceMinutes;
    if (minutes == null) return '';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
  }

  bool get isBeginnerTutorial =>
      difficulty == 'Beginner' ||
      tags.any((tag) => tag.toLowerCase() == 'beginner tutorials');

  bool matchesCategory(String filter) {
    if (filter == 'All Ideas') return true;
    if (filter == 'Beginner Tutorials') return isBeginnerTutorial;
    return category == filter;
  }

  bool matchesSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [
      title,
      description,
      learningObjective,
      category,
      ...tags,
      ...software,
      assignment,
    ].any((value) => value.toLowerCase().contains(normalized));
  }
}
