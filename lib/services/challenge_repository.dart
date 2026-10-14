import '../models/course.dart';
import '../models/learning_challenge.dart';

/// Expandable lesson-linked challenge catalogue for the local learning demo.
class ChallengeRepository {
  ChallengeRepository._();

  static final Map<String, List<LearningChallenge>> _byCourse = {
    'video-editing': _set('video', [
      _c(
          'Timeline ordering',
          'Which sequence makes a clear short story?',
          [
            'Establishing shot → action → reaction',
            'Reaction → ending → establishing shot',
            'Random clips → title → action'
          ],
          0,
          'A wide establishing shot gives context before action and reaction.'),
      _c(
          'Transition matching',
          'A new location begins. Which edit usually keeps the story clear?',
          [
            'Hard cut on the action',
            'Long decorative spin',
            'Cross dissolve between every clip'
          ],
          0,
          'A motivated cut keeps the pace direct; transitions should support meaning.'),
      _c(
          'Pacing challenge',
          'A quiet reflective moment needs what pacing?',
          [
            'Longer holds and fewer cuts',
            'Rapid cuts every few frames',
            'A transition on every beat'
          ],
          0,
          'Longer holds give the viewer time to read the emotion.'),
      _c(
          'Sound matching',
          'Which sound layer helps a door closing feel grounded?',
          [
            'A synced door close effect',
            'A random applause track',
            'A continuous alarm'
          ],
          0,
          'A synced effect reinforces the visible action.'),
    ]),
    'graphic-designing': _set('design', [
      _c(
          'Color combination',
          'Which palette suits a calm wellness brand?',
          [
            'Muted teal, warm cream, soft sage',
            'Neon red, lime, bright violet',
            'Four equally saturated primaries'
          ],
          0,
          'Related muted hues create a calm, coherent impression.'),
      _c(
          'Typography matching',
          'For a readable event poster, choose:',
          [
            'A display headline with a simple body face',
            'Three decorative script fonts',
            'Only condensed capitals at tiny sizes'
          ],
          0,
          'Contrast in role with readable body text creates a clear hierarchy.'),
      _c(
          'Layout challenge',
          'Where should the primary headline sit?',
          [
            'At the strongest focal point with clear spacing',
            'Over the busiest image detail',
            'At the edge with no margin'
          ],
          0,
          'A focal position and breathing room improve scanning.'),
      _c(
          'Contrast test',
          'Which choice improves small text readability?',
          [
            'Dark text on a light plain surface',
            'Pale grey text over a busy photo',
            'Two similar mid-tone colors'
          ],
          0,
          'Strong luminance contrast makes text easier to read.'),
    ]),
    'motion-graphics': _set('motion', [
      _c(
          'Animation timing',
          'A short logo reveal should usually feel:',
          [
            'Clear and intentional, with time to read',
            'So fast it cannot be seen',
            'The same duration as a long credit roll'
          ],
          0,
          'Readable timing respects the message and viewing context.'),
      _c(
          'Keyframe ordering',
          'What is the usual order for a simple move?',
          [
            'Start pose → travel → settled end pose',
            'End pose → start pose → travel',
            'Travel → start pose → end pose'
          ],
          0,
          'The movement needs a start, trajectory, and resolved end.'),
      _c(
          'Easing comparison',
          'Which curve gives a natural stop?',
          [
            'Ease out near the destination',
            'Constant speed through the stop',
            'Abruptly reverse at the end'
          ],
          0,
          'Ease out reduces speed as the object approaches its destination.'),
      _c(
          'Typography animation',
          'A serious safety message benefits from:',
          [
            'A restrained, readable reveal',
            'Unpredictable bouncing on every word',
            'Rapid spinning that obscures the text'
          ],
          0,
          'Motion should reinforce tone while keeping the words legible.'),
    ]),
    '2d-animation': _set('animation2d', [
      _c(
          'Pose ordering',
          'Which order communicates a jump?',
          [
            'Anticipation → take-off → airborne → landing',
            'Landing → airborne → anticipation → take-off',
            'Take-off → landing → anticipation → airborne'
          ],
          0,
          'Preparation, action, and recovery make the movement readable.'),
      _c(
          'Squash and stretch',
          'When is squash and stretch most useful?',
          [
            'To emphasize impact while preserving volume',
            'To randomly change character size',
            'To remove all weight from motion'
          ],
          0,
          'Controlled deformation adds force and flexibility while keeping volume believable.'),
      _c(
          'Timing and spacing',
          'To show acceleration, frame spacing should:',
          [
            'Grow farther apart over time',
            'Stay identical in every frame',
            'Move backward from the target'
          ],
          0,
          'Increasing spacing communicates increasing speed.'),
      _c(
          'Storyboard ordering',
          'What normally introduces a scene?',
          [
            'An establishing panel showing place',
            'A close detail with no context',
            'A final reaction before the action'
          ],
          0,
          'An establishing view helps orient the audience.'),
    ]),
    '3d-animation': _set('animation3d', [
      _c(
          'Identify 3D tools',
          'Which viewport tool moves a selected object?',
          [
            'Translate / move gizmo',
            'Render output settings',
            'Material preview sphere'
          ],
          0,
          'The translate gizmo changes an object’s position in 3D space.'),
      _c(
          'Model workflow',
          'A clean asset workflow begins with:',
          [
            'Reference and blockout',
            'Final lighting before geometry',
            'Rigging before a model exists'
          ],
          0,
          'Reference and a simple blockout establish proportions early.'),
      _c(
          'Production ordering',
          'Choose a practical character pipeline:',
          [
            'Model → texture → rig → light → animate',
            'Animate → model → light → texture → rig',
            'Light → rig → animate → model → texture'
          ],
          0,
          'Build the asset before rigging and animation; lighting follows scene assembly.'),
      _c(
          'Camera and lighting',
          'Which setup often gives a portrait depth?',
          [
            'Key light plus softer fill and rim separation',
            'Flat light from every direction',
            'Camera facing directly into a bright source'
          ],
          0,
          'A key, fill, and rim can separate subject planes while retaining readable shadows.'),
    ]),
  };

  static List<LearningChallenge> forCourse(Course course) =>
      _byCourse[course.id] ?? const [];
  static LearningChallenge _c(String title, String prompt, List<String> options,
          int answer, String why) =>
      LearningChallenge(
          id: title,
          title: title,
          prompt: prompt,
          options: options,
          answerIndex: answer,
          explanation: why,
          visualLabel: 'Visual question • ${title.toLowerCase()}');
  static List<LearningChallenge> _set(
          String prefix, List<LearningChallenge> items) =>
      [
        for (var i = 0; i < items.length; i++)
          LearningChallenge(
              id: '$prefix-$i',
              title: items[i].title,
              prompt: items[i].prompt,
              options: items[i].options,
              answerIndex: items[i].answerIndex,
              explanation: items[i].explanation,
              visualLabel: items[i].visualLabel)
      ];
}
