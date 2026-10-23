import '../models/idea_lab_idea.dart';

class IdeaLabRepository {
  IdeaLabRepository._();

  static const categories = [
    'All Ideas',
    'Video Editing',
    'Motion Graphics',
    '2D Animation',
    '3D Animation',
    'Graphic Design',
    'Branding & Advertising',
    'Visual Effects',
    'Beginner Tutorials',
  ];

  static const ideas = <IdeaLabIdea>[
    IdeaLabIdea(
      id: 'cinematic-product-reveal',
      title: 'Cinematic Product Reveal',
      description:
          'Build a compact product story that moves from an atmospheric detail to a clean, confident hero frame.',
      learningObjective:
          'Practice shot order, deliberate pacing, and a motivated final reveal.',
      category: 'Video Editing',
      tags: ['product film', 'storytelling', 'beginner tutorials'],
      difficulty: 'Beginner',
      practiceMinutes: 35,
      imageAsset: 'assets/images/courses/video editing.png',
      software: ['Any non-linear video editor'],
      requiredAssets: [
        'Three product shots: detail, process, and finished item',
        'One licensed music or ambience track'
      ],
      tutorialSteps: [
        'Choose a single product benefit and make it the story’s point of view.',
        'Open with a detail shot that creates a question without hiding the subject.',
        'Cut to one making or context shot, then let the clean hero frame resolve the story.',
        'Use music accents to support the cuts; keep dialogue and effects clear.',
        'Review the edit once without sound and once at phone-screen size.'
      ],
      assignment:
          'Edit a 15-second reveal for a handmade object using no more than six shots. End on a readable product frame and a simple call to action.',
      checklist: [
        'The opening shot creates visual interest',
        'The sequence clearly introduces and reveals the product',
        'The final frame stays readable for at least two seconds'
      ],
      relatedIdeaIds: [
        'real-estate-composition',
        'color-grading-before-after',
        'short-brand-ad'
      ],
    ),
    IdeaLabIdea(
      id: 'color-grading-before-after',
      title: 'Color-Grading Before & After',
      description:
          'Turn a flat daylight clip into a consistent, natural look while keeping skin and neutral surfaces believable.',
      learningObjective:
          'Separate exposure correction from creative color styling and compare both clearly.',
      category: 'Video Editing',
      tags: ['color', 'grading', 'beginner tutorials'],
      difficulty: 'Beginner',
      practiceMinutes: 30,
      imageAsset: 'assets/images/courses/video editing.png',
      software: ['A video editor with color controls'],
      requiredAssets: [
        'A short, well-exposed daylight clip',
        'A neutral reference such as a grey card or white surface'
      ],
      tutorialSteps: [
        'Duplicate the source clip so the original remains untouched.',
        'Correct white balance and exposure before adding a creative look.',
        'Adjust contrast gently and protect highlights from clipping.',
        'Use a split view or wipe to compare the corrected shot with the source.',
        'Check the result on a second display or a phone before exporting.'
      ],
      assignment:
          'Create a matched before-and-after grade for a 5-second clip. Keep neutral objects neutral and document the two correction moves that mattered most.',
      checklist: [
        'White balance is consistent',
        'Important highlights retain detail',
        'The comparison makes the change easy to evaluate'
      ],
      relatedIdeaIds: [
        'cinematic-product-reveal',
        'real-estate-composition',
        'brand-color-system'
      ],
    ),
    IdeaLabIdea(
      id: 'real-estate-composition',
      title: 'Real Estate Video Composition',
      description:
          'Shape a short room tour around clear sightlines, steady camera movement, and useful context rather than decorative cuts.',
      learningObjective:
          'Plan coverage that communicates room layout and keeps verticals visually stable.',
      category: 'Video Editing',
      tags: ['composition', 'camera', 'intermediate'],
      difficulty: 'Intermediate',
      practiceMinutes: 45,
      imageAsset: 'assets/images/courses/video editing.png',
      software: ['Any non-linear video editor'],
      requiredAssets: [
        'Wide, detail, and connecting shots from one room',
        'A simple room sequence or floor plan'
      ],
      tutorialSteps: [
        'Start with the widest stable shot that explains where the viewer is.',
        'Sequence rooms in the same order someone would naturally walk through them.',
        'Use details only when they clarify a feature or the room’s function.',
        'Trim camera starts and stops, and avoid cutting during a distracting wobble.',
        'Keep captions and transitions away from architectural details.'
      ],
      assignment:
          'Edit a 30-second walkthrough of one room and its connection to an adjacent space. Make the route understandable without narration.',
      checklist: [
        'The opening establishes the room layout',
        'The shot order follows a clear path',
        'No transition obscures an important feature'
      ],
      relatedIdeaIds: [
        'cinematic-product-reveal',
        'color-grading-before-after'
      ],
    ),
    IdeaLabIdea(
      id: 'glowing-flicker-typography',
      title: 'Glowing Flicker Typography',
      description:
          'Design a restrained neon title whose flicker feels like a purposeful sign switching on, not a random strobe.',
      learningObjective:
          'Combine type contrast, glow layers, and controlled timing without losing legibility.',
      category: 'Motion Graphics',
      tags: ['typography', 'glow', 'timing'],
      difficulty: 'Intermediate',
      practiceMinutes: 40,
      imageAsset: 'assets/images/courses/motion-graphics.png',
      software: ['A motion graphics or compositing application'],
      requiredAssets: [
        'A short title or two-word phrase',
        'A dark, uncluttered background'
      ],
      tutorialSteps: [
        'Choose a sturdy typeface and check the title at thumbnail size.',
        'Separate the crisp letterform from a softer, low-opacity glow layer.',
        'Animate one brief power-up flicker, then hold the title steady.',
        'Add a subtle reflected color only where it supports the composition.',
        'Preview at full speed and reduce glow until the letter edges stay clear.'
      ],
      assignment:
          'Create a 4-second title card with one controlled startup flicker and a 2-second readable hold. Keep the brightest glow inside the title silhouette.',
      checklist: [
        'The title is legible before and after the flicker',
        'The flicker has a clear beginning and end',
        'Glow does not merge neighboring letters'
      ],
      relatedIdeaIds: ['kinetic-typography', 'seamless-shape-transition'],
    ),
    IdeaLabIdea(
      id: 'seamless-shape-transition',
      title: 'Seamless Shape Transition',
      description:
          'Connect two graphic scenes with a shape that travels through the frame and gives the cut a clear visual reason.',
      learningObjective:
          'Use matching motion direction, scale, and timing to hide a scene change cleanly.',
      category: 'Motion Graphics',
      tags: ['transition', 'shapes', 'beginner tutorials'],
      difficulty: 'Beginner',
      practiceMinutes: 25,
      imageAsset: 'assets/images/courses/motion-graphics.png',
      software: ['A motion graphics application'],
      requiredAssets: [
        'Two still frames or simple graphic scenes',
        'One circle, bar, or other clean transition shape'
      ],
      tutorialSteps: [
        'Pick one shape that belongs naturally in both scenes.',
        'Animate it across the frame with a single consistent direction.',
        'Place the scene change when the shape fully covers the frame.',
        'Match the outgoing and incoming motion speeds across the cut.',
        'Remove extra blur or easing if it makes the movement feel soft.'
      ],
      assignment:
          'Build a one-second transition between two contrasting title cards using only one animated shape and one hidden cut.',
      checklist: [
        'Both scenes use the same movement direction',
        'The cut is hidden by the covering shape',
        'The transition remains readable at real speed'
      ],
      relatedIdeaIds: ['glowing-flicker-typography', 'animated-poster-design'],
    ),
    IdeaLabIdea(
      id: 'kinetic-typography',
      title: 'Typography Kinetic Animation',
      description:
          'Give a short spoken phrase visual rhythm by assigning each word an entrance that reinforces its meaning.',
      learningObjective:
          'Coordinate type movement, phrase timing, and hierarchy while maintaining comfortable reading time.',
      category: 'Motion Graphics',
      tags: ['type animation', 'rhythm', 'storytelling'],
      difficulty: 'Intermediate',
      practiceMinutes: 50,
      imageAsset: 'assets/images/courses/motion-graphics.png',
      software: ['A motion graphics application'],
      requiredAssets: [
        'A recorded or written phrase under eight words',
        'A timing guide or simple audio waveform'
      ],
      tutorialSteps: [
        'Mark the phrase’s stressed words and natural pauses.',
        'Choose one movement rule for stressed words and a quieter treatment for supporting words.',
        'Set key poses first, then refine spacing and easing between them.',
        'Hold each phrase long enough to read before introducing the next idea.',
        'Test the sequence with sound muted to confirm its meaning still reads.'
      ],
      assignment:
          'Animate a six-word phrase in six seconds. Use no more than two type styles and make the visual emphasis follow the spoken stress.',
      checklist: [
        'Emphasis follows the phrase’s meaning',
        'Words have enough time to be read',
        'Motion stays consistent across the sequence'
      ],
      relatedIdeaIds: [
        'glowing-flicker-typography',
        'seamless-shape-transition'
      ],
    ),
    IdeaLabIdea(
      id: 'animated-poster-design',
      title: 'Animated Poster Design',
      description:
          'Turn a still event poster into a short loop by animating one focal element while protecting the information hierarchy.',
      learningObjective:
          'Preserve poster readability while adding a single purposeful movement cue.',
      category: 'Graphic Design',
      tags: ['poster', 'layout', 'beginner tutorials'],
      difficulty: 'Beginner',
      practiceMinutes: 35,
      imageAsset: 'assets/images/courses/graphic-designing.png',
      software: ['A design tool and optional motion graphics app'],
      requiredAssets: [
        'Event name, date, venue, and one short supporting line',
        'A single licensed illustration or geometric focal element'
      ],
      tutorialSteps: [
        'Place the event name first and group the date and venue together.',
        'Check contrast and spacing before introducing any motion.',
        'Animate only the illustration or a small accent shape.',
        'Keep essential information stationary and visible through the full loop.',
        'Export a still frame and compare its reading order with the original.'
      ],
      assignment:
          'Create a looping 5-second event poster for a fictional animation workshop. Keep all event details readable throughout.',
      checklist: [
        'Event title is the first visual stop',
        'Date and venue are easy to locate',
        'The loop returns without a visible jump'
      ],
      relatedIdeaIds: ['brand-color-system', 'short-brand-ad'],
    ),
    IdeaLabIdea(
      id: 'bounce-timing-basics',
      title: 'Bounce Timing Fundamentals',
      description:
          'Make a simple bouncing ball feel heavy or light by changing its spacing, squash, and time in the air.',
      learningObjective:
          'Read motion through timing and spacing before adding decorative detail.',
      category: '2D Animation',
      tags: ['animation principles', 'timing', 'beginner tutorials'],
      difficulty: 'Beginner',
      practiceMinutes: 30,
      imageAsset: 'assets/images/courses/2d animation.png',
      software: ['Any 2D animation or drawing application'],
      requiredAssets: [
        'A simple circle drawing',
        'A baseline and a short frame-rate guide'
      ],
      tutorialSteps: [
        'Draw the contact pose, highest point, and next contact pose.',
        'Add more drawings near the top to create a slower moment in the air.',
        'Space drawings farther apart as the ball accelerates toward the ground.',
        'Compress the ball briefly on impact and restore its round shape as it lifts.',
        'Play the loop and remove drawings that make the action wobble.'
      ],
      assignment:
          'Animate three bounces: one heavy, one medium, and one light. Change timing and squash-and-stretch rather than changing the ball design.',
      checklist: [
        'The ball accelerates toward contact',
        'Impact has a readable squash and recovery',
        'Each bounce communicates a different weight'
      ],
      relatedIdeaIds: ['animated-poster-design', 'character-turntable'],
    ),
    IdeaLabIdea(
      id: '3d-product-lighting',
      title: '3D Product Lighting Setup',
      description:
          'Shape a small product with a broad key, controlled fill, and narrow rim so its silhouette separates from a dark studio.',
      learningObjective:
          'Build a repeatable three-light setup and judge material highlights without flattening form.',
      category: '3D Animation',
      tags: ['lighting', 'rendering', 'product'],
      difficulty: 'Intermediate',
      practiceMinutes: 55,
      imageAsset: 'assets/images/courses/3d animation.png',
      software: ['Blender, Maya, or another 3D package'],
      requiredAssets: [
        'A simple product mesh with at least one reflective material',
        'A neutral studio background'
      ],
      tutorialSteps: [
        'Set the camera and a neutral material before adjusting lights.',
        'Place a large key light to reveal the main surface and product shape.',
        'Raise a softer fill only enough to preserve shadow detail.',
        'Add a narrow rim light to separate the far edge from the background.',
        'Inspect highlights for clipping and render a small test before final quality.'
      ],
      assignment:
          'Render the same product with two key-light directions. Present both results and explain which surface details each setup reveals.',
      checklist: [
        'Key light establishes a clear form',
        'Fill preserves detail without removing all contrast',
        'Rim separates the silhouette without a hard halo'
      ],
      relatedIdeaIds: [
        'character-turntable',
        'camera-movement-3d',
        'cinematic-product-reveal'
      ],
    ),
    IdeaLabIdea(
      id: 'character-turntable',
      title: '3D Character Turntable',
      description:
          'Prepare a clean character rotation that keeps the face, silhouette, and lighting readable for a portfolio review.',
      learningObjective:
          'Align the camera, turntable speed, and light placement for a useful model presentation.',
      category: '3D Animation',
      tags: ['character', 'camera', 'animation'],
      difficulty: 'Intermediate',
      practiceMinutes: 60,
      imageAsset: 'assets/images/courses/3d animation.png',
      software: ['Blender, Maya, or another 3D package'],
      requiredAssets: [
        'A rigged or posed character model',
        'A simple studio floor and background'
      ],
      tutorialSteps: [
        'Set the character in a relaxed pose with a readable silhouette.',
        'Frame the full body with a small amount of breathing room.',
        'Use a stable key and fill, then add a subtle rim for separation.',
        'Animate a slow, constant 360-degree rotation around the character.',
        'Check the front, profile, and back views for clipping and distracting shadows.'
      ],
      assignment:
          'Create a 10-second turntable that completes one smooth rotation. Keep the character inside frame and include one neutral still for pose review.',
      checklist: [
        'The complete model stays inside the camera frame',
        'Rotation speed is even',
        'The face and silhouette remain readable'
      ],
      relatedIdeaIds: [
        '3d-product-lighting',
        'camera-movement-3d',
        'bounce-timing-basics'
      ],
    ),
    IdeaLabIdea(
      id: 'camera-movement-3d',
      title: 'Camera Movement for 3D Scenes',
      description:
          'Use a short, motivated camera move to reveal depth and guide attention through a small 3D scene.',
      learningObjective:
          'Plan camera paths around a focal subject and reduce acceleration that distracts from it.',
      category: '3D Animation',
      tags: ['camera', 'composition', 'scene'],
      difficulty: 'Advanced',
      practiceMinutes: 65,
      imageAsset: 'assets/images/courses/3d animation.png',
      software: ['Blender, Maya, or another 3D package'],
      requiredAssets: [
        'A small scene with a clear focal subject',
        'A camera target or framing reference'
      ],
      tutorialSteps: [
        'Choose the detail the viewer should notice first and set the opening frame.',
        'Sketch the camera path with a start, one reveal, and a clean end frame.',
        'Keep the focal point inside frame as the camera travels.',
        'Ease into and out of the move so the scene settles naturally.',
        'Preview with a proxy render and remove any path segment that adds no information.'
      ],
      assignment:
          'Create a 6-second camera move that reveals one focal object from behind a foreground shape without losing the subject.',
      checklist: [
        'The camera move reveals new scene information',
        'The subject stays framed during the move',
        'The final camera settles without a visible jolt'
      ],
      relatedIdeaIds: ['3d-product-lighting', 'character-turntable'],
    ),
    IdeaLabIdea(
      id: 'brand-color-system',
      title: 'Brand Identity Color System',
      description:
          'Build a compact palette with a clear primary color, supporting neutrals, and an accent that remains accessible in real layouts.',
      learningObjective:
          'Assign palette roles and test contrast instead of selecting colors only by preference.',
      category: 'Graphic Design',
      tags: ['branding', 'color', 'beginner tutorials'],
      difficulty: 'Beginner',
      practiceMinutes: 40,
      imageAsset: 'assets/images/courses/graphic-designing.png',
      software: ['Any design or vector application'],
      requiredAssets: [
        'A one-sentence fictional brand brief',
        'A contrast checker or grayscale preview'
      ],
      tutorialSteps: [
        'Write down the intended audience and the feeling the brand should communicate.',
        'Choose one primary color and two neutrals before adding an accent.',
        'Assign each swatch a role such as background, text, action, or highlight.',
        'Test text and button combinations at small sizes and in grayscale.',
        'Document the palette with color values and one example application.'
      ],
      assignment:
          'Create a five-swatch identity palette for a fictional nature-focused studio and apply it to one social tile and one small call-to-action.',
      checklist: [
        'Each color has a defined role',
        'Text and action colors have sufficient contrast',
        'The palette still feels coherent in two layouts'
      ],
      relatedIdeaIds: [
        'animated-poster-design',
        'short-brand-ad',
        'kinetic-typography'
      ],
    ),
    IdeaLabIdea(
      id: 'short-brand-ad',
      title: '15-Second Brand Advertisement',
      description:
          'Plan a concise fictional brand spot that links one audience need to one memorable visual benefit.',
      learningObjective:
          'Translate a simple brief into a focused message, shot plan, and clear end card.',
      category: 'Branding & Advertising',
      tags: ['advertising', 'storyboard', 'brand'],
      difficulty: 'Intermediate',
      practiceMinutes: 50,
      imageAsset: 'assets/images/courses/motion-graphics.png',
      software: ['Any video editor or motion graphics app'],
      requiredAssets: [
        'A fictional brand name and one-sentence audience brief',
        'Three original or properly licensed visual references'
      ],
      tutorialSteps: [
        'Write one audience problem and one specific product benefit.',
        'Plan a hook, a proof point, and a concise brand resolution.',
        'Assign only the shots needed to communicate those three beats.',
        'Keep the brand mark and call to action on screen long enough to read.',
        'Review the spot with sound muted to verify the visual message.'
      ],
      assignment:
          'Storyboard a 15-second advertisement for a fictional reusable bottle brand in five frames. Use one claim that the visuals can honestly support.',
      checklist: [
        'The spot has one focused audience benefit',
        'Each planned shot supports the same message',
        'The end card includes a clear fictional brand sign-off'
      ],
      relatedIdeaIds: [
        'brand-color-system',
        'cinematic-product-reveal',
        'animated-poster-design'
      ],
    ),
    IdeaLabIdea(
      id: 'screen-replacement-vfx',
      title: 'Clean Screen Replacement',
      description:
          'Replace a blank device display while preserving perspective, reflections, and believable motion across the shot.',
      learningObjective:
          'Track a planar surface and integrate replacement imagery without flattening the photographed device.',
      category: 'Visual Effects',
      tags: ['compositing', 'tracking', 'intermediate'],
      difficulty: 'Advanced',
      practiceMinutes: 70,
      imageAsset: null,
      software: ['A compositor with planar tracking tools'],
      requiredAssets: [
        'A short shot of a device with a blank or simple screen',
        'Replacement artwork created for this exercise'
      ],
      tutorialSteps: [
        'Choose a shot with visible screen corners and limited motion blur.',
        'Track the display plane and review the track at the beginning and end.',
        'Corner-pin the replacement image and crop it just inside the screen bezel.',
        'Restore subtle reflections or glare above the replacement layer.',
        'Check edges at full resolution and inspect the composite in motion.'
      ],
      assignment:
          'Composite an original app mockup into a 5-second device shot. Preserve at least one natural reflection and keep the replacement aligned through the whole move.',
      checklist: [
        'The screen track remains attached at every frame',
        'The replacement respects the screen bezel',
        'Reflections and edge softness match the source shot'
      ],
      relatedIdeaIds: [
        'glowing-flicker-typography',
        'cinematic-product-reveal',
        'camera-movement-3d'
      ],
    ),
    IdeaLabIdea(
      id: 'logo-motion-study',
      title: 'Smooth Logo Animation',
      description:
          'Animate a simple original mark with a clear reveal, balanced easing, and a final hold that respects its static proportions.',
      learningObjective:
          'Create logo motion that supports brand character without distorting the mark.',
      category: 'Branding & Advertising',
      tags: ['logo', 'motion graphics', 'beginner tutorials'],
      difficulty: 'Beginner',
      practiceMinutes: 35,
      imageAsset: 'assets/images/courses/motion-graphics.png',
      software: ['A vector tool and optional motion graphics app'],
      requiredAssets: [
        'An original simple wordmark or geometric symbol',
        'A flat-color background'
      ],
      tutorialSteps: [
        'Check the mark’s static silhouette and define a safe area around it.',
        'Choose a reveal based on the shape’s construction rather than a preset effect.',
        'Animate the reveal with one primary movement and restrained easing.',
        'Settle at the exact original logo proportions and hold for readability.',
        'Compare the first and final frames to ensure the identity has not changed.'
      ],
      assignment:
          'Create a 4-second reveal for an original fictional studio mark. Use one movement idea and finish on a clean, undistorted lockup.',
      checklist: [
        'The mark remains recognizable during its reveal',
        'The final logo matches its original proportions',
        'The ending hold is long enough to read'
      ],
      relatedIdeaIds: [
        'brand-color-system',
        'kinetic-typography',
        'seamless-shape-transition'
      ],
    ),
    IdeaLabIdea(
      id: 'light-wrap-composite',
      title: 'Subtle Light Wrap Composite',
      description:
          'Integrate a keyed subject against a new background by borrowing a small amount of edge color and light direction.',
      learningObjective:
          'Improve subject integration while keeping the matte clean and the wrap effect restrained.',
      category: 'Visual Effects',
      tags: ['keying', 'compositing', 'advanced'],
      difficulty: 'Advanced',
      practiceMinutes: 60,
      imageAsset: null,
      software: ['A compositor with keying and matte controls'],
      requiredAssets: [
        'A short, evenly lit green-screen clip',
        'A background with a distinct but soft light direction'
      ],
      tutorialSteps: [
        'Create a clean matte before adding any edge treatment.',
        'Place the subject over the new background and match overall exposure.',
        'Sample only the nearby background color for a narrow edge wrap.',
        'Mask the wrap to the light-facing edge and keep it behind the subject detail.',
        'Toggle the effect at full size and inspect hair and high-contrast edges.'
      ],
      assignment:
          'Composite a short original subject clip into a new environment. Compare the result with and without a restrained directional light wrap.',
      checklist: [
        'The matte has no obvious green fringe',
        'Edge color comes from the replacement environment',
        'The wrap does not wash out facial or costume detail'
      ],
      relatedIdeaIds: [
        'screen-replacement-vfx',
        '3d-product-lighting',
        'color-grading-before-after'
      ],
    ),
    IdeaLabIdea(
      id: 'editorial-brand-layout',
      title: 'Editorial Brand Layout',
      description:
          'Create a social launch tile that pairs one strong headline with a supporting image, useful spacing, and a consistent brand accent.',
      learningObjective:
          'Apply typographic hierarchy and a repeatable color system to a compact communication.',
      category: 'Graphic Design',
      tags: ['layout', 'typography', 'branding'],
      difficulty: 'Intermediate',
      practiceMinutes: 45,
      imageAsset: 'assets/images/courses/graphic-designing.png',
      software: ['Any design or vector application'],
      requiredAssets: [
        'A short fictional event or product announcement',
        'One original or properly licensed supporting image'
      ],
      tutorialSteps: [
        'Write a headline that communicates one idea without supporting copy.',
        'Establish a strong alignment edge and a deliberate margin system.',
        'Use type scale and weight to separate the headline from the details.',
        'Apply one brand accent to guide attention toward the next action.',
        'Check contrast, safe areas, and legibility at a phone-sized preview.'
      ],
      assignment:
          'Design a 1080-square fictional launch tile with one headline, one detail line, and a clear brand accent. Make a second version for a dark background.',
      checklist: [
        'Headline and details have distinct hierarchy',
        'Margins and alignment feel intentional',
        'Both color versions preserve readable contrast'
      ],
      relatedIdeaIds: [
        'brand-color-system',
        'animated-poster-design',
        'short-brand-ad'
      ],
    ),
  ];

  static IdeaLabIdea byId(String id) =>
      ideas.firstWhere((idea) => idea.id == id);

  static List<IdeaLabIdea> relatedTo(IdeaLabIdea idea) => [
        for (final id in idea.relatedIdeaIds)
          for (final candidate in ideas)
            if (candidate.id == id) candidate,
      ];
}
