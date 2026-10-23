import 'package:flutter/material.dart';

import '../models/course.dart';

/// Course catalogue. Prices/durations/support text come from the website's script.js.
/// Later this can be loaded from the backend; screens will not need to change.
///
/// Course content lives outside the screens so curriculum can be reviewed and
/// updated without duplicating it in presentation code. Lesson outlines remain
/// previews until recordings and instructor material are connected.
class CourseRepository {
  CourseRepository._();

  static const _levelLabel = {
    'basic': 'Basic',
    'advanced': 'Advanced',
    'professional': 'Professional / Job-Oriented',
  };
  static const _levelShort = {
    'basic': 'Basic',
    'advanced': 'Advanced',
    'professional': 'Professional',
  };

  static const _support = {
    'basic': ['Live classes', 'Limited doubts', 'Basic project feedback'],
    'advanced': [
      'Live classes',
      'Regular doubts',
      'Project reviews',
      'WhatsApp support',
      'Portfolio guidance',
    ],
    'professional': [
      'Everything in Advanced',
      'Priority doubt support',
      'One-to-one project discussion',
      'WhatsApp support',
      'Phone call support when required',
      'Personal project feedback',
      'Freelancing guidance',
      'Career guidance',
    ],
  };

  static List<String> _features(
      String name, List<String> skills, String level) {
    switch (level) {
      case 'basic':
        return [
          'Fundamentals of $name',
          'Core skills: ${skills.join(', ')}',
          'Practical, project-based learning',
        ];
      case 'advanced':
        return [
          'Everything in Basic',
          'Deeper applied practice in $name',
          'Portfolio-focused project work',
        ];
      default:
        return [
          'Everything in Advanced',
          'Job-oriented, professional workflows',
          'Industry-focused projects for freelance or career use',
        ];
    }
  }

  static List<Plan> _plans(String name, List<String> skills,
      List<String> durations, List<int> prices) {
    const ids = ['basic', 'advanced', 'professional'];
    return [
      for (var i = 0; i < 3; i++)
        Plan(
          levelId: ids[i],
          label: _levelLabel[ids[i]]!,
          shortLabel: _levelShort[ids[i]]!,
          duration: durations[i],
          price: prices[i],
          features: _features(name, skills, ids[i]),
          support: _support[ids[i]]!,
        ),
    ];
  }

  static final List<Course> courses = [
    Course(
      id: 'video-editing',
      name: 'Video Editing',
      tagline: 'Shape raw footage into a clear, well-paced story.',
      description:
          'Build an edit from source footage: choose useful shots, establish a story, shape pacing, balance sound, refine colour, and deliver versions suited to their destination.',
      suitedFor:
          'Beginners and creators who want to edit short films, social videos, or client content with a repeatable workflow.',
      prerequisites: const [
        'No editing experience required',
        'A computer able to run an editing application'
      ],
      imageAsset: 'assets/images/courses/video editing.png',
      icon: Icons.movie_creation_outlined,
      skills: const ['Cutting & pacing', 'Sound design', 'Colour basics'],
      tools: const [],
      modules: const [
        CourseModule(title: 'Footage & Story', topics: [
          'Organise and review source footage',
          'Select takes for meaning and continuity',
          'Build a clear beginning, middle, and end'
        ]),
        CourseModule(title: 'Edit Rhythm', topics: [
          'Create a first assembly',
          'Refine timing and pacing',
          'Use transitions only when they support the cut'
        ]),
        CourseModule(title: 'Sound & Colour', topics: [
          'Clean dialogue and balance levels',
          'Layer music and useful effects',
          'Correct exposure and establish a consistent look'
        ]),
        CourseModule(title: 'Delivery', topics: [
          'Review picture and audio quality',
          'Export for web and social formats',
          'Package project files for handoff'
        ]),
      ],
      practiceProjects: const [
        'Edit a 20-second product story',
        'Create two different rhythms from the same footage',
        'Prepare a clean dialogue and music mix'
      ],
      finalProject:
          'Produce a 60–90 second story-led edit with a shot plan, balanced audio, a consistent colour pass, and delivery exports.',
      plans: _plans(
          'Video Editing',
          const ['Cutting & pacing', 'Sound design', 'Colour basics'],
          const ['3\u20134 Months', '4\u20135 Months', '5\u20136 Months'],
          const [1999, 3999, 5999]),
    ),
    Course(
      id: '2d-animation',
      name: '2D Animation',
      tagline: 'Give drawings weight, timing, and clear intent.',
      description:
          'Plan and animate expressive 2D movement with readable poses, deliberate timing, clean arcs, and a polished final pass.',
      suitedFor:
          'Illustrators and beginners interested in character motion, simple scenes, or animated explainers.',
      prerequisites: const [
        'Drawing experience helps but is not required',
        'Basic familiarity with a 2D drawing or animation app is useful'
      ],
      imageAsset: 'assets/images/courses/2d animation.png',
      icon: Icons.animation_outlined,
      skills: const [
        'Animation fundamentals',
        'Animation principles',
        'Creative visual production'
      ],
      tools: const [],
      modules: const [
        CourseModule(title: 'Plan the Motion', topics: [
          'Thumbnail key poses',
          'Choose an action and line of action',
          'Set timing with a simple exposure plan'
        ]),
        CourseModule(title: 'Timing & Spacing', topics: [
          'Block extremes and breakdowns',
          'Adjust spacing to control speed and weight',
          'Use anticipation and follow-through'
        ]),
        CourseModule(title: 'Arcs & Acting', topics: [
          'Keep paths of motion readable',
          'Use overlap to separate body parts',
          'Clarify the character’s intention'
        ]),
        CourseModule(title: 'Polish & Output', topics: [
          'Clean drawings without losing energy',
          'Add restrained secondary motion',
          'Export a review-ready animation'
        ]),
      ],
      practiceProjects: const [
        'Animate a bouncing object with changing weight',
        'Create a short anticipation-and-action cycle',
        'Polish a simple character turn'
      ],
      finalProject:
          'Create a short character action with a pose plan, readable timing, controlled arcs, and a clean playback export.',
      plans: _plans('2D Animation', const [
        'Animation fundamentals',
        'Animation principles',
        'Creative visual production'
      ], const [
        '4\u20135 Months',
        '5\u20136 Months',
        '6\u20137 Months'
      ], const [
        6999,
        9999,
        13999
      ]),
    ),
    Course(
      id: 'graphic-designing',
      name: 'Graphic Designing',
      tagline: 'Make visual messages clear, balanced, and memorable.',
      description:
          'Develop a design system from a brief by setting hierarchy, choosing type and colour, building layouts, and preparing consistent brand deliverables.',
      suitedFor:
          'New designers, small-business creators, and anyone making posters, social graphics, or basic brand materials.',
      prerequisites: const [
        'No formal design training required',
        'A vector or page-layout tool is recommended'
      ],
      imageAsset: 'assets/images/courses/graphic-designing.png',
      icon: Icons.palette_outlined,
      skills: const ['Composition', 'Branding basics', 'Social creatives'],
      tools: const [],
      modules: const [
        CourseModule(title: 'Read the Brief', topics: [
          'Identify audience and message',
          'Gather references with intent',
          'Write a concise visual direction'
        ]),
        CourseModule(title: 'Type & Hierarchy', topics: [
          'Choose type pairings for a purpose',
          'Build a clear reading order',
          'Use scale and spacing to guide attention'
        ]),
        CourseModule(title: 'Layout & Colour', topics: [
          'Compose with grids and alignment',
          'Build a useful colour palette',
          'Adapt one concept to multiple formats'
        ]),
        CourseModule(title: 'Identity & Delivery', topics: [
          'Create a compact visual identity',
          'Prepare accessible and legible variants',
          'Export organised files for print and screen'
        ]),
      ],
      practiceProjects: const [
        'Redesign a crowded event poster',
        'Create a three-tile social campaign',
        'Build a one-page mini brand guide'
      ],
      finalProject:
          'Deliver a small identity package with a primary graphic, two supporting layouts, and clearly named export files.',
      plans: _plans(
          'Graphic Designing',
          const ['Composition', 'Branding basics', 'Social creatives'],
          const ['3\u20134 Months', '4\u20135 Months', '5\u20136 Months'],
          const [1999, 3999, 5999]),
    ),
    Course(
      id: 'motion-graphics',
      name: 'Motion Graphics',
      tagline: 'Animate type and shapes with purposeful visual rhythm.',
      description:
          'Turn a message into a timed visual sequence using composition, keyframes, easing, typography, transitions, and a disciplined render workflow.',
      suitedFor:
          'Designers and editors who want to add animated titles, explainers, or branded motion to their work.',
      prerequisites: const [
        'Basic computer skills',
        'Design or editing experience is useful but not required'
      ],
      imageAsset: 'assets/images/courses/motion-graphics.png',
      icon: Icons.auto_awesome_motion_outlined,
      skills: const ['Keyframe animation', 'Typography motion', 'Compositing'],
      tools: const [],
      modules: const [
        CourseModule(title: 'Composition in Motion', topics: [
          'Plan a frame for movement',
          'Stage a focal point',
          'Use contrast and negative space over time'
        ]),
        CourseModule(title: 'Keyframes & Easing', topics: [
          'Set key poses and timing',
          'Shape acceleration with easing',
          'Use anticipation and overshoot sparingly'
        ]),
        CourseModule(title: 'Type & Transitions', topics: [
          'Animate typography for readability',
          'Design transitions that connect ideas',
          'Build a consistent visual rhythm'
        ]),
        CourseModule(title: 'Composite & Render', topics: [
          'Organise layers and precompositions',
          'Balance effects with legibility',
          'Render and check delivery settings'
        ]),
      ],
      practiceProjects: const [
        'Animate a typographic name card',
        'Create a shape-based transition',
        'Build a five-second title reveal'
      ],
      finalProject:
          'Create a 10–15 second motion piece that explains one idea through coordinated type, shape, timing, and sound.',
      plans: _plans(
          'Motion Graphics',
          const ['Keyframe animation', 'Typography motion', 'Compositing'],
          const ['3\u20134 Months', '4\u20135 Months', '6\u20137 Months'],
          const [5999, 7999, 11999]),
    ),
    Course(
      id: '3d-animation',
      name: '3D Animation',
      tagline: 'Build a scene from model and material to final render.',
      description:
          'Learn a practical 3D pipeline: shape a clean asset, assign materials, light and frame a scene, animate a simple action, and prepare a render.',
      suitedFor:
          'Learners curious about 3D scenes, product visuals, or entry-level animation workflows in Maya.',
      prerequisites: const [
        'No 3D background required',
        'A computer that can run Maya and render small scenes'
      ],
      imageAsset: 'assets/images/courses/3d animation.png',
      icon: Icons.view_in_ar_outlined,
      skills: const [
        '3D workflows',
        'Modelling & animation concepts',
        'Rendering concepts'
      ],
      tools: const ['Maya'],
      modules: const [
        CourseModule(title: 'Scene & Modelling Basics', topics: [
          'Navigate the viewport and scene graph',
          'Block simple forms with proportion',
          'Use clean naming and transforms'
        ]),
        CourseModule(title: 'Topology & Materials', topics: [
          'Refine a simple mesh for its purpose',
          'Assign materials and readable surface values',
          'Check scale and silhouette'
        ]),
        CourseModule(title: 'Light, Camera & Motion', topics: [
          'Frame a clear camera view',
          'Shape a subject with key and fill light',
          'Prepare a simple rig and key a short movement'
        ]),
        CourseModule(title: 'Render & Review', topics: [
          'Choose practical render settings',
          'Check noise, framing, and output size',
          'Package scene dependencies for review'
        ]),
      ],
      practiceProjects: const [
        'Model a small hard-surface prop',
        'Create a three-light product setup',
        'Animate a simple object turntable'
      ],
      finalProject:
          'Create a short product or prop showcase with a finished model, materials, lighting, camera movement, and a reviewed render.',
      plans: _plans('3D Animation', const [
        '3D workflows',
        'Modelling & animation concepts',
        'Rendering concepts'
      ], const [
        '5\u20136 Months',
        '6\u20137 Months',
        '7\u20138 Months'
      ], const [
        14999,
        17999,
        24999
      ]),
    ),
  ];
}
