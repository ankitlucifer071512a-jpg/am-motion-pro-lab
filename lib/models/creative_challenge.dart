/// A small, reusable unit of practice for the CreativeVerse arena.
class CreativeChallenge {
  const CreativeChallenge({
    required this.id,
    required this.title,
    required this.mode,
    required this.brief,
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.explanation,
    required this.hint,
    required this.skill,
    this.difficulty = 'Beginner',
    this.requiredSkills = const [],
    this.instructions = const [],
    this.referenceAssets = const [],
    this.evaluationCriteria = const [],
    this.completionSummary = '',
    this.xp = 30,
  });

  final String id;
  final String title;
  final String mode;
  final String brief;
  final String prompt;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  final String hint;
  final String skill;
  final String difficulty;
  final List<String> requiredSkills;
  final List<String> instructions;
  final List<String> referenceAssets;
  final List<String> evaluationCriteria;
  final String completionSummary;
  final int xp;
}

class ChallengeResult {
  const ChallengeResult({required this.correct, required this.xpEarned});
  final bool correct;
  final int xpEarned;
}

/// Shared scoring entry point. Correctness and learning are rewarded, not speed.
class CreativeChallengeEngine {
  const CreativeChallengeEngine();

  ChallengeResult evaluate(CreativeChallenge challenge, int selectedIndex) =>
      ChallengeResult(
        correct: selectedIndex == challenge.answerIndex,
        xpEarned: selectedIndex == challenge.answerIndex ? challenge.xp : 0,
      );
}
