class LearningChallenge {
  const LearningChallenge({
    required this.id,
    required this.title,
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.explanation,
    this.visualLabel = 'Lesson visual placeholder',
  });

  final String id;
  final String title;
  final String prompt;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  final String visualLabel;
}
