import '../models/creative_challenge.dart';

/// Curated sample missions. These are local examples, not AI-generated data.
class CreativeChallengeRepository {
  CreativeChallengeRepository._();

  static const missions = <CreativeChallenge>[
    CreativeChallenge(
      id: 'creativeverse-rescue-poster-v1',
      title: 'Rescue the launch poster',
      mode: 'ColorCraft',
      brief:
          'A student has 3 seconds to notice a weekend design workshop poster.',
      prompt: 'What is the strongest first fix for this crowded poster?',
      options: [
        'Make the event title the clear focal point and add breathing room',
        'Add two decorative fonts and more small labels',
        'Reduce every text size so the background image feels larger',
      ],
      answerIndex: 0,
      explanation:
          'One clear focal point and enough negative space help the viewer understand the event quickly. Supporting details can come second.',
      hint:
          'Think about what a viewer should understand first, before reading details.',
      skill: 'Visual hierarchy',
      difficulty: 'Beginner',
      requiredSkills: ['Typography basics', 'Visual hierarchy'],
      instructions: [
        'Study the crowded poster preview.',
        'Choose the single change that improves the reading order first.',
        'Use the explanation to plan one refinement for your next design.',
      ],
      referenceAssets: ['Crowded weekend workshop poster preview'],
      evaluationCriteria: [
        'Clear focal point',
        'Readable event title',
        'Useful negative space'
      ],
      completionSummary:
          'You practiced prioritizing a message before decorating it.',
      xp: 30,
    ),
    CreativeChallenge(
      id: 'creativeverse-edit-sequence-v1',
      title: 'Build a clear product edit',
      mode: 'EditRush',
      brief:
          'A 10-second product edit needs to introduce a handmade coffee mug.',
      prompt: 'Which opening sequence gives the viewer useful context?',
      options: [
        'Show the workspace, then the making action, then the finished mug',
        'Show three close-ups of the handle, then an unrelated title',
        'Start with the final frame and cut randomly between shots',
      ],
      answerIndex: 0,
      explanation:
          'A context shot followed by action and result gives a short edit a readable visual story.',
      hint:
          'Think about the order that helps a viewer understand place, action, and result.',
      skill: 'Editing rhythm',
      difficulty: 'Beginner',
      requiredSkills: ['Shot selection', 'Story sequence'],
      instructions: [
        'Imagine the three clips in the brief.',
        'Choose an order that communicates context, action, and result.',
        'Try to keep each shot long enough to understand.',
      ],
      referenceAssets: [
        'Workspace establishing shot',
        'Mug shaping shot',
        'Finished mug close-up'
      ],
      evaluationCriteria: [
        'Context comes first',
        'Action is easy to follow',
        'Result feels earned'
      ],
      completionSummary:
          'You practiced sequencing shots to tell a compact visual story.',
      xp: 30,
    ),
    CreativeChallenge(
      id: 'creativeverse-model-light-v1',
      title: 'Give a 3D portrait more depth',
      mode: 'ModelVerse',
      brief:
          'A 3D character render looks flat against a dark studio background.',
      prompt: 'Which lighting adjustment is a useful first experiment?',
      options: [
        'Keep a key light, add softer fill, and use a rim for separation',
        'Use equally bright lights from every direction',
        'Turn off the key light and brighten only the background',
      ],
      answerIndex: 0,
      explanation:
          'A key, fill, and rim can shape the face while separating the subject from the background.',
      hint:
          'Look for a setup that keeps form visible and separates the silhouette.',
      skill: '3D lighting',
      difficulty: 'Intermediate',
      requiredSkills: ['Light direction', 'Subject separation'],
      instructions: [
        'Notice the flat silhouette in the scene description.',
        'Choose a lighting setup that shapes the face and separates the outline.',
        'In a 3D tool, test the key light before adding subtle fill and rim.',
      ],
      referenceAssets: ['Dark studio portrait scene description'],
      evaluationCriteria: [
        'Readable key direction',
        'Controlled shadow fill',
        'Subject separated from background'
      ],
      completionSummary: 'You practiced using light to reveal form and depth.',
      xp: 35,
    ),
  ];

  static CreativeChallenge get daily => missions.first;
}
