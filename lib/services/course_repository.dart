import 'package:flutter/material.dart';

import '../models/course.dart';

/// Course catalogue. Prices/durations/support text come from the website's script.js.
/// Later this can be loaded from the backend; screens will not need to change.
///
/// NOTE: module titles/topics below are SAMPLE structure built from the website's
/// skill lists (the website has no module data yet). Replace with real modules.
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

  static List<CourseModule> _modules(String name, List<String> skills) => [
        CourseModule(title: '$name Fundamentals', topics: const [
          'Understanding the basics',
          'Tools and interface',
          'First practice exercises'
        ]),
        CourseModule(title: 'Core Skills', topics: skills),
        const CourseModule(title: 'Professional Workflow', topics: [
          'Working on real briefs',
          'Feedback and refinement',
          'Export and delivery'
        ]),
        const CourseModule(title: 'Real Projects & Portfolio', topics: [
          'Project-based practice',
          'Portfolio building',
          'Freelance preparation'
        ]),
      ];

  static final List<Course> courses = [
    Course(
      id: 'video-editing',
      name: 'Video Editing',
      tagline: 'From fundamentals to professional editing workflows.',
      description:
          'Professional editing, storytelling, pacing, transitions, sound design and social-media-ready content.',
      imageAsset: 'assets/images/courses/video editing.png',
      icon: Icons.movie_creation_outlined,
      skills: const ['Cutting & pacing', 'Sound design', 'Colour basics'],
      tools: const [],
      modules: _modules('Video Editing',
          const ['Cutting & pacing', 'Sound design', 'Colour basics']),
      plans: _plans(
          'Video Editing',
          const ['Cutting & pacing', 'Sound design', 'Colour basics'],
          const ['3\u20134 Months', '4\u20135 Months', '5\u20136 Months'],
          const [1999, 3999, 5999]),
    ),
    Course(
      id: '2d-animation',
      name: '2D Animation',
      tagline: 'Learn animation workflows and build creative projects.',
      description:
          'Animation fundamentals, animation principles and creative visual production.',
      imageAsset: 'assets/images/courses/2d animation.png',
      icon: Icons.animation_outlined,
      skills: const [
        'Animation fundamentals',
        'Animation principles',
        'Creative visual production'
      ],
      tools: const [],
      modules: _modules('2D Animation', const [
        'Animation fundamentals',
        'Animation principles',
        'Creative visual production'
      ]),
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
      tagline: 'Build strong visual design and creative communication skills.',
      description:
          'Visual composition, branding, layouts, social creatives and core design fundamentals.',
      imageAsset: 'assets/images/courses/graphic-designing.png',
      icon: Icons.palette_outlined,
      skills: const ['Composition', 'Branding basics', 'Social creatives'],
      tools: const [],
      modules: _modules('Graphic Designing',
          const ['Composition', 'Branding basics', 'Social creatives']),
      plans: _plans(
          'Graphic Designing',
          const ['Composition', 'Branding basics', 'Social creatives'],
          const ['3\u20134 Months', '4\u20135 Months', '5\u20136 Months'],
          const [1999, 3999, 5999]),
    ),
    Course(
      id: 'motion-graphics',
      name: 'Motion Graphics',
      tagline: 'Create animated visuals that communicate ideas.',
      description:
          'Animation principles, typography animation, visual effects, compositing and motion design.',
      imageAsset: 'assets/images/courses/motion-graphics.png',
      icon: Icons.auto_awesome_motion_outlined,
      skills: const ['Keyframe animation', 'Typography motion', 'Compositing'],
      tools: const [],
      modules: _modules('Motion Graphics',
          const ['Keyframe animation', 'Typography motion', 'Compositing']),
      plans: _plans(
          'Motion Graphics',
          const ['Keyframe animation', 'Typography motion', 'Compositing'],
          const ['3\u20134 Months', '4\u20135 Months', '6\u20137 Months'],
          const [5999, 7999, 11999]),
    ),
    Course(
      id: '3d-animation',
      name: '3D Animation',
      tagline: 'Learn 3D Animation with Maya.',
      description:
          '3D workflows, modelling and animation concepts, and creative visual production.',
      imageAsset: 'assets/images/courses/3d animation.png',
      icon: Icons.view_in_ar_outlined,
      skills: const [
        '3D workflows',
        'Modelling & animation concepts',
        'Rendering concepts'
      ],
      tools: const ['Maya'],
      modules: _modules('3D Animation', const [
        '3D workflows',
        'Modelling & animation concepts',
        'Rendering concepts'
      ]),
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
